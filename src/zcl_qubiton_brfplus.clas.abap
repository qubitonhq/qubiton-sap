"! <p class="shorttext synchronized">QubitOn BRF+ Decision Helper</p>
"!
"! Wraps `FDT_FUNCTION_PROCESS` so BAdI implementations can delegate the
"! "block / warn / route / silent" decision to a customer-maintained
"! BRF+ application instead of hardcoded policy.
"!
"! This lets non-developer admins (BRF+ workbench users) tune the
"! policy without touching ABAP — change a threshold, add a country
"! exception, route a new BAdI to existing rules — by editing rules
"! in transaction BRFPLUS or the BRF+ Fiori app.
"!
"! ── Customer setup ─────────────────────────────────────────────────
"!   1. Transaction BRFPLUS → create application ZQUBITON_RULES
"!   2. Inside the application, create a Function:
"!        Name:        DECIDE_VENDOR_RISK_VERDICT
"!        Mode:        Functional Mode
"!        Result type: Element of type "VERDICT" (DDIC: CHAR1, fixed
"!                     values: E, W, S, R)
"!   3. Add input data objects:
"!        VENDOR_COUNTRY  CHAR3
"!        SANCTIONS_HIT   ABAP_BOOL
"!        CYBER_SCORE     INT4    (0–100)
"!        UBO_FLAGGED     ABAP_BOOL
"!   4. Build a Decision Table or Ruleset that maps the inputs to one
"!      of the verdict codes
"!   5. Activate the function — note its Function ID (a UUID)
"!   6. Maintain ZQUBITON_CONFIG.BRFPLUS_FUNCTION_ID = "<the UUID>"
"!   7. The BAdI implementation calls
"!        zcl_qubiton_brfplus=>get_verdict( ... )
"!      which returns 'E', 'W', 'S', or 'R' from the BRF+ rule
"!
"! ── On / off ──────────────────────────────────────────────────────
"!   Reads ZQUBITON_CONFIG.BRFPLUS_ENABLED. Disabled = falls back to
"!   ZQUBITON_SCREEN_CFG row policy (the on_invalid / on_error fields).
"!   This means BRF+ is purely additive — turn it off and the connector
"!   reverts to the simpler config-table policy.
"!
"! Reference docs: SAP help.sap.com → BRFplus → API → FDT_FUNCTION_PROCESS
"!
"! @version 1.0.0
"! @author  QubitOn
CLASS zcl_qubiton_brfplus DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Verdict codes returned by the BRF+ decision function. These map
    "! 1:1 onto the existing ZQUBITON_SCREEN_CFG.ON_INVALID values plus
    "! a new "ROUTE" verdict for workflow-based approval routing.
    CONSTANTS:
      gc_verdict_block  TYPE char1 VALUE 'E', " block save (on_invalid='E')
      gc_verdict_warn   TYPE char1 VALUE 'W', " warn but allow
      gc_verdict_silent TYPE char1 VALUE 'S', " silent — caller checks
      gc_verdict_route  TYPE char1 VALUE 'R'. " route via workflow

    "! Inputs the BRF+ function consumes. Pass whatever your BRF+
    "! decision table expects; unset fields default to ABAP initial.
    TYPES:
      BEGIN OF ty_decision_input,
        vendor_country TYPE land1,
        sanctions_hit  TYPE abap_bool,
        cyber_score    TYPE i,
        ubo_flagged    TYPE abap_bool,
        " Custom inputs — extend the structure in your subclass and the
        " corresponding BRF+ data object.
        custom_field_1 TYPE string,
        custom_field_2 TYPE string,
      END OF ty_decision_input.

    "! Check the master kill switch.
    CLASS-METHODS is_enabled
      RETURNING
        VALUE(rv_enabled) TYPE abap_bool.

    "! Evaluate the configured BRF+ function and return its verdict.
    "! When BRF+ is disabled, returns SPACE so the caller knows to
    "! fall back to ZQUBITON_SCREEN_CFG policy.
    "!
    "! @parameter is_input | Inputs to pass to the BRF+ function
    "! @parameter rv_verdict | One of gc_verdict_*; SPACE = fall back to legacy policy
    METHODS get_verdict
      IMPORTING
        is_input         TYPE ty_decision_input
      RETURNING
        VALUE(rv_verdict) TYPE char1
      RAISING
        zcx_qubiton.

  PRIVATE SECTION.

    "! The function ID configured in ZQUBITON_CONFIG.BRFPLUS_FUNCTION_ID.
    "! Cached on first read to avoid repeated config lookups.
    DATA mv_function_id TYPE string.

    METHODS get_function_id
      RETURNING
        VALUE(rv_function_id) TYPE string.

ENDCLASS.


CLASS zcl_qubiton_brfplus IMPLEMENTATION.

  METHOD is_enabled.
    rv_enabled = boolc(
      zcl_qubiton_screen=>get_config_value( 'BRFPLUS_ENABLED' ) = 'X' ).
  ENDMETHOD.


  METHOD get_function_id.
    IF mv_function_id IS INITIAL.
      mv_function_id = zcl_qubiton_screen=>get_config_value( 'BRFPLUS_FUNCTION_ID' ).
    ENDIF.
    rv_function_id = mv_function_id.
  ENDMETHOD.


  METHOD get_verdict.
    " Honour the master kill switch — disabled means return SPACE so
    " caller falls back to legacy ZQUBITON_SCREEN_CFG policy.
    IF is_enabled( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_function_id) = get_function_id( ).
    IF lv_function_id IS INITIAL.
      " Misconfigured — function ID not set. Fall back gracefully.
      MESSAGE w003(zcl_qubiton_msg) WITH 'BRFPLUS_FUNCTION_ID not configured'.
      RETURN.
    ENDIF.

    " Wrap the BRF+ call in a TRY block — a misconfigured BRF+ function
    " (deleted, deactivated, schema mismatch) should not crash the BAdI.
    " On any failure we fall back to the legacy ZQUBITON_SCREEN_CFG path.
    TRY.
        " Pseudo-code for FDT_FUNCTION_PROCESS — exact API signature
        " varies by BRF+ release. Customers complete this method per
        " their landscape; the helper keeps the call site uniform.
        "
        " Recommended pattern:
        "
        "   DATA(lo_function) = cl_fdt_factory=>get_instance( )->get_function(
        "       iv_id = lv_function_id ).
        "   DATA(lo_context) = lo_function->get_process_context( ).
        "   lo_context->set_value( iv_name = 'VENDOR_COUNTRY' ia_value = is_input-vendor_country ).
        "   ...
        "   lo_function->process( EXPORTING io_context = lo_context
        "                         IMPORTING eo_result = DATA(lo_result) ).
        "   lo_result->get_value( IMPORTING ea_value = rv_verdict ).
        "
        " Until the customer fills in the FDT_FUNCTION_PROCESS plumbing,
        " this method returns SPACE and the BAdI falls back to legacy
        " policy.
        rv_verdict = space.

      CATCH cx_root INTO DATA(lx).
        " BRF+ runtime error — degrade to legacy policy
        MESSAGE w003(zcl_qubiton_msg) WITH lx->get_text( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
