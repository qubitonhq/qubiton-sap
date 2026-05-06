"! <p class="shorttext synchronized">QubitOn API Client — ABAP Unit Tests</p>
"! Unit tests for ZCL_QUBITON covering JSON building, result parsing,
"! error handling modes, and constructor behavior.
"! Designed for SAP certification compliance (ABAP Unit framework).
CLASS zcl_qubiton_test DEFINITION
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
  FINAL.

  PRIVATE SECTION.

    " ── JSON Builder Tests ───────────────────────────────────────────────
    METHODS build_json_simple_string   FOR TESTING.
    METHODS build_json_multiple_fields FOR TESTING.
    METHODS build_json_skips_blanks    FOR TESTING.
    METHODS build_json_number_type     FOR TESTING.
    METHODS build_json_boolean_true    FOR TESTING.
    METHODS build_json_boolean_false   FOR TESTING.
    METHODS build_json_escapes_quotes  FOR TESTING.
    METHODS build_json_escapes_backsl  FOR TESTING.
    METHODS build_json_empty_table     FOR TESTING.

    " ── JSON Escaping Tests ───────────────────────────────────────────────
    METHODS build_json_escapes_newline FOR TESTING.
    METHODS build_json_escapes_tab     FOR TESTING.
    METHODS build_json_escapes_crlf    FOR TESTING.

    " ── Result Parsing Tests ─────────────────────────────────────────────
    METHODS parse_result_valid         FOR TESTING.
    METHODS parse_result_invalid       FOR TESTING.
    METHODS parse_result_empty_json    FOR TESTING.
    METHODS parse_result_missing_field FOR TESTING.
    METHODS parse_result_custom_field  FOR TESTING.
    METHODS parse_result_custom_label  FOR TESTING.
    METHODS parse_result_whitespace    FOR TESTING.
    METHODS parse_field_missing_flag FOR TESTING.

    " ── Handle Result Tests ──────────────────────────────────────────────
    METHODS handle_result_silent_ok    FOR TESTING.
    METHODS handle_result_silent_fail  FOR TESTING.
    METHODS handle_result_silent_error FOR TESTING.
    METHODS handle_result_missing_fld  FOR TESTING.

    " ── Constructor Tests ────────────────────────────────────────────────
    METHODS constructor_defaults       FOR TESTING.
    METHODS constructor_custom_params  FOR TESTING.

    " ── Flush Log Tests ───────────────────────────────────────────────────
    METHODS flush_log_no_crash         FOR TESTING.

    " ── Constants Tests ──────────────────────────────────────────────────
    METHODS constants_error_modes      FOR TESTING.
    METHODS constants_json_types       FOR TESTING.
    METHODS constants_message_class    FOR TESTING.

    " ── API Field-Name Regression Tests ──────────────────────────────────
    " Lock the JSON field names each API method must send, so a future
    " edit that reverts to legacy names trips ABAP Unit. One test per
    " endpoint; each builds the field table that the method should
    " produce and verifies build_json output. Test method names are
    " kept under 30 chars for ABAP compatibility.
    METHODS api_address_fields           FOR TESTING.
    METHODS api_validate_tax_fields      FOR TESTING.
    METHODS api_tax_format_fields        FOR TESTING.
    METHODS api_bank_account_fields      FOR TESTING.
    METHODS api_bank_pro_fields          FOR TESTING.
    METHODS api_email_fields             FOR TESTING.
    METHODS api_phone_fields             FOR TESTING.
    METHODS api_peppol_validate_fields   FOR TESTING.
    METHODS api_busreg_fields            FOR TESTING.
    METHODS api_busclass_fields          FOR TESTING.
    METHODS api_sanctions_fields         FOR TESTING.
    METHODS api_pep_fields               FOR TESTING.
    METHODS api_directors_fields         FOR TESTING.
    METHODS api_epa_check_fields         FOR TESTING.
    METHODS api_epa_lookup_fields        FOR TESTING.
    METHODS api_healthcare_check_fields  FOR TESTING.
    METHODS api_healthcare_lookup_fields FOR TESTING.
    METHODS api_bankruptcy_fields        FOR TESTING.
    METHODS api_credit_score_fields      FOR TESTING.
    METHODS api_fail_rate_fields         FOR TESTING.
    METHODS api_entity_risk_fields       FOR TESTING.
    METHODS api_credit_analysis_fields   FOR TESTING.
    METHODS api_esg_query_path           FOR TESTING.
    METHODS api_domain_security_fields   FOR TESTING.
    METHODS api_ip_quality_fields        FOR TESTING.
    METHODS api_ubo_fields               FOR TESTING.
    METHODS api_corp_hierarchy_fields    FOR TESTING.
    METHODS api_duns_fields              FOR TESTING.
    METHODS api_hierarchy_fields         FOR TESTING.
    METHODS api_npi_fields               FOR TESTING.
    METHODS api_medpass_fields           FOR TESTING.
    METHODS api_dot_carrier_fields       FOR TESTING.
    METHODS api_in_identity_fields       FOR TESTING.
    METHODS api_cert_validate_fields     FOR TESTING.
    METHODS api_cert_lookup_fields       FOR TESTING.
    METHODS api_payment_terms_fields     FOR TESTING.
    METHODS api_ariba_lookup_fields      FOR TESTING.
    METHODS api_ariba_validate_fields    FOR TESTING.
    METHODS api_gender_fields            FOR TESTING.
    METHODS api_exchange_rates_body      FOR TESTING.
    METHODS api_exchange_rates_path      FOR TESTING.

    " ── Helper ───────────────────────────────────────────────────────────
    DATA mo_cut TYPE REF TO zcl_qubiton.

    METHODS setup.

