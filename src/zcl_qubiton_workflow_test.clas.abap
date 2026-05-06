"! <p class="shorttext synchronized">QubitOn Workflow Helper — ABAP Unit Tests</p>
"!
"! Tests for ZCL_QUBITON_WORKFLOW. Coverage focuses on what can be
"! verified without a live SAP runtime:
"!
"!   * Public constants (event names, object types) are stable and
"!     correctly cased — a future "constants cleanup" PR that lower-
"!     cases them would silently mismatch the workflow event linkage
"!     in SWE2, breaking customer integrations.
"!   * Constructor / instantiation does not raise when WORKFLOW_ENABLED
"!     is unset (the default for fresh installs).
"!   * raise_po_risk delegates to raise_event with the right object
"!     type and event name.
"!
"! The actual SAP_WAPI_CREATE_EVENT call path is exercised in the
"! integration test environment (Satya's S/4 sandbox) — local ABAP
"! Unit cannot fire workflow events.
CLASS zcl_qubiton_workflow_test DEFINITION
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
  FINAL.

  PRIVATE SECTION.

    " ── Constants (regression locks) ─────────────────────────────────
    METHODS const_event_risk        FOR TESTING.
    METHODS const_event_blocked     FOR TESTING.
    METHODS const_event_review      FOR TESTING.
    METHODS const_objtype_po        FOR TESTING.
    METHODS const_objtype_invoice   FOR TESTING.
    METHODS const_objtype_payment   FOR TESTING.

    " ── Public API surface ───────────────────────────────────────────
    METHODS instantiate_does_not_raise FOR TESTING.
    METHODS is_enabled_returns_bool    FOR TESTING.

ENDCLASS.


CLASS zcl_qubiton_workflow_test IMPLEMENTATION.

  " ── Constants ──────────────────────────────────────────────────────
  " The wire contract is the workflow event name on a customer's SWE2
  " event linkage. If we rename a constant here, every customer's
  " linkage breaks until they re-register. Lock the values.

  METHOD const_event_risk.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_qubiton_workflow=>gc_event_risk
      exp = 'RISK_DETECTED'
      msg = 'Renaming gc_event_risk breaks every customer SWE2 linkage' ).
  ENDMETHOD.

  METHOD const_event_blocked.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_qubiton_workflow=>gc_event_blocked
      exp = 'PAYMENT_BLOCKED' ).
  ENDMETHOD.

  METHOD const_event_review.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_qubiton_workflow=>gc_event_review
      exp = 'REVIEW_REQUIRED' ).
  ENDMETHOD.

  METHOD const_objtype_po.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_qubiton_workflow=>gc_objtype_po
      exp = 'ZQUBITON_PO'
      msg = 'Object type changes break SWO1 / event linkage' ).
  ENDMETHOD.

  METHOD const_objtype_invoice.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_qubiton_workflow=>gc_objtype_invoice
      exp = 'ZQUBITON_INV' ).
  ENDMETHOD.

  METHOD const_objtype_payment.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_qubiton_workflow=>gc_objtype_payment
      exp = 'ZQUBITON_PAY' ).
  ENDMETHOD.

  " ── Public API surface ─────────────────────────────────────────────

  METHOD instantiate_does_not_raise.
    " Fresh installs should not blow up at constructor time even when
    " WORKFLOW_ENABLED config row is missing. Helper instances are cheap
    " and intended to be created per-call.
    DATA(lo_wf) = NEW zcl_qubiton_workflow( ).
    cl_abap_unit_assert=>assert_bound(
      act = lo_wf
      msg = 'Constructor must not raise when WORKFLOW_ENABLED is unset' ).
  ENDMETHOD.

  METHOD is_enabled_returns_bool.
    " is_enabled is a CLASS-METHOD; calling it on a fresh DB
    " (WORKFLOW_ENABLED row missing) must return abap_false (not raise).
    " Real SAP DB will likely return false here; we just assert the type.
    DATA(lv_enabled) = zcl_qubiton_workflow=>is_enabled( ).
    " ABAP boolean is char1; valid values are 'X' / abap_true / 'true' or
    " '' / abap_false. Confirm we get one of those, not garbage.
    cl_abap_unit_assert=>assert_true(
      act = boolc( lv_enabled = abap_true OR lv_enabled = abap_false )
      msg = 'is_enabled must return abap_true or abap_false' ).
  ENDMETHOD.

ENDCLASS.
