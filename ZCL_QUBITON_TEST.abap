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
    METHODS parse_result_field_missing_flag FOR TESTING.

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
    cl_abap_unit_assert=>assert_char_not_cp(
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


  METHOD parse_result_field_missing_flag.
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

ENDCLASS.
