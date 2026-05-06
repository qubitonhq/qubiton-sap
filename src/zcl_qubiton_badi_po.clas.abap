"! <p class="shorttext synchronized">QubitOn BAdI: Purchase Order Validation</p>
"!
"! Reference implementation of BAdI ME_PROCESS_PO_CUST (interface
"! IF_EX_ME_PROCESS_PO_CUST). Called during PO save in ME21N / ME22N /
"! ME29N / mass change. Lets you block PO posting (or warn the user)
"! based on the validation result of the PO's vendor.
"!
"! Typical use cases:
"!   * Block PO save when the vendor matches a sanctions list (OFAC, EU, UN).
"!   * Warn (do not block) when the vendor's cyber risk score is below
"!     threshold; route the PO to additional approvals via standard
"!     SAP release strategy.
"!   * Auto-populate a Z-field on the PO header with the vendor's risk
"!     posture for downstream reporting.
"!
"! ── On/off control (two layers):
"!   1. MASTER KILL SWITCH — ZQUBITON_CONFIG.TXN_VALIDATION_ENABLED
"!      Set to 'X' to enable, blank/missing/'-' to disable. Disabled
"!      means this BAdI exits immediately (no LFA1 read, no API call,
"!      no log write). Use this as the emergency-off lever — flipping
"!      one row stops every transactional BAdI in this connector at
"!      once.
"!   2. PER-TCODE CONFIG — ZQUBITON_SCREEN_CFG rows keyed by TCODE +
"!      VAL_TYPE. ACTIVE = '' on a row disables just that one check
"!      for just that one transaction; lets you turn off (e.g.) cyber
"!      score on PO save while keeping sanctions on.
"!
"! ── Best-practice fail-mode policy (defaults shown — override per ZQUBITON_SCREEN_CFG):
"!   * Sanctions       → ON_INVALID = 'E' (BLOCK SAVE — fail closed)
"!   * Cyber risk      → ON_INVALID = 'W' (WARN; do not block)
"!   * API unreachable → ON_ERROR   = 'W' (warn; allow PO save to proceed)
"!
"! Activate in SE19 for BAdI ME_PROCESS_PO_CUST.
"! See docs/transaction-validation.md for the full design and per-version
"! wiring instructions (S/4HANA on-prem, S/4HANA Cloud, ECC).
"!
"! @version 1.0.0
"! @author  QubitOn
CLASS zcl_qubiton_badi_po DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_ex_me_process_po_cust.

  PROTECTED SECTION.

    "! Run the configured validations against the PO's vendor and return
    "! TRUE when at least one validation issued a BLOCK-severity result.
    "! Override in a subclass to plug in additional checks (credit limit,
    "! payment-term policy, custom thresholds).
    METHODS check_po_vendor
      IMPORTING
        iv_lifnr        TYPE lifnr
        iv_bukrs        TYPE bukrs
      RETURNING
        VALUE(rv_block) TYPE abap_bool.

ENDCLASS.


