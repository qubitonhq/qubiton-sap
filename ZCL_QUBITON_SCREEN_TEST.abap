"! <p class="shorttext synchronized">QubitOn Screen Enhancement — ABAP Unit Tests</p>
"! Unit tests for ZCL_QUBITON_SCREEN covering tax type determination,
"! field extraction helpers, config loading, skip logic, and tax type
"! correctness (STCEG always maps to VAT).
"! Does NOT call the live API — tests orchestration logic only.
CLASS zcl_qubiton_screen_test DEFINITION
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
  FINAL.

  PRIVATE SECTION.

    " ── Tax Type Determination Tests ───────────────────────────────────────
    METHODS tax_type_us               FOR TESTING.
    METHODS tax_type_de               FOR TESTING.
    METHODS tax_type_br               FOR TESTING.
    METHODS tax_type_in               FOR TESTING.
    METHODS tax_type_au               FOR TESTING.
    METHODS tax_type_gb               FOR TESTING.
    METHODS tax_type_ca               FOR TESTING.
    METHODS tax_type_mx               FOR TESTING.
    METHODS tax_type_jp               FOR TESTING.
    METHODS tax_type_kr               FOR TESTING.
    METHODS tax_type_ru               FOR TESTING.
    METHODS tax_type_za               FOR TESTING.
    METHODS tax_type_fr_vat_default   FOR TESTING.
    METHODS tax_type_unknown_country  FOR TESTING.

    " ── Vendor Name Extraction ─────────────────────────────────────────────
    METHODS vendor_name_both          FOR TESTING.
    METHODS vendor_name_only_name1    FOR TESTING.
    METHODS vendor_name_blank         FOR TESTING.

    " ── Customer Name Extraction ───────────────────────────────────────────
    METHODS customer_name_both        FOR TESTING.
    METHODS customer_name_blank       FOR TESTING.

    " ── BP Name Extraction ─────────────────────────────────────────────────
    METHODS bp_name_org               FOR TESTING.
    METHODS bp_name_person            FOR TESTING.
    METHODS bp_name_blank             FOR TESTING.

    " ── Vendor Tax Number Extraction ───────────────────────────────────────
    METHODS vendor_tax_stceg          FOR TESTING.
    METHODS vendor_tax_stcd1_fallback FOR TESTING.
    METHODS vendor_tax_stcd2_fallback FOR TESTING.
    METHODS vendor_tax_empty          FOR TESTING.

    " ── Skip Logic (empty fields) ──────────────────────────────────────────
    METHODS vendor_tax_skip_empty     FOR TESTING.
    METHODS vendor_bank_skip_empty    FOR TESTING.
    METHODS vendor_addr_skip_empty    FOR TESTING.
    METHODS customer_tax_skip_empty   FOR TESTING.
    METHODS customer_bank_skip_empty  FOR TESTING.
    METHODS customer_addr_skip_empty  FOR TESTING.
    METHODS bp_tax_skip_empty         FOR TESTING.
    METHODS bp_bank_skip_empty        FOR TESTING.
    METHODS bp_addr_skip_empty        FOR TESTING.

    " ── Config Injection ───────────────────────────────────────────────────
    METHODS config_injection          FOR TESTING.
    METHODS config_country_filter     FOR TESTING.

    " ── Sanctions Skip Logic ──────────────────────────────────────────────
    METHODS vendor_sanctions_skip     FOR TESTING.
    METHODS customer_sanctions_skip   FOR TESTING.
    METHODS bp_sanctions_skip         FOR TESTING.

    " ── Constants ──────────────────────────────────────────────────────────
    METHODS constants_val_types       FOR TESTING.

    " ── Helper ─────────────────────────────────────────────────────────────
    DATA mo_cut TYPE REF TO zcl_qubiton_screen.

    METHODS setup.

ENDCLASS.


