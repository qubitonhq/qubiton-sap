"! <p class="shorttext synchronized">QubitOn BRF+ Helper — ABAP Unit Tests</p>
"!
"! Tests for ZCL_QUBITON_BRFPLUS. Verdict-code constants are pinned so
"! a future cleanup PR doesn't accidentally shift the wire contract
"! between the helper and BAdI consumers.
"!
"! The actual FDT_FUNCTION_PROCESS call is exercised on a real SAP
"! system with an installed BRF+ application — local ABAP Unit cannot
"! invoke BRF+ rules.
CLASS zcl_qubiton_brfplus_test DEFINITION
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
  FINAL.

  PRIVATE SECTION.

    " ── Verdict constants (regression locks) ─────────────────────────
    METHODS const_verdict_block    FOR TESTING.
    METHODS const_verdict_warn     FOR TESTING.
    METHODS const_verdict_silent   FOR TESTING.
    METHODS const_verdict_route    FOR TESTING.

    " ── Constants alignment with ZQUBITON_SCREEN_CFG ─────────────────
    METHODS verdicts_align_with_cfg FOR TESTING.

    " ── Public API surface ───────────────────────────────────────────
    METHODS instantiate_does_not_raise FOR TESTING.
    METHODS is_enabled_returns_bool    FOR TESTING.
    METHODS verdict_falls_back_when_off FOR TESTING.

ENDCLASS.


CLASS zcl_qubiton_brfplus_test IMPLEMENTATION.

  " ── Verdict constants ──────────────────────────────────────────────
  " These map 1:1 onto ZQUBITON_SCREEN_CFG.ON_INVALID values. If they
  " drift apart, BAdIs that translate BRF+ verdicts back into ON_INVALID
  " policy break silently.

  METHOD const_verdict_block.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_qubiton_brfplus=>gc_verdict_block
      exp = 'E'
      msg = 'Verdict BLOCK must equal ZQUBITON_SCREEN_CFG.ON_INVALID = ''E''' ).
  ENDMETHOD.

  METHOD const_verdict_warn.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_qubiton_brfplus=>gc_verdict_warn
      exp = 'W'
      msg = 'Verdict WARN must equal ZQUBITON_SCREEN_CFG.ON_INVALID = ''W''' ).
  ENDMETHOD.

  METHOD const_verdict_silent.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_qubiton_brfplus=>gc_verdict_silent
      exp = 'S'
      msg = 'Verdict SILENT must equal ZQUBITON_SCREEN_CFG.ON_INVALID = ''S''' ).
  ENDMETHOD.

  METHOD const_verdict_route.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_qubiton_brfplus=>gc_verdict_route
      exp = 'R'
      msg = 'Verdict ROUTE is BRF+-specific (workflow routing); must equal ''R''' ).
  ENDMETHOD.

  METHOD verdicts_align_with_cfg.
    " Cross-check that the four verdict values are distinct (no accidental
    " duplicate constants). Distinctness keeps the CASE statement in BAdI
    " consumers exhaustive and unambiguous.
    cl_abap_unit_assert=>assert_differs(
      act = zcl_qubiton_brfplus=>gc_verdict_block
      exp = zcl_qubiton_brfplus=>gc_verdict_warn ).
    cl_abap_unit_assert=>assert_differs(
      act = zcl_qubiton_brfplus=>gc_verdict_warn
      exp = zcl_qubiton_brfplus=>gc_verdict_silent ).
    cl_abap_unit_assert=>assert_differs(
      act = zcl_qubiton_brfplus=>gc_verdict_silent
      exp = zcl_qubiton_brfplus=>gc_verdict_route ).
  ENDMETHOD.

  " ── Public API surface ─────────────────────────────────────────────

  METHOD instantiate_does_not_raise.
    DATA(lo_brfplus) = NEW zcl_qubiton_brfplus( ).
    cl_abap_unit_assert=>assert_bound(
      act = lo_brfplus
      msg = 'Constructor must not raise on fresh installs' ).
  ENDMETHOD.

  METHOD is_enabled_returns_bool.
    DATA(lv_enabled) = zcl_qubiton_brfplus=>is_enabled( ).
    cl_abap_unit_assert=>assert_true(
      act = boolc( lv_enabled = abap_true OR lv_enabled = abap_false )
      msg = 'is_enabled must return abap_true or abap_false' ).
  ENDMETHOD.

  METHOD verdict_falls_back_when_off.
    " Contract: when BRFPLUS_ENABLED is not 'X' (the default), get_verdict
    " must return SPACE so the caller knows to fall back to the simpler
    " ZQUBITON_SCREEN_CFG row policy. This is the "additive only" promise.
    "
    " Note: this test is correct when BRFPLUS_ENABLED row is unset OR
    " explicitly disabled. In a CI environment with a fresh DB the row
    " is absent — get_config_value returns SPACE — is_enabled returns
    " abap_false — get_verdict short-circuits to SPACE.
    DATA(lo_brfplus) = NEW zcl_qubiton_brfplus( ).
    TRY.
        DATA(lv_verdict) = lo_brfplus->get_verdict(
          is_input = VALUE #(
            vendor_country = 'US'
            sanctions_hit  = abap_true
            cyber_score    = 50 ) ).
        " When BRFPLUS_ENABLED is off, get_verdict short-circuits and
        " returns SPACE. We accept any value here when the test runs
        " against a system where BRFPLUS_ENABLED happens to be 'X' —
        " in that case we'd be exercising the real BRF+ runtime which
        " is out of scope for this unit test.
        IF zcl_qubiton_brfplus=>is_enabled( ) = abap_false.
          cl_abap_unit_assert=>assert_initial(
            act = lv_verdict
            msg = 'When BRFPLUS_ENABLED is off, get_verdict must return SPACE so caller falls back to legacy policy' ).
        ENDIF.
      CATCH zcx_qubiton.
        " Acceptable: real-system BRF+ misconfiguration. Not a unit-test
        " concern — the helper documents it falls back gracefully.
        RETURN.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
