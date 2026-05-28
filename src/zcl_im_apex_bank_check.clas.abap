class ZCL_IM_APEX_BANK_CHECK definition
  public
  final
  create public .

public section.

  interfaces IF_EX_BUPA_BANK_CHECK .
protected section.
private section.
ENDCLASS.



CLASS ZCL_IM_APEX_BANK_CHECK IMPLEMENTATION.


  METHOD if_ex_bupa_bank_check~check.
    DATA:
      iv_country              TYPE string,
      iv_bank_account_holder  TYPE string,
      iv_account_number       TYPE string,
      iv_bank_code            TYPE string,
      iv_iban                 TYPE string,
      iv_swift_code           TYPE string,
      iv_taxidnumber          TYPE string,
      lv_offset               TYPE i,
      lv_name                 TYPE c LENGTH 20,
      lv_value                TYPE c LENGTH 20,
      lv_result               TYPE c LENGTH 40,
      ls_return               TYPE bapiret2,
      lv_errflg               TYPE c,
      iv_company_name         TYPE string,
      iv_tax_number           TYPE string,
      iv_tax_type             TYPE string,
      iv_business_entity_type TYPE string,
      iv_entity_name          TYPE string,
      lv_json                 TYPE string.
*---Only for existing Business partner
    IF iv_activity = '02'.
      iv_country               = is_bankdetail-bank_ctry.
      iv_bank_account_holder   = is_bankdetail-accountholder.
      iv_account_number        = is_bankdetail-bank_acct.
      iv_bank_code             = is_bankdetail-bank_key.
      iv_iban                  = is_bankdetail-iban.

      SELECT SINGLE swift
               FROM bnka
         INTO @DATA(lv_swift)
              WHERE banks = @is_bankdetail-bank_ctry
                AND bankl = @is_bankdetail-bank_key.
      IF sy-subrc IS INITIAL.
        iv_swift_code = lv_swift.
      ENDIF.
      SELECT SINGLE *
               FROM dfkkbptaxnum
               INTO @DATA(ls_taxdetails)
              WHERE partner EQ @is_but000-partner.
      IF ls_taxdetails IS NOT INITIAL.
        iv_taxidnumber = ls_taxdetails-taxnum.
      ENDIF.

      " Resolve the BP's primary address country from BUT020/ADRC so the
      " tax-validate call below uses an ISO country code rather than the
      " first two chars of a customer-defined tax-type code (e.g. 'US1',
      " 'IT0', 'AU0' — the prefix is not guaranteed to be ISO).
      DATA lv_bp_country TYPE adrc-country.
      SELECT SINGLE a~country
        INTO @lv_bp_country
        FROM but020 AS b
        INNER JOIN adrc AS a ON a~addrnumber = b~addrnumber
        WHERE b~partner = @is_but000-partner.

      IF NOT ( is_bankdetail IS INITIAL  AND ls_taxdetails IS INITIAL ).
        zcl_qubiton=>validate_bank_pro(
          EXPORTING
            iv_country              = iv_country
            iv_bank_account_holder  = iv_bank_account_holder
            iv_account_number       = iv_account_number
            iv_bank_code            = iv_bank_code
            iv_iban                 = iv_iban
            iv_swift_code           = iv_swift_code
            iv_taxidnumber          = iv_taxidnumber
          RECEIVING
            rv_json                 = lv_json
        ).
        CLEAR: lv_offset.
        FIND FIRST OCCURRENCE OF '"score":' IN lv_json MATCH OFFSET lv_offset.
        IF sy-subrc IS INITIAL.
          CLEAR: lv_result, lv_name, lv_value.
          lv_result = lv_json+lv_offset(15).
          SPLIT lv_result AT ':' INTO lv_name lv_value.
          REPLACE ALL OCCURRENCES OF ',' IN lv_value WITH space.
          REPLACE ALL OCCURRENCES OF '#' IN lv_value WITH space.
          CONDENSE lv_value NO-GAPS.
          " Right-pad so 1- or 2-digit scores (0..99) don't trip
          " CX_SY_RANGE_OUT_OF_BOUNDS on the substring comparison.
          DATA(lv_score_bank) = lv_value.
          IF strlen( lv_value ) < 3.
            lv_score_bank = lv_score_bank && '   '.
          ENDIF.
          IF lv_score_bank(3) NE '100'.
            ls_return-id = 'ZQUBITON'.
            ls_return-number = '003'.
            ls_return-type = 'E'.
            APPEND ls_return TO et_return.
            lv_errflg = 'X'.
          ELSE.
            ls_return-id = 'ZQUBITON'.
            ls_return-number = '004'.
            ls_return-type = 'S'.
            APPEND ls_return TO et_return.
            CLEAR lv_errflg.
          ENDIF.
        ELSE.
          " No score field in the bank-validate response (network failure,
          " auth failure, or unexpected JSON shape). Fail closed so the BP
          " save is blocked rather than passing silently. The full payload
          " is in SLG1 / ZQUBITON for triage.
          ls_return-id      = 'ZQUBITON'.
          ls_return-number  = '003'.
          ls_return-type    = 'E'.
          ls_return-message = 'QubitOn bank validation could not be verified — see SLG1 / ZQUBITON.'.
          APPEND ls_return TO et_return.
          lv_errflg = 'X'.
        ENDIF.
        IF lv_errflg IS INITIAL AND ls_taxdetails IS NOT INITIAL.
          iv_tax_number   = ls_taxdetails-taxnum.
          CASE ls_taxdetails-taxtype.
            WHEN 'US1'.
              iv_tax_type = 'TIN'.
            WHEN 'US2'.
              iv_tax_type = 'SSN'.
            WHEN 'AU0'.
              iv_tax_type = 'ABN'.
            WHEN 'FR0'.
              iv_tax_type = 'VAT'.
          ENDCASE.
          " Prefer the BP's address country (ISO) over a substring of the
          " customer-defined tax-type code; fall back if no address is set.
          IF lv_bp_country IS NOT INITIAL.
            iv_country = lv_bp_country.
          ELSE.
            iv_country = ls_taxdetails-taxtype(2).
          ENDIF.
          iv_company_name         = is_but000-name_org1.
          " businessEntityType stays empty when not known. The API accepts
          " the field as optional; the BP master-data model does not carry
          " a direct "entity type" attribute. Sites that maintain a custom
          " mapping (e.g. by BU_GROUP or BPKIND) can populate this slot in
          " a downstream copy of the BAdI.
          CLEAR iv_business_entity_type.
          iv_entity_name          = is_but000-name_org2.
          zcl_qubiton=>validate_tax(
            EXPORTING
              iv_tax_number           = iv_tax_number
              iv_tax_type             = iv_tax_type
              iv_country              = iv_country
              iv_company_name         = iv_company_name
              iv_business_entity_type = iv_business_entity_type
              iv_entity_name          = iv_entity_name
            RECEIVING
              rv_json                 = lv_json
          ).
          CLEAR: lv_offset.
          FIND FIRST OCCURRENCE OF '"score":' IN lv_json MATCH OFFSET lv_offset.
          IF sy-subrc IS INITIAL.
            CLEAR: lv_result, lv_name, lv_value.
            lv_result = lv_json+lv_offset(15).
            SPLIT lv_result AT ':' INTO lv_name lv_value.
            REPLACE ALL OCCURRENCES OF ',' IN lv_value WITH space.
            REPLACE ALL OCCURRENCES OF '#' IN lv_value WITH space.
            CONDENSE lv_value NO-GAPS.
            DATA(lv_score_tax) = lv_value.
            IF strlen( lv_value ) < 3.
              lv_score_tax = lv_score_tax && '   '.
            ENDIF.
            IF lv_score_tax(3) NE '100'.
              ls_return-id = 'ZQUBITON'.
              ls_return-number = '005'.
              ls_return-type = 'E'.
              APPEND ls_return TO et_return.
              lv_errflg = 'X'.
            ELSE.
              ls_return-id = 'ZQUBITON'.
              ls_return-number = '006'.
              ls_return-type = 'S'.
              APPEND ls_return TO et_return.
              CLEAR lv_errflg.
            ENDIF.
          ELSE.
            " No score field in the tax-validate response — fail closed.
            ls_return-id      = 'ZQUBITON'.
            ls_return-number  = '005'.
            ls_return-type    = 'E'.
            ls_return-message = 'QubitOn tax validation could not be verified — see SLG1 / ZQUBITON.'.
            APPEND ls_return TO et_return.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
