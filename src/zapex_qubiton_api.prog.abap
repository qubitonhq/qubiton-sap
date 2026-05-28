*&---------------------------------------------------------------------*
*& Report ZAPEX_QUBITON_API
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zapex_qubiton_api.
TYPE-POOLS: icon.
*----------------------------------------------------------------------*
*  TABLES
*----------------------------------------------------------------------*
TABLES but000.
TABLES but100.
TABLES but0bk.
*----------------------------------------------------------------------*
*  TYPES
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_data,
         icon           TYPE icon_d,
         partner        TYPE partner,
         score          TYPE c LENGTH 20,
         validationPass TYPE c LENGTH 20,
         Description    TYPE c LENGTH 20,
         path           TYPE c LENGTH 50,
       END OF ty_data.
TYPES: BEGIN OF ty_addr,
         icon           TYPE icon_d,
         partner        TYPE partner,
         country        TYPE adrc-country,
         street         TYPE adrc-street,
         str_suppl1     TYPE adrc-str_suppl1,
         city1          TYPE adrc-city1,
         region         TYPE adrc-region,
         post_code1     TYPE adrc-post_code1,
         name1          TYPE adrc-name1,
         score          TYPE c LENGTH 20,
         validationPass TYPE c LENGTH 20,
         Description    TYPE c LENGTH 20,
         path           TYPE c LENGTH 50,
       END OF ty_addr.
TYPES: BEGIN OF ty_bank,
         icon           TYPE icon_d,
         partner        TYPE partner,
         banks          TYPE  but0bk-banks,
         bankl          TYPE  but0bk-bankl,
         banka          TYPE  bnka-banka,
         iban           TYPE  but0bk-iban,
         koinh          TYPE  but0bk-koinh,
         bankn          TYPE  but0bk-bankn,
         swift          TYPE bnka-swift,
         taxtype        TYPE dfkkbptaxnum-taxtype,
         taxnum         TYPE dfkkbptaxnum-taxnum,
         score          TYPE c LENGTH 20,
         validationPass TYPE c LENGTH 20,
         Description    TYPE c LENGTH 20,
         path           TYPE c LENGTH 50,
       END OF ty_bank.
TYPES: BEGIN OF ty_tax,
         icon           TYPE icon_d,
         partner        TYPE partner,
         score          TYPE c LENGTH 20,
         taxtype        TYPE dfkkbptaxnum-taxtype,
         taxnum         TYPE dfkkbptaxnum-taxnum,
         country        TYPE adrc-country,
         name_org1      TYPE but000-name_org1,
         validationPass TYPE c LENGTH 20,
         Description    TYPE c LENGTH 20,
         path           TYPE c LENGTH 50,
       END OF ty_tax.
*----------------------------------------------------------------------*
*  DATA DECLARATION
*----------------------------------------------------------------------*
DATA :
  iv_country              TYPE string,
  iv_address_line1        TYPE string,
  iv_address_line2        TYPE string,
  iv_city                 TYPE string,
  iv_state                TYPE string,
  iv_postal_code          TYPE string,
  iv_company_name         TYPE string,
  iv_country1             TYPE string,
  iv_bank_account_holder  TYPE string,
  iv_account_number       TYPE string,
  iv_bank_code            TYPE string,
  iv_iban                 TYPE string,
  iv_swift_code           TYPE string,
  iv_taxidnumber          TYPE string,
  iv_tax_number           TYPE string,
  iv_tax_type             TYPE string,
  iv_business_entity_type TYPE string,
  iv_entity_name          TYPE string,
  lv_json                 TYPE string.

DATA: lt_partner TYPE RANGE OF partner,
      ls_partner LIKE LINE OF lt_partner,
      ls_data    TYPE ty_data,
      gt_data    TYPE TABLE OF ty_data,
      gt_addr    TYPE TABLE OF ty_addr,
      ls_addr    TYPE ty_addr,
      gt_bank    TYPE TABLE OF ty_bank,
      ls_bank    TYPE ty_bank,
      gt_tax     TYPE TABLE OF ty_tax,
      ls_tax     TYPE ty_tax,
      lv_path    TYPE string.
*----------------------------------------------------------------------*
* Selection Screen
*----------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK blk01 WITH FRAME TITLE TEXT-b01.
  PARAMETERS: rb_addr RADIOBUTTON GROUP gp1 DEFAULT 'X'.
  PARAMETERS: rb_bank RADIOBUTTON GROUP gp1.
  PARAMETERS: rb_Tax RADIOBUTTON GROUP gp1.
SELECTION-SCREEN END OF BLOCK blk01.

SELECTION-SCREEN BEGIN OF BLOCK blk03 WITH FRAME TITLE TEXT-b03.
  SELECT-OPTIONS s_crdat FOR but000-crdat NO INTERVALS.
  SELECT-OPTIONS s_rltyp FOR but100-rltyp NO INTERVALS.
  SELECT-OPTIONS s_bupa FOR but000-partner.

SELECTION-SCREEN END OF BLOCK blk03.

*----------------------------------------------------------------------*
*START-OF-SELECTION.
*----------------------------------------------------------------------*
START-OF-SELECTION.
  LOOP AT s_bupa.
    ls_partner-sign = s_bupa-sign.
    ls_partner-option = s_bupa-option.
    ls_partner-low = s_bupa-low.
    ls_partner-high = s_bupa-high.
    APPEND ls_partner TO lt_partner.
  ENDLOOP.
