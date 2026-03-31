"! <p class="shorttext synchronized">QubitOn Screen Enhancement Orchestrator</p>
"! Reads configuration from ZQUBITON_SCREEN_CFG and dispatches validations
"! to ZCL_QUBITON for vendor master, customer master, and Business Partner
"! screen enhancements (BADIs / user exits).
"!
"! Configuration table ZQUBITON_SCREEN_CFG controls which validations run
"! for which transaction, with per-validation error handling behavior.
"!
"! Note: When using this class directly (outside a BAdI), you must call
"! COMMIT WORK after processing to persist BAL application log entries.
"! BAdI frameworks handle COMMIT automatically.
"!
"! @version 1.2.0
"! @author  QubitOn
CLASS zcl_qubiton_screen DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  GLOBAL FRIENDS zcl_qubiton_screen_test.

  PUBLIC SECTION.

    " ── Validation Type Constants ──────────────────────────────────────────
    CONSTANTS:
      gc_val_tax     TYPE char10 VALUE 'TAX',
      gc_val_bank    TYPE char10 VALUE 'BANK',
      gc_val_address TYPE char10 VALUE 'ADDRESS',
      gc_val_email   TYPE char10 VALUE 'EMAIL',
      gc_val_phone   TYPE char10 VALUE 'PHONE',
      gc_val_sanct   TYPE char10 VALUE 'SANCTION'.

    " ── Configuration Table Line Type ──────────────────────────────────────
    "! Each row controls one validation for one transaction code.
    "! Maintained via SM30 (table maintenance generator) by SAP admins.
    TYPES:
      BEGIN OF ty_screen_cfg,
        mandt          TYPE mandt,      " Client
        tcode          TYPE tcode,      " Transaction code (XK01, XK02, FK01, FK02, BP, etc.)
        val_type       TYPE char10,     " Validation type: TAX, BANK, ADDRESS, EMAIL, PHONE, SANCTION
        active         TYPE abap_bool,  " Is this validation active?
        on_invalid     TYPE char1,      " E=stop, W=warn, S=silent (overrides constructor default)
        on_error       TYPE char1,      " E=stop, W=warn, S=silent
        country_filter TYPE land1,      " Optional: only validate for this country (blank = all)
      END OF ty_screen_cfg,
      tt_screen_cfg TYPE STANDARD TABLE OF ty_screen_cfg WITH EMPTY KEY.

    " ── Vendor Field Mapping Types (LFA1 + LFBK) ──────────────────────────
    TYPES:
      BEGIN OF ty_vendor_data,
        lifnr TYPE lifnr,     " Vendor number
        land1 TYPE land1,     " Country key
        name1 TYPE name1_gp,  " Name 1
        name2 TYPE name2_gp,  " Name 2
        stras TYPE stras_gp,  " Street
        ort01 TYPE ort01_gp,  " City
        regio TYPE regio,     " Region / State
        pstlz TYPE pstlz,    " Postal code
        stceg TYPE stceg,     " VAT registration number
        stcd1 TYPE stcd1,     " Tax number 1 (EIN, CNPJ, ABN, TIN)
        stcd2 TYPE stcd2,     " Tax number 2
        telf1 TYPE telf1,     " Telephone number
        adrnr TYPE adrnr,     " Address number (for SMTP lookup)
        email TYPE ad_smtpadr, " Email address (from ADR6 via ADRNR)
      END OF ty_vendor_data.

    TYPES:
      BEGIN OF ty_vendor_bank,
        lifnr TYPE lifnr,     " Vendor number
        banks TYPE banks,     " Bank country key
        bankl TYPE bankl,     " Bank key (routing/sort code, CLABE for MX)
        bankn TYPE bankn,     " Bank account number
        bkont TYPE bkont,     " Bank control key (account type)
        iban  TYPE iban,      " IBAN
        swift TYPE swift,     " SWIFT/BIC code
        koinh TYPE koinh_gp,  " Account holder name
      END OF ty_vendor_bank.

    " ── Customer Field Mapping Types (KNA1 + KNBK) ─────────────────────────
    TYPES:
      BEGIN OF ty_customer_data,
        kunnr TYPE kunnr,     " Customer number
        land1 TYPE land1,
        name1 TYPE name1_gp,
        name2 TYPE name2_gp,
        stras TYPE stras_gp,
        ort01 TYPE ort01_gp,
        regio TYPE regio,
        pstlz TYPE pstlz,
        stceg TYPE stceg,
        stcd1 TYPE stcd1,
        stcd2 TYPE stcd2,
        telf1 TYPE telf1,
        adrnr TYPE adrnr,
        email TYPE ad_smtpadr, " Email address (from ADR6 via ADRNR)
      END OF ty_customer_data.

    TYPES:
      BEGIN OF ty_customer_bank,
        kunnr TYPE kunnr,     " Customer number
        banks TYPE banks,     " Bank country key
        bankl TYPE bankl,     " Bank key (routing/sort code, CLABE for MX)
        bankn TYPE bankn,     " Bank account number
        bkont TYPE bkont,     " Bank control key (account type)
        iban  TYPE iban,      " IBAN
        swift TYPE swift,     " SWIFT/BIC code
        koinh TYPE koinh_gp,  " Account holder name
      END OF ty_customer_bank.

    " ── Business Partner Field Mapping Types (BUT000 + address + bank) ────
    TYPES:
      BEGIN OF ty_bp_data,
        partner    TYPE bu_partner,  " BP number
        bu_group   TYPE bu_group,    " BP grouping
        name_org1  TYPE bu_nameor1,  " Organization name 1
        name_org2  TYPE bu_nameor2,  " Organization name 2
        name_last  TYPE bu_namep_l,  " Last name (person)
        name_first TYPE bu_namep_f,  " First name (person)
        bpkind     TYPE bu_bpkind,   " BP type (1=person, 2=org)
        country    TYPE land1,
        street     TYPE ad_street,
        city       TYPE ad_city1,
        region     TYPE regio,
        postl_cod1 TYPE ad_pstcd1,
        taxnum     TYPE bptaxnum,    " Tax number
        taxtype    TYPE bptaxtype,   " Tax type
        tel_number TYPE ad_tlnmbr1,  " Phone
        email      TYPE ad_smtpadr,  " Email address
      END OF ty_bp_data.

    TYPES:
      BEGIN OF ty_bp_bank,
        partner TYPE bu_partner,  " BP number
        banks   TYPE banks,       " Bank country key
        bankl   TYPE bankl,       " Bank key (routing/sort code)
        bankn   TYPE bankn,       " Bank account number
        bkont   TYPE bkont,       " Bank control key
        iban    TYPE iban,        " IBAN
        swift   TYPE swift,       " SWIFT/BIC code
        koinh   TYPE koinh_gp,   " Account holder name
      END OF ty_bp_bank.

    " ── Validation Result Collection ───────────────────────────────────────
    TYPES:
      BEGIN OF ty_screen_result,
        val_type   TYPE char10,            " Which validation ran
        result     TYPE zcl_qubiton=>ty_result, " API result
        blocked    TYPE abap_bool,         " True if MESSAGE TYPE 'E' was issued
      END OF ty_screen_result,
      tt_screen_result TYPE STANDARD TABLE OF ty_screen_result WITH EMPTY KEY.

    "! <p class="shorttext synchronized">Constructor</p>
    "! @parameter iv_apikey | QubitOn API key
    "! @parameter iv_destination | RFC destination (default: QubitOn)
    METHODS constructor
      IMPORTING
        iv_apikey      TYPE string
        iv_destination TYPE string DEFAULT 'QubitOn'
      RAISING
        zcx_qubiton.

    " ── Vendor Master Validations ──────────────────────────────────────────

    "! Validate vendor tax ID (STCEG or STCD1 depending on country)
    METHODS validate_vendor_tax
      IMPORTING
        is_vendor      TYPE ty_vendor_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate vendor bank account (IBAN, SWIFT, routing, account number)
    METHODS validate_vendor_bank
      IMPORTING
        is_bank           TYPE ty_vendor_bank
        iv_vendor_name    TYPE string
        iv_tax_id         TYPE string OPTIONAL
        iv_tax_type       TYPE string OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate vendor address
    METHODS validate_vendor_address
      IMPORTING
        is_vendor      TYPE ty_vendor_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Screen vendor against global sanctions/prohibited lists (OFAC, EU, UN)
    METHODS check_vendor_sanctions
      IMPORTING
        is_vendor      TYPE ty_vendor_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate vendor phone number
    METHODS validate_vendor_phone
      IMPORTING
        is_vendor        TYPE ty_vendor_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate vendor email address
    METHODS validate_vendor_email
      IMPORTING
        is_vendor        TYPE ty_vendor_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Run all active validations for vendor master based on config table
    METHODS validate_vendor_all
      IMPORTING
        is_vendor      TYPE ty_vendor_data
        is_bank        TYPE ty_vendor_bank OPTIONAL
      RETURNING
        VALUE(rt_results) TYPE tt_screen_result.

    " ── Customer Master Validations ────────────────────────────────────────

    "! Validate customer tax ID
    METHODS validate_customer_tax
      IMPORTING
        is_customer    TYPE ty_customer_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate customer bank account (IBAN, SWIFT, routing, account number)
    METHODS validate_customer_bank
      IMPORTING
        is_bank                TYPE ty_customer_bank
        iv_customer_name       TYPE string
        iv_tax_id              TYPE string OPTIONAL
        iv_tax_type            TYPE string OPTIONAL
        iv_business_entity_type TYPE string DEFAULT 'Business'
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate customer address
    METHODS validate_customer_address
      IMPORTING
        is_customer    TYPE ty_customer_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Screen customer against global sanctions/prohibited lists (OFAC, EU, UN)
    METHODS check_customer_sanctions
      IMPORTING
        is_customer    TYPE ty_customer_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate customer phone number
    METHODS validate_customer_phone
      IMPORTING
        is_customer      TYPE ty_customer_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate customer email address
    METHODS validate_customer_email
      IMPORTING
        is_customer      TYPE ty_customer_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Run all active validations for customer master based on config table
    METHODS validate_customer_all
      IMPORTING
        is_customer    TYPE ty_customer_data
        is_bank        TYPE ty_customer_bank OPTIONAL
      RETURNING
        VALUE(rt_results) TYPE tt_screen_result.

    " ── Business Partner Validations ───────────────────────────────────────

    "! Validate BP tax ID
    METHODS validate_bp_tax
      IMPORTING
        is_bp          TYPE ty_bp_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate BP bank account
    METHODS validate_bp_bank
      IMPORTING
        is_bank            TYPE ty_bp_bank
        iv_bp_name         TYPE string
        iv_bp_entity_type  TYPE string DEFAULT 'Business'
        iv_tax_id          TYPE string OPTIONAL
        iv_tax_type        TYPE string OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate BP address
    METHODS validate_bp_address
      IMPORTING
        is_bp          TYPE ty_bp_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Screen BP against global sanctions/prohibited lists (OFAC, EU, UN)
    METHODS check_bp_sanctions
      IMPORTING
        is_bp          TYPE ty_bp_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate BP phone number
    METHODS validate_bp_phone
      IMPORTING
        is_bp            TYPE ty_bp_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Validate BP email address
    METHODS validate_bp_email
      IMPORTING
        is_bp            TYPE ty_bp_data
      RETURNING
        VALUE(rs_result) TYPE zcl_qubiton=>ty_result.

    "! Run all active validations for Business Partner based on config table.
    "! NOTE: For BP BAdI (BADI_BUS1006_CHECK), do NOT use this method — call
    "! individual validate_bp_* methods directly to avoid double-messaging
    "! (this method issues MESSAGE statements; BP BAdI uses et_return).
    METHODS validate_bp_all
      IMPORTING
        is_bp          TYPE ty_bp_data
        is_bank        TYPE ty_bp_bank OPTIONAL
      RETURNING
        VALUE(rt_results) TYPE tt_screen_result.

    " ── Utility ────────────────────────────────────────────────────────────

    "! Determine the tax type from country code
    "! Maps SAP country key to QubitOn tax type (VAT, EIN, CNPJ, GSTIN, etc.)
    METHODS determine_tax_type
      IMPORTING
        iv_country     TYPE land1
      RETURNING
        VALUE(rv_type) TYPE string.

    "! Read active configuration for the current transaction
    METHODS get_active_config
      IMPORTING
        iv_tcode       TYPE tcode OPTIONAL
      RETURNING
        VALUE(rt_config) TYPE tt_screen_cfg.

    "! Retrieve QubitOn API key from configuration table ZQUBITON_CONFIG.
    "! All BAdI implementations call this shared method.
    "! Falls back to empty string if table doesn't exist yet.
    CLASS-METHODS get_apikey
      RETURNING
        VALUE(rv_key) TYPE string.

    "! Read a config value from ZQUBITON_CONFIG by key.
    CLASS-METHODS get_config_value
      IMPORTING
        iv_key          TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.

    "! Inject configuration for testing (bypasses DB read)
    METHODS set_config_for_testing
      IMPORTING
        it_config TYPE tt_screen_cfg.

  PRIVATE SECTION.

    DATA mo_api     TYPE REF TO zcl_qubiton.
    DATA mv_apikey  TYPE string.
    DATA mv_dest    TYPE string.
    DATA mt_config  TYPE tt_screen_cfg.
    DATA mv_tcode   TYPE tcode.

    "! Read configuration from ZQUBITON_SCREEN_CFG table (dynamic SQL)
    METHODS load_config.

    "! Issue a SAP MESSAGE statement based on validation result and config mode
    "! Returns abap_true if the message blocked processing (type E)
    METHODS issue_message
      IMPORTING
        iv_label       TYPE string
        is_result      TYPE zcl_qubiton=>ty_result
        iv_on_invalid  TYPE char1
        iv_on_error    TYPE char1
      RETURNING
        VALUE(rv_blocked) TYPE abap_bool.

    "! Get the best company name from vendor data
    METHODS get_vendor_name
      IMPORTING
        is_vendor      TYPE ty_vendor_data
      RETURNING
        VALUE(rv_name) TYPE string.

    "! Get the best company name from customer data
    METHODS get_customer_name
      IMPORTING
        is_customer    TYPE ty_customer_data
      RETURNING
        VALUE(rv_name) TYPE string.

    "! Get the best name from BP data
    METHODS get_bp_name
      IMPORTING
        is_bp          TYPE ty_bp_data
      RETURNING
        VALUE(rv_name) TYPE string.

    "! Get tax number from vendor data (STCEG preferred, then STCD1)
    METHODS get_vendor_tax_number
      IMPORTING
        is_vendor      TYPE ty_vendor_data
      RETURNING
        VALUE(rv_tax)  TYPE string.

    "! Get tax number from customer data
    METHODS get_customer_tax_number
      IMPORTING
        is_customer    TYPE ty_customer_data
      RETURNING
        VALUE(rv_tax)  TYPE string.