CLASS zcl_qubiton_screen_test IMPLEMENTATION.

  METHOD setup.
    TRY.
        mo_cut = NEW zcl_qubiton_screen( iv_apikey = 'test-key' ).
      CATCH zcx_qubiton.
        cl_abap_unit_assert=>fail( msg = 'Constructor should not raise' ).
    ENDTRY.
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Tax Type Determination
  " ═══════════════════════════════════════════════════════════════════════

  METHOD tax_type_us.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'US' )
      exp = 'EIN'
      msg = 'US should map to EIN' ).
  ENDMETHOD.

  METHOD tax_type_de.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'DE' )
      exp = 'VAT'
      msg = 'DE should map to VAT' ).
  ENDMETHOD.

  METHOD tax_type_br.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'BR' )
      exp = 'CNPJ'
      msg = 'BR should map to CNPJ' ).
  ENDMETHOD.

  METHOD tax_type_in.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'IN' )
      exp = 'GSTIN'
      msg = 'IN should map to GSTIN' ).
  ENDMETHOD.

  METHOD tax_type_au.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'AU' )
      exp = 'ABN'
      msg = 'AU should map to ABN' ).
  ENDMETHOD.

  METHOD tax_type_gb.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'GB' )
      exp = 'UTR'
      msg = 'GB should map to UTR' ).
  ENDMETHOD.

  METHOD tax_type_ca.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'CA' )
      exp = 'BN'
      msg = 'CA should map to BN' ).
  ENDMETHOD.

  METHOD tax_type_mx.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'MX' )
      exp = 'RFC'
      msg = 'MX should map to RFC' ).
  ENDMETHOD.

  METHOD tax_type_jp.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'JP' )
      exp = 'CN'
      msg = 'JP should map to CN' ).
  ENDMETHOD.

  METHOD tax_type_kr.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'KR' )
      exp = 'BRN'
      msg = 'KR should map to BRN' ).
  ENDMETHOD.

  METHOD tax_type_ru.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'RU' )
      exp = 'INN'
      msg = 'RU should map to INN' ).
  ENDMETHOD.

  METHOD tax_type_za.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'ZA' )
      exp = 'TIN'
      msg = 'ZA should map to TIN' ).
  ENDMETHOD.

  METHOD tax_type_fr_vat_default.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'FR' )
      exp = 'VAT'
      msg = 'FR should default to VAT' ).
  ENDMETHOD.

  METHOD tax_type_unknown_country.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->determine_tax_type( 'XX' )
      exp = 'VAT'
      msg = 'Unknown countries should default to VAT' ).
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Name Extraction
  " ═══════════════════════════════════════════════════════════════════════

  METHOD vendor_name_both.
    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data(
      lifnr = '0001000001' name1 = 'Acme' name2 = 'Corporation' ).

    DATA(lv_name) = mo_cut->get_vendor_name( ls_vendor ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_name
      exp = 'Acme Corporation'
      msg = 'Should concatenate name1 and name2' ).
  ENDMETHOD.

  METHOD vendor_name_only_name1.
    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data(
      lifnr = '0001000001' name1 = 'Acme' ).

    DATA(lv_name) = mo_cut->get_vendor_name( ls_vendor ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_name
      exp = 'Acme'
      msg = 'Should use name1 only when name2 is blank' ).
  ENDMETHOD.

  METHOD vendor_name_blank.
    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data(
      lifnr = '0001000001' ).

    DATA(lv_name) = mo_cut->get_vendor_name( ls_vendor ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_name
      exp = '*Vendor*0001000001*'
      msg = 'Should fall back to Vendor + number' ).
  ENDMETHOD.

  METHOD customer_name_both.
    DATA(ls_cust) = VALUE zcl_qubiton_screen=>ty_customer_data(
      kunnr = '0000100001' name1 = 'Global' name2 = 'Trading' ).

    DATA(lv_name) = mo_cut->get_customer_name( ls_cust ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_name
      exp = 'Global Trading' ).
  ENDMETHOD.

  METHOD customer_name_blank.
    DATA(ls_cust) = VALUE zcl_qubiton_screen=>ty_customer_data(
      kunnr = '0000100001' ).

    DATA(lv_name) = mo_cut->get_customer_name( ls_cust ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_name
      exp = '*Customer*0000100001*' ).
  ENDMETHOD.

  METHOD bp_name_org.
    DATA(ls_bp) = VALUE zcl_qubiton_screen=>ty_bp_data(
      partner = '0000000001' bpkind = '2' name_org1 = 'Acme' name_org2 = 'Inc' ).

    DATA(lv_name) = mo_cut->get_bp_name( ls_bp ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_name
      exp = 'Acme Inc' ).
  ENDMETHOD.

  METHOD bp_name_person.
    DATA(ls_bp) = VALUE zcl_qubiton_screen=>ty_bp_data(
      partner = '0000000001' bpkind = '1' name_first = 'John' name_last = 'Doe' ).

    DATA(lv_name) = mo_cut->get_bp_name( ls_bp ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_name
      exp = 'John Doe' ).
  ENDMETHOD.

  METHOD bp_name_blank.
    DATA(ls_bp) = VALUE zcl_qubiton_screen=>ty_bp_data(
      partner = '0000000001' bpkind = '1' ).

    DATA(lv_name) = mo_cut->get_bp_name( ls_bp ).

    cl_abap_unit_assert=>assert_char_cp(
      act = lv_name
      exp = '*BP*0000000001*' ).
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Vendor Tax Number Extraction
  " ═══════════════════════════════════════════════════════════════════════

  METHOD vendor_tax_stceg.
    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data(
      stceg = 'DE123456789' stcd1 = '12345' ).

    DATA(lv_tax) = mo_cut->get_vendor_tax_number( ls_vendor ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_tax
      exp = 'DE123456789'
      msg = 'STCEG should take priority over STCD1' ).
  ENDMETHOD.

  METHOD vendor_tax_stcd1_fallback.
    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data(
      stcd1 = '12-3456789' stcd2 = '999' ).

    DATA(lv_tax) = mo_cut->get_vendor_tax_number( ls_vendor ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_tax
      exp = '12-3456789'
      msg = 'Should fall back to STCD1 when STCEG is empty' ).
  ENDMETHOD.

  METHOD vendor_tax_stcd2_fallback.
    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data(
      stcd2 = 'SECONDARY' ).

    DATA(lv_tax) = mo_cut->get_vendor_tax_number( ls_vendor ).

    cl_abap_unit_assert=>assert_equals(
      act = lv_tax
      exp = 'SECONDARY'
      msg = 'Should fall back to STCD2 when STCEG and STCD1 are empty' ).
  ENDMETHOD.

  METHOD vendor_tax_empty.
    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data( ).

    DATA(lv_tax) = mo_cut->get_vendor_tax_number( ls_vendor ).

    cl_abap_unit_assert=>assert_initial(
      act = lv_tax
      msg = 'Should be empty when all tax fields are blank' ).
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Skip Logic (empty fields → graceful skip, not API error)
  " ═══════════════════════════════════════════════════════════════════════

  METHOD vendor_tax_skip_empty.
    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data( land1 = 'US' ).

    DATA(ls_result) = mo_cut->validate_vendor_tax( ls_vendor ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.

  METHOD vendor_bank_skip_empty.
    DATA(ls_bank) = VALUE zcl_qubiton_screen=>ty_vendor_bank( ).

    DATA(ls_result) = mo_cut->validate_vendor_bank(
      is_bank        = ls_bank
      iv_vendor_name = 'Acme' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.

  METHOD vendor_addr_skip_empty.
    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data( land1 = 'US' ).

    DATA(ls_result) = mo_cut->validate_vendor_address( ls_vendor ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.

  METHOD customer_tax_skip_empty.
    DATA(ls_cust) = VALUE zcl_qubiton_screen=>ty_customer_data( land1 = 'DE' ).

    DATA(ls_result) = mo_cut->validate_customer_tax( ls_cust ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.

  METHOD customer_bank_skip_empty.
    DATA(ls_bank) = VALUE zcl_qubiton_screen=>ty_customer_bank( ).

    DATA(ls_result) = mo_cut->validate_customer_bank(
      is_bank          = ls_bank
      iv_customer_name = 'Global Corp' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.

  METHOD customer_addr_skip_empty.
    DATA(ls_cust) = VALUE zcl_qubiton_screen=>ty_customer_data( land1 = 'DE' ).

    DATA(ls_result) = mo_cut->validate_customer_address( ls_cust ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.

  METHOD bp_tax_skip_empty.
    DATA(ls_bp) = VALUE zcl_qubiton_screen=>ty_bp_data( country = 'US' ).

    DATA(ls_result) = mo_cut->validate_bp_tax( ls_bp ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.

  METHOD bp_bank_skip_empty.
    DATA(ls_bank) = VALUE zcl_qubiton_screen=>ty_bp_bank( ).

    DATA(ls_result) = mo_cut->validate_bp_bank(
      is_bank    = ls_bank
      iv_bp_name = 'Acme Inc' ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.

  METHOD bp_addr_skip_empty.
    DATA(ls_bp) = VALUE zcl_qubiton_screen=>ty_bp_data( country = 'US' ).

    DATA(ls_result) = mo_cut->validate_bp_address( ls_bp ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Config Injection
  " ═══════════════════════════════════════════════════════════════════════

  METHOD config_injection.
    " Inject test config and verify get_active_config returns it
    DATA(lt_cfg) = VALUE zcl_qubiton_screen=>tt_screen_cfg(
      ( tcode = sy-tcode val_type = 'TAX'     active = abap_true on_invalid = 'E' on_error = 'W' )
      ( tcode = sy-tcode val_type = 'BANK'    active = abap_true on_invalid = 'W' on_error = 'S' )
      ( tcode = sy-tcode val_type = 'ADDRESS' active = abap_false on_invalid = 'W' on_error = 'W' ) ).

    mo_cut->set_config_for_testing( lt_cfg ).
    DATA(lt_active) = mo_cut->get_active_config( ).

    " Only active rows should be returned
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_active )
      exp = 2
      msg = 'Should return only active config rows' ).

    " Verify TAX and BANK are present but ADDRESS (inactive) is not
    DATA lv_found_tax TYPE abap_bool.
    DATA lv_found_bank TYPE abap_bool.
    LOOP AT lt_active INTO DATA(ls_cfg).
      IF ls_cfg-val_type = 'TAX'. lv_found_tax = abap_true. ENDIF.
      IF ls_cfg-val_type = 'BANK'. lv_found_bank = abap_true. ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_true( act = lv_found_tax  msg = 'TAX should be in active config' ).
    cl_abap_unit_assert=>assert_true( act = lv_found_bank msg = 'BANK should be in active config' ).
  ENDMETHOD.

  METHOD config_country_filter.
    " Verify country filter works — config for US only, vendor is DE
    DATA(lt_cfg) = VALUE zcl_qubiton_screen=>tt_screen_cfg(
      ( tcode = sy-tcode val_type = 'TAX' active = abap_true
        on_invalid = 'E' on_error = 'W' country_filter = 'US' ) ).

    mo_cut->set_config_for_testing( lt_cfg ).

    " Vendor from DE — should get no results because filter is US only
    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data(
      land1 = 'DE' stceg = 'DE123456789' name1 = 'Test GmbH' ).

    DATA(lt_results) = mo_cut->validate_vendor_all( is_vendor = ls_vendor ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_results )
      exp = 0
      msg = 'Country filter should skip non-matching vendors' ).
  ENDMETHOD.


  " ═══════════════════════════════════════════════════════════════════════
  " Constants
  " ═══════════════════════════════════════════════════════════════════════

  METHOD vendor_sanctions_skip.
    " Vendor with no name1 — sanctions should be skipped
    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data(
      lifnr = '0001000001' land1 = 'US' ).

    DATA(ls_result) = mo_cut->check_vendor_sanctions( ls_vendor ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.

  METHOD customer_sanctions_skip.
    " Customer with no name1 — sanctions should be skipped
    DATA(ls_cust) = VALUE zcl_qubiton_screen=>ty_customer_data(
      kunnr = '0000100001' land1 = 'DE' ).

    DATA(ls_result) = mo_cut->check_customer_sanctions( ls_cust ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.

  METHOD bp_sanctions_skip.
    " BP with no name_org1 and no name_last — sanctions should be skipped
    DATA(ls_bp) = VALUE zcl_qubiton_screen=>ty_bp_data(
      partner = '0000000001' country = 'US' bpkind = '2' ).

    DATA(ls_result) = mo_cut->check_bp_sanctions( ls_bp ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-success  exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-is_valid exp = abap_true ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-message exp = '*skipped*' ).
  ENDMETHOD.


  METHOD constants_val_types.
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton_screen=>gc_val_tax     exp = 'TAX' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton_screen=>gc_val_bank    exp = 'BANK' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton_screen=>gc_val_address exp = 'ADDRESS' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton_screen=>gc_val_email   exp = 'EMAIL' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton_screen=>gc_val_phone   exp = 'PHONE' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_qubiton_screen=>gc_val_sanct   exp = 'SANCTION' ).
  ENDMETHOD.

ENDCLASS.
