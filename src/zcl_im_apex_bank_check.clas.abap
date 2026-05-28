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
      ls_return               TYPE bapiret2,
      lv_errflg               TYPE c,
      iv_company_name         TYPE string,
      iv_tax_number           TYPE string,
      iv_tax_type             TYPE string,
      iv_business_entity_type TYPE string,
      iv_entity_name          TYPE string,
      lv_score_found          TYPE abap_bool,
      lv_score                TYPE i,
      lv_bp_country           TYPE adrc-country,
      lv_json                 TYPE string.

    " Activity '02' = change. The original design only runs validation
    " against existing partners on update; create-path validation is a
    " separate scope.
    IF iv_activity <> '02'.
      RETURN.
    ENDIF.

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
    SELECT SINGLE a~country
      INTO @lv_bp_country
      FROM but020 AS b
      INNER JOIN adrc AS a ON a~addrnumber = b~addrnumber
      WHERE b~partner = @is_but000-partner.

    IF is_bankdetail IS INITIAL AND ls_taxdetails IS INITIAL.
      RETURN.
    ENDIF.

    " ── Bank validation ──────────────────────────────────────────────────
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

    zcl_qubiton=>extract_score_from_json(
      EXPORTING iv_json  = lv_json
      IMPORTING ev_found = lv_score_found
                ev_score = lv_score
    ).

    CLEAR ls_return.
    ls_return-id = 'ZQUBITON'.
    IF lv_score_found = abap_false.
      ls_return-number = '008'.
      ls_return-type   = 'E'.
      lv_errflg        = 'X'.
    ELSEIF lv_score = 100.
      ls_return-number = '004'.
      ls_return-type   = 'S'.
      CLEAR lv_errflg.
    ELSE.
      ls_return-number = '003'.
      ls_return-type   = 'E'.
      lv_errflg        = 'X'.
    ENDIF.
    APPEND ls_return TO et_return.

    " ── Tax validation (chained when bank passes and a tax record exists) ─
    IF lv_errflg IS NOT INITIAL OR ls_taxdetails IS INITIAL.
      RETURN.
    ENDIF.

    iv_tax_number = ls_taxdetails-taxnum.
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

    iv_company_name = is_but000-name_org1.
    " businessEntityType stays empty when not known. The API accepts the
    " field as optional; the BP master-data model does not carry a direct
    " "entity type" attribute. Sites that maintain a custom mapping
    " (e.g. by BU_GROUP or BPKIND) can populate this slot in a downstream
    " copy of the BAdI.
    CLEAR iv_business_entity_type.
    iv_entity_name = is_but000-name_org2.

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

    zcl_qubiton=>extract_score_from_json(
      EXPORTING iv_json  = lv_json
      IMPORTING ev_found = lv_score_found
                ev_score = lv_score
    ).

    CLEAR ls_return.
    ls_return-id = 'ZQUBITON'.
    IF lv_score_found = abap_false.
      ls_return-number = '009'.
      ls_return-type   = 'E'.
    ELSEIF lv_score = 100.
      ls_return-number = '006'.
      ls_return-type   = 'S'.
    ELSE.
      ls_return-number = '005'.
      ls_return-type   = 'E'.
    ENDIF.
    APPEND ls_return TO et_return.
  ENDMETHOD.
ENDCLASS.