ENDCLASS.


CLASS zcl_qubiton_screen IMPLEMENTATION.

  METHOD constructor.
    mv_apikey = iv_apikey.
    mv_dest   = iv_destination.
    mv_tcode  = sy-tcode.

    " Check if auth is required via config table
    DATA(lv_check_auth) = COND abap_bool(
      WHEN get_config_value( 'CHECK_AUTH' ) = 'X' THEN abap_true
      ELSE abap_false ).

    " Create API client in silent mode — we handle messaging ourselves
    mo_api = NEW zcl_qubiton(
      iv_apikey      = iv_apikey
      iv_destination = iv_destination
      iv_on_error    = zcl_qubiton=>gc_on_error_silent
      iv_on_invalid  = zcl_qubiton=>gc_on_invalid_silent
      iv_check_auth  = lv_check_auth
      iv_log_enabled = abap_true ).

    load_config( ).
  ENDMETHOD.


  METHOD load_config.
    " Dynamic SQL so cx_sy_dynamic_osql_error is catchable when table doesn't exist
    TRY.
        SELECT * FROM ('ZQUBITON_SCREEN_CFG')
          INTO TABLE @mt_config
          WHERE ('TCODE') = @mv_tcode
            AND ('ACTIVE') = @abap_true.
      CATCH cx_sy_dynamic_osql_error.
        " Table doesn't exist yet — normal during initial deployment
        CLEAR mt_config.
    ENDTRY.
  ENDMETHOD.


  METHOD get_active_config.
    DATA lv_tcode TYPE tcode.
    lv_tcode = COND #( WHEN iv_tcode IS SUPPLIED AND iv_tcode IS NOT INITIAL
                        THEN iv_tcode
                        ELSE mv_tcode ).

    LOOP AT mt_config INTO DATA(ls_cfg) WHERE tcode = lv_tcode AND active = abap_true.
      APPEND ls_cfg TO rt_config.
    ENDLOOP.
  ENDMETHOD.


  METHOD determine_tax_type.
    " Map SAP country key to QubitOn tax type
    CASE iv_country.
      WHEN 'US'. rv_type = 'EIN'.
      WHEN 'BR'. rv_type = 'CNPJ'.
      WHEN 'IN'. rv_type = 'GSTIN'.
      WHEN 'AU'. rv_type = 'ABN'.
      WHEN 'CA'. rv_type = 'BN'.
      WHEN 'GB'. rv_type = 'UTR'.
      WHEN 'MX'. rv_type = 'RFC'.
      WHEN 'CN'. rv_type = 'USCI'.
      WHEN 'JP'. rv_type = 'CN'.
      WHEN 'KR'. rv_type = 'BRN'.
      WHEN 'RU'. rv_type = 'INN'.
      WHEN 'ZA'. rv_type = 'TIN'.
      WHEN OTHERS.
        " EU and most other countries use VAT
        rv_type = 'VAT'.
    ENDCASE.
  ENDMETHOD.


  METHOD get_vendor_name.
    rv_name = COND #( WHEN is_vendor-name1 IS NOT INITIAL
                       THEN |{ is_vendor-name1 } { is_vendor-name2 }|
                       ELSE |Vendor { is_vendor-lifnr }| ).
    rv_name = condense( rv_name ).
  ENDMETHOD.


  METHOD get_customer_name.
    rv_name = COND #( WHEN is_customer-name1 IS NOT INITIAL
                       THEN |{ is_customer-name1 } { is_customer-name2 }|
                       ELSE |Customer { is_customer-kunnr }| ).
    rv_name = condense( rv_name ).
  ENDMETHOD.


  METHOD get_bp_name.
    IF is_bp-bpkind = '2' OR is_bp-name_org1 IS NOT INITIAL.
      " Organization
      rv_name = COND #( WHEN is_bp-name_org1 IS NOT INITIAL
                         THEN |{ is_bp-name_org1 } { is_bp-name_org2 }|
                         ELSE |BP { is_bp-partner }| ).
    ELSE.
      " Person
      rv_name = COND #( WHEN is_bp-name_last IS NOT INITIAL
                         THEN |{ is_bp-name_first } { is_bp-name_last }|
                         ELSE |BP { is_bp-partner }| ).
    ENDIF.
    rv_name = condense( rv_name ).
  ENDMETHOD.


  METHOD get_vendor_tax_number.
    " Prefer STCEG (VAT registration number) if populated
    IF is_vendor-stceg IS NOT INITIAL.
      rv_tax = is_vendor-stceg.
    ELSEIF is_vendor-stcd1 IS NOT INITIAL.
      rv_tax = is_vendor-stcd1.
    ELSEIF is_vendor-stcd2 IS NOT INITIAL.
      rv_tax = is_vendor-stcd2.
    ENDIF.
  ENDMETHOD.


  METHOD get_customer_tax_number.
    IF is_customer-stceg IS NOT INITIAL.
      rv_tax = is_customer-stceg.
    ELSEIF is_customer-stcd1 IS NOT INITIAL.
      rv_tax = is_customer-stcd1.
    ELSEIF is_customer-stcd2 IS NOT INITIAL.
      rv_tax = is_customer-stcd2.
    ENDIF.
  ENDMETHOD.


  METHOD issue_message.
    rv_blocked = abap_false.

    IF is_result-success = abap_false.
      " API error — use on_error mode
      CASE iv_on_error.
        WHEN 'E'.
          MESSAGE e003(zcl_qubiton_msg) WITH iv_label.
          rv_blocked = abap_true.
        WHEN 'W'.
          MESSAGE w003(zcl_qubiton_msg) WITH iv_label.
        WHEN OTHERS.
          " Silent — do nothing
      ENDCASE.
    ELSEIF is_result-field_missing = abap_true.
      " Missing expected field — unexpected response
      CASE iv_on_error.
        WHEN 'E'.
          MESSAGE e004(zcl_qubiton_msg) WITH iv_label 'isValid'.
          rv_blocked = abap_true.
        WHEN 'W'.
          MESSAGE w004(zcl_qubiton_msg) WITH iv_label 'isValid'.
        WHEN OTHERS.
          " Silent
      ENDCASE.
    ELSEIF is_result-is_valid = abap_false.
      " Validation failure — use on_invalid mode
      CASE iv_on_invalid.
        WHEN 'E'.
          MESSAGE e002(zcl_qubiton_msg) WITH iv_label.
          rv_blocked = abap_true.
        WHEN 'W'.
          MESSAGE w002(zcl_qubiton_msg) WITH iv_label.
        WHEN OTHERS.
          " Silent
      ENDCASE.
    ENDIF.
    " Success case: no message — silent by design
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Vendor Master Validations
  " ═══════════════════════════════════════════════════════════════════════

  METHOD validate_vendor_tax.
    DATA lv_json     TYPE string.
    DATA lv_tax      TYPE string.
    DATA lv_tax_type TYPE string.

    " STCEG is always a VAT registration number regardless of country.
    " STCD1/STCD2 use country-based tax type determination.
    IF is_vendor-stceg IS NOT INITIAL.
      lv_tax      = is_vendor-stceg.
      lv_tax_type = 'VAT'.  " STCEG is always VAT
    ELSEIF is_vendor-stcd1 IS NOT INITIAL.
      lv_tax      = is_vendor-stcd1.
      lv_tax_type = determine_tax_type( is_vendor-land1 ).
    ELSEIF is_vendor-stcd2 IS NOT INITIAL.
      lv_tax      = is_vendor-stcd2.
      lv_tax_type = determine_tax_type( is_vendor-land1 ).
    ELSE.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Tax: skipped (no tax number)'.
      RETURN.
    ENDIF.

    DATA(lv_name) = get_vendor_name( is_vendor ).

    TRY.
        lv_json = mo_api->validate_tax(
          iv_tax_number           = lv_tax
          iv_tax_type             = lv_tax_type
          iv_country              = CONV string( is_vendor-land1 )
          iv_company_name         = lv_name
          iv_business_entity_type = 'Business' ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Tax ID' ).
  ENDMETHOD.


  METHOD validate_vendor_bank.
    DATA lv_json TYPE string.

    IF is_bank-bankn IS INITIAL AND is_bank-iban IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Bank: skipped (no account number)'.
      RETURN.
    ENDIF.

    DATA(lv_holder) = COND string(
      WHEN is_bank-koinh IS NOT INITIAL THEN CONV string( is_bank-koinh )
      ELSE iv_vendor_name ).

    TRY.
        " Maps SAP bank fields to QubitOn API:
        "   BANKL → bank_code (routing number US, sort code UK, CLABE MX, BSB AU)
        "   BANKN → account_number
        "   IBAN  → iban (European/international)
        "   SWIFT → swift_code (BIC)
        lv_json = mo_api->validate_bank_account(
          iv_business_entity_type = 'Business'
          iv_country              = CONV string( is_bank-banks )
          iv_bank_account_holder  = lv_holder
          iv_account_number       = CONV string( is_bank-bankn )
          iv_bank_code            = CONV string( is_bank-bankl )
          iv_iban                 = CONV string( is_bank-iban )
          iv_swift_code           = CONV string( is_bank-swift )
          iv_business_name        = iv_vendor_name
          iv_tax_id_number        = iv_tax_id
          iv_tax_type             = iv_tax_type ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Bank Account' ).
  ENDMETHOD.


  METHOD validate_vendor_address.
    DATA lv_json TYPE string.

    IF is_vendor-stras IS INITIAL AND is_vendor-ort01 IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Address: skipped (no address data)'.
      RETURN.
    ENDIF.

    TRY.
        lv_json = mo_api->validate_address(
          iv_country       = CONV string( is_vendor-land1 )
          iv_address_line1 = CONV string( is_vendor-stras )
          iv_city          = CONV string( is_vendor-ort01 )
          iv_state         = CONV string( is_vendor-regio )
          iv_postal_code   = CONV string( is_vendor-pstlz )
          iv_company_name  = get_vendor_name( is_vendor ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Address' ).
  ENDMETHOD.


  METHOD check_vendor_sanctions.
    DATA lv_json TYPE string.

    IF is_vendor-name1 IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Sanctions: skipped (no name)'.
      RETURN.
    ENDIF.

    DATA(lv_name) = get_vendor_name( is_vendor ).

    TRY.
        lv_json = mo_api->check_sanctions(
          iv_company_name  = lv_name
          iv_country       = CONV string( is_vendor-land1 )
          iv_address_line1 = CONV string( is_vendor-stras )
          iv_city          = CONV string( is_vendor-ort01 )
          iv_state         = CONV string( is_vendor-regio )
          iv_postal_code   = CONV string( is_vendor-pstlz ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'hasMatches'
      iv_label = 'Sanctions' ).

    " Invert: hasMatches=true means BLOCKED (found on prohibited list)
    IF rs_result-success = abap_true AND rs_result-field_missing = abap_false.
      rs_result-is_valid = COND #( WHEN rs_result-is_valid = abap_true THEN abap_false
                                    ELSE abap_true ).
      rs_result-message = COND #( WHEN rs_result-is_valid = abap_true
                                   THEN 'Sanctions: clear'
                                   ELSE 'Sanctions: match found' ).
    ENDIF.
  ENDMETHOD.


  METHOD validate_vendor_phone.
    IF is_vendor-telf1 IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Phone: skipped (no phone number)'.
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_json) = mo_api->validate_phone(
          iv_phone_number = CONV string( is_vendor-telf1 )
          iv_country      = CONV string( is_vendor-land1 ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Phone' ).
  ENDMETHOD.


  METHOD validate_vendor_email.
    IF is_vendor-email IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Email: skipped (no email address)'.
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_json) = mo_api->validate_email(
          iv_email_address = CONV string( is_vendor-email ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Email' ).
  ENDMETHOD.


  METHOD validate_vendor_all.
    DATA ls_screen_result TYPE ty_screen_result.

    LOOP AT mt_config INTO DATA(ls_cfg)
      WHERE tcode = mv_tcode AND active = abap_true.

      " Country filter: skip if configured for a specific country and vendor doesn't match
      IF ls_cfg-country_filter IS NOT INITIAL AND ls_cfg-country_filter <> is_vendor-land1.
        CONTINUE.
      ENDIF.

      CLEAR ls_screen_result.
      ls_screen_result-val_type = ls_cfg-val_type.

      CASE ls_cfg-val_type.
        WHEN gc_val_tax.
          ls_screen_result-result = validate_vendor_tax( is_vendor ).

        WHEN gc_val_bank.
          IF is_bank IS SUPPLIED AND is_bank IS NOT INITIAL.
            ls_screen_result-result = validate_vendor_bank(
              is_bank        = is_bank
              iv_vendor_name = get_vendor_name( is_vendor )
              iv_tax_id      = get_vendor_tax_number( is_vendor )
              iv_tax_type    = COND #( WHEN is_vendor-stceg IS NOT INITIAL THEN 'VAT'
                                       ELSE determine_tax_type( is_vendor-land1 ) ) ).
          ELSE.
            CONTINUE.  " No bank data provided
          ENDIF.

        WHEN gc_val_address.
          ls_screen_result-result = validate_vendor_address( is_vendor ).

        WHEN gc_val_sanct.
          ls_screen_result-result = check_vendor_sanctions( is_vendor ).

        WHEN gc_val_phone.
          ls_screen_result-result = validate_vendor_phone( is_vendor ).

        WHEN gc_val_email.
          ls_screen_result-result = validate_vendor_email( is_vendor ).

        WHEN OTHERS.
          CONTINUE.
      ENDCASE.

      ls_screen_result-blocked = issue_message(
        iv_label      = SWITCH #( ls_cfg-val_type
          WHEN gc_val_tax     THEN 'Tax ID'
          WHEN gc_val_bank    THEN 'Bank Account'
          WHEN gc_val_address THEN 'Address'
          WHEN gc_val_sanct   THEN 'Sanctions'
          WHEN gc_val_phone   THEN 'Phone'
          WHEN gc_val_email   THEN 'Email'
          ELSE ls_cfg-val_type )
        is_result     = ls_screen_result-result
        iv_on_invalid = ls_cfg-on_invalid
        iv_on_error   = ls_cfg-on_error ).

      APPEND ls_screen_result TO rt_results.
    ENDLOOP.
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Customer Master Validations
  " ═══════════════════════════════════════════════════════════════════════

  METHOD validate_customer_tax.
    DATA lv_json     TYPE string.
    DATA lv_tax      TYPE string.
    DATA lv_tax_type TYPE string.

    " STCEG is always VAT regardless of country
    IF is_customer-stceg IS NOT INITIAL.
      lv_tax      = is_customer-stceg.
      lv_tax_type = 'VAT'.
    ELSEIF is_customer-stcd1 IS NOT INITIAL.
      lv_tax      = is_customer-stcd1.
      lv_tax_type = determine_tax_type( is_customer-land1 ).
    ELSEIF is_customer-stcd2 IS NOT INITIAL.
      lv_tax      = is_customer-stcd2.
      lv_tax_type = determine_tax_type( is_customer-land1 ).
    ELSE.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Tax: skipped (no tax number)'.
      RETURN.
    ENDIF.

    DATA(lv_name) = get_customer_name( is_customer ).

    " Customers can be individuals or businesses — determine from name fields
    DATA(lv_entity_type) = COND string(
      WHEN is_customer-name1 IS NOT INITIAL THEN 'Business'
      ELSE 'Individual' ).

    TRY.
        lv_json = mo_api->validate_tax(
          iv_tax_number           = lv_tax
          iv_tax_type             = lv_tax_type
          iv_country              = CONV string( is_customer-land1 )
          iv_company_name         = lv_name
          iv_business_entity_type = lv_entity_type ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Tax ID' ).
  ENDMETHOD.


  METHOD validate_customer_bank.
    DATA lv_json TYPE string.

    IF is_bank-bankn IS INITIAL AND is_bank-iban IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Bank: skipped (no account number)'.
      RETURN.
    ENDIF.

    DATA(lv_holder) = COND string(
      WHEN is_bank-koinh IS NOT INITIAL THEN CONV string( is_bank-koinh )
      ELSE iv_customer_name ).

    TRY.
        lv_json = mo_api->validate_bank_account(
          iv_business_entity_type = iv_business_entity_type
          iv_country              = CONV string( is_bank-banks )
          iv_bank_account_holder  = lv_holder
          iv_account_number       = CONV string( is_bank-bankn )
          iv_bank_code            = CONV string( is_bank-bankl )
          iv_iban                 = CONV string( is_bank-iban )
          iv_swift_code           = CONV string( is_bank-swift )
          iv_business_name        = iv_customer_name
          iv_tax_id_number        = iv_tax_id
          iv_tax_type             = iv_tax_type ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Bank Account' ).
  ENDMETHOD.


  METHOD validate_customer_address.
    DATA lv_json TYPE string.

    IF is_customer-stras IS INITIAL AND is_customer-ort01 IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Address: skipped (no address data)'.
      RETURN.
    ENDIF.

    TRY.
        lv_json = mo_api->validate_address(
          iv_country       = CONV string( is_customer-land1 )
          iv_address_line1 = CONV string( is_customer-stras )
          iv_city          = CONV string( is_customer-ort01 )
          iv_state         = CONV string( is_customer-regio )
          iv_postal_code   = CONV string( is_customer-pstlz )
          iv_company_name  = get_customer_name( is_customer ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Address' ).
  ENDMETHOD.


  METHOD check_customer_sanctions.
    DATA lv_json TYPE string.

    IF is_customer-name1 IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Sanctions: skipped (no name)'.
      RETURN.
    ENDIF.

    DATA(lv_name) = get_customer_name( is_customer ).

    TRY.
        lv_json = mo_api->check_sanctions(
          iv_company_name  = lv_name
          iv_country       = CONV string( is_customer-land1 )
          iv_address_line1 = CONV string( is_customer-stras )
          iv_city          = CONV string( is_customer-ort01 )
          iv_state         = CONV string( is_customer-regio )
          iv_postal_code   = CONV string( is_customer-pstlz ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'hasMatches'
      iv_label = 'Sanctions' ).

    IF rs_result-success = abap_true AND rs_result-field_missing = abap_false.
      rs_result-is_valid = COND #( WHEN rs_result-is_valid = abap_true THEN abap_false
                                    ELSE abap_true ).
    ENDIF.
  ENDMETHOD.


  METHOD validate_customer_phone.
    IF is_customer-telf1 IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Phone: skipped (no phone number)'.
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_json) = mo_api->validate_phone(
          iv_phone_number = CONV string( is_customer-telf1 )
          iv_country      = CONV string( is_customer-land1 ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Phone' ).
  ENDMETHOD.


  METHOD validate_customer_email.
    IF is_customer-email IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Email: skipped (no email address)'.
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_json) = mo_api->validate_email(
          iv_email_address = CONV string( is_customer-email ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Email' ).
  ENDMETHOD.


  METHOD validate_customer_all.
    DATA ls_screen_result TYPE ty_screen_result.

    LOOP AT mt_config INTO DATA(ls_cfg)
      WHERE tcode = mv_tcode AND active = abap_true.

      IF ls_cfg-country_filter IS NOT INITIAL AND ls_cfg-country_filter <> is_customer-land1.
        CONTINUE.
      ENDIF.

      CLEAR ls_screen_result.
      ls_screen_result-val_type = ls_cfg-val_type.

      CASE ls_cfg-val_type.
        WHEN gc_val_tax.
          ls_screen_result-result = validate_customer_tax( is_customer ).

        WHEN gc_val_bank.
          IF is_bank IS SUPPLIED AND is_bank IS NOT INITIAL.
            ls_screen_result-result = validate_customer_bank(
              is_bank                 = is_bank
              iv_customer_name        = get_customer_name( is_customer )
              iv_tax_id               = get_customer_tax_number( is_customer )
              iv_tax_type             = COND #( WHEN is_customer-stceg IS NOT INITIAL THEN 'VAT'
                                                ELSE determine_tax_type( is_customer-land1 ) )
              iv_business_entity_type = COND #( WHEN is_customer-name1 IS NOT INITIAL THEN 'Business'
                                                ELSE 'Individual' ) ).
          ELSE.
            CONTINUE.  " No bank data provided
          ENDIF.

        WHEN gc_val_address.
          ls_screen_result-result = validate_customer_address( is_customer ).

        WHEN gc_val_sanct.
          ls_screen_result-result = check_customer_sanctions( is_customer ).

        WHEN gc_val_phone.
          ls_screen_result-result = validate_customer_phone( is_customer ).

        WHEN gc_val_email.
          ls_screen_result-result = validate_customer_email( is_customer ).

        WHEN OTHERS.
          CONTINUE.
      ENDCASE.

      ls_screen_result-blocked = issue_message(
        iv_label      = SWITCH #( ls_cfg-val_type
          WHEN gc_val_tax     THEN 'Tax ID'
          WHEN gc_val_bank    THEN 'Bank Account'
          WHEN gc_val_address THEN 'Address'
          WHEN gc_val_sanct   THEN 'Sanctions'
          WHEN gc_val_phone   THEN 'Phone'
          WHEN gc_val_email   THEN 'Email'
          ELSE ls_cfg-val_type )
        is_result     = ls_screen_result-result
        iv_on_invalid = ls_cfg-on_invalid
        iv_on_error   = ls_cfg-on_error ).

      APPEND ls_screen_result TO rt_results.
    ENDLOOP.
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Business Partner Validations
  " ═══════════════════════════════════════════════════════════════════════

  METHOD validate_bp_tax.
    DATA lv_json TYPE string.

    IF is_bp-taxnum IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Tax: skipped (no tax number)'.
      RETURN.
    ENDIF.

    " Use explicit tax type from BP if available, otherwise determine from country
    DATA(lv_tax_type) = COND string(
      WHEN is_bp-taxtype IS NOT INITIAL THEN CONV string( is_bp-taxtype )
      ELSE determine_tax_type( is_bp-country ) ).

    DATA(lv_name) = get_bp_name( is_bp ).

    DATA(lv_entity_type) = COND string(
      WHEN is_bp-bpkind = '1' THEN 'Individual'
      ELSE 'Business' ).

    TRY.
        lv_json = mo_api->validate_tax(
          iv_tax_number           = CONV string( is_bp-taxnum )
          iv_tax_type             = lv_tax_type
          iv_country              = CONV string( is_bp-country )
          iv_company_name         = lv_name
          iv_business_entity_type = lv_entity_type ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Tax ID' ).
  ENDMETHOD.


  METHOD validate_bp_bank.
    DATA lv_json TYPE string.

    IF is_bank-bankn IS INITIAL AND is_bank-iban IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Bank: skipped (no account number)'.
      RETURN.
    ENDIF.

    DATA(lv_holder) = COND string(
      WHEN is_bank-koinh IS NOT INITIAL THEN CONV string( is_bank-koinh )
      ELSE iv_bp_name ).

    TRY.
        lv_json = mo_api->validate_bank_account(
          iv_business_entity_type = iv_bp_entity_type
          iv_country              = CONV string( is_bank-banks )
          iv_bank_account_holder  = lv_holder
          iv_account_number       = CONV string( is_bank-bankn )
          iv_bank_code            = CONV string( is_bank-bankl )
          iv_iban                 = CONV string( is_bank-iban )
          iv_swift_code           = CONV string( is_bank-swift )
          iv_business_name        = iv_bp_name
          iv_tax_id_number        = iv_tax_id
          iv_tax_type             = iv_tax_type ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Bank Account' ).
  ENDMETHOD.


  METHOD validate_bp_address.
    DATA lv_json TYPE string.

    IF is_bp-street IS INITIAL AND is_bp-city IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Address: skipped (no address data)'.
      RETURN.
    ENDIF.

    TRY.
        lv_json = mo_api->validate_address(
          iv_country       = CONV string( is_bp-country )
          iv_address_line1 = CONV string( is_bp-street )
          iv_city          = CONV string( is_bp-city )
          iv_state         = CONV string( is_bp-region )
          iv_postal_code   = CONV string( is_bp-postl_cod1 )
          iv_company_name  = get_bp_name( is_bp ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Address' ).
  ENDMETHOD.


  METHOD check_bp_sanctions.
    DATA lv_json TYPE string.

    IF is_bp-name_org1 IS INITIAL AND is_bp-name_last IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Sanctions: skipped (no name)'.
      RETURN.
    ENDIF.

    DATA(lv_name) = get_bp_name( is_bp ).

    TRY.
        lv_json = mo_api->check_sanctions(
          iv_company_name  = lv_name
          iv_country       = CONV string( is_bp-country )
          iv_address_line1 = CONV string( is_bp-street )
          iv_city          = CONV string( is_bp-city )
          iv_state         = CONV string( is_bp-region )
          iv_postal_code   = CONV string( is_bp-postl_cod1 ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'hasMatches'
      iv_label = 'Sanctions' ).

    IF rs_result-success = abap_true AND rs_result-field_missing = abap_false.
      rs_result-is_valid = COND #( WHEN rs_result-is_valid = abap_true THEN abap_false
                                    ELSE abap_true ).
    ENDIF.
  ENDMETHOD.


  METHOD validate_bp_phone.
    IF is_bp-tel_number IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Phone: skipped (no phone number)'.
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_json) = mo_api->validate_phone(
          iv_phone_number = CONV string( is_bp-tel_number )
          iv_country      = CONV string( is_bp-country ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Phone' ).
  ENDMETHOD.


  METHOD validate_bp_email.
    IF is_bp-email IS INITIAL.
      rs_result-success  = abap_true.
      rs_result-is_valid = abap_true.
      rs_result-message  = 'Email: skipped (no email address)'.
      RETURN.
    ENDIF.

    TRY.
        DATA(lv_json) = mo_api->validate_email(
          iv_email_address = CONV string( is_bp-email ) ).
      CATCH zcx_qubiton INTO DATA(lx_err).
        rs_result-success  = abap_false.
        rs_result-message  = lx_err->get_text( ).
        RETURN.
    ENDTRY.

    rs_result = mo_api->parse_result(
      iv_json  = lv_json
      iv_field = 'isValid'
      iv_label = 'Email' ).
  ENDMETHOD.


  METHOD validate_bp_all.
    DATA ls_screen_result TYPE ty_screen_result.

    " Determine business entity type from BP kind
    DATA(lv_entity_type) = COND string(
      WHEN is_bp-bpkind = '1' THEN 'Individual'
      ELSE 'Business' ).

    LOOP AT mt_config INTO DATA(ls_cfg)
      WHERE tcode = mv_tcode AND active = abap_true.

      IF ls_cfg-country_filter IS NOT INITIAL AND ls_cfg-country_filter <> is_bp-country.
        CONTINUE.
      ENDIF.

      CLEAR ls_screen_result.
      ls_screen_result-val_type = ls_cfg-val_type.

      CASE ls_cfg-val_type.
        WHEN gc_val_tax.
          ls_screen_result-result = validate_bp_tax( is_bp ).

        WHEN gc_val_bank.
          IF is_bank IS SUPPLIED AND is_bank IS NOT INITIAL.
            ls_screen_result-result = validate_bp_bank(
              is_bank           = is_bank
              iv_bp_name        = get_bp_name( is_bp )
              iv_bp_entity_type = lv_entity_type
              iv_tax_id         = COND #( WHEN is_bp-taxnum IS NOT INITIAL
                                          THEN CONV string( is_bp-taxnum ) )
              iv_tax_type       = COND #( WHEN is_bp-taxnum IS NOT INITIAL AND is_bp-taxtype IS NOT INITIAL
                                          THEN CONV string( is_bp-taxtype )
                                          WHEN is_bp-taxnum IS NOT INITIAL
                                          THEN determine_tax_type( is_bp-country ) ) ).
          ELSE.
            CONTINUE.
          ENDIF.

        WHEN gc_val_address.
          ls_screen_result-result = validate_bp_address( is_bp ).

        WHEN gc_val_sanct.
          ls_screen_result-result = check_bp_sanctions( is_bp ).

        WHEN gc_val_phone.
          ls_screen_result-result = validate_bp_phone( is_bp ).

        WHEN gc_val_email.
          ls_screen_result-result = validate_bp_email( is_bp ).

        WHEN OTHERS.
          CONTINUE.
      ENDCASE.

      ls_screen_result-blocked = issue_message(
        iv_label      = SWITCH #( ls_cfg-val_type
          WHEN gc_val_tax     THEN 'Tax ID'
          WHEN gc_val_bank    THEN 'Bank Account'
          WHEN gc_val_address THEN 'Address'
          WHEN gc_val_sanct   THEN 'Sanctions'
          WHEN gc_val_phone   THEN 'Phone'
          WHEN gc_val_email   THEN 'Email'
          ELSE ls_cfg-val_type )
        is_result     = ls_screen_result-result
        iv_on_invalid = ls_cfg-on_invalid
        iv_on_error   = ls_cfg-on_error ).

      APPEND ls_screen_result TO rt_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_apikey.
    rv_key = get_config_value( 'APIKEY' ).
  ENDMETHOD.


  METHOD get_config_value.
    " Read a config value from ZQUBITON_CONFIG table using dynamic SQL.
    " Table structure: MANDT, CONFIG_KEY (CHAR30), CONFIG_VALUE (STRING)
    TRY.
        SELECT SINGLE ('CONFIG_VALUE') FROM ('ZQUBITON_CONFIG')
          INTO @rv_value
          WHERE ('CONFIG_KEY') = @iv_key.
      CATCH cx_sy_dynamic_osql_error.
        " Table doesn't exist yet — return empty
        CLEAR rv_value.
    ENDTRY.
  ENDMETHOD.


  METHOD set_config_for_testing.
    mt_config = it_config.
  ENDMETHOD.

ENDCLASS.