CLASS zcl_qubiton_badi_po IMPLEMENTATION.

  " ── Active method: CHECK (the only one we drive logic in) ──────────────

  METHOD if_ex_me_process_po_cust~check.
    " Called automatically on PO save (ME21N / ME22N) and on mass change.
    " Reads the PO header and queries the vendor's risk posture via the
    " QubitOn API. Sets CH_FAILED = abap_true to block save when a strict
    " (E) policy is configured for the validation that failed.

    DATA ls_header TYPE mepoheader.
    DATA lv_block  TYPE abap_bool.

    " ── Master kill switch ─────────────────────────────────────────────
    " Single ZQUBITON_CONFIG row controls the entire transactional-
    " validation feature across every BAdI in this connector. Flip this
    " to disable in seconds; no transports needed.
    IF zcl_qubiton_screen=>get_config_value( 'TXN_VALIDATION_ENABLED' ) <> 'X'.
      RETURN.
    ENDIF.

    " Pull the header from the PO BAdI document object
    ls_header = im_header->get_data( ).

    IF ls_header-lifnr IS INITIAL.
      " No vendor on the PO yet (e.g. stock transfer); nothing to validate
      RETURN.
    ENDIF.

    lv_block = check_po_vendor(
      iv_lifnr = ls_header-lifnr
      iv_bukrs = ls_header-bukrs ).

    IF lv_block = abap_true.
      ch_failed = abap_true.
    ENDIF.
  ENDMETHOD.


  " ── Helper that delegates to the screening orchestrator ───────────────

  METHOD check_po_vendor.
    " Look up the vendor master and run the screening orchestrator.
    " Pipeline:
    "   1. Pull LFA1 → ty_vendor_data
    "   2. Run validate_vendor_all (returns one ty_screen_result per
    "      configured check; respects ZQUBITON_SCREEN_CFG)
    "   3. (optional) Ask BRF+ for the final verdict per validation
    "      when BRFPLUS_ENABLED='X' (overrides ON_INVALID column)
    "   4. (optional) Raise an SWIE workflow event when a warn-tier
    "      verdict says "route to approver" (WORKFLOW_ENABLED='X')
    "   5. Return rv_block=abap_true only on a hard block; warn-tier
    "      verdicts surface a yellow message and let save proceed

    DATA ls_lfa1 TYPE lfa1.

    SELECT SINGLE * FROM lfa1 INTO ls_lfa1 WHERE lifnr = iv_lifnr.
    IF sy-subrc <> 0.
      " Vendor master missing — out of scope for our validation
      RETURN.
    ENDIF.

    DATA ls_vendor TYPE zcl_qubiton_screen=>ty_vendor_data.
    ls_vendor-lifnr = ls_lfa1-lifnr.
    ls_vendor-land1 = ls_lfa1-land1.
    ls_vendor-name1 = ls_lfa1-name1.
    ls_vendor-name2 = ls_lfa1-name2.
    ls_vendor-stras = ls_lfa1-stras.
    ls_vendor-ort01 = ls_lfa1-ort01.
    ls_vendor-regio = ls_lfa1-regio.
    ls_vendor-pstlz = ls_lfa1-pstlz.
    ls_vendor-stceg = ls_lfa1-stceg.
    ls_vendor-stcd1 = ls_lfa1-stcd1.

    TRY.
        DATA(lo_screen) = NEW zcl_qubiton_screen(
          iv_apikey = zcl_qubiton_screen=>get_apikey( ) ).

        " 1. Run all configured checks. validate_vendor_all honours the
        " ZQUBITON_SCREEN_CFG row for tcode 'ME21N'/'ME22N'.
        DATA(lt_results) = lo_screen->validate_vendor_all(
          is_vendor = ls_vendor ).

        " 2. Apply the verdict per result. Use BRF+ when configured,
        " fall back to the result's own blocked flag otherwise.
        DATA(lo_brfplus) = NEW zcl_qubiton_brfplus( ).
        DATA(lo_workflow) = NEW zcl_qubiton_workflow( ).

        LOOP AT lt_results INTO DATA(ls_res).
          DATA lv_verdict TYPE char1.

          IF zcl_qubiton_brfplus=>is_enabled( ) = abap_true.
            " Customer has wired up a BRF+ application — let it decide.
            lv_verdict = lo_brfplus->get_verdict( is_input = VALUE #(
              vendor_country = ls_vendor-land1
              sanctions_hit  = COND #(
                WHEN ls_res-val_type = zcl_qubiton_screen=>gc_val_sanct
                 AND ls_res-blocked  = abap_true THEN abap_true
                ELSE abap_false ) ) ).
          ENDIF.

          IF lv_verdict IS INITIAL.
            " BRF+ disabled or fell back — use the per-result blocked flag
            " (which itself comes from ZQUBITON_SCREEN_CFG.ON_INVALID).
            lv_verdict = COND #( WHEN ls_res-blocked = abap_true
                                 THEN zcl_qubiton_brfplus=>gc_verdict_block
                                 ELSE zcl_qubiton_brfplus=>gc_verdict_silent ).
          ENDIF.

          " 3. Act on the verdict.
          CASE lv_verdict.
            WHEN zcl_qubiton_brfplus=>gc_verdict_block.
              rv_block = abap_true.
              EXIT.   " first hard-block wins; no need to evaluate more

            WHEN zcl_qubiton_brfplus=>gc_verdict_route.
              " Customer wants approval routing instead of hard-block.
              " Raise an SWIE event so a workflow template picks it up.
              " (No-op when WORKFLOW_ENABLED is off.)
              IF zcl_qubiton_workflow=>is_enabled( ) = abap_true.
                lo_workflow->raise_event(
                  iv_objtype = zcl_qubiton_workflow=>gc_objtype_po
                  iv_objkey  = CONV #( iv_lifnr )
                  iv_event   = zcl_qubiton_workflow=>gc_event_review
                  is_result  = ls_res-result ).
              ENDIF.

            WHEN zcl_qubiton_brfplus=>gc_verdict_warn.
              " Yellow status-bar warning; save proceeds.
              MESSAGE w003(zcl_qubiton_msg) WITH ls_res-result-message.

            WHEN OTHERS.
              " gc_verdict_silent — log only, no user message.
              CONTINUE.
          ENDCASE.
        ENDLOOP.

      CATCH zcx_qubiton INTO DATA(lx_err).
        " API unreachable — log and allow save (fail-open by default).
        " Override ZQUBITON_SCREEN_CFG.ON_ERROR = 'E' if your policy is
        " strict-fail-closed.
        MESSAGE w003(zcl_qubiton_msg) WITH lx_err->get_text( ).
    ENDTRY.
  ENDMETHOD.


  " ── Required interface stubs ──────────────────────────────────────────
  " The PO BAdI fires every method on every PO action; if any are missing
  " the activation in SE19 fails. Each stub below is intentionally empty —
  " our validation only happens in CHECK at save time.

  METHOD if_ex_me_process_po_cust~initialize.
  ENDMETHOD.

  METHOD if_ex_me_process_po_cust~open.
  ENDMETHOD.

  METHOD if_ex_me_process_po_cust~close.
  ENDMETHOD.

  METHOD if_ex_me_process_po_cust~post.
  ENDMETHOD.

  METHOD if_ex_me_process_po_cust~process_header.
  ENDMETHOD.

  METHOD if_ex_me_process_po_cust~process_item.
  ENDMETHOD.

  METHOD if_ex_me_process_po_cust~process_account.
  ENDMETHOD.

  METHOD if_ex_me_process_po_cust~process_schedule.
  ENDMETHOD.

  METHOD if_ex_me_process_po_cust~fieldselection_header.
  ENDMETHOD.

  METHOD if_ex_me_process_po_cust~fieldselection_header_refkeys.
  ENDMETHOD.

  METHOD if_ex_me_process_po_cust~fieldselection_item.
  ENDMETHOD.

  METHOD if_ex_me_process_po_cust~fieldselection_item_refkeys.
  ENDMETHOD.

ENDCLASS.
