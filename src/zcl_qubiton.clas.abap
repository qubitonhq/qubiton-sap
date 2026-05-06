"! <p class="shorttext synchronized">QubitOn API Client</p>
"! ABAP class for calling the QubitOn API from SAP S/4HANA, ECC, or BTP.
"! Full API coverage: 42 methods across address, tax, bank, email, phone,
"! compliance, risk, corporate structure, healthcare, certification, and more.
"!
"! <p>Requires RFC destination <strong>QubitOn</strong> of type HTTP
"! pointing to <code>https://api.qubiton.com</code>.</p>
"!
"! <p>Configurable error handling: iv_on_error (API failures) and iv_on_invalid
"! (validation failures) accept E=stop, W=warn, S=silent.</p>
"!
"! @version 1.0.0
"! @author  QubitOn
"! @see     https://www.qubiton.com/docs
CLASS zcl_qubiton DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC
  GLOBAL FRIENDS zcl_qubiton_test.

  PUBLIC SECTION.

    " ── JSON Field Type Constants ───────────────────────────────────────────
    CONSTANTS:
      gc_type_string  TYPE char1 VALUE 'S',  " Default — JSON string (quoted)
      gc_type_number  TYPE char1 VALUE 'N',  " JSON number (unquoted)
      gc_type_boolean TYPE char1 VALUE 'B'.  " JSON boolean (unquoted true/false)

    " ── Error Handling Mode Constants ───────────────────────────────────────
    CONSTANTS:
      gc_on_error_stop   TYPE char1 VALUE 'E',  " Hard stop — raise exception (block save)
      gc_on_error_warn   TYPE char1 VALUE 'W',  " Soft warning — show message, let user proceed
      gc_on_error_silent TYPE char1 VALUE 'S'.  " Silent — log only, no user message

    " ── Validation Failure Mode Constants ───────────────────────────────────
    CONSTANTS:
      gc_on_invalid_stop   TYPE char1 VALUE 'E',  " Block save when validation returns isValid=false
      gc_on_invalid_warn   TYPE char1 VALUE 'W',  " Warn but allow save
      gc_on_invalid_silent TYPE char1 VALUE 'S'.  " Silent — caller checks result

    " ── Message Class Constants (SE91: ZCL_QUBITON_MSG) ───────────────────
    CONSTANTS:
      gc_msgid TYPE symsgid VALUE 'ZCL_QUBITON_MSG'.  " Message class for translatable messages

    " ── BAL Log Object Constants (SLG0: ZQUBITON) ─────────────────────────
    CONSTANTS:
      gc_bal_object    TYPE balobj_d  VALUE 'ZQUBITON',
      gc_bal_subobject TYPE balsubobj VALUE 'ZAPI_CALL'.

    TYPES:
      BEGIN OF ty_name_value,
        name  TYPE string,
        value TYPE string,
        type  TYPE char1,  " S=string (default), N=number, B=boolean
      END OF ty_name_value,
      tt_name_value TYPE STANDARD TABLE OF ty_name_value WITH EMPTY KEY.

    "! Parsed API result — use instead of raw JSON when you want built-in message handling
    TYPES:
      BEGIN OF ty_result,
        success       TYPE abap_bool,  " API call succeeded (HTTP 2xx)
        is_valid      TYPE abap_bool,  " Validation passed (isValid/found/hasMatches from response)
        field_missing TYPE abap_bool,  " True when the expected validity field is absent from response
        message       TYPE string,     " Human-readable message for UI display
        raw_json      TYPE string,     " Full JSON response for further processing
      END OF ty_result,
      tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    "! <p class="shorttext synchronized">Constructor</p>
    "! @parameter iv_destination | RFC destination name (default: QubitOn)
    "! @parameter iv_apikey      | API key (overrides destination header if supplied)
    "! @parameter iv_on_error    | What to do on HTTP/network failure: E=stop, W=warn (default), S=silent
    "! @parameter iv_on_invalid  | What to do when validation fails: E=stop, W=warn (default), S=silent
    "! @parameter iv_check_auth  | Check ZQUBITON_API authorization before API calls (falls back to S_RFC; default: false)
    "! @parameter iv_log_enabled | Write API calls to BAL Application Log SLG1 (default: true)
    "! @parameter iv_keep_alive  | Reuse HTTP connection across calls (default: false — faster for batch)
    "! @parameter iv_timeout     | HTTP timeout in seconds (default: 30)
    METHODS constructor
      IMPORTING
        iv_destination  TYPE string DEFAULT 'QubitOn'
        iv_apikey       TYPE string OPTIONAL
        iv_on_error     TYPE char1 DEFAULT 'W'
        iv_on_invalid   TYPE char1 DEFAULT 'W'
        iv_check_auth   TYPE abap_bool DEFAULT abap_false
        iv_log_enabled  TYPE abap_bool DEFAULT abap_true
        iv_keep_alive   TYPE abap_bool DEFAULT abap_false
        iv_timeout      TYPE i DEFAULT 30
      RAISING
        zcx_qubiton.

    " ── Address Validation ──────────────────────────────────────────────────

    "! POST /api/address/validate — Validate and standardize postal addresses (249 countries)
    METHODS validate_address
      IMPORTING
        iv_country       TYPE string
        iv_address_line1 TYPE string OPTIONAL
        iv_address_line2 TYPE string OPTIONAL
        iv_city          TYPE string OPTIONAL
        iv_state         TYPE string OPTIONAL
        iv_postal_code   TYPE string OPTIONAL
        iv_company_name  TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)   TYPE string
      RAISING
        zcx_qubiton.

    " ── Tax Validation ──────────────────────────────────────────────────────

    "! POST /api/tax/validate — Validate tax IDs with live authority checks (60+ countries)
    METHODS validate_tax
      IMPORTING
        iv_tax_number          TYPE string
        iv_tax_type            TYPE string
        iv_country             TYPE string
        iv_company_name        TYPE string
        iv_business_entity_type TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)         TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/tax/format-validate — Validate tax ID format via regex/checksum (193 countries)
    METHODS validate_tax_format
      IMPORTING
        iv_tax_number  TYPE string
        iv_tax_type    TYPE string
        iv_country     TYPE string
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    " ── Bank Account Validation ─────────────────────────────────────────────

    "! POST /api/bank/validate — Validate bank accounts (180+ countries)
    METHODS validate_bank_account
      IMPORTING
        iv_business_entity_type TYPE string
        iv_country              TYPE string
        iv_bank_account_holder  TYPE string
        iv_account_number       TYPE string OPTIONAL
        iv_business_name        TYPE string OPTIONAL
        iv_tax_id_number        TYPE string OPTIONAL
        iv_tax_type             TYPE string OPTIONAL
        iv_bank_code            TYPE string OPTIONAL
        iv_iban                 TYPE string OPTIONAL
        iv_swift_code           TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)          TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/bankaccount/pro/validate — Premium bank analytics with ownership verification
    METHODS validate_bank_pro
      IMPORTING
        iv_business_entity_type TYPE string
        iv_country              TYPE string
        iv_bank_account_holder  TYPE string
        iv_account_number       TYPE string OPTIONAL
        iv_bank_code            TYPE string OPTIONAL
        iv_iban                 TYPE string OPTIONAL
        iv_swift_code           TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)          TYPE string
      RAISING
        zcx_qubiton.

    " ── Email & Phone Validation ────────────────────────────────────────────

    "! POST /api/email/validate — Validate email deliverability and risk
    METHODS validate_email
      IMPORTING
        iv_email_address TYPE string
      RETURNING
        VALUE(rv_json)   TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/phone/validate — Validate phone numbers against carrier databases
    METHODS validate_phone
      IMPORTING
        iv_phone_number    TYPE string
        iv_country         TYPE string
        iv_phone_extension TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)     TYPE string
      RAISING
        zcx_qubiton.

    " ── Business Registration ───────────────────────────────────────────────

    "! POST /api/businessregistration/lookup — Look up official business registration records
    METHODS lookup_business_registration
      IMPORTING
        iv_company_name TYPE string
        iv_country      TYPE string
        iv_state        TYPE string OPTIONAL
        iv_city         TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)  TYPE string
      RAISING
        zcx_qubiton.

    " ── Peppol ──────────────────────────────────────────────────────────────

    "! POST /api/peppol/validate — Validate Peppol participant IDs (70+ ICD schemes)
    METHODS validate_peppol
      IMPORTING
        iv_participant_id   TYPE string
        iv_directory_lookup TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)      TYPE string
      RAISING
        zcx_qubiton.

    " ── Sanctions & Compliance ──────────────────────────────────────────────

    "! POST /api/prohibited/lookup — Screen against 100+ global sanctions lists (OFAC, EU, UN)
    METHODS check_sanctions
      IMPORTING
        iv_company_name  TYPE string
        iv_country       TYPE string
        iv_address_line1 TYPE string OPTIONAL
        iv_address_line2 TYPE string OPTIONAL
        iv_city          TYPE string OPTIONAL
        iv_state         TYPE string OPTIONAL
        iv_postal_code   TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)   TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/pep/lookup — Screen against Politically Exposed Person databases
    METHODS screen_pep
      IMPORTING
        iv_name        TYPE string
        iv_country     TYPE string
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/disqualifieddirectors/validate — Check for disqualified directors
    METHODS check_directors
      IMPORTING
        iv_first_name  TYPE string
        iv_last_name   TYPE string
        iv_country     TYPE string
        iv_middle_name TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    " ── EPA Prosecution ─────────────────────────────────────────────────────

    "! POST /api/criminalprosecution/validate — Screen against EPA criminal prosecution records
    METHODS check_epa_prosecution
      IMPORTING
        iv_name        TYPE string OPTIONAL
        iv_state       TYPE string OPTIONAL
        iv_fiscal_year TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/criminalprosecution/lookup — Look up EPA criminal prosecution details
    METHODS lookup_epa_prosecution
      IMPORTING
        iv_name        TYPE string OPTIONAL
        iv_state       TYPE string OPTIONAL
        iv_fiscal_year TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    " ── Healthcare Exclusion ────────────────────────────────────────────────

    "! POST /api/providerexclusion/validate — Screen against healthcare provider exclusion lists
    METHODS check_healthcare_exclusion
      IMPORTING
        iv_healthcare_type TYPE string
        iv_entity_name     TYPE string OPTIONAL
        iv_last_name       TYPE string OPTIONAL
        iv_first_name      TYPE string OPTIONAL
        iv_address         TYPE string OPTIONAL
        iv_city            TYPE string OPTIONAL
        iv_state           TYPE string OPTIONAL
        iv_zip_code        TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)     TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/providerexclusion/lookup — Look up healthcare provider exclusion details
    METHODS lookup_healthcare_exclusion
      IMPORTING
        iv_healthcare_type TYPE string
        iv_entity_name     TYPE string OPTIONAL
        iv_last_name       TYPE string OPTIONAL
        iv_first_name      TYPE string OPTIONAL
        iv_address         TYPE string OPTIONAL
        iv_city            TYPE string OPTIONAL
        iv_state           TYPE string OPTIONAL
        iv_zip_code        TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)     TYPE string
      RAISING
        zcx_qubiton.

    " ── Risk & Financial ────────────────────────────────────────────────────

    "! POST /api/risk/lookup (category=Bankruptcy) — Check for bankruptcy filings
    METHODS check_bankruptcy_risk
      IMPORTING
        iv_company_name TYPE string
        iv_country      TYPE string
      RETURNING
        VALUE(rv_json)  TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/risk/lookup (category=Credit Score) — Look up commercial credit scores
    METHODS lookup_credit_score
      IMPORTING
        iv_company_name TYPE string
        iv_country      TYPE string
      RETURNING
        VALUE(rv_json)  TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/risk/lookup (category=Fail Rate) — Look up payment failure rates
    METHODS lookup_fail_rate
      IMPORTING
        iv_company_name TYPE string
        iv_country      TYPE string
      RETURNING
        VALUE(rv_json)  TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/entity/fraud/lookup — Assess entity fraud risk and adverse media
    METHODS assess_entity_risk
      IMPORTING
        iv_company_name         TYPE string
        iv_country              TYPE string OPTIONAL
        iv_category             TYPE string OPTIONAL
        iv_url                  TYPE string OPTIONAL
        iv_business_entity_type TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)          TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/creditanalysis/lookup — Comprehensive credit analysis
    METHODS lookup_credit_analysis
      IMPORTING
        iv_company_name  TYPE string
        iv_address_line1 TYPE string
        iv_city          TYPE string
        iv_state         TYPE string
        iv_country       TYPE string
        iv_duns_number   TYPE string OPTIONAL
        iv_postal_code   TYPE string OPTIONAL
        iv_address_line2 TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)   TYPE string
      RAISING
        zcx_qubiton.

    " ── ESG & Cybersecurity ─────────────────────────────────────────────────

    "! POST /api/esg/Scores — Look up ESG (Environmental, Social, Governance) scores
    METHODS lookup_esg_score
      IMPORTING
        iv_company_name TYPE string
        iv_country      TYPE string
        iv_domain       TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)  TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/itsecurity/domainreport — Assess domain cybersecurity and threat intelligence
    METHODS domain_security_report
      IMPORTING
        iv_domain_name TYPE string
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/ipquality/validate — Check IP address quality and fraud risk
    METHODS check_ip_quality
      IMPORTING
        iv_ip_address  TYPE string
        iv_user_agent  TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    " ── Corporate Structure ─────────────────────────────────────────────────

    "! POST /api/beneficialownership/lookup — Look up beneficial ownership (UBO)
    METHODS lookup_beneficial_ownership
      IMPORTING
        iv_company_name  TYPE string
        iv_country_iso2  TYPE string
        iv_ubo_threshold TYPE string OPTIONAL
        iv_max_layers    TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)   TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/corporatehierarchy/lookup — Look up corporate hierarchy (US only)
    METHODS lookup_corporate_hierarchy
      IMPORTING
        iv_company_name  TYPE string
        iv_address_line1 TYPE string
        iv_city          TYPE string
        iv_state         TYPE string
        iv_zip_code      TYPE string
      RETURNING
        VALUE(rv_json)   TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/duns-number-lookup — Look up DUNS number
    METHODS lookup_duns
      IMPORTING
        iv_duns_number TYPE string
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/company/hierarchy/lookup — Look up company parent-child hierarchy
    METHODS lookup_hierarchy
      IMPORTING
        iv_identifier      TYPE string
        iv_identifier_type TYPE string
        iv_country         TYPE string OPTIONAL
        iv_options         TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)     TYPE string
      RAISING
        zcx_qubiton.

    " ── Industry Specific ───────────────────────────────────────────────────

    "! POST /api/nationalprovideridentifier/validate — Validate US National Provider Identifiers
    METHODS validate_npi
      IMPORTING
        iv_npi               TYPE string
        iv_organization_name TYPE string OPTIONAL
        iv_last_name         TYPE string OPTIONAL
        iv_first_name        TYPE string OPTIONAL
        iv_middle_name       TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)       TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/medpass/validate — Validate healthcare suppliers via Medpass
    METHODS validate_medpass
      IMPORTING
        iv_id                   TYPE string
        iv_business_entity_type TYPE string
        iv_company_name         TYPE string OPTIONAL
        iv_tax_id               TYPE string OPTIONAL
        iv_country              TYPE string OPTIONAL
        iv_state                TYPE string OPTIONAL
        iv_city                 TYPE string OPTIONAL
        iv_postal_code          TYPE string OPTIONAL
        iv_address_line1        TYPE string OPTIONAL
        iv_address_line2        TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)          TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/dot/fmcsa/lookup — Look up USDOT/FMCSA motor carrier safety data
    METHODS lookup_dot_carrier
      IMPORTING
        iv_dot_number  TYPE string
        iv_entity_name TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/inidentity/validate — Validate Indian identity documents
    METHODS validate_india_identity
      IMPORTING
        iv_identity_number      TYPE string
        iv_identity_number_type TYPE string
        iv_entity_name          TYPE string OPTIONAL
        iv_dob                  TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)          TYPE string
      RAISING
        zcx_qubiton.

    " ── Certification ───────────────────────────────────────────────────────

    "! POST /api/certification/validate — Validate business certifications (MBE, WBE, DBE)
    METHODS validate_certification
      IMPORTING
        iv_company_name         TYPE string
        iv_country              TYPE string
        iv_city                 TYPE string OPTIONAL
        iv_state                TYPE string OPTIONAL
        iv_zip_code             TYPE string OPTIONAL
        iv_address_line1        TYPE string OPTIONAL
        iv_address_line2        TYPE string OPTIONAL
        iv_identity_type        TYPE string OPTIONAL
        iv_certification_type   TYPE string OPTIONAL
        iv_certification_group  TYPE string OPTIONAL
        iv_certification_number TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)          TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/certification/lookup — Look up business certifications
    METHODS lookup_certification
      IMPORTING
        iv_company_name         TYPE string
        iv_country              TYPE string
        iv_city                 TYPE string OPTIONAL
        iv_state                TYPE string OPTIONAL
        iv_zip_code             TYPE string OPTIONAL
        iv_address_line1        TYPE string OPTIONAL
        iv_address_line2        TYPE string OPTIONAL
        iv_identity_type        TYPE string OPTIONAL
        iv_certification_type   TYPE string OPTIONAL
        iv_certification_group  TYPE string OPTIONAL
        iv_certification_number TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)          TYPE string
      RAISING
        zcx_qubiton.

    " ── Business Classification ─────────────────────────────────────────────

    "! POST /api/businessclassification/lookup — Look up NAICS/SIC codes
    METHODS lookup_business_classification
      IMPORTING
        iv_company_name TYPE string
        iv_city         TYPE string
        iv_state        TYPE string
        iv_country      TYPE string
        iv_address1     TYPE string OPTIONAL
        iv_address2     TYPE string OPTIONAL
        iv_phone        TYPE string OPTIONAL
        iv_postal_code  TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)  TYPE string
      RAISING
        zcx_qubiton.

    " ── Financial Operations ────────────────────────────────────────────────

    "! POST /api/paymentterms/validate — Analyze payment terms for optimization
    METHODS analyze_payment_terms
      IMPORTING
        iv_current_pay_term TYPE string
        iv_annual_spend     TYPE string
        iv_avg_days_pay     TYPE string
        iv_savings_rate     TYPE string
        iv_threshold        TYPE string
        iv_vendor_name      TYPE string OPTIONAL
        iv_country          TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json)      TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/currency/exchange-rates/{baseCurrency} — Look up currency exchange rates
    METHODS lookup_exchange_rates
      IMPORTING
        iv_base_currency TYPE string
        iv_dates         TYPE string
      RETURNING
        VALUE(rv_json)   TYPE string
      RAISING
        zcx_qubiton.

    " ── Supplier Profile (SAP Ariba) ────────────────────────────────────────

    "! POST /api/aribasupplierprofile/lookup — Look up SAP Ariba supplier profile by ANID
    METHODS lookup_ariba_supplier
      IMPORTING
        iv_anid        TYPE string
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    "! POST /api/aribasupplierprofile/validate — Validate SAP Ariba supplier profile by ANID
    METHODS validate_ariba_supplier
      IMPORTING
        iv_anid        TYPE string
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    " ── Gender Identification ───────────────────────────────────────────────

    "! POST /api/genderize/identifygender — Predict gender from a person's name
    METHODS identify_gender
      IMPORTING
        iv_name        TYPE string
        iv_country     TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    " ── Reference Endpoints ─────────────────────────────────────────────────

    "! GET /api/tax/format-validate/countries — List supported tax format countries
    METHODS get_supported_tax_formats
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    "! GET /api/peppol/schemes — List supported Peppol ICD schemes
    METHODS get_peppol_schemes
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    " ── Safe Call Wrapper ──────────────────────────────────────────────────

    "! Call any API method with built-in error and validation handling.
    "! Returns a parsed result with success/is_valid/message instead of raw JSON.
    "! Honors the iv_on_error and iv_on_invalid config from the constructor.
    "! Does NOT raise exceptions — safe for real-time UI hooks.
    "! @parameter iv_json | Raw JSON response from any API method (pass result of validate_* / lookup_* / check_*)
    "! @parameter iv_field | JSON field to check for validity (default: isValid). Use hasMatches, found, etc. for other endpoints.
    "! @parameter iv_label | Human-readable label for messages (e.g., 'Tax ID', 'Bank Account')
    METHODS parse_result
      IMPORTING
        iv_json        TYPE string
        iv_field       TYPE string DEFAULT 'isValid'
        iv_label       TYPE string DEFAULT 'Validation'
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    "! Convenience wrapper: call an API method safely with automatic error/validation handling.
    "! Use this instead of calling API methods directly when you want the class to handle
    "! messaging and stop/warn behavior based on configuration.
    "! @parameter iv_json  | Raw JSON from an API method call
    "! @parameter iv_field | JSON field name for the validity check (default: isValid)
    "! @parameter iv_label | Label for user-facing messages (e.g., 'Address', 'Tax ID')
    METHODS handle_result
      IMPORTING
        iv_json          TYPE string
        iv_field         TYPE string DEFAULT 'isValid'
        iv_label         TYPE string DEFAULT 'Validation'
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    "! Persist BAL log entries to database (viewable in SLG1).
    "! Call this after a batch of API calls to flush the log.
    "! Automatically called on each send_request for real-time logging.
    "! Note: BAL_DB_SAVE requires COMMIT WORK in some contexts (batch reports).
    "! BAdI frameworks handle COMMIT automatically; standalone callers must commit.
    METHODS flush_log.

    "! Close the persistent HTTP connection (only needed when iv_keep_alive = true).
    "! Call this when you are done making API calls to release the connection.
    "! Safe to call even when no connection is open.
    METHODS close.

  PRIVATE SECTION.

    DATA mv_destination  TYPE string.
    DATA mv_apikey       TYPE string.
    DATA mv_on_error     TYPE char1.
    DATA mv_on_invalid   TYPE char1.
    DATA mv_check_auth   TYPE abap_bool.
    DATA mv_log_enabled  TYPE abap_bool.
    DATA mv_keep_alive   TYPE abap_bool.
    DATA mv_timeout      TYPE i.
    DATA mv_log_handle   TYPE balloghndl.
    DATA mo_client       TYPE REF TO if_http_client.

    "! Generic POST helper
    METHODS post
      IMPORTING
        iv_path        TYPE string
        iv_body        TYPE string
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    "! Generic GET helper
    METHODS get
      IMPORTING
        iv_path        TYPE string
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    "! Send an HTTP request and return the response body
    METHODS send_request
      IMPORTING
        iv_path        TYPE string
        iv_method      TYPE string
        iv_body        TYPE string OPTIONAL
      RETURNING
        VALUE(rv_json) TYPE string
      RAISING
        zcx_qubiton.

    "! Build a JSON object from name/value pairs (skips blank values)
    METHODS build_json
      IMPORTING
        it_fields      TYPE tt_name_value
      RETURNING
        VALUE(rv_json) TYPE string.

    "! Build a JSON array of strings from a comma-separated value list.
    "! Empty entries are skipped; each non-empty entry is JSON-escaped and
    "! quoted. Used by endpoints that expect a body of the shape ["a","b"].
    METHODS build_json_array
      IMPORTING
        iv_csv         TYPE string
      RETURNING
        VALUE(rv_json) TYPE string.

    " ── Per-endpoint body builders ──────────────────────────────────────
    " Each helper builds the JSON request body for one QubitOn API endpoint.
    " Extracted from the API methods so unit tests can verify the wire
    " contract directly (instead of building expected field tables and
    " hoping they match the method). Five helpers are shared across
    " endpoints with identical request shapes (see comments on each).

    METHODS build_address_body
      IMPORTING iv_country       TYPE string
                iv_address_line1 TYPE string OPTIONAL
                iv_address_line2 TYPE string OPTIONAL
                iv_city          TYPE string OPTIONAL
                iv_state         TYPE string OPTIONAL
                iv_postal_code   TYPE string OPTIONAL
                iv_company_name  TYPE string OPTIONAL
      RETURNING VALUE(rv_json)   TYPE string.

    METHODS build_tax_body
      IMPORTING iv_tax_number          TYPE string
                iv_tax_type            TYPE string
                iv_country             TYPE string
                iv_company_name        TYPE string
                iv_business_entity_type TYPE string OPTIONAL
      RETURNING VALUE(rv_json)         TYPE string.

    METHODS build_tax_format_body
      IMPORTING iv_tax_number  TYPE string
                iv_tax_type    TYPE string
                iv_country     TYPE string
      RETURNING VALUE(rv_json) TYPE string.

    METHODS build_bank_account_body
      IMPORTING iv_business_entity_type TYPE string
                iv_country              TYPE string
                iv_bank_account_holder  TYPE string
                iv_account_number       TYPE string OPTIONAL
                iv_business_name        TYPE string OPTIONAL
                iv_tax_id_number        TYPE string OPTIONAL
                iv_tax_type             TYPE string OPTIONAL
                iv_bank_code            TYPE string OPTIONAL
                iv_iban                 TYPE string OPTIONAL
                iv_swift_code           TYPE string OPTIONAL
      RETURNING VALUE(rv_json)          TYPE string.

    METHODS build_bank_pro_body
      IMPORTING iv_business_entity_type TYPE string
                iv_country              TYPE string
                iv_bank_account_holder  TYPE string
                iv_account_number       TYPE string OPTIONAL
                iv_bank_code            TYPE string OPTIONAL
                iv_iban                 TYPE string OPTIONAL
                iv_swift_code           TYPE string OPTIONAL
      RETURNING VALUE(rv_json)          TYPE string.

    METHODS build_email_body
      IMPORTING iv_email_address TYPE string
      RETURNING VALUE(rv_json)   TYPE string.

    METHODS build_phone_body
      IMPORTING iv_phone_number    TYPE string
                iv_country         TYPE string
                iv_phone_extension TYPE string OPTIONAL
      RETURNING VALUE(rv_json)     TYPE string.

    METHODS build_peppol_body
      IMPORTING iv_participant_id   TYPE string
                iv_directory_lookup TYPE string OPTIONAL
      RETURNING VALUE(rv_json)      TYPE string.

    METHODS build_busreg_body
      IMPORTING iv_company_name TYPE string
                iv_country      TYPE string
                iv_state        TYPE string OPTIONAL
                iv_city         TYPE string OPTIONAL
      RETURNING VALUE(rv_json)  TYPE string.

    METHODS build_busclass_body
      IMPORTING iv_company_name TYPE string
                iv_city         TYPE string
                iv_state        TYPE string
                iv_country      TYPE string
                iv_address1     TYPE string OPTIONAL
                iv_address2     TYPE string OPTIONAL
                iv_phone        TYPE string OPTIONAL
                iv_postal_code  TYPE string OPTIONAL
      RETURNING VALUE(rv_json)  TYPE string.

    METHODS build_sanctions_body
      IMPORTING iv_company_name  TYPE string
                iv_country       TYPE string
                iv_address_line1 TYPE string OPTIONAL
                iv_address_line2 TYPE string OPTIONAL
                iv_city          TYPE string OPTIONAL
                iv_state         TYPE string OPTIONAL
                iv_postal_code   TYPE string OPTIONAL
      RETURNING VALUE(rv_json)   TYPE string.

    METHODS build_pep_body
      IMPORTING iv_name        TYPE string
                iv_country     TYPE string
      RETURNING VALUE(rv_json) TYPE string.

    METHODS build_directors_body
      IMPORTING iv_first_name  TYPE string
                iv_last_name   TYPE string
                iv_country     TYPE string
                iv_middle_name TYPE string OPTIONAL
      RETURNING VALUE(rv_json) TYPE string.

    "! Shared by check_epa_prosecution and lookup_epa_prosecution
    "! (identical request shape).
    METHODS build_epa_body
      IMPORTING iv_name        TYPE string OPTIONAL
                iv_state       TYPE string OPTIONAL
                iv_fiscal_year TYPE string OPTIONAL
      RETURNING VALUE(rv_json) TYPE string.

    "! Shared by check_healthcare_exclusion and lookup_healthcare_exclusion.
    METHODS build_healthcare_body
      IMPORTING iv_healthcare_type TYPE string
                iv_entity_name     TYPE string OPTIONAL
                iv_last_name       TYPE string OPTIONAL
                iv_first_name      TYPE string OPTIONAL
                iv_address         TYPE string OPTIONAL
                iv_city            TYPE string OPTIONAL
                iv_state           TYPE string OPTIONAL
                iv_zip_code        TYPE string OPTIONAL
      RETURNING VALUE(rv_json)     TYPE string.

    "! Shared by check_bankruptcy_risk, lookup_credit_score, lookup_fail_rate
    "! (all POST /api/risk/lookup, distinguished by iv_category).
    METHODS build_risk_body
      IMPORTING iv_company_name TYPE string
                iv_category     TYPE string
                iv_country      TYPE string
      RETURNING VALUE(rv_json)  TYPE string.

    METHODS build_entity_risk_body
      IMPORTING iv_company_name         TYPE string
                iv_country              TYPE string OPTIONAL
                iv_category             TYPE string OPTIONAL
                iv_url                  TYPE string OPTIONAL
                iv_business_entity_type TYPE string OPTIONAL
      RETURNING VALUE(rv_json)          TYPE string.

    METHODS build_credit_analysis_body
      IMPORTING iv_company_name  TYPE string
                iv_address_line1 TYPE string
                iv_city          TYPE string
                iv_state         TYPE string
                iv_country       TYPE string
                iv_duns_number   TYPE string OPTIONAL
                iv_postal_code   TYPE string OPTIONAL
                iv_address_line2 TYPE string OPTIONAL
      RETURNING VALUE(rv_json)   TYPE string.

    "! ESG body contains only companyName; country and domain are bound
    "! as [FromQuery] on the API controller and built into the URL by
    "! lookup_esg_score itself.
    METHODS build_esg_body
      IMPORTING iv_company_name TYPE string
      RETURNING VALUE(rv_json)  TYPE string.

    METHODS build_domain_security_body
      IMPORTING iv_domain_name TYPE string
      RETURNING VALUE(rv_json) TYPE string.

    METHODS build_ip_quality_body
      IMPORTING iv_ip_address  TYPE string
                iv_user_agent  TYPE string OPTIONAL
      RETURNING VALUE(rv_json) TYPE string.

    METHODS build_ubo_body
      IMPORTING iv_company_name  TYPE string
                iv_country_iso2  TYPE string
                iv_ubo_threshold TYPE string OPTIONAL
                iv_max_layers    TYPE string OPTIONAL
      RETURNING VALUE(rv_json)   TYPE string.

    METHODS build_corp_hierarchy_body
      IMPORTING iv_company_name  TYPE string
                iv_address_line1 TYPE string
                iv_city          TYPE string
                iv_state         TYPE string
                iv_zip_code      TYPE string
      RETURNING VALUE(rv_json)   TYPE string.

    METHODS build_duns_body
      IMPORTING iv_duns_number TYPE string
      RETURNING VALUE(rv_json) TYPE string.

    METHODS build_hierarchy_body
      IMPORTING iv_identifier      TYPE string
                iv_identifier_type TYPE string
                iv_country         TYPE string OPTIONAL
                iv_options         TYPE string OPTIONAL
      RETURNING VALUE(rv_json)     TYPE string.

    METHODS build_npi_body
      IMPORTING iv_npi               TYPE string
                iv_organization_name TYPE string OPTIONAL
                iv_last_name         TYPE string OPTIONAL
                iv_first_name        TYPE string OPTIONAL
                iv_middle_name       TYPE string OPTIONAL
      RETURNING VALUE(rv_json)       TYPE string.

    METHODS build_medpass_body
      IMPORTING iv_id                   TYPE string
                iv_business_entity_type TYPE string
                iv_company_name         TYPE string OPTIONAL
                iv_tax_id               TYPE string OPTIONAL
                iv_country              TYPE string OPTIONAL
                iv_state                TYPE string OPTIONAL
                iv_city                 TYPE string OPTIONAL
                iv_postal_code          TYPE string OPTIONAL
                iv_address_line1        TYPE string OPTIONAL
                iv_address_line2        TYPE string OPTIONAL
      RETURNING VALUE(rv_json)          TYPE string.

    METHODS build_dot_carrier_body
      IMPORTING iv_dot_number  TYPE string
                iv_entity_name TYPE string OPTIONAL
      RETURNING VALUE(rv_json) TYPE string.

    METHODS build_in_identity_body
      IMPORTING iv_identity_number      TYPE string
                iv_identity_number_type TYPE string
                iv_entity_name          TYPE string OPTIONAL
                iv_dob                  TYPE string OPTIONAL
      RETURNING VALUE(rv_json)          TYPE string.

    "! Shared by validate_certification and lookup_certification.
    METHODS build_certification_body
      IMPORTING iv_company_name         TYPE string
                iv_country              TYPE string
                iv_city                 TYPE string OPTIONAL
                iv_state                TYPE string OPTIONAL
                iv_zip_code             TYPE string OPTIONAL
                iv_address_line1        TYPE string OPTIONAL
                iv_address_line2        TYPE string OPTIONAL
                iv_identity_type        TYPE string OPTIONAL
                iv_certification_type   TYPE string OPTIONAL
                iv_certification_group  TYPE string OPTIONAL
                iv_certification_number TYPE string OPTIONAL
      RETURNING VALUE(rv_json)          TYPE string.

    METHODS build_payment_terms_body
      IMPORTING iv_current_pay_term TYPE string
                iv_annual_spend     TYPE string
                iv_avg_days_pay     TYPE string
                iv_savings_rate     TYPE string
                iv_threshold        TYPE string
                iv_vendor_name      TYPE string OPTIONAL
                iv_country          TYPE string OPTIONAL
      RETURNING VALUE(rv_json)      TYPE string.

    "! Shared by lookup_ariba_supplier and validate_ariba_supplier.
    METHODS build_ariba_body
      IMPORTING iv_anid        TYPE string
      RETURNING VALUE(rv_json) TYPE string.

    METHODS build_gender_body
      IMPORTING iv_name        TYPE string
                iv_country     TYPE string OPTIONAL
      RETURNING VALUE(rv_json) TYPE string.

    "! Check S_RFC authorization
    METHODS check_authority
      RAISING
        zcx_qubiton.

    "! Write entry to BAL Application Log (SLG1)
    METHODS log_api_call
      IMPORTING
        iv_method  TYPE string
        iv_path    TYPE string
        iv_status  TYPE i
        iv_elapsed TYPE i
        iv_msgtype TYPE symsgty DEFAULT 'I'.

    "! Open BAL log handle for this session
    METHODS open_log.

    "! Save and close BAL log
    METHODS save_log.

    "! Escape a string for JSON (backslash, quotes, control characters)
    METHODS escape_json_value
      IMPORTING
        iv_value         TYPE string
      RETURNING
        VALUE(rv_escaped) TYPE string.

