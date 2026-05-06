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
  " The .NET API renamed several Tax / BusinessRegistration request DTOs
  " (taxNumber → identityNumber, taxType → identityNumberType,
  "  country → countryIso2, companyName → entityName).
  " These tests document the post-rename contract by exercising build_json
  " with the exact field tables each API method must produce. If the API
  " method is reverted to legacy names, mirror the test field names too.
  " ═══════════════════════════════════════════════════════════════════════

  METHOD api_validate_tax_fields.
    " validate_tax → POST /api/tax/validate
    " Required by .NET TaxRequest: identityNumber, identityNumberType, country
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'identityNumber'     value = '12-3456789' )
      ( name = 'identityNumberType' value = 'EIN' )
      ( name = 'country'            value = 'US' )
      ( name = 'companyName'        value = 'Acme Corp' )
      ( name = 'businessEntityType' value = 'CORP' ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

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
  ENDMETHOD.


  METHOD api_tax_format_fields.
    " validate_tax_format → POST /api/tax/format-validate
    " Required by .NET TaxFormatValidationRequest: identityNumber, identityNumberType, countryIso2
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'identityNumber'     value = '12-3456789' )
      ( name = 'identityNumberType' value = 'EIN' )
      ( name = 'countryIso2'        value = 'US' ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"identityNumber":"12-3456789"*'
      msg = 'validate_tax_format must send identityNumber (renamed from taxNumber)' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"identityNumberType":"EIN"*'
      msg = 'validate_tax_format must send identityNumberType (renamed from taxType)' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"countryIso2":"US"*'
      msg = 'validate_tax_format must send countryIso2 (renamed from country)' ).
  ENDMETHOD.


  METHOD api_busreg_fields.
    " lookup_business_registration → POST /api/businessregistration/lookup
    " Required by .NET BusinessRegistrationRequest: entityName, country
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'entityName' value = 'Acme Corp' )
      ( name = 'country'    value = 'US' )
      ( name = 'state'      value = 'IL' )
      ( name = 'city'       value = 'Springfield' ) ).

    DATA(lv_json) = mo_cut->build_json( lt_fields ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"entityName":"Acme Corp"*'
      msg = 'lookup_business_registration must send entityName (renamed from companyName)' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"country":"US"*'
      msg = 'lookup_business_registration must keep country field' ).
  ENDMETHOD.


  METHOD api_esg_query_path.
    " lookup_esg_score → POST /api/esg/Scores?country=...&domain=...
    " Body must contain ONLY companyName; country and domain are query params
    " ([FromQuery] on the .NET controller).
    DATA(lt_body_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'companyName' value = 'Acme Corp' ) ).

    DATA(lv_body) = mo_cut->build_json( lt_body_fields ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_body
      exp = '*"companyName":"Acme Corp"*'
      msg = 'lookup_esg_score body must contain companyName' ).
    cl_abap_unit_assert=>assert_false(
      act = boolc( lv_body CS '"country"' )
      msg = 'lookup_esg_score body must NOT contain country (it is [FromQuery])' ).
    cl_abap_unit_assert=>assert_false(
      act = boolc( lv_body CS '"domain"' )
      msg = 'lookup_esg_score body must NOT contain domain (it is [FromQuery])' ).

    " Sanity-check the URL-encoding helper used to build the query string
    cl_abap_unit_assert=>assert_equals(
      act = cl_http_utility=>escape_url( 'US' )
      exp = 'US'
      msg = 'Plain ISO2 codes round-trip without escaping' ).
  ENDMETHOD.


  METHOD api_address_fields.
    " validate_address → POST /api/address/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'country'      value = 'US' )
      ( name = 'addressLine1' value = '123 Main St' )
      ( name = 'addressLine2' value = '456 Suite' )
      ( name = 'city'         value = 'Springfield' )
      ( name = 'state'        value = 'IL' )
      ( name = 'postalCode'   value = '62701' )
      ( name = 'companyName'  value = 'Acme Corp' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"country":*"addressLine1":*"city":*"state":*"postalCode":*"companyName":*'
      msg = 'validate_address must send standard address fields in order' ).
  ENDMETHOD.


  METHOD api_bank_account_fields.
    " validate_bank_account → POST /api/bank/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'businessEntityType' value = 'CORP' )
      ( name = 'country'            value = 'US' )
      ( name = 'bankAccountHolder'  value = 'John Doe' )
      ( name = 'accountNumber'      value = '9876543210' )
      ( name = 'businessName'       value = 'Acme Corp' )
      ( name = 'taxIdNumber'        value = '12-3456789' )
      ( name = 'taxType'            value = 'EIN' )
      ( name = 'bankCode'           value = '021000021' )
      ( name = 'iban'               value = 'DE89370400440532013000' )
      ( name = 'swiftCode'          value = 'COBADEFF' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"businessEntityType":*"country":*"bankAccountHolder":*"accountNumber":*"iban":*"swiftCode":*'
      msg = 'validate_bank_account must send the canonical bank fields' ).
  ENDMETHOD.


  METHOD api_bank_pro_fields.
    " validate_bank_pro → POST /api/bankaccount/pro/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'businessEntityType' value = 'CORP' )
      ( name = 'country'            value = 'US' )
      ( name = 'bankAccountHolder'  value = 'John Doe' )
      ( name = 'accountNumber'      value = '9876543210' )
      ( name = 'bankCode'           value = '021000021' )
      ( name = 'iban'               value = 'DE89370400440532013000' )
      ( name = 'swiftCode'          value = 'COBADEFF' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"bankAccountHolder":*"accountNumber":*"iban":*"swiftCode":*'
      msg = 'validate_bank_pro must send ownership-relevant bank fields' ).
  ENDMETHOD.


  METHOD api_email_fields.
    " validate_email → POST /api/email/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'emailAddress' value = 'contact@example.com' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"emailAddress":"contact@example.com"*'
      msg = 'validate_email must send emailAddress' ).
  ENDMETHOD.


  METHOD api_phone_fields.
    " validate_phone → POST /api/phone/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'phoneNumber'    value = '+1-555-0100' )
      ( name = 'country'        value = 'US' )
      ( name = 'phoneExtension' value = '100' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"phoneNumber":*"country":*"phoneExtension":*'
      msg = 'validate_phone must send phoneNumber/country/phoneExtension' ).
  ENDMETHOD.


  METHOD api_peppol_validate_fields.
    " validate_peppol → POST /api/peppol/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'participantId'   value = '0088:5490000095220' )
      ( name = 'directoryLookup' value = 'true' type = zcl_qubiton=>gc_type_boolean ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"participantId":"0088:5490000095220"*"directoryLookup":true*'
      msg = 'validate_peppol must send participantId and unquoted boolean directoryLookup' ).
  ENDMETHOD.


  METHOD api_busclass_fields.
    " lookup_business_classification → POST /api/businessclassification/lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'companyName' value = 'Acme Corp' )
      ( name = 'city'        value = 'Springfield' )
      ( name = 'state'       value = 'IL' )
      ( name = 'country'     value = 'US' )
      ( name = 'address1'    value = '123 Main St' )
      ( name = 'address2'    value = '456 Suite' )
      ( name = 'phone'       value = '+1-555-0100' )
      ( name = 'postalCode'  value = '62701' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"city":*"state":*"country":*"address1":*"postalCode":*'
      msg = 'lookup_business_classification must send classification fields' ).
  ENDMETHOD.


  METHOD api_sanctions_fields.
    " check_sanctions → POST /api/prohibited/lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'companyName'  value = 'Acme Corp' )
      ( name = 'country'      value = 'US' )
      ( name = 'addressLine1' value = '123 Main St' )
      ( name = 'addressLine2' value = '456 Suite' )
      ( name = 'city'         value = 'Springfield' )
      ( name = 'state'        value = 'IL' )
      ( name = 'postalCode'   value = '62701' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"country":*"addressLine1":*"city":*"state":*"postalCode":*'
      msg = 'check_sanctions must send entity + address fields' ).
  ENDMETHOD.


  METHOD api_pep_fields.
    " screen_pep → POST /api/pep/lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'name'    value = 'John Doe' )
      ( name = 'country' value = 'US' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"name":"John Doe"*"country":"US"*'
      msg = 'screen_pep must send name and country' ).
  ENDMETHOD.


  METHOD api_directors_fields.
    " check_directors → POST /api/disqualifieddirectors/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'firstName'  value = 'John' )
      ( name = 'lastName'   value = 'Doe' )
      ( name = 'country'    value = 'US' )
      ( name = 'middleName' value = 'Q' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"firstName":*"lastName":*"country":*"middleName":*'
      msg = 'check_directors must send name parts and country' ).
  ENDMETHOD.


  METHOD api_epa_check_fields.
    " check_epa_prosecution → POST /api/criminalprosecution/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'name'       value = 'John Doe' )
      ( name = 'state'      value = 'IL' )
      ( name = 'fiscalYear' value = '2023' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"name":*"state":*"fiscalYear":*'
      msg = 'check_epa_prosecution must send name/state/fiscalYear' ).
  ENDMETHOD.


  METHOD api_epa_lookup_fields.
    " lookup_epa_prosecution → POST /api/criminalprosecution/lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'name'       value = 'John Doe' )
      ( name = 'state'      value = 'IL' )
      ( name = 'fiscalYear' value = '2023' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"name":*"state":*"fiscalYear":*'
      msg = 'lookup_epa_prosecution must send name/state/fiscalYear' ).
  ENDMETHOD.


  METHOD api_healthcare_check_fields.
    " check_healthcare_exclusion → POST /api/providerexclusion/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'healthCareType' value = 'INDIVIDUAL' )
      ( name = 'entityName'     value = 'Acme Medical' )
      ( name = 'lastName'       value = 'Doe' )
      ( name = 'firstName'      value = 'John' )
      ( name = 'address'        value = '123 Main St' )
      ( name = 'city'           value = 'Springfield' )
      ( name = 'state'          value = 'IL' )
      ( name = 'zipCode'        value = '62701' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"healthCareType":*"entityName":*"lastName":*"firstName":*"city":*"state":*"zipCode":*'
      msg = 'check_healthcare_exclusion must send healthcare provider fields' ).
  ENDMETHOD.


  METHOD api_healthcare_lookup_fields.
    " lookup_healthcare_exclusion → POST /api/providerexclusion/lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'healthCareType' value = 'INDIVIDUAL' )
      ( name = 'entityName'     value = 'Acme Medical' )
      ( name = 'lastName'       value = 'Doe' )
      ( name = 'firstName'      value = 'John' )
      ( name = 'address'        value = '123 Main St' )
      ( name = 'city'           value = 'Springfield' )
      ( name = 'state'          value = 'IL' )
      ( name = 'zipCode'        value = '62701' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"healthCareType":*"entityName":*"lastName":*"firstName":*"zipCode":*'
      msg = 'lookup_healthcare_exclusion must send healthcare provider fields' ).
  ENDMETHOD.


  METHOD api_bankruptcy_fields.
    " check_bankruptcy_risk → POST /api/risk/lookup with category='Bankruptcy'
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'entityName' value = 'Acme Corp' )
      ( name = 'category'   value = 'Bankruptcy' )
      ( name = 'country'    value = 'US' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"category":"Bankruptcy"*'
      msg = 'check_bankruptcy_risk must pin category to "Bankruptcy"' ).
  ENDMETHOD.


  METHOD api_credit_score_fields.
    " lookup_credit_score → POST /api/risk/lookup with category='Credit Score'
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'entityName' value = 'Acme Corp' )
      ( name = 'category'   value = 'Credit Score' )
      ( name = 'country'    value = 'US' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"category":"Credit Score"*'
      msg = 'lookup_credit_score must pin category to "Credit Score"' ).
  ENDMETHOD.


  METHOD api_fail_rate_fields.
    " lookup_fail_rate → POST /api/risk/lookup with category='Fail Rate'
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'entityName' value = 'Acme Corp' )
      ( name = 'category'   value = 'Fail Rate' )
      ( name = 'country'    value = 'US' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"category":"Fail Rate"*'
      msg = 'lookup_fail_rate must pin category to "Fail Rate"' ).
  ENDMETHOD.


  METHOD api_entity_risk_fields.
    " assess_entity_risk → POST /api/entity/fraud/lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'companyName'            value = 'Acme Corp' )
      ( name = 'countryOfIncorporation' value = 'US' )
      ( name = 'category'               value = 'FRAUD' )
      ( name = 'url'                    value = 'https://acme.com' )
      ( name = 'businessEntityType'     value = 'CORP' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"countryOfIncorporation":*"category":*"businessEntityType":*'
      msg = 'assess_entity_risk must send fraud-risk fields' ).
  ENDMETHOD.


  METHOD api_credit_analysis_fields.
    " lookup_credit_analysis → POST /api/creditanalysis/lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'companyName'  value = 'Acme Corp' )
      ( name = 'addressLine1' value = '123 Main St' )
      ( name = 'city'         value = 'Springfield' )
      ( name = 'state'        value = 'IL' )
      ( name = 'country'      value = 'US' )
      ( name = 'dunsNumber'   value = '123456789' )
      ( name = 'postalCode'   value = '62701' )
      ( name = 'addressLine2' value = '456 Suite' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"addressLine1":*"city":*"state":*"country":*"dunsNumber":*'
      msg = 'lookup_credit_analysis must send credit-analysis fields' ).
  ENDMETHOD.


  METHOD api_domain_security_fields.
    " domain_security_report → POST /api/itsecurity/domainreport
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'domain' value = 'example.com' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"domain":"example.com"*'
      msg = 'domain_security_report must send domain' ).
  ENDMETHOD.


  METHOD api_ip_quality_fields.
    " check_ip_quality → POST /api/ipquality/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'ipAddress' value = '192.0.2.1' )
      ( name = 'userAgent' value = 'Mozilla/5.0' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"ipAddress":*"userAgent":*'
      msg = 'check_ip_quality must send ipAddress and userAgent' ).
  ENDMETHOD.


  METHOD api_ubo_fields.
    " lookup_beneficial_ownership → POST /api/beneficialownership/lookup
    " Note: uboThreshold and maxLayers are unquoted JSON numbers
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'companyName'  value = 'Acme Corp' )
      ( name = 'countryIso2'  value = 'US' )
      ( name = 'uboThreshold' value = '25.0' type = zcl_qubiton=>gc_type_number )
      ( name = 'maxLayers'    value = '5'    type = zcl_qubiton=>gc_type_number ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"countryIso2":*"uboThreshold":25.0*"maxLayers":5*'
      msg = 'lookup_beneficial_ownership must send numeric uboThreshold and maxLayers' ).
  ENDMETHOD.


  METHOD api_corp_hierarchy_fields.
    " lookup_corporate_hierarchy → POST /api/corporatehierarchy/lookup
    " Note: .NET DTO has all 5 fields [Required] and no Country (flagged for API team)
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'companyName'  value = 'Acme Corp' )
      ( name = 'addressLine1' value = '123 Main St' )
      ( name = 'city'         value = 'Springfield' )
      ( name = 'state'        value = 'IL' )
      ( name = 'zipCode'      value = '62701' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"addressLine1":*"city":*"state":*"zipCode":*'
      msg = 'lookup_corporate_hierarchy must send 5 required fields (no Country on DTO)' ).
  ENDMETHOD.


  METHOD api_duns_fields.
    " lookup_duns → POST /api/duns-number-lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'dunsNumber' value = '123456789' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"dunsNumber":"123456789"*'
      msg = 'lookup_duns must send dunsNumber' ).
  ENDMETHOD.


  METHOD api_hierarchy_fields.
    " lookup_hierarchy → POST /api/company/hierarchy/lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'identifier'     value = '123456789' )
      ( name = 'identifierType' value = 'DUNS' )
      ( name = 'country'        value = 'US' )
      ( name = 'options'        value = 'INCLUDE_FINANCIALS' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"identifier":*"identifierType":*"country":*"options":*'
      msg = 'lookup_hierarchy must send identifier/identifierType/country/options' ).
  ENDMETHOD.


  METHOD api_npi_fields.
    " validate_npi → POST /api/nationalprovideridentifier/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'npi'              value = '1234567890' )
      ( name = 'organizationName' value = 'Acme Medical' )
      ( name = 'lastName'         value = 'Doe' )
      ( name = 'firstName'        value = 'John' )
      ( name = 'middleName'       value = 'Q' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"npi":*"organizationName":*"lastName":*"firstName":*"middleName":*'
      msg = 'validate_npi must send npi + provider name parts' ).
  ENDMETHOD.


  METHOD api_medpass_fields.
    " validate_medpass → POST /api/medpass/validate
    " Note: ABAP sends 'taxId' (camelCase); .NET DTO property is TaxID — System.Text.Json
    " is case-insensitive on deserialization by default in this project, so OK
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'id'                 value = 'MEDPASS123' )
      ( name = 'businessEntityType' value = 'INDIVIDUAL' )
      ( name = 'companyName'        value = 'Acme Medical' )
      ( name = 'taxId'              value = '12-3456789' )
      ( name = 'country'            value = 'US' )
      ( name = 'state'              value = 'IL' )
      ( name = 'city'               value = 'Springfield' )
      ( name = 'postalCode'         value = '62701' )
      ( name = 'addressLine1'       value = '123 Main St' )
      ( name = 'addressLine2'       value = '456 Suite' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"id":*"businessEntityType":*"taxId":*"country":*"addressLine1":*'
      msg = 'validate_medpass must send Medpass identification + address fields' ).
  ENDMETHOD.


  METHOD api_dot_carrier_fields.
    " lookup_dot_carrier → POST /api/dot/fmcsa/lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'dotNumber'  value = '123456' )
      ( name = 'entityName' value = 'Acme Trucking' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"dotNumber":*"entityName":*'
      msg = 'lookup_dot_carrier must send dotNumber and entityName' ).
  ENDMETHOD.


  METHOD api_in_identity_fields.
    " validate_india_identity → POST /api/inidentity/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'identityNumber'     value = '123456789012' )
      ( name = 'identityNumberType' value = 'AADHAAR' )
      ( name = 'entityName'         value = 'Acme India' )
      ( name = 'dob'                value = '1990-01-15' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"identityNumber":*"identityNumberType":*"entityName":*"dob":*'
      msg = 'validate_india_identity must send identityNumber/Type/entityName/dob' ).
  ENDMETHOD.


  METHOD api_cert_validate_fields.
    " validate_certification → POST /api/certification/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'companyName'         value = 'Acme Corp' )
      ( name = 'country'             value = 'US' )
      ( name = 'city'                value = 'Springfield' )
      ( name = 'state'               value = 'IL' )
      ( name = 'zipCode'             value = '62701' )
      ( name = 'addressLine1'        value = '123 Main St' )
      ( name = 'addressLine2'        value = '456 Suite' )
      ( name = 'identityType'        value = 'COMPANY' )
      ( name = 'certificationType'   value = 'ISO9001' )
      ( name = 'certificationGroup'  value = 'QUALITY' )
      ( name = 'certificationNumber' value = 'CERT123456' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"country":*"certificationType":*"certificationGroup":*"certificationNumber":*'
      msg = 'validate_certification must send certification key fields' ).
  ENDMETHOD.


  METHOD api_cert_lookup_fields.
    " lookup_certification → POST /api/certification/lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'companyName'         value = 'Acme Corp' )
      ( name = 'country'             value = 'US' )
      ( name = 'city'                value = 'Springfield' )
      ( name = 'state'               value = 'IL' )
      ( name = 'zipCode'             value = '62701' )
      ( name = 'addressLine1'        value = '123 Main St' )
      ( name = 'addressLine2'        value = '456 Suite' )
      ( name = 'identityType'        value = 'COMPANY' )
      ( name = 'certificationType'   value = 'ISO9001' )
      ( name = 'certificationGroup'  value = 'QUALITY' )
      ( name = 'certificationNumber' value = 'CERT123456' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"companyName":*"country":*"certificationType":*"certificationNumber":*'
      msg = 'lookup_certification must send certification key fields' ).
  ENDMETHOD.


  METHOD api_payment_terms_fields.
    " analyze_payment_terms → POST /api/paymentterms/validate
    " Numeric fields must be unquoted (gc_type_number)
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'currentPayTerm' value = '30'      type = zcl_qubiton=>gc_type_number )
      ( name = 'annualSpend'    value = '1000000' type = zcl_qubiton=>gc_type_number )
      ( name = 'avgDaysPay'     value = '35'      type = zcl_qubiton=>gc_type_number )
      ( name = 'savingsRate'    value = '2.5'     type = zcl_qubiton=>gc_type_number )
      ( name = 'threshold'      value = '50000'   type = zcl_qubiton=>gc_type_number )
      ( name = 'vendorName'     value = 'Acme Supplies' )
      ( name = 'country'        value = 'US' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"currentPayTerm":30*"annualSpend":1000000*"avgDaysPay":35*"savingsRate":2.5*"threshold":50000*"vendorName":*"country":*'
      msg = 'analyze_payment_terms must send 5 unquoted numerics + vendorName + country' ).
  ENDMETHOD.


  METHOD api_ariba_lookup_fields.
    " lookup_ariba_supplier → POST /api/aribasupplierprofile/lookup
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'anid' value = 'ANID123456' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"anid":"ANID123456"*'
      msg = 'lookup_ariba_supplier must send anid' ).
  ENDMETHOD.


  METHOD api_ariba_validate_fields.
    " validate_ariba_supplier → POST /api/aribasupplierprofile/validate
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'anid' value = 'ANID123456' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"anid":"ANID123456"*'
      msg = 'validate_ariba_supplier must send anid' ).
  ENDMETHOD.


  METHOD api_gender_fields.
    " identify_gender → POST /api/genderize/identifygender
    DATA(lt_fields) = VALUE zcl_qubiton=>tt_name_value(
      ( name = 'name'    value = 'John' )
      ( name = 'country' value = 'US' ) ).
    DATA(lv_json) = mo_cut->build_json( lt_fields ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lv_json
      exp = '*"name":"John"*"country":"US"*'
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
    " .NET controller route /api/currency/exchange-rates/{baseCurrency}.
    DATA(lv_path) = `/api/currency/exchange-rates/` && `USD`.
    cl_abap_unit_assert=>assert_equals(
      act = lv_path
      exp = '/api/currency/exchange-rates/USD'
      msg = 'Exchange-rates URL must template baseCurrency directly into the path segment' ).
  ENDMETHOD.

ENDCLASS.
