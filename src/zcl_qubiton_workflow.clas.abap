"! <p class="shorttext synchronized">QubitOn Workflow Event Raiser (SWIE)</p>
"!
"! Helper for SAP Business Workflow integration. Raises a workflow event
"! when a QubitOn validation produces a "warn" or "route" verdict, so a
"! workflow template can route the document to an additional approver
"! instead of hard-blocking the user.
"!
"! The event raised is `ZQUBITON_RISK_DETECTED` on object type
"! `ZQUBITON_DOC` with the document key (PO number, invoice number,
"! payment doc) and the validation outcome as event container parameters.
"!
"! ── Customer setup ─────────────────────────────────────────────────
"!   1. SE11 → activate object type ZQUBITON_DOC (template in this class
"!      header — copy into your namespace)
"!   2. SWE2 → register event linkage:
"!        Object Type:  ZQUBITON_DOC
"!        Event:        RISK_DETECTED
"!        Receiver Type: WS9000xxxx (your workflow template)
"!   3. PFTC → build a workflow template that picks up the event,
"!      reads the validation result from the event container, and
"!      routes a decision task to the right approver group.
"!
"! ── On / off ──────────────────────────────────────────────────────
"!   Reads ZQUBITON_CONFIG.WORKFLOW_ENABLED. Disabled = no event raised
"!   (BAdI surfaces the warning to the user instead).
"!
"! Reference docs: SAP help.sap.com → Workflow → SWE_EVENT_CREATE_FOR_UPD_TASK
"!
"! @version 1.0.0
"! @author  QubitOn
CLASS zcl_qubiton_workflow DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Event names raised by this class. Customers can route different
    "! workflows on different verdict severities.
    CONSTANTS:
      gc_event_risk      TYPE string VALUE 'RISK_DETECTED',
      gc_event_blocked   TYPE string VALUE 'PAYMENT_BLOCKED',
      gc_event_review    TYPE string VALUE 'REVIEW_REQUIRED'.

    "! Document types — used as the OBJTYPE in SAP_WAPI_CREATE_EVENT.
    "! Set up the corresponding object type in SE11/SWO1 in your namespace.
    CONSTANTS:
      gc_objtype_po      TYPE swo_objtyp VALUE 'ZQUBITON_PO',
      gc_objtype_invoice TYPE swo_objtyp VALUE 'ZQUBITON_INV',
      gc_objtype_payment TYPE swo_objtyp VALUE 'ZQUBITON_PAY'.

    "! Raise a workflow event so a customer-defined workflow template
    "! can pick it up and route an approval task. The validation result
    "! is packed into the event container so the template can branch
    "! on severity.
    "!
    "! @parameter iv_objtype | Object type (ZQUBITON_PO, _INV, _PAY)
    "! @parameter iv_objkey  | Document key (PO #, invoice #, payment doc #)
    "! @parameter iv_event   | Event name from gc_event_*
    "! @parameter is_result  | Validation outcome to pack into the container
    "! @raising zcx_qubiton  | When SWE_EVENT_CREATE_FOR_UPD_TASK fails
    METHODS raise_event
      IMPORTING
        iv_objtype TYPE swo_objtyp
        iv_objkey  TYPE swo_typeid
        iv_event   TYPE string
        is_result  TYPE zcl_qubiton=>ty_result OPTIONAL
      RAISING
        zcx_qubiton.

    "! Convenience wrapper around raise_event for the common PO case.
    "! Raises ZQUBITON_PO/RISK_DETECTED with the PO number as the key.
    METHODS raise_po_risk
      IMPORTING
        iv_ebeln  TYPE ebeln
        is_result TYPE zcl_qubiton=>ty_result
      RAISING
        zcx_qubiton.

    "! Check the master kill switch — workflow integration disabled
    "! means raise_event() and convenience wrappers all return without
    "! firing.
    CLASS-METHODS is_enabled
      RETURNING
        VALUE(rv_enabled) TYPE abap_bool.

ENDCLASS.


CLASS zcl_qubiton_workflow IMPLEMENTATION.

  METHOD is_enabled.
    rv_enabled = boolc(
      zcl_qubiton_screen=>get_config_value( 'WORKFLOW_ENABLED' ) = 'X' ).
  ENDMETHOD.


  METHOD raise_event.
    " Honour the master kill switch — disabled means do nothing.
    IF is_enabled( ) = abap_false.
      RETURN.
    ENDIF.

    " Build the event container with the validation outcome packed
    " as named parameters. The receiving workflow template reads them
    " via &EVT_CONTAINER.RESULT_TYPE& etc.
    DATA lt_container TYPE STANDARD TABLE OF swcont.

    APPEND VALUE swcont(
      element = 'EVENT_NAME'
      tab_index = 0
      elemlength = strlen( CONV string( iv_event ) )
      type = 'C'
      value = iv_event ) TO lt_container.

    IF is_result-message IS NOT INITIAL.
      APPEND VALUE swcont(
        element = 'MESSAGE'
        tab_index = 0
        elemlength = strlen( is_result-message )
        type = 'C'
        value = CONV string( is_result-message ) ) TO lt_container.
    ENDIF.

    IF is_result-success = abap_true.
      APPEND VALUE swcont(
        element = 'IS_VALID'
        type = 'C'
        elemlength = 1
        value = COND #( WHEN is_result-is_valid = abap_true THEN 'X' ELSE '' )
      ) TO lt_container.
    ENDIF.

    DATA lv_event_id TYPE swedumevtid.
    DATA lv_rc       TYPE sysubrc.

    CALL FUNCTION 'SAP_WAPI_CREATE_EVENT'
      EXPORTING
        object_type        = iv_objtype
        object_key         = iv_objkey
        event              = CONV swo_event( iv_event )
        commit_work        = 'X'
      IMPORTING
        return_code        = lv_rc
        event_id           = lv_event_id
      TABLES
        input_container    = lt_container
      EXCEPTIONS
        OTHERS             = 99.

    IF lv_rc <> 0 OR sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_qubiton
        EXPORTING
          error_text = |Failed to raise workflow event { iv_event } on { iv_objtype }/{ iv_objkey }: rc={ lv_rc }|.
    ENDIF.
  ENDMETHOD.


  METHOD raise_po_risk.
    raise_event(
      iv_objtype = gc_objtype_po
      iv_objkey  = CONV swo_typeid( iv_ebeln )
      iv_event   = gc_event_risk
      is_result  = is_result ).
  ENDMETHOD.

ENDCLASS.