ENDCLASS.


CLASS zcl_qubiton IMPLEMENTATION.

  METHOD constructor.
    mv_destination  = iv_destination.
    mv_apikey       = iv_apikey.
    mv_on_error     = iv_on_error.
    mv_on_invalid   = iv_on_invalid.
    mv_check_auth   = iv_check_auth.
    mv_log_enabled  = iv_log_enabled.
    mv_keep_alive   = iv_keep_alive.
    mv_timeout      = iv_timeout.

    " S_RFC authorization check (optional — required for SAP certification)
    IF mv_check_auth = abap_true.
      check_authority( ).
    ENDIF.

    " Open BAL application log session
    IF mv_log_enabled = abap_true.
      open_log( ).
    ENDIF.
  ENDMETHOD.


  METHOD send_request.
    DATA: lo_client   TYPE REF TO if_http_client,
          lv_status   TYPE i,
          lv_reason   TYPE string,
          lv_start    TYPE i,
          lv_end      TYPE i,
          lv_elapsed  TYPE i.

    " Capture start time for BAL logging
    GET RUN TIME FIELD lv_start.

    " Create or reuse HTTP client
    IF mv_keep_alive = abap_true AND mo_client IS BOUND.
      lo_client = mo_client.
      " Clear previous request body to prevent stale POST data on subsequent GET calls
      lo_client->request->set_cdata( '' ).
    ELSE.
      " Create HTTP client from RFC destination
      cl_http_client=>create_by_destination(
        EXPORTING
          destination              = CONV rfcdest( mv_destination )
        IMPORTING
          client                   = lo_client
        EXCEPTIONS
          argument_not_found       = 1
          destination_not_found    = 2
          destination_no_authority = 3
          plugin_not_active        = 4
          internal_error           = 5
          OTHERS                   = 6 ).

      IF sy-subrc <> 0 OR lo_client IS NOT BOUND.
        log_api_call( iv_method = iv_method iv_path = iv_path iv_status = 0 iv_elapsed = 0 iv_msgtype = 'E' ).
        save_log( ).
        RAISE EXCEPTION TYPE zcx_qubiton
          EXPORTING error_text = |Failed to create HTTP client for destination "{ mv_destination }" (sy-subrc={ sy-subrc })|.
      ENDIF.

      IF mv_keep_alive = abap_true.
        mo_client = lo_client.
      ENDIF.
    ENDIF.

    " Set URI path
    cl_http_utility=>set_request_uri(
      request = lo_client->request
      uri     = iv_path ).

    " Set HTTP method
    CASE iv_method.
      WHEN 'GET'.
        lo_client->request->set_method( if_http_request=>co_request_method_get ).
      WHEN OTHERS.
        lo_client->request->set_method( if_http_request=>co_request_method_post ).
    ENDCASE.

    " Headers
    lo_client->request->set_header_field(
      name  = 'Content-Type'
      value = 'application/json' ).

    lo_client->request->set_header_field(
      name  = 'Accept'
      value = 'application/json' ).

    " API key header (explicit key overrides destination-level header)
    IF mv_apikey IS NOT INITIAL.
      lo_client->request->set_header_field(
        name  = 'apikey'
        value = mv_apikey ).
    ENDIF.

    " Request body (POST only)
    IF iv_body IS NOT INITIAL.
      lo_client->request->set_cdata( iv_body ).
    ENDIF.

    " Send (with timeout to prevent freezing dialog work processes)
    lo_client->send(
      EXPORTING
        timeout                    = mv_timeout
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).

    IF sy-subrc <> 0.
      DATA(lv_subrc_send) = sy-subrc.
      lo_client->close( ).
      CLEAR mo_client.
      GET RUN TIME FIELD lv_end.
      lv_elapsed = ( lv_end - lv_start ) / 1000. " microseconds → milliseconds
      log_api_call( iv_method = iv_method iv_path = iv_path iv_status = 0 iv_elapsed = lv_elapsed iv_msgtype = 'E' ).
      save_log( ).
      RAISE EXCEPTION TYPE zcx_qubiton
        EXPORTING error_text = |{ iv_method } { iv_path }: send failed (sy-subrc={ lv_subrc_send })|.
    ENDIF.

    " Receive (with timeout)
    lo_client->receive(
      EXPORTING
        timeout                    = mv_timeout
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).

    IF sy-subrc <> 0.
      DATA(lv_subrc_recv) = sy-subrc.
      lo_client->close( ).
      CLEAR mo_client.
      GET RUN TIME FIELD lv_end.
      lv_elapsed = ( lv_end - lv_start ) / 1000.
      log_api_call( iv_method = iv_method iv_path = iv_path iv_status = 0 iv_elapsed = lv_elapsed iv_msgtype = 'E' ).
      save_log( ).
      RAISE EXCEPTION TYPE zcx_qubiton
        EXPORTING error_text = |{ iv_method } { iv_path }: receive failed (sy-subrc={ lv_subrc_recv })|.
    ENDIF.

    " Check HTTP status
    lo_client->response->get_status(
      IMPORTING
        code   = lv_status
        reason = lv_reason ).

    rv_json = lo_client->response->get_cdata( ).

    " Close connection unless keep-alive is enabled
    IF mv_keep_alive = abap_false.
      lo_client->close( ).
    ENDIF.

    " Capture elapsed time
    GET RUN TIME FIELD lv_end.
    lv_elapsed = ( lv_end - lv_start ) / 1000. " microseconds → milliseconds

    IF lv_status < 200 OR lv_status >= 300.
      log_api_call( iv_method = iv_method iv_path = iv_path iv_status = lv_status iv_elapsed = lv_elapsed iv_msgtype = 'E' ).
      save_log( ).
      RAISE EXCEPTION TYPE zcx_qubiton
        EXPORTING
          http_status = lv_status
          error_text  = |{ iv_method } { iv_path }: HTTP { lv_status } { lv_reason }|.
    ENDIF.

    " Success — log informational
    log_api_call( iv_method = iv_method iv_path = iv_path iv_status = lv_status iv_elapsed = lv_elapsed iv_msgtype = 'I' ).

    " Persist log entries after each call (ensures SLG1 visibility)
    save_log( ).
  ENDMETHOD.


  METHOD post.
    rv_json = send_request( iv_path   = iv_path
                            iv_method = 'POST'
                            iv_body   = iv_body ).
  ENDMETHOD.


  METHOD get.
    rv_json = send_request( iv_path   = iv_path
                            iv_method = 'GET' ).
  ENDMETHOD.


  METHOD build_json.
    " Builds a flat JSON object from name/value pairs, skipping blank values.
    " Supports typed values: S=string (quoted), N=number (unquoted), B=boolean (unquoted).
    DATA lv_sep TYPE string.

    rv_json = `{`.
    lv_sep  = ``.

    LOOP AT it_fields INTO DATA(ls_field).
      IF ls_field-value IS NOT INITIAL.
        rv_json = rv_json && lv_sep && `"` && ls_field-name && `":`.

        CASE ls_field-type.
          WHEN gc_type_number.
            " Numeric value — no quotes; validate to prevent JSON injection
            DATA(lv_num) = ls_field-value.
            CONDENSE lv_num.
            " Strip leading/trailing whitespace and verify it looks numeric
            IF lv_num CO '0123456789.-+eE'.
              rv_json = rv_json && lv_num.
            ELSE.
              " Non-numeric value — emit as quoted string to prevent malformed JSON
              rv_json = rv_json && `"` && escape_json_value( ls_field-value ) && `"`.
            ENDIF.
          WHEN gc_type_boolean.
            " Boolean — emit true/false without quotes
            IF ls_field-value = 'true' OR ls_field-value = 'X' OR ls_field-value = '1'.
              rv_json = rv_json && `true`.
            ELSE.
              rv_json = rv_json && `false`.
            ENDIF.
          WHEN OTHERS.
            " String — escape quotes, backslashes, and control characters
            rv_json = rv_json && `"` && escape_json_value( ls_field-value ) && `"`.
        ENDCASE.

        lv_sep = `,`.
      ENDIF.
    ENDLOOP.

    rv_json = rv_json && `}`.
  ENDMETHOD.


  METHOD build_json_array.
    " Splits iv_csv on commas, trims each entry, JSON-escapes and quotes
    " non-empty entries, and joins them as a JSON array.  Empty entries
    " (consecutive commas, leading/trailing commas) are skipped.
    DATA lv_sep  TYPE string.
    DATA lv_item TYPE string.

    rv_json = `[`.
    SPLIT iv_csv AT ',' INTO TABLE DATA(lt_items).
    LOOP AT lt_items INTO lv_item.
      CONDENSE lv_item.
      IF lv_item IS NOT INITIAL.
        rv_json = rv_json && lv_sep && `"` && escape_json_value( lv_item ) && `"`.
        lv_sep = `,`.
      ENDIF.
    ENDLOOP.
    rv_json = rv_json && `]`.
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Per-endpoint body builders
  " ═══════════════════════════════════════════════════════════════════════

  METHOD build_address_body.
    rv_json = build_json( VALUE #(
      ( name = 'country'      value = iv_country )
      ( name = 'addressLine1' value = iv_address_line1 )
      ( name = 'addressLine2' value = iv_address_line2 )
      ( name = 'city'         value = iv_city )
      ( name = 'state'        value = iv_state )
      ( name = 'postalCode'   value = iv_postal_code )
      ( name = 'companyName'  value = iv_company_name ) ) ).
  ENDMETHOD.

  METHOD build_tax_body.
    rv_json = build_json( VALUE #(
      ( name = 'identityNumber'     value = iv_tax_number )
      ( name = 'identityNumberType' value = iv_tax_type )
      ( name = 'country'            value = iv_country )
      ( name = 'companyName'        value = iv_company_name )
      ( name = 'businessEntityType' value = iv_business_entity_type ) ) ).
  ENDMETHOD.

  METHOD build_tax_format_body.
    rv_json = build_json( VALUE #(
      ( name = 'identityNumber'     value = iv_tax_number )
      ( name = 'identityNumberType' value = iv_tax_type )
      ( name = 'countryIso2'        value = iv_country ) ) ).
  ENDMETHOD.

  METHOD build_bank_account_body.
    rv_json = build_json( VALUE #(
      ( name = 'businessEntityType' value = iv_business_entity_type )
      ( name = 'country'            value = iv_country )
      ( name = 'bankAccountHolder'  value = iv_bank_account_holder )
      ( name = 'accountNumber'      value = iv_account_number )
      ( name = 'businessName'       value = iv_business_name )
      ( name = 'taxIdNumber'        value = iv_tax_id_number )
      ( name = 'taxType'            value = iv_tax_type )
      ( name = 'bankCode'           value = iv_bank_code )
      ( name = 'iban'               value = iv_iban )
      ( name = 'swiftCode'          value = iv_swift_code ) ) ).
  ENDMETHOD.

  METHOD build_bank_pro_body.
    rv_json = build_json( VALUE #(
      ( name = 'businessEntityType' value = iv_business_entity_type )
      ( name = 'country'            value = iv_country )
      ( name = 'bankAccountHolder'  value = iv_bank_account_holder )
      ( name = 'accountNumber'      value = iv_account_number )
      ( name = 'bankCode'           value = iv_bank_code )
      ( name = 'iban'               value = iv_iban )
      ( name = 'swiftCode'          value = iv_swift_code ) ) ).
  ENDMETHOD.

  METHOD build_email_body.
    rv_json = build_json( VALUE #(
      ( name = 'emailAddress' value = iv_email_address ) ) ).
  ENDMETHOD.

  METHOD build_phone_body.
    rv_json = build_json( VALUE #(
      ( name = 'phoneNumber'    value = iv_phone_number )
      ( name = 'country'        value = iv_country )
      ( name = 'phoneExtension' value = iv_phone_extension ) ) ).
  ENDMETHOD.

  METHOD build_peppol_body.
    rv_json = build_json( VALUE #(
      ( name = 'participantId'   value = iv_participant_id )
      ( name = 'directoryLookup' value = iv_directory_lookup type = gc_type_boolean ) ) ).
  ENDMETHOD.

  METHOD build_busreg_body.
    rv_json = build_json( VALUE #(
      ( name = 'entityName' value = iv_company_name )
      ( name = 'country'    value = iv_country )
      ( name = 'state'      value = iv_state )
      ( name = 'city'       value = iv_city ) ) ).
  ENDMETHOD.

  METHOD build_busclass_body.
    rv_json = build_json( VALUE #(
      ( name = 'companyName' value = iv_company_name )
      ( name = 'city'        value = iv_city )
      ( name = 'state'       value = iv_state )
      ( name = 'country'     value = iv_country )
      ( name = 'address1'    value = iv_address1 )
      ( name = 'address2'    value = iv_address2 )
      ( name = 'phone'       value = iv_phone )
      ( name = 'postalCode'  value = iv_postal_code ) ) ).
  ENDMETHOD.

  METHOD build_sanctions_body.
    rv_json = build_json( VALUE #(
      ( name = 'companyName'  value = iv_company_name )
      ( name = 'country'      value = iv_country )
      ( name = 'addressLine1' value = iv_address_line1 )
      ( name = 'addressLine2' value = iv_address_line2 )
      ( name = 'city'         value = iv_city )
      ( name = 'state'        value = iv_state )
      ( name = 'postalCode'   value = iv_postal_code ) ) ).
  ENDMETHOD.

  METHOD build_pep_body.
    rv_json = build_json( VALUE #(
      ( name = 'name'    value = iv_name )
      ( name = 'country' value = iv_country ) ) ).
  ENDMETHOD.

  METHOD build_directors_body.
    rv_json = build_json( VALUE #(
      ( name = 'firstName'  value = iv_first_name )
      ( name = 'lastName'   value = iv_last_name )
      ( name = 'country'    value = iv_country )
      ( name = 'middleName' value = iv_middle_name ) ) ).
  ENDMETHOD.

  METHOD build_epa_body.
    rv_json = build_json( VALUE #(
      ( name = 'name'       value = iv_name )
      ( name = 'state'      value = iv_state )
      ( name = 'fiscalYear' value = iv_fiscal_year ) ) ).
  ENDMETHOD.

  METHOD build_healthcare_body.
    rv_json = build_json( VALUE #(
      ( name = 'healthCareType' value = iv_healthcare_type )
      ( name = 'entityName'     value = iv_entity_name )
      ( name = 'lastName'       value = iv_last_name )
      ( name = 'firstName'      value = iv_first_name )
      ( name = 'address'        value = iv_address )
      ( name = 'city'           value = iv_city )
      ( name = 'state'          value = iv_state )
      ( name = 'zipCode'        value = iv_zip_code ) ) ).
  ENDMETHOD.

  METHOD build_risk_body.
    rv_json = build_json( VALUE #(
      ( name = 'entityName' value = iv_company_name )
      ( name = 'category'   value = iv_category )
      ( name = 'country'    value = iv_country ) ) ).
  ENDMETHOD.

  METHOD build_entity_risk_body.
    rv_json = build_json( VALUE #(
      ( name = 'companyName'            value = iv_company_name )
      ( name = 'countryOfIncorporation' value = iv_country )
      ( name = 'category'               value = iv_category )
      ( name = 'url'                    value = iv_url )
      ( name = 'businessEntityType'     value = iv_business_entity_type ) ) ).
  ENDMETHOD.

  METHOD build_credit_analysis_body.
    rv_json = build_json( VALUE #(
      ( name = 'companyName'  value = iv_company_name )
      ( name = 'addressLine1' value = iv_address_line1 )
      ( name = 'city'         value = iv_city )
      ( name = 'state'        value = iv_state )
      ( name = 'country'      value = iv_country )
      ( name = 'dunsNumber'   value = iv_duns_number )
      ( name = 'postalCode'   value = iv_postal_code )
      ( name = 'addressLine2' value = iv_address_line2 ) ) ).
  ENDMETHOD.

  METHOD build_esg_body.
    rv_json = build_json( VALUE #(
      ( name = 'companyName' value = iv_company_name ) ) ).
  ENDMETHOD.

  METHOD build_domain_security_body.
    rv_json = build_json( VALUE #(
      ( name = 'domain' value = iv_domain_name ) ) ).
  ENDMETHOD.

  METHOD build_ip_quality_body.
    rv_json = build_json( VALUE #(
      ( name = 'ipAddress' value = iv_ip_address )
      ( name = 'userAgent' value = iv_user_agent ) ) ).
  ENDMETHOD.

  METHOD build_ubo_body.
    rv_json = build_json( VALUE #(
      ( name = 'companyName'  value = iv_company_name )
      ( name = 'countryIso2'  value = iv_country_iso2 )
      ( name = 'uboThreshold' value = iv_ubo_threshold type = gc_type_number )
      ( name = 'maxLayers'    value = iv_max_layers    type = gc_type_number ) ) ).
  ENDMETHOD.

  METHOD build_corp_hierarchy_body.
    rv_json = build_json( VALUE #(
      ( name = 'companyName'  value = iv_company_name )
      ( name = 'addressLine1' value = iv_address_line1 )
      ( name = 'city'         value = iv_city )
      ( name = 'state'        value = iv_state )
      ( name = 'zipCode'      value = iv_zip_code ) ) ).
  ENDMETHOD.

  METHOD build_duns_body.
    rv_json = build_json( VALUE #(
      ( name = 'dunsNumber' value = iv_duns_number ) ) ).
  ENDMETHOD.

  METHOD build_hierarchy_body.
    rv_json = build_json( VALUE #(
      ( name = 'identifier'     value = iv_identifier )
      ( name = 'identifierType' value = iv_identifier_type )
      ( name = 'country'        value = iv_country )
      ( name = 'options'        value = iv_options ) ) ).
  ENDMETHOD.

  METHOD build_npi_body.
    rv_json = build_json( VALUE #(
      ( name = 'npi'              value = iv_npi )
      ( name = 'organizationName' value = iv_organization_name )
      ( name = 'lastName'         value = iv_last_name )
      ( name = 'firstName'        value = iv_first_name )
      ( name = 'middleName'       value = iv_middle_name ) ) ).
  ENDMETHOD.

  METHOD build_medpass_body.
    rv_json = build_json( VALUE #(
      ( name = 'id'                 value = iv_id )
      ( name = 'businessEntityType' value = iv_business_entity_type )
      ( name = 'companyName'        value = iv_company_name )
      ( name = 'taxId'              value = iv_tax_id )
      ( name = 'country'            value = iv_country )
      ( name = 'state'              value = iv_state )
      ( name = 'city'               value = iv_city )
      ( name = 'postalCode'         value = iv_postal_code )
      ( name = 'addressLine1'       value = iv_address_line1 )
      ( name = 'addressLine2'       value = iv_address_line2 ) ) ).
  ENDMETHOD.

  METHOD build_dot_carrier_body.
    rv_json = build_json( VALUE #(
      ( name = 'dotNumber'  value = iv_dot_number )
      ( name = 'entityName' value = iv_entity_name ) ) ).
  ENDMETHOD.

  METHOD build_in_identity_body.
    rv_json = build_json( VALUE #(
      ( name = 'identityNumber'     value = iv_identity_number )
      ( name = 'identityNumberType' value = iv_identity_number_type )
      ( name = 'entityName'         value = iv_entity_name )
      ( name = 'dob'                value = iv_dob ) ) ).
  ENDMETHOD.

  METHOD build_certification_body.
    rv_json = build_json( VALUE #(
      ( name = 'companyName'         value = iv_company_name )
      ( name = 'country'             value = iv_country )
      ( name = 'city'                value = iv_city )
      ( name = 'state'               value = iv_state )
      ( name = 'zipCode'             value = iv_zip_code )
      ( name = 'addressLine1'        value = iv_address_line1 )
      ( name = 'addressLine2'        value = iv_address_line2 )
      ( name = 'identityType'        value = iv_identity_type )
      ( name = 'certificationType'   value = iv_certification_type )
      ( name = 'certificationGroup'  value = iv_certification_group )
      ( name = 'certificationNumber' value = iv_certification_number ) ) ).
  ENDMETHOD.

  METHOD build_payment_terms_body.
    rv_json = build_json( VALUE #(
      ( name = 'currentPayTerm' value = iv_current_pay_term type = gc_type_number )
      ( name = 'annualSpend'    value = iv_annual_spend     type = gc_type_number )
      ( name = 'avgDaysPay'     value = iv_avg_days_pay     type = gc_type_number )
      ( name = 'savingsRate'    value = iv_savings_rate     type = gc_type_number )
      ( name = 'threshold'      value = iv_threshold        type = gc_type_number )
      ( name = 'vendorName'     value = iv_vendor_name )
      ( name = 'country'        value = iv_country ) ) ).
  ENDMETHOD.

  METHOD build_ariba_body.
    rv_json = build_json( VALUE #(
      ( name = 'anid' value = iv_anid ) ) ).
  ENDMETHOD.

  METHOD build_gender_body.
    rv_json = build_json( VALUE #(
      ( name = 'name'    value = iv_name )
      ( name = 'country' value = iv_country ) ) ).
  ENDMETHOD.


  " ── Address Validation ──────────────────────────────────────────────────

  METHOD validate_address.
    rv_json = post( iv_path = '/api/address/validate'
                    iv_body = build_address_body(
                      iv_country       = iv_country
                      iv_address_line1 = iv_address_line1
                      iv_address_line2 = iv_address_line2
                      iv_city          = iv_city
                      iv_state         = iv_state
                      iv_postal_code   = iv_postal_code
                      iv_company_name  = iv_company_name ) ).
  ENDMETHOD.


  " ── Tax Validation ────────────────────────────────────────────────────

  METHOD validate_tax.
    rv_json = post( iv_path = '/api/tax/validate'
                    iv_body = build_tax_body(
                      iv_tax_number          = iv_tax_number
                      iv_tax_type            = iv_tax_type
                      iv_country             = iv_country
                      iv_company_name        = iv_company_name
                      iv_business_entity_type = iv_business_entity_type ) ).
  ENDMETHOD.


  METHOD validate_tax_format.
    rv_json = post( iv_path = '/api/tax/format-validate'
                    iv_body = build_tax_format_body(
                      iv_tax_number = iv_tax_number
                      iv_tax_type   = iv_tax_type
                      iv_country    = iv_country ) ).
  ENDMETHOD.


  " ── Bank Account Validation ─────────────────────────────────────────────

  METHOD validate_bank_account.
    rv_json = post( iv_path = '/api/bank/validate'
                    iv_body = build_bank_account_body(
                      iv_business_entity_type = iv_business_entity_type
                      iv_country              = iv_country
                      iv_bank_account_holder  = iv_bank_account_holder
                      iv_account_number       = iv_account_number
                      iv_business_name        = iv_business_name
                      iv_tax_id_number        = iv_tax_id_number
                      iv_tax_type             = iv_tax_type
                      iv_bank_code            = iv_bank_code
                      iv_iban                 = iv_iban
                      iv_swift_code           = iv_swift_code ) ).
  ENDMETHOD.


  METHOD validate_bank_pro.
    rv_json = post( iv_path = '/api/bankaccount/pro/validate'
                    iv_body = build_bank_pro_body(
                      iv_business_entity_type = iv_business_entity_type
                      iv_country              = iv_country
                      iv_bank_account_holder  = iv_bank_account_holder
                      iv_account_number       = iv_account_number
                      iv_bank_code            = iv_bank_code
                      iv_iban                 = iv_iban
                      iv_swift_code           = iv_swift_code ) ).
  ENDMETHOD.


  " ── Email & Phone Validation ────────────────────────────────────────────

  METHOD validate_email.
    rv_json = post( iv_path = '/api/email/validate'
                    iv_body = build_email_body( iv_email_address = iv_email_address ) ).
  ENDMETHOD.


  METHOD validate_phone.
    rv_json = post( iv_path = '/api/phone/validate'
                    iv_body = build_phone_body(
                      iv_phone_number    = iv_phone_number
                      iv_country         = iv_country
                      iv_phone_extension = iv_phone_extension ) ).
  ENDMETHOD.


  " ── Business Registration ───────────────────────────────────────────────

  METHOD lookup_business_registration.
    rv_json = post( iv_path = '/api/businessregistration/lookup'
                    iv_body = build_busreg_body(
                      iv_company_name = iv_company_name
                      iv_country      = iv_country
                      iv_state        = iv_state
                      iv_city         = iv_city ) ).
  ENDMETHOD.


  " ── Peppol ──────────────────────────────────────────────────────────────

  METHOD validate_peppol.
    rv_json = post( iv_path = '/api/peppol/validate'
                    iv_body = build_peppol_body(
                      iv_participant_id   = iv_participant_id
                      iv_directory_lookup = iv_directory_lookup ) ).
  ENDMETHOD.


  " ── Sanctions & Compliance ──────────────────────────────────────────────

  METHOD check_sanctions.
    rv_json = post( iv_path = '/api/prohibited/lookup'
                    iv_body = build_sanctions_body(
                      iv_company_name  = iv_company_name
                      iv_country       = iv_country
                      iv_address_line1 = iv_address_line1
                      iv_address_line2 = iv_address_line2
                      iv_city          = iv_city
                      iv_state         = iv_state
                      iv_postal_code   = iv_postal_code ) ).
  ENDMETHOD.


  METHOD screen_pep.
    rv_json = post( iv_path = '/api/pep/lookup'
                    iv_body = build_pep_body(
                      iv_name    = iv_name
                      iv_country = iv_country ) ).
  ENDMETHOD.


  METHOD check_directors.
    rv_json = post( iv_path = '/api/disqualifieddirectors/validate'
                    iv_body = build_directors_body(
                      iv_first_name  = iv_first_name
                      iv_last_name   = iv_last_name
                      iv_country     = iv_country
                      iv_middle_name = iv_middle_name ) ).
  ENDMETHOD.


  " ── EPA Prosecution ─────────────────────────────────────────────────────

  METHOD check_epa_prosecution.
    rv_json = post( iv_path = '/api/criminalprosecution/validate'
                    iv_body = build_epa_body(
                      iv_name        = iv_name
                      iv_state       = iv_state
                      iv_fiscal_year = iv_fiscal_year ) ).
  ENDMETHOD.


  METHOD lookup_epa_prosecution.
    rv_json = post( iv_path = '/api/criminalprosecution/lookup'
                    iv_body = build_epa_body(
                      iv_name        = iv_name
                      iv_state       = iv_state
                      iv_fiscal_year = iv_fiscal_year ) ).
  ENDMETHOD.


  " ── Healthcare Exclusion ────────────────────────────────────────────────

  METHOD check_healthcare_exclusion.
    rv_json = post( iv_path = '/api/providerexclusion/validate'
                    iv_body = build_healthcare_body(
                      iv_healthcare_type = iv_healthcare_type
                      iv_entity_name     = iv_entity_name
                      iv_last_name       = iv_last_name
                      iv_first_name      = iv_first_name
                      iv_address         = iv_address
                      iv_city            = iv_city
                      iv_state           = iv_state
                      iv_zip_code        = iv_zip_code ) ).
  ENDMETHOD.


  METHOD lookup_healthcare_exclusion.
    rv_json = post( iv_path = '/api/providerexclusion/lookup'
                    iv_body = build_healthcare_body(
                      iv_healthcare_type = iv_healthcare_type
                      iv_entity_name     = iv_entity_name
                      iv_last_name       = iv_last_name
                      iv_first_name      = iv_first_name
                      iv_address         = iv_address
                      iv_city            = iv_city
                      iv_state           = iv_state
                      iv_zip_code        = iv_zip_code ) ).
  ENDMETHOD.


  " ── Risk & Financial ────────────────────────────────────────────────────

  METHOD check_bankruptcy_risk.
    rv_json = post( iv_path = '/api/risk/lookup'
                    iv_body = build_risk_body(
                      iv_company_name = iv_company_name
                      iv_category     = 'Bankruptcy'
                      iv_country      = iv_country ) ).
  ENDMETHOD.


  METHOD lookup_credit_score.
    rv_json = post( iv_path = '/api/risk/lookup'
                    iv_body = build_risk_body(
                      iv_company_name = iv_company_name
                      iv_category     = 'Credit Score'
                      iv_country      = iv_country ) ).
  ENDMETHOD.


  METHOD lookup_fail_rate.
    rv_json = post( iv_path = '/api/risk/lookup'
                    iv_body = build_risk_body(
                      iv_company_name = iv_company_name
                      iv_category     = 'Fail Rate'
                      iv_country      = iv_country ) ).
  ENDMETHOD.


  METHOD assess_entity_risk.
    rv_json = post( iv_path = '/api/entity/fraud/lookup'
                    iv_body = build_entity_risk_body(
                      iv_company_name         = iv_company_name
                      iv_country              = iv_country
                      iv_category             = iv_category
                      iv_url                  = iv_url
                      iv_business_entity_type = iv_business_entity_type ) ).
  ENDMETHOD.


  METHOD lookup_credit_analysis.
    rv_json = post( iv_path = '/api/creditanalysis/lookup'
                    iv_body = build_credit_analysis_body(
                      iv_company_name  = iv_company_name
                      iv_address_line1 = iv_address_line1
                      iv_city          = iv_city
                      iv_state         = iv_state
                      iv_country       = iv_country
                      iv_duns_number   = iv_duns_number
                      iv_postal_code   = iv_postal_code
                      iv_address_line2 = iv_address_line2 ) ).
  ENDMETHOD.


  " ── ESG & Cybersecurity ─────────────────────────────────────────────────

  METHOD lookup_esg_score.
    " country and domain are bound as [FromQuery] on the API controller, not body.
    " Only companyName goes in the JSON body (esgId not exposed by this connector method).
    DATA lv_path TYPE string.
    DATA lv_qs   TYPE string.

    IF iv_country IS NOT INITIAL.
      lv_qs = `?country=` && cl_http_utility=>escape_url( iv_country ).
    ENDIF.
    IF iv_domain IS NOT INITIAL.
      IF lv_qs IS INITIAL.
        lv_qs = `?domain=` && cl_http_utility=>escape_url( iv_domain ).
      ELSE.
        lv_qs = lv_qs && `&domain=` && cl_http_utility=>escape_url( iv_domain ).
      ENDIF.
    ENDIF.

    lv_path = `/api/esg/Scores` && lv_qs.

    rv_json = post( iv_path = lv_path
                    iv_body = build_esg_body( iv_company_name = iv_company_name ) ).
  ENDMETHOD.


  METHOD domain_security_report.
    rv_json = post( iv_path = '/api/itsecurity/domainreport'
                    iv_body = build_domain_security_body( iv_domain_name = iv_domain_name ) ).
  ENDMETHOD.


  METHOD check_ip_quality.
    rv_json = post( iv_path = '/api/ipquality/validate'
                    iv_body = build_ip_quality_body(
                      iv_ip_address = iv_ip_address
                      iv_user_agent = iv_user_agent ) ).
  ENDMETHOD.


  " ── Corporate Structure ─────────────────────────────────────────────────

  METHOD lookup_beneficial_ownership.
    rv_json = post( iv_path = '/api/beneficialownership/lookup'
                    iv_body = build_ubo_body(
                      iv_company_name  = iv_company_name
                      iv_country_iso2  = iv_country_iso2
                      iv_ubo_threshold = iv_ubo_threshold
                      iv_max_layers    = iv_max_layers ) ).
  ENDMETHOD.


  METHOD lookup_corporate_hierarchy.
    rv_json = post( iv_path = '/api/corporatehierarchy/lookup'
                    iv_body = build_corp_hierarchy_body(
                      iv_company_name  = iv_company_name
                      iv_address_line1 = iv_address_line1
                      iv_city          = iv_city
                      iv_state         = iv_state
                      iv_zip_code      = iv_zip_code ) ).
  ENDMETHOD.


  METHOD lookup_duns.
    rv_json = post( iv_path = '/api/duns-number-lookup'
                    iv_body = build_duns_body( iv_duns_number = iv_duns_number ) ).
  ENDMETHOD.


  METHOD lookup_hierarchy.
    rv_json = post( iv_path = '/api/company/hierarchy/lookup'
                    iv_body = build_hierarchy_body(
                      iv_identifier      = iv_identifier
                      iv_identifier_type = iv_identifier_type
                      iv_country         = iv_country
                      iv_options         = iv_options ) ).
  ENDMETHOD.


  " ── Industry Specific ───────────────────────────────────────────────────

  METHOD validate_npi.
    rv_json = post( iv_path = '/api/nationalprovideridentifier/validate'
                    iv_body = build_npi_body(
                      iv_npi               = iv_npi
                      iv_organization_name = iv_organization_name
                      iv_last_name         = iv_last_name
                      iv_first_name        = iv_first_name
                      iv_middle_name       = iv_middle_name ) ).
  ENDMETHOD.


  METHOD validate_medpass.
    rv_json = post( iv_path = '/api/medpass/validate'
                    iv_body = build_medpass_body(
                      iv_id                   = iv_id
                      iv_business_entity_type = iv_business_entity_type
                      iv_company_name         = iv_company_name
                      iv_tax_id               = iv_tax_id
                      iv_country              = iv_country
                      iv_state                = iv_state
                      iv_city                 = iv_city
                      iv_postal_code          = iv_postal_code
                      iv_address_line1        = iv_address_line1
                      iv_address_line2        = iv_address_line2 ) ).
  ENDMETHOD.


  METHOD lookup_dot_carrier.
    rv_json = post( iv_path = '/api/dot/fmcsa/lookup'
                    iv_body = build_dot_carrier_body(
                      iv_dot_number  = iv_dot_number
                      iv_entity_name = iv_entity_name ) ).
  ENDMETHOD.


  METHOD validate_india_identity.
    rv_json = post( iv_path = '/api/inidentity/validate'
                    iv_body = build_in_identity_body(
                      iv_identity_number      = iv_identity_number
                      iv_identity_number_type = iv_identity_number_type
                      iv_entity_name          = iv_entity_name
                      iv_dob                  = iv_dob ) ).
  ENDMETHOD.


  " ── Certification ───────────────────────────────────────────────────────

  METHOD validate_certification.
    rv_json = post( iv_path = '/api/certification/validate'
                    iv_body = build_certification_body(
                      iv_company_name         = iv_company_name
                      iv_country              = iv_country
                      iv_city                 = iv_city
                      iv_state                = iv_state
                      iv_zip_code             = iv_zip_code
                      iv_address_line1        = iv_address_line1
                      iv_address_line2        = iv_address_line2
                      iv_identity_type        = iv_identity_type
                      iv_certification_type   = iv_certification_type
                      iv_certification_group  = iv_certification_group
                      iv_certification_number = iv_certification_number ) ).
  ENDMETHOD.


  METHOD lookup_certification.
    rv_json = post( iv_path = '/api/certification/lookup'
                    iv_body = build_certification_body(
                      iv_company_name         = iv_company_name
                      iv_country              = iv_country
                      iv_city                 = iv_city
                      iv_state                = iv_state
                      iv_zip_code             = iv_zip_code
                      iv_address_line1        = iv_address_line1
                      iv_address_line2        = iv_address_line2
                      iv_identity_type        = iv_identity_type
                      iv_certification_type   = iv_certification_type
                      iv_certification_group  = iv_certification_group
                      iv_certification_number = iv_certification_number ) ).
  ENDMETHOD.


  " ── Business Classification ─────────────────────────────────────────────

  METHOD lookup_business_classification.
    rv_json = post( iv_path = '/api/businessclassification/lookup'
                    iv_body = build_busclass_body(
                      iv_company_name = iv_company_name
                      iv_city         = iv_city
                      iv_state        = iv_state
                      iv_country      = iv_country
                      iv_address1     = iv_address1
                      iv_address2     = iv_address2
                      iv_phone        = iv_phone
                      iv_postal_code  = iv_postal_code ) ).
  ENDMETHOD.


  " ── Financial Operations ────────────────────────────────────────────────

  METHOD analyze_payment_terms.
    rv_json = post( iv_path = '/api/paymentterms/validate'
                    iv_body = build_payment_terms_body(
                      iv_current_pay_term = iv_current_pay_term
                      iv_annual_spend     = iv_annual_spend
                      iv_avg_days_pay     = iv_avg_days_pay
                      iv_savings_rate     = iv_savings_rate
                      iv_threshold        = iv_threshold
                      iv_vendor_name      = iv_vendor_name
                      iv_country          = iv_country ) ).
  ENDMETHOD.


  METHOD lookup_exchange_rates.
    " baseCurrency is a path parameter; body is the dates as a JSON array.
    DATA(lv_path) = `/api/currency/exchange-rates/` && iv_base_currency.
    rv_json = post( iv_path = lv_path
                    iv_body = build_json_array( iv_dates ) ).
  ENDMETHOD.


  " ── Supplier Profile (SAP Ariba) ────────────────────────────────────────

  METHOD lookup_ariba_supplier.
    rv_json = post( iv_path = '/api/aribasupplierprofile/lookup'
                    iv_body = build_ariba_body( iv_anid = iv_anid ) ).
  ENDMETHOD.


  METHOD validate_ariba_supplier.
    rv_json = post( iv_path = '/api/aribasupplierprofile/validate'
                    iv_body = build_ariba_body( iv_anid = iv_anid ) ).
  ENDMETHOD.


  " ── Gender Identification ───────────────────────────────────────────────

  METHOD identify_gender.
    rv_json = post( iv_path = '/api/genderize/identifygender'
                    iv_body = build_gender_body(
                      iv_name    = iv_name
                      iv_country = iv_country ) ).
  ENDMETHOD.


  " ── Reference Endpoints ─────────────────────────────────────────────────

  METHOD get_supported_tax_formats.
    rv_json = get( iv_path = '/api/tax/format-validate/countries' ).
  ENDMETHOD.


  METHOD get_peppol_schemes.
    rv_json = get( iv_path = '/api/peppol/schemes' ).
  ENDMETHOD.


  " ── Result Parsing & Handling ──────────────────────────────────────────

  METHOD parse_result.
    DATA: lv_offset TYPE i,
          lv_end    TYPE i,
          lv_val    TYPE string.

    " Default: call succeeded (we have JSON), validity unknown
    rs_result-success  = abap_true.
    rs_result-raw_json = iv_json.

    " Empty response = API call failed upstream
    IF iv_json IS INITIAL.
      rs_result-success = abap_false.
      rs_result-message = iv_label && `: API returned empty response`.
      RETURN.
    ENDIF.

    " Look for the validity field in the JSON (e.g. "isValid":true or "isValid" : true)
    " Supports: isValid, found, hasMatches, isExcluded, etc.
    " Use regex to handle optional whitespace around the colon
    FIND REGEX `"` && iv_field && `"\s*:\s*` IN iv_json MATCH OFFSET lv_offset MATCH LENGTH DATA(lv_match_len).
    IF sy-subrc <> 0.
      " Field not in response — can't determine validity
      rs_result-is_valid      = abap_false.
      rs_result-field_missing = abap_true.
      rs_result-message       = iv_label && `: response missing "` && iv_field && `" field`.
      RETURN.
    ENDIF.

    " Extract the value after the matched pattern (field name + colon + whitespace)
    lv_val = iv_json+lv_offset.
    lv_val = lv_val+lv_match_len.
    CONDENSE lv_val.

    " Check for true/false
    IF lv_val CP 'true*'.
      rs_result-is_valid = abap_true.
      rs_result-message  = iv_label && `: passed`.
    ELSE.
      rs_result-is_valid = abap_false.
      rs_result-message  = iv_label && `: failed`.
    ENDIF.
  ENDMETHOD.


  METHOD handle_result.
    " First, parse the raw JSON
    rs_result = parse_result(
      iv_json  = iv_json
      iv_field = iv_field
      iv_label = iv_label ).

    " ── Handle API/network errors ──────────────────────────────────────────
    IF rs_result-success = abap_false.
      CASE mv_on_error.
        WHEN gc_on_error_stop.
          " Message 003: &1: API returned empty response
          MESSAGE e003(zcl_qubiton_msg) WITH iv_label.
        WHEN gc_on_error_warn.
          MESSAGE w003(zcl_qubiton_msg) WITH iv_label.
        WHEN gc_on_error_silent.
          " Silent — caller checks rs_result, no SAP message issued
      ENDCASE.
      RETURN.
    ENDIF.

    " ── Handle missing validity field (unexpected response format) ─────────
    IF rs_result-field_missing = abap_true.
      CASE mv_on_error.
        WHEN gc_on_error_stop.
          " Message 004: &1: response missing "&2" field
          MESSAGE e004(zcl_qubiton_msg) WITH iv_label iv_field.
        WHEN gc_on_error_warn.
          MESSAGE w004(zcl_qubiton_msg) WITH iv_label iv_field.
        WHEN gc_on_error_silent.
          " Silent — caller checks rs_result-field_missing
      ENDCASE.
      RETURN.
    ENDIF.

    " ── Handle validation failures ─────────────────────────────────────────
    IF rs_result-is_valid = abap_false.
      CASE mv_on_invalid.
        WHEN gc_on_invalid_stop.
          " Message 002: &1: failed
          MESSAGE e002(zcl_qubiton_msg) WITH iv_label.
        WHEN gc_on_invalid_warn.
          MESSAGE w002(zcl_qubiton_msg) WITH iv_label.
        WHEN gc_on_invalid_silent.
          " Silent — caller checks rs_result, no SAP message issued
      ENDCASE.
    ENDIF.
  ENDMETHOD.


  " ── Authorization Check ──────────────────────────────────────────────────

  METHOD check_authority.
    " Check custom authorization object ZQUBITON_API.
    " This performs a single all-or-nothing check at construction time.
    " The user must have activity 01 (or *) assigned in PFCG.
    " For per-category enforcement, implement checks in subclass or calling code.
    " Falls back to S_RFC if the custom object is not yet registered.
    AUTHORITY-CHECK OBJECT 'ZQUBITON_API'
      ID 'ZQBT_ACTVT' FIELD '01'.

    IF sy-subrc = 12.
      " Object not registered in SU21 — fall back to generic S_RFC check
      AUTHORITY-CHECK OBJECT 'S_RFC'
        ID 'RFC_TYPE' FIELD 'FUGR'
        ID 'RFC_NAME' FIELD 'SYST'
        ID 'ACTVT'    FIELD '16'.
    ENDIF.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_qubiton
        EXPORTING error_text = |Authorization check failed for QubitOn API|.
    ENDIF.
  ENDMETHOD.


  " ── BAL Application Logging ──────────────────────────────────────────────

  METHOD open_log.
    DATA: ls_log TYPE bal_s_log.

    IF mv_log_enabled = abap_false.
      RETURN.
    ENDIF.

    ls_log-object    = gc_bal_object.
    ls_log-subobject = gc_bal_subobject.
    ls_log-aluser    = sy-uname.
    ls_log-alprog    = sy-repid.
    ls_log-extnumber = |QubitOn API { sy-datum } { sy-uzeit }|.

    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log      = ls_log
      IMPORTING
        e_log_handle = mv_log_handle
      EXCEPTIONS
        OTHERS       = 1.

    IF sy-subrc <> 0.
      " Logging failure is non-fatal — clear handle, calls will skip logging
      CLEAR mv_log_handle.
    ENDIF.
  ENDMETHOD.


  METHOD log_api_call.
    DATA: ls_msg TYPE bal_s_msg.

    IF mv_log_enabled = abap_false OR mv_log_handle IS INITIAL.
      RETURN.
    ENDIF.

    ls_msg-msgty = iv_msgtype.
    ls_msg-msgid = gc_msgid.
    ls_msg-msgno = '010'.            " &1 &2 completed in &3 ms (HTTP &4)
    ls_msg-msgv1 = iv_method.
    ls_msg-msgv2 = iv_path.
    ls_msg-msgv3 = |{ iv_elapsed }|.
    ls_msg-msgv4 = |{ iv_status }|.

    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle = mv_log_handle
        i_s_msg      = ls_msg
      EXCEPTIONS
        OTHERS       = 1.

    " Non-fatal if logging fails — ignore errors
  ENDMETHOD.


  METHOD save_log.
    DATA: lt_handles TYPE bal_t_logh.

    IF mv_log_enabled = abap_false OR mv_log_handle IS INITIAL.
      RETURN.
    ENDIF.

    APPEND mv_log_handle TO lt_handles.

    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle = lt_handles
      EXCEPTIONS
        OTHERS         = 1.

    " Non-fatal if save fails
  ENDMETHOD.


  METHOD flush_log.
    save_log( ).
  ENDMETHOD.


  METHOD close.
    IF mo_client IS BOUND.
      mo_client->close( ).
      CLEAR mo_client.
    ENDIF.
  ENDMETHOD.


  METHOD escape_json_value.
    " Escape a string for safe embedding in a JSON value.
    " Handles: backslash, double quote, and all control characters per RFC 8259.
    DATA lv_cr    TYPE c LENGTH 1.
    DATA lv_char  TYPE c LENGTH 1.
    DATA lv_code  TYPE i.
    DATA lv_len   TYPE i.
    DATA lv_idx   TYPE i.
    DATA lv_out   TYPE string.

    rv_escaped = iv_value.
    " Backslash first (before introducing new backslashes)
    rv_escaped = replace( val = rv_escaped sub = `\` with = `\\` occ = 0 ).
    " Double quote
    rv_escaped = replace( val = rv_escaped sub = `"` with = `\"` occ = 0 ).
    " Control characters — CR+LF must be replaced before standalone LF and CR
    rv_escaped = replace( val = rv_escaped sub = cl_abap_char_utilities=>cr_lf   with = `\r\n` occ = 0 ).
    rv_escaped = replace( val = rv_escaped sub = cl_abap_char_utilities=>newline with = `\n`   occ = 0 ).
    lv_cr = cl_abap_char_utilities=>cr_lf(1). " Extract standalone CR character
    rv_escaped = replace( val = rv_escaped sub = lv_cr with = `\r` occ = 0 ).
    rv_escaped = replace( val = rv_escaped sub = cl_abap_char_utilities=>horizontal_tab with = `\t` occ = 0 ).

    " Escape remaining control characters U+0000-U+001F as \uXXXX (RFC 8259)
    lv_len = strlen( rv_escaped ).
    lv_idx = 0.
    CLEAR lv_out.
    WHILE lv_idx < lv_len.
      lv_char = rv_escaped+lv_idx(1).
      lv_code = cl_abap_conv_out_ce=>uccpi( lv_char ).
      IF lv_code >= 0 AND lv_code <= 31.
        " Already handled: \n (10), \r (13), \t (9) — but those are already replaced above
        " This catches null (0), backspace (8), form feed (12), and other rare control chars
        " Convert code point to hex via arithmetic (safe across all ABAP releases)
        CONSTANTS lc_hex TYPE string VALUE `0123456789abcdef`.
        DATA(lv_hi) = lv_code DIV 16.
        DATA(lv_lo) = lv_code MOD 16.
        lv_out = lv_out && `\u00` && lc_hex+lv_hi(1) && lc_hex+lv_lo(1).
      ELSE.
        lv_out = lv_out && lv_char.
      ENDIF.
      lv_idx = lv_idx + 1.
    ENDWHILE.
    rv_escaped = lv_out.
  ENDMETHOD.

ENDCLASS.