*---Address validation
  IF rb_addr = 'X'.
    CALL METHOD zcl_qubiton=>get_bp_address
      EXPORTING
        ir_partner = lt_partner[].

    LOOP AT zcl_qubiton=>mt_adrc INTO DATA(ls_adrc).
      iv_country       = ls_adrc-country.
      iv_address_line1 = ls_adrc-street.
      iv_address_line2 = ls_adrc-str_suppl1.
      iv_city          = ls_adrc-city1.
      iv_state         = ls_adrc-region.
      iv_postal_code   =  ls_adrc-post_code1.
      iv_company_name  = ls_adrc-name1.

      zcl_qubiton=>validate_address(
        EXPORTING
          iv_country       = iv_country
          iv_address_line1 = iv_address_line1
          iv_address_line2 = iv_address_line2
          iv_city          = iv_city
          iv_state         = iv_state
          iv_postal_code   = iv_postal_code
          iv_company_name  = iv_company_name
        RECEIVING
          rv_json          = lv_json
      ).
      CLEAR lv_path.
      zcl_qubiton=>application_log(
        EXPORTING
          iv_json    = lv_json
          iv_partner = ls_adrc-partner                  " Partner number
        RECEIVING
          rv_path    = lv_path
      ).
      PERFORM read_results.
      MOVE-CORRESPONDING ls_data TO ls_addr.
      MOVE-CORRESPONDING ls_adrc TO ls_addr.
      ls_addr-path = lv_path.
      APPEND ls_addr TO gt_addr.
    ENDLOOP.
    PERFORM alv_display USING gt_addr.
*---Bank Validation
  ELSEIF rb_bank = 'X'.
    CALL METHOD zcl_qubiton=>get_bank_details
      EXPORTING
        ir_partner = lt_partner[].
    LOOP AT zcl_qubiton=>mt_bank INTO DATA(ls_bank_t).
      iv_country             = ls_bank_t-banks.
      iv_bank_account_holder = ls_bank_t-koinh.
      iv_account_number      = ls_bank_t-bankn.
      iv_bank_code           = ls_bank_t-bankl.
      iv_iban                = ls_bank_t-iban.
      iv_swift_code          = ls_bank_t-swift.
      iv_taxidnumber         = ls_bank_t-taxnum.

      zcl_qubiton=>validate_bank_pro(
        EXPORTING
          iv_country              = iv_country
          iv_bank_account_holder  = iv_bank_account_holder
          iv_account_number       = iv_account_number
          iv_bank_code            = iv_bank_code
          iv_iban                 = iv_iban
          iv_swift_code           = iv_swift_code
          iv_taxidnumber          =  iv_taxidnumber
        RECEIVING
          rv_json                 = lv_json
      ).
      CLEAR lv_path.
      zcl_qubiton=>application_log(
        EXPORTING
          iv_json    = lv_json
          iv_partner =  ls_bank_t-partner                " Partner number
        RECEIVING
          rv_path    = lv_path ).

      PERFORM read_results.
      MOVE-CORRESPONDING ls_data TO ls_bank.
      MOVE-CORRESPONDING ls_bank_t TO ls_bank.
      ls_bank-path = lv_path.
      APPEND ls_bank TO gt_bank.
    ENDLOOP.
    PERFORM alv_display USING gt_bank.
*---Tax validation
  ELSEIF rb_tax = 'X'.
    zcl_qubiton=>get_tax_details( ir_partner = lt_partner[] ).

    LOOP AT zcl_qubiton=>mt_tax INTO DATA(ls_tax_t).
      iv_tax_number   = ls_tax_t-taxnum.
      CASE ls_tax_t-taxtype.
        WHEN 'US1'.
          iv_tax_type = 'TIN'.
        WHEN 'US2'.
          iv_tax_type = 'SSN'.
        WHEN 'AU0'.
          iv_tax_type = 'ABN'.
        WHEN 'FR0'.
          iv_tax_type = 'VAT'.
      ENDCASE.
      iv_country      = ls_tax_t-country.
      iv_company_name = ls_tax_t-name_org1.
      " businessEntityType is left empty in the report. The BP master
      " data model has no direct entity-type attribute — the company
      " name is not a substitute. Customers that maintain a custom
      " mapping (e.g. via BU_GROUP or BPKIND) can populate this field
      " from that mapping before the validate_tax call.
      CLEAR iv_business_entity_type.
      iv_entity_name = ls_tax_t-name_org2.
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
      CLEAR lv_path.
      zcl_qubiton=>application_log(
        EXPORTING
          iv_json    = lv_json
          iv_partner =  ls_tax_t-partner                " Partner number
        RECEIVING
          rv_path    = lv_path ).
      PERFORM read_results.
      MOVE-CORRESPONDING ls_data TO ls_tax.
      MOVE-CORRESPONDING ls_tax_t TO ls_tax.
      ls_tax-path = lv_path.
      APPEND ls_tax TO gt_tax.
      clear ls_data.
    ENDLOOP.
    PERFORM alv_display USING gt_tax.
  ENDIF.
  INCLUDE zapex_qubiton_api_f01.
