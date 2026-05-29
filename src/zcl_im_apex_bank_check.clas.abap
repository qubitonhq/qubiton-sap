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
*      iv_taxidnumber          TYPE string,
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
          IF lv_value(3) NE '100'.
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
        ENDIF.
      ENDIF.

      IF NOT ls_taxdetails IS INITIAL.
        IF lv_errflg IS INITIAL.
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
          iv_country              = ls_taxdetails-taxtype(2).
          iv_company_name         = is_but000-name_org1.
          iv_business_entity_type = is_but000-name_org1.
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
            IF lv_value(3) NE '100'.
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
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