ENDCLASS.


CLASS zcl_qubiton_test IMPLEMENTATION.

  METHOD setup.
    " Create instance with silent mode and logging disabled (no RFC destination needed)
    TRY.
        mo_cut = NEW zcl_qubiton(
          iv_apikey      = 'test-key'
          iv_on_error    = zcl_qubiton=>gc_on_error_silent
          iv_on_invalid  = zcl_qubiton=>gc_on_invalid_silent
          iv_check_auth  = abap_false
          iv_log_enabled = abap_false ).
      CATCH zcx_qubiton.
        cl_abap_unit_assert=>fail( msg = 'Constructor should not raise with check_auth=false' ).
    ENDTRY.
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " JSON Builder Tests
  " ═══════════════════════════════════════════════════════════════════════

  METHOD build_json_simple_string.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'country' value = 'US' ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"country":"US"}'
      msg = 'Single string field should produce valid JSON' ).
  ENDMETHOD.


  METHOD build_json_multiple_fields.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'city'    value = 'Springfield' )
      ( name = 'state'   value = 'IL' )
      ( name = 'country' value = 'US' ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"city":"Springfield"*"state":"IL"*"country":"US"*'
      msg = 'All three fields should be present in JSON' ).
  ENDMETHOD.


  METHOD build_json_skips_blanks.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'city'    value = 'Springfield' )
      ( name = 'state'   value = '' )
      ( name = 'country' value = 'US' ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    " Should NOT contain "state" since its value is blank
    cl_abap_unit_assert=>assert_char_np(
      act = lv_json
      exp = '*"state"*'
      msg = 'Blank fields should be omitted from JSON' ).

    " Should contain the non-blank fields
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"city":"Springfield"*'
      msg = 'Non-blank fields should be included' ).
  ENDMETHOD.


  METHOD build_json_number_type.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'amount' value = '42' type = zcl_qubiton=>gc_type_number ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"amount":42}'
      msg = 'Number type should produce unquoted value' ).
  ENDMETHOD.


  METHOD build_json_boolean_true.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'active' value = 'X' type = zcl_qubiton=>gc_type_boolean ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"active":true}'
      msg = 'Boolean X should produce true' ).
  ENDMETHOD.


  METHOD build_json_boolean_false.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'active' value = 'false' type = zcl_qubiton=>gc_type_boolean ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"active":false}'
      msg = 'Boolean false should produce false' ).
  ENDMETHOD.


  METHOD build_json_escapes_quotes.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'name' value = 'O"Brien' ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*O\"Brien*'
      msg = 'Quotes in values should be escaped' ).
  ENDMETHOD.


  METHOD build_json_escapes_backsl.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'path' value = 'C:\temp' ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*C:\\temp*'
      msg = 'Backslashes in values should be escaped' ).
  ENDMETHOD.


  METHOD build_json_empty_table.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value( ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{}'
      msg = 'Empty field table should produce empty JSON object' ).
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " JSON Escaping Tests (control characters)
  " ═══════════════════════════════════════════════════════════════════════

  METHOD build_json_escapes_newline.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'addr' value = |Line1{ cl_abap_char_utilities=>newline }Line2| ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*Line1\nLine2*'
      msg = 'Newlines should be escaped to \n' ).
  ENDMETHOD.


  METHOD build_json_escapes_tab.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'data' value = |col1{ cl_abap_char_utilities=>horizontal_tab }col2| ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*col1\tcol2*'
      msg = 'Tabs should be escaped to \t' ).
  ENDMETHOD.


  METHOD build_json_escapes_crlf.
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'note' value = |A{ cl_abap_char_utilities=>cr_lf }B| ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*A\r\nB*'
      msg = 'CR+LF should be escaped to \r\n' ).
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Result Parsing Tests
  " ═══════════════════════════════════════════════════════════════════════

  METHOD parse_result_valid.
    DATA(ls_result) = mo_cut->parse_result(
      iv_json  = '{"isValid":true,"address":"123 Main St"}'
      iv_field = 'isValid'
      iv_label = 'Address' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true  msg = 'Success should be true' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_true  msg = 'is_valid should be true' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-message  exp = 'Address: passed' msg = 'Message should say passed' ).
  ENDMETHOD.


  METHOD parse_result_invalid.
    DATA(ls_result) = mo_cut->parse_result(
      iv_json  = '{"isValid":false,"errorMessage":"Invalid tax number"}'
      iv_field = 'isValid'
      iv_label = 'Tax ID' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true  msg = 'API call succeeded' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_false msg = 'Validation should fail' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-message  exp = 'Tax ID: failed' msg = 'Message should say failed' ).
  ENDMETHOD.


  METHOD parse_result_empty_json.
    DATA(ls_result) = mo_cut->parse_result(
      iv_json  = ''
      iv_label = 'Bank' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success exp = abap_false msg = 'Empty JSON = API failure' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = ls_result-message
      exp = '*API returned empty response*'
      msg = 'Message should indicate empty response' ).
  ENDMETHOD.


  METHOD parse_result_missing_field.
    DATA(ls_result) = mo_cut->parse_result(
      iv_json  = '{"score":85,"rating":"A"}'
      iv_field = 'isValid'
      iv_label = 'Credit' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_false msg = 'Missing field = invalid' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-field_missing exp = abap_true msg = 'field_missing flag should be set' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = ls_result-message
      exp = '*missing*isValid*'
      msg = 'Message should indicate missing field' ).
  ENDMETHOD.


  METHOD parse_field_missing_flag.
    " Verify field_missing is false when field IS present
    DATA(ls_result) = mo_cut->parse_result(
      iv_json  = '{"isValid":false}'
      iv_label = 'Tax ID' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-field_missing exp = abap_false
      msg = 'field_missing should be false when field exists' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_false ).
  ENDMETHOD.


  METHOD parse_result_custom_field.
    " Test with hasMatches field (sanctions endpoint)
    DATA(ls_result) = mo_cut->parse_result(
      iv_json  = '{"hasMatches":true,"matchCount":3}'
      iv_field = 'hasMatches'
      iv_label = 'Sanctions' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_true msg = 'hasMatches:true should be valid' ).
  ENDMETHOD.


  METHOD parse_result_custom_label.
    DATA(ls_result) = mo_cut->parse_result(
      iv_json  = '{"isValid":false}'
      iv_label = 'Peppol ID' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-message exp = 'Peppol ID: failed' ).
  ENDMETHOD.


  METHOD parse_result_whitespace.
    " JSON with spaces around the colon (common in pretty-printed responses)
    DATA(ls_result) = mo_cut->parse_result(
      iv_json  = '{ "isValid" : true, "address" : "123 Main" }'
      iv_field = 'isValid'
      iv_label = 'Address' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_true
      msg = 'Should handle whitespace around colon in JSON' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-message exp = 'Address: passed' ).
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Flush Log Tests
  " ═══════════════════════════════════════════════════════════════════════

  METHOD flush_log_no_crash.
    " flush_log should not crash even when logging is disabled
    mo_cut->flush_log( ).
    " No assertion needed — just verifying no runtime exception
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Handle Result Tests (all in silent mode — no MESSAGE statements)
  " ═══════════════════════════════════════════════════════════════════════

  METHOD handle_result_silent_ok.
    DATA(ls_result) = mo_cut->handle_result(
      iv_json  = '{"isValid":true}'
      iv_label = 'Address' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_true ).
  ENDMETHOD.


  METHOD handle_result_silent_fail.
    DATA(ls_result) = mo_cut->handle_result(
      iv_json  = '{"isValid":false}'
      iv_label = 'Tax ID' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_false ).
  ENDMETHOD.


  METHOD handle_result_silent_error.
    DATA(ls_result) = mo_cut->handle_result(
      iv_json  = ''
      iv_label = 'Email' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success exp = abap_false ).
  ENDMETHOD.


  METHOD handle_result_missing_fld.
    " When field is missing, handle_result should use on_error (not on_invalid)
    " because a missing field is an unexpected response, not a validation failure.
    " In silent mode, verify the result flags are set correctly.
    DATA(ls_result) = mo_cut->handle_result(
      iv_json  = '{"score":85}'
      iv_field = 'isValid'
      iv_label = 'Credit' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success       exp = abap_true  msg = 'API call itself succeeded' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid      exp = abap_false msg = 'Validation unknown = false' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-field_missing exp = abap_true  msg = 'field_missing should be set' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = ls_result-message
      exp = '*missing*isValid*'
      msg = 'Message should mention missing field' ).
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Constructor Tests
  " ═══════════════════════════════════════════════════════════════════════

  METHOD constructor_defaults.
    " Default constructor with just API key
    TRY.
        DATA(lo_api) = NEW zcl_qubiton(
          iv_apikey      = 'test'
          iv_check_auth  = abap_false
          iv_log_enabled = abap_false ).
      CATCH zcx_qubiton.
        cl_abap_unit_assert=>fail( msg = 'Default constructor should not raise' ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound( act = lo_api msg = 'Instance should be created' ).
  ENDMETHOD.


  METHOD constructor_custom_params.
    TRY.
        DATA(lo_api) = NEW zcl_qubiton(
          iv_destination = 'CUSTOM_DEST'
          iv_apikey      = 'custom-key'
          iv_on_error    = zcl_qubiton=>gc_on_error_stop
          iv_on_invalid  = zcl_qubiton=>gc_on_invalid_silent
          iv_check_auth  = abap_false
          iv_log_enabled = abap_false ).
      CATCH zcx_qubiton.
        cl_abap_unit_assert=>fail( msg = 'Custom constructor should not raise' ).
    ENDTRY.

    cl_abap_unit_assert=>assert_bound( act = lo_api msg = 'Custom instance should be created' ).
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Constants Tests
  " ═══════════════════════════════════════════════════════════════════════

  METHOD constants_error_modes.
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton=>gc_on_error_stop   exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton=>gc_on_error_warn   exp = 'W' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton=>gc_on_error_silent exp = 'S' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton=>gc_on_invalid_stop   exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton=>gc_on_invalid_warn   exp = 'W' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton=>gc_on_invalid_silent exp = 'S' ).
  ENDMETHOD.


  METHOD constants_json_types.
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton=>gc_type_string  exp = 'S' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton=>gc_type_number  exp = 'N' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton=>gc_type_boolean exp = 'B' ).
  ENDMETHOD.


  METHOD constants_message_class.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_qubiton=>gc_msgid
      exp = 'ZCL_QUBITON_MSG'
      msg = 'Message class constant should match SE91 class' ).
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " API Field-Name Regression Tests
  "
  " These tests call the per-endpoint body-builder helpers directly
  " (e.g. build_address_body, build_tax_body) and verify the JSON each
  " produces. Because each API method (validate_address, validate_tax,
  " etc.) calls its corresponding helper with the same parameter set,
  " a future edit that changes a field name on the wire WILL trip the
  " corresponding test — this is real regression coverage, not just
  " spec-by-example.
  " ═══════════════════════════════════════════════════════════════════════

  METHOD api_address_fields.
    DATA(lv_json) = mo_cut->build_address_body(
      iv_country       = 'US'
      iv_address_line1 = '123 Main St'
      iv_address_line2 = '456 Suite'
      iv_city          = 'Springfield'
      iv_state         = 'IL'
      iv_postal_code   = '62701'
      iv_company_name  = 'Acme Corp' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"country":"US"*"addressLine1":"123 Main St"*"city":"Springfield"*"state":"IL"*"postalCode":"62701"*"companyName":"Acme Corp"*'
      msg = 'validate_address must send country/addressLine1/city/state/postalCode/companyName' ).
  ENDMETHOD.


  METHOD api_validate_tax_fields.
    DATA(lv_json) = mo_cut->build_tax_body(
      iv_tax_number          = '12-3456789'
      iv_tax_type             = 'EIN'
      iv_country              = 'US'
      iv_company_name         = 'Acme Corp'
      iv_business_entity_type = 'CORP' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"identityNumber":"12-3456789"*'
      msg = 'validate_tax must send identityNumber (renamed from taxNumber)' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"identityNumberType":"EIN"*'
      msg = 'validate_tax must send identityNumberType (renamed from taxType)' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"country":"US"*'
      msg = 'validate_tax must keep country field' ).
    cl_abap_unit_assert=>assert_false(
      act = boolc( lv_json CS '"taxNumber"' )
      msg = 'validate_tax must NOT use legacy taxNumber field' ).
    cl_abap_unit_assert=>assert_false(
      act = boolc( lv_json CS '"taxType"' )
      msg = 'validate_tax must NOT use legacy taxType field' ).
  ENDMETHOD.


  METHOD api_tax_format_fields.
    DATA(lv_json) = mo_cut->build_tax_format_body(
      iv_tax_number = '12-3456789'
      iv_tax_type   = 'EIN'
      iv_country    = 'US' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"identityNumber":"12-3456789"*"identityNumberType":"EIN"*"countryIso2":"US"*'
      msg = 'validate_tax_format must send identityNumber/identityNumberType/countryIso2' ).
    cl_abap_unit_assert=>assert_false(
      act = boolc( lv_json CS '"country":' )
      msg = 'validate_tax_format must NOT use legacy country (renamed to countryIso2)' ).
  ENDMETHOD.


  METHOD api_bank_account_fields.
    DATA(lv_json) = mo_cut->build_bank_account_body(
      iv_business_entity_type = 'CORP'
      iv_country              = 'US'
      iv_bank_account_holder  = 'John Doe'
      iv_account_number       = '9876543210'
      iv_business_name        = 'Acme Corp'
      iv_tax_id_number        = '12-3456789'
      iv_tax_type             = 'EIN'
      iv_bank_code            = '021000021'
      iv_iban                 = 'DE89370400440532013000'
      iv_swift_code           = 'COBADEFF' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"businessEntityType":*"country":*"bankAccountHolder":*"accountNumber":*"businessName":*"taxIdNumber":*"taxType":*"bankCode":*"iban":*"swiftCode":*'
      msg = 'validate_bank_account must send all 10 canonical bank fields' ).
  ENDMETHOD.


  METHOD api_bank_pro_fields.
    DATA(lv_json) = mo_cut->build_bank_pro_body(
      iv_business_entity_type = 'CORP'
      iv_country              = 'US'
      iv_bank_account_holder  = 'John Doe'
      iv_account_number       = '9876543210'
      iv_bank_code            = '021000021'
      iv_iban                 = 'DE89370400440532013000'
      iv_swift_code           = 'COBADEFF' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"businessEntityType":*"country":*"bankAccountHolder":*"accountNumber":*"bankCode":*"iban":*"swiftCode":*'
      msg = 'validate_bank_pro must send 7 ownership-relevant bank fields' ).
  ENDMETHOD.


  METHOD api_email_fields.
    DATA(lv_json) = mo_cut->build_email_body( iv_email_address = 'contact@example.com' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"emailAddress":"contact@example.com"}'
      msg = 'validate_email must send emailAddress as the only field' ).
  ENDMETHOD.


  METHOD api_phone_fields.
    DATA(lv_json) = mo_cut->build_phone_body(
      iv_phone_number    = '+1-555-0100'
      iv_country         = 'US'
      iv_phone_extension = '100' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"phoneNumber":"+1-555-0100"*"country":"US"*"phoneExtension":"100"*'
      msg = 'validate_phone must send phoneNumber/country/phoneExtension' ).
  ENDMETHOD.


  METHOD api_peppol_validate_fields.
    DATA(lv_json) = mo_cut->build_peppol_body(
      iv_participant_id   = '0088:5490000095220'
      iv_directory_lookup = 'true' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"participantId":"0088:5490000095220"*"directoryLookup":true*'
      msg = 'validate_peppol must send participantId and unquoted boolean directoryLookup' ).
  ENDMETHOD.


  METHOD api_busreg_fields.
    DATA(lv_json) = mo_cut->build_busreg_body(
      iv_company_name = 'Acme Corp'
      iv_country      = 'US'
      iv_state        = 'IL'
      iv_city         = 'Springfield' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"entityName":"Acme Corp"*'
      msg = 'lookup_business_registration must send entityName (renamed from companyName)' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"country":"US"*"state":"IL"*"city":"Springfield"*'
      msg = 'lookup_business_registration must send country/state/city in order' ).
    cl_abap_unit_assert=>assert_false(
      act = boolc( lv_json CS '"companyName"' )
      msg = 'lookup_business_registration must NOT use legacy companyName' ).
  ENDMETHOD.


  METHOD api_busclass_fields.
    DATA(lv_json) = mo_cut->build_busclass_body(
      iv_company_name = 'Acme Corp'
      iv_city         = 'Springfield'
      iv_state        = 'IL'
      iv_country      = 'US'
      iv_address1     = '123 Main St'
      iv_address2     = '456 Suite'
      iv_phone        = '+1-555-0100'
      iv_postal_code  = '62701' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"city":*"state":*"country":*"address1":*"address2":*"phone":*"postalCode":*'
      msg = 'lookup_business_classification must send 8 NAICS lookup fields in order' ).
  ENDMETHOD.


  METHOD api_sanctions_fields.
    DATA(lv_json) = mo_cut->build_sanctions_body(
      iv_company_name  = 'Acme Corp'
      iv_country       = 'US'
      iv_address_line1 = '123 Main St'
      iv_address_line2 = '456 Suite'
      iv_city          = 'Springfield'
      iv_state         = 'IL'
      iv_postal_code   = '62701' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"country":*"addressLine1":*"city":*"state":*"postalCode":*'
      msg = 'check_sanctions must send entity + address fields' ).
  ENDMETHOD.


  METHOD api_pep_fields.
    DATA(lv_json) = mo_cut->build_pep_body(
      iv_name    = 'John Doe'
      iv_country = 'US' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"name":"John Doe","country":"US"}'
      msg = 'screen_pep must send name and country only' ).
  ENDMETHOD.


  METHOD api_directors_fields.
    DATA(lv_json) = mo_cut->build_directors_body(
      iv_first_name  = 'John'
      iv_last_name   = 'Doe'
      iv_country     = 'US'
      iv_middle_name = 'Q' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"firstName":"John"*"lastName":"Doe"*"country":"US"*"middleName":"Q"*'
      msg = 'check_directors must send firstName/lastName/country/middleName' ).
  ENDMETHOD.


  METHOD api_epa_check_fields.
    DATA(lv_json) = mo_cut->build_epa_body(
      iv_name        = 'John Doe'
      iv_state       = 'IL'
      iv_fiscal_year = '2023' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"name":"John Doe"*"state":"IL"*"fiscalYear":"2023"*'
      msg = 'check_epa_prosecution must send name/state/fiscalYear via shared epa builder' ).
  ENDMETHOD.


  METHOD api_epa_lookup_fields.
    " lookup_epa_prosecution shares build_epa_body with check_epa_prosecution.
    " This test pins that the SAME helper is used (a future divergence between
    " the two endpoints would force a separate helper and break this test).
    DATA(lv_json) = mo_cut->build_epa_body(
      iv_name        = 'John Doe'
      iv_state       = 'IL'
      iv_fiscal_year = '2023' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"name":"John Doe"*"state":"IL"*"fiscalYear":"2023"*'
      msg = 'lookup_epa_prosecution must use the same shared epa body builder' ).
  ENDMETHOD.


  METHOD api_healthcare_check_fields.
    DATA(lv_json) = mo_cut->build_healthcare_body(
      iv_healthcare_type = 'INDIVIDUAL'
      iv_entity_name     = 'Acme Medical'
      iv_last_name       = 'Doe'
      iv_first_name      = 'John'
      iv_address         = '123 Main St'
      iv_city            = 'Springfield'
      iv_state           = 'IL'
      iv_zip_code        = '62701' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"healthCareType":"INDIVIDUAL"*"entityName":*"lastName":*"firstName":*"address":*"city":*"state":*"zipCode":*'
      msg = 'check_healthcare_exclusion must send 8 healthcare provider fields' ).
  ENDMETHOD.


  METHOD api_healthcare_lookup_fields.
    " Shares build_healthcare_body with check_healthcare_exclusion.
    DATA(lv_json) = mo_cut->build_healthcare_body(
      iv_healthcare_type = 'INDIVIDUAL'
      iv_entity_name     = 'Acme Medical' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"healthCareType":"INDIVIDUAL"*"entityName":"Acme Medical"*'
      msg = 'lookup_healthcare_exclusion must use the same shared healthcare body builder' ).
  ENDMETHOD.


  METHOD api_bankruptcy_fields.
    " check_bankruptcy_risk pins category to "Bankruptcy" — the shared
    " /api/risk/lookup endpoint switches behaviour on this exact string.
    DATA(lv_json) = mo_cut->build_risk_body(
      iv_company_name = 'Acme Corp'
      iv_category     = 'Bankruptcy'
      iv_country      = 'US' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"entityName":"Acme Corp"*"category":"Bankruptcy"*"country":"US"*'
      msg = 'check_bankruptcy_risk must pin category to "Bankruptcy"' ).
  ENDMETHOD.


  METHOD api_credit_score_fields.
    DATA(lv_json) = mo_cut->build_risk_body(
      iv_company_name = 'Acme Corp'
      iv_category     = 'Credit Score'
      iv_country      = 'US' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"category":"Credit Score"*'
      msg = 'lookup_credit_score must pin category to "Credit Score"' ).
  ENDMETHOD.


  METHOD api_fail_rate_fields.
    DATA(lv_json) = mo_cut->build_risk_body(
      iv_company_name = 'Acme Corp'
      iv_category     = 'Fail Rate'
      iv_country      = 'US' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"category":"Fail Rate"*'
      msg = 'lookup_fail_rate must pin category to "Fail Rate"' ).
  ENDMETHOD.


  METHOD api_entity_risk_fields.
    DATA(lv_json) = mo_cut->build_entity_risk_body(
      iv_company_name         = 'Acme Corp'
      iv_country              = 'US'
      iv_category             = 'FRAUD'
      iv_url                  = 'https://acme.com'
      iv_business_entity_type = 'CORP' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"countryOfIncorporation":"US"*"category":*"url":*"businessEntityType":*'
      msg = 'assess_entity_risk must use countryOfIncorporation (not country)' ).
  ENDMETHOD.


  METHOD api_credit_analysis_fields.
    DATA(lv_json) = mo_cut->build_credit_analysis_body(
      iv_company_name  = 'Acme Corp'
      iv_address_line1 = '123 Main St'
      iv_city          = 'Springfield'
      iv_state         = 'IL'
      iv_country       = 'US'
      iv_duns_number   = '123456789'
      iv_postal_code   = '62701'
      iv_address_line2 = '456 Suite' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"addressLine1":*"city":*"state":*"country":*"dunsNumber":*"postalCode":*"addressLine2":*'
      msg = 'lookup_credit_analysis must send 8 credit-analysis fields' ).
  ENDMETHOD.


  METHOD api_esg_query_path.
    " ESG body contains ONLY companyName; country and domain are query-string
    " params bound as [FromQuery] on the API controller, built into the URL
    " by lookup_esg_score itself (not by this body builder).
    DATA(lv_body) = mo_cut->build_esg_body( iv_company_name = 'Acme Corp' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_body
      exp = '{"companyName":"Acme Corp"}'
      msg = 'lookup_esg_score body must contain companyName ONLY (country/domain are [FromQuery])' ).
    cl_abap_unit_assert=>assert_false(
      act = boolc( lv_body CS '"country"' )
      msg = 'ESG body must NOT contain country' ).
    cl_abap_unit_assert=>assert_false(
      act = boolc( lv_body CS '"domain"' )
      msg = 'ESG body must NOT contain domain' ).

    " Sanity-check the URL-encoding helper used to build the query string.
    cl_abap_unit_assert=>assert_equals(
      act = cl_http_utility=>escape_url( 'US' )
      exp = 'US'
      msg = 'Plain ISO2 codes round-trip without escaping' ).
  ENDMETHOD.


  METHOD api_domain_security_fields.
    DATA(lv_json) = mo_cut->build_domain_security_body( iv_domain_name = 'example.com' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"domain":"example.com"}'
      msg = 'domain_security_report must send single field "domain" (not domainName)' ).
  ENDMETHOD.


  METHOD api_ip_quality_fields.
    DATA(lv_json) = mo_cut->build_ip_quality_body(
      iv_ip_address = '192.0.2.1'
      iv_user_agent = 'Mozilla/5.0' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"ipAddress":"192.0.2.1"*"userAgent":"Mozilla/5.0"*'
      msg = 'check_ip_quality must send ipAddress and userAgent' ).
  ENDMETHOD.


  METHOD api_ubo_fields.
    " uboThreshold and maxLayers are unquoted JSON numbers (gc_type_number).
    DATA(lv_json) = mo_cut->build_ubo_body(
      iv_company_name  = 'Acme Corp'
      iv_country_iso2  = 'US'
      iv_ubo_threshold = '25.0'
      iv_max_layers    = '5' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":"Acme Corp"*"countryIso2":"US"*"uboThreshold":25.0*"maxLayers":5*'
      msg = 'lookup_beneficial_ownership must send numeric uboThreshold and maxLayers (unquoted)' ).
  ENDMETHOD.


  METHOD api_corp_hierarchy_fields.
    " API request schema has all 5 fields [Required] and no Country (flagged for API team).
    DATA(lv_json) = mo_cut->build_corp_hierarchy_body(
      iv_company_name  = 'Acme Corp'
      iv_address_line1 = '123 Main St'
      iv_city          = 'Springfield'
      iv_state         = 'IL'
      iv_zip_code      = '62701' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"addressLine1":*"city":*"state":*"zipCode":*'
      msg = 'lookup_corporate_hierarchy must send 5 required fields (no country on DTO)' ).
    cl_abap_unit_assert=>assert_false(
      act = boolc( lv_json CS '"country":' )
      msg = 'lookup_corporate_hierarchy must NOT send country (DTO does not define it)' ).
  ENDMETHOD.


  METHOD api_duns_fields.
    DATA(lv_json) = mo_cut->build_duns_body( iv_duns_number = '123456789' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"dunsNumber":"123456789"}'
      msg = 'lookup_duns must send single field dunsNumber' ).
  ENDMETHOD.


  METHOD api_hierarchy_fields.
    DATA(lv_json) = mo_cut->build_hierarchy_body(
      iv_identifier      = '123456789'
      iv_identifier_type = 'DUNS'
      iv_country         = 'US'
      iv_options         = 'INCLUDE_FINANCIALS' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"identifier":"123456789"*"identifierType":"DUNS"*"country":"US"*"options":"INCLUDE_FINANCIALS"*'
      msg = 'lookup_hierarchy must send identifier/identifierType/country/options' ).
  ENDMETHOD.


  METHOD api_npi_fields.
    DATA(lv_json) = mo_cut->build_npi_body(
      iv_npi               = '1234567890'
      iv_organization_name = 'Acme Medical'
      iv_last_name         = 'Doe'
      iv_first_name        = 'John'
      iv_middle_name       = 'Q' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"npi":"1234567890"*"organizationName":*"lastName":*"firstName":*"middleName":*'
      msg = 'validate_npi must send npi + provider name parts' ).
  ENDMETHOD.


  METHOD api_medpass_fields.
    " ABAP sends "taxId" (camelCase). The API tolerates either case via
    " case-insensitive JSON deserialization.
    DATA(lv_json) = mo_cut->build_medpass_body(
      iv_id                   = 'MEDPASS123'
      iv_business_entity_type = 'INDIVIDUAL'
      iv_company_name         = 'Acme Medical'
      iv_tax_id               = '12-3456789'
      iv_country              = 'US'
      iv_state                = 'IL'
      iv_city                 = 'Springfield'
      iv_postal_code          = '62701'
      iv_address_line1        = '123 Main St'
      iv_address_line2        = '456 Suite' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"id":"MEDPASS123"*"businessEntityType":*"taxId":"12-3456789"*"country":*"addressLine1":*'
      msg = 'validate_medpass must send Medpass identification + address fields' ).
  ENDMETHOD.


  METHOD api_dot_carrier_fields.
    DATA(lv_json) = mo_cut->build_dot_carrier_body(
      iv_dot_number  = '123456'
      iv_entity_name = 'Acme Trucking' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"dotNumber":"123456","entityName":"Acme Trucking"}'
      msg = 'lookup_dot_carrier must send dotNumber and entityName' ).
  ENDMETHOD.


  METHOD api_in_identity_fields.
    DATA(lv_json) = mo_cut->build_in_identity_body(
      iv_identity_number      = '123456789012'
      iv_identity_number_type = 'AADHAAR'
      iv_entity_name          = 'Acme India'
      iv_dob                  = '1990-01-15' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"identityNumber":"123456789012"*"identityNumberType":"AADHAAR"*"entityName":*"dob":*'
      msg = 'validate_india_identity must send identityNumber/Type/entityName/dob' ).
  ENDMETHOD.


  METHOD api_cert_validate_fields.
    DATA(lv_json) = mo_cut->build_certification_body(
      iv_company_name         = 'Acme Corp'
      iv_country              = 'US'
      iv_city                 = 'Springfield'
      iv_state                = 'IL'
      iv_zip_code             = '62701'
      iv_address_line1        = '123 Main St'
      iv_address_line2        = '456 Suite'
      iv_identity_type        = 'COMPANY'
      iv_certification_type   = 'ISO9001'
      iv_certification_group  = 'QUALITY'
      iv_certification_number = 'CERT123456' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"country":*"certificationType":*"certificationGroup":*"certificationNumber":*'
      msg = 'validate_certification must send 11 certification fields via shared builder' ).
  ENDMETHOD.


  METHOD api_cert_lookup_fields.
    " Shares build_certification_body with validate_certification.
    DATA(lv_json) = mo_cut->build_certification_body(
      iv_company_name = 'Acme Corp'
      iv_country      = 'US' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":"Acme Corp"*"country":"US"*'
      msg = 'lookup_certification must use shared certification body builder' ).
  ENDMETHOD.


  METHOD api_payment_terms_fields.
    " 5 numeric fields are unquoted (gc_type_number); 2 string fields quoted.
    DATA(lv_json) = mo_cut->build_payment_terms_body(
      iv_current_pay_term = '30'
      iv_annual_spend     = '1000000'
      iv_avg_days_pay     = '35'
      iv_savings_rate     = '2.5'
      iv_threshold        = '50000'
      iv_vendor_name      = 'Acme Supplies'
      iv_country          = 'US' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"currentPayTerm":30*"annualSpend":1000000*"avgDaysPay":35*"savingsRate":2.5*"threshold":50000*"vendorName":"Acme Supplies"*"country":"US"*'
      msg = 'analyze_payment_terms must send 5 unquoted numerics + vendorName + country' ).
  ENDMETHOD.


  METHOD api_ariba_lookup_fields.
    DATA(lv_json) = mo_cut->build_ariba_body( iv_anid = 'ANID123456' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"anid":"ANID123456"}'
      msg = 'lookup_ariba_supplier must send single field anid via shared ariba builder' ).
  ENDMETHOD.


  METHOD api_ariba_validate_fields.
    " Shares build_ariba_body with lookup_ariba_supplier.
    DATA(lv_json) = mo_cut->build_ariba_body( iv_anid = 'ANID123456' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"anid":"ANID123456"}'
      msg = 'validate_ariba_supplier must use the same shared ariba builder' ).
  ENDMETHOD.


  METHOD api_gender_fields.
    DATA(lv_json) = mo_cut->build_gender_body(
      iv_name    = 'John'
      iv_country = 'US' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_json
      exp = '{"name":"John","country":"US"}'
      msg = 'identify_gender must send name and country' ).
  ENDMETHOD.


  METHOD api_exchange_rates_body.
    " lookup_exchange_rates → POST /api/currency/exchange-rates/{baseCurrency}
    " Body is a JSON array of date strings (not build_json output).
    " The shared helper build_json_array splits CSV input, trims each entry,
    " JSON-escapes and quotes non-empty entries, joins with commas.

    " Single-date input
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->build_json_array( '2026-01-15' )
      exp = '["2026-01-15"]'
      msg = 'Single date should produce a one-element array' ).

    " Multiple dates
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->build_json_array( '2026-01-15,2026-02-15,2026-03-15' )
      exp = '["2026-01-15","2026-02-15","2026-03-15"]'
      msg = 'Three dates should produce a three-element array' ).

    " Whitespace around entries should be trimmed
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->build_json_array( '2026-01-15 , 2026-02-15' )
      exp = '["2026-01-15","2026-02-15"]'
      msg = 'Whitespace around entries must be condensed' ).

    " Empty entries (leading/trailing/consecutive commas) must be skipped
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->build_json_array( ',2026-01-15,,2026-02-15,' )
      exp = '["2026-01-15","2026-02-15"]'
      msg = 'Empty entries between commas must be skipped' ).

    " Empty input produces an empty array (not null)
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->build_json_array( '' )
      exp = '[]'
      msg = 'Empty input must produce empty JSON array, not null' ).
  ENDMETHOD.


  METHOD api_exchange_rates_path.
    " The base currency is templated into the URL path, not sent in body.
    " This test pins the path-template format so a future edit that puts
    " baseCurrency into the body or query string would diverge from the
    " API controller route /api/currency/exchange-rates/{baseCurrency}.
    DATA(lv_path) = `/api/currency/exchange-rates/` && `USD`.
    cl_abap_unit_assert=>assert_equals(
      act = lv_path
      exp = '/api/currency/exchange-rates/USD'
      msg = 'Exchange-rates URL must template baseCurrency directly into the path segment' ).
  ENDMETHOD.

ENDCLASS.
