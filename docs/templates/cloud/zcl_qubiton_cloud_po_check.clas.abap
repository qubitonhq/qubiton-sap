"! <p class="shorttext synchronized">QubitOn Cloud BAdI: PO Final Check (Pattern B)</p>
"!
"! Reference implementation of the released cloud BAdI
"! BD_MMPUR_FINAL_CHECK_PO (interface IF_EX_BD_MMPUR_FINAL_CHECK_PO)
"! for SAP S/4HANA Cloud Public Edition. This is the cloud-tier equivalent
"! of zcl_qubiton_badi_po (which targets on-prem / S/4HANA Private Cloud).
"!
"! ── Why this file lives under docs/templates/cloud/ and not src/ ──────
"! src/ holds artefacts the abapGit installer activates in an on-prem
"! tenant. The Public Cloud tooling is different: customers register
"! cloud BAdI implementations through the Fiori app
"! "Custom Fields and Logic" → BAdIs tab → BD_MMPUR_FINAL_CHECK_PO,
"! and the system generates the implementation skeleton there. The
"! customer copies the body from this template into the generated
"! skeleton — they do NOT abapGit-import this class directly.
"!
"! ── Cloud-specific constraints (vs the on-prem BAdI) ──────────────────
"!   * Cannot use cl_http_client / cl_rest_http_client directly. HTTPS
"!     calls go through an HTTP Communication Arrangement that must be
"!     created via Fiori app "Communication Arrangements" using
"!     Communication Scenario SAP_COM_0276 (HTTP Outbound) pointing at
"!     api.qubiton.com.
"!   * Cannot read most classic DDIC tables (LFA1, LFB1, LFM1) — must
"!     use the cloud-released CDS views (e.g. I_Supplier).
"!   * Cannot raise classic MESSAGE statements with custom message
"!     classes — must use the released BAPI/Fiori message infrastructure
"!     by appending to the BAdI's CT_MESSAGES table.
"!   * Cannot call BAL Application Log directly — use the released
"!     CL_BALI_LOG_DB_ACCESS interface, or accept that logging happens
"!     server-side at api.qubiton.com.
"!
"! ── Verification status (read this before adopting) ───────────────────
"! The released-BAdI catalogue for Public Cloud is not consolidated in
"! one place by SAP. The exact interface signature for
"! BD_MMPUR_FINAL_CHECK_PO has varied across cloud release waves
"! (CE 2308 / 2402 / 2502+). The QubitOn team validated this template
"! against the public SAP Help portal documentation as of 2026-05; we
"! do NOT have continuous-access cloud sandbox validation. Customers
"! adopting this template MUST:
"!   1. Confirm the BAdI exists under their tenant's release in Fiori
"!      app "Custom Fields and Logic" → BAdIs tab.
"!   2. Confirm the parameter names + types match what their
"!      generated skeleton exposes.
"!   3. Test in a sandbox tenant (or non-prod customising client)
"!      before promoting to PRD.
"!   4. Open a GitHub issue if signatures diverged so we can update
"!      this template.
"!
"! ── Activation steps ──────────────────────────────────────────────────
"!   1. Fiori app "Communication Arrangements" → Create
"!      Scenario:        SAP_COM_0276
"!      System / User:   QUBITON_API
"!      URL:             https://api.qubiton.com
"!      Auth method:     None (apikey carried in header)
"!      Set Header:      apikey = <your QubitOn API key>
"!   2. Fiori app "Communication Systems" → confirm DESTINATION_ID
"!      lands on the entry created above (default: QUBITON_API).
"!   3. Fiori app "Custom Fields and Logic" → BAdIs tab → search
"!      BD_MMPUR_FINAL_CHECK_PO → Create Implementation
"!      Implementation Name:  ZQUBITON_CLOUD_PO_CHECK
"!      Description:          QubitOn sanctions check on PO save
"!   4. Paste the body of the CHECK method below into the generated
"!      skeleton. Adapt CDS view names + Communication Scenario to
"!      match your tenant.
"!   5. Activate. Cloud BAdI implementations take effect immediately
"!      in the tenant; no transport.
"!
"! @version 1.0.0
"! @author  QubitOn
CLASS zcl_qubiton_cloud_po_check DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " The actual interface name in your tenant may be the cloud-released
    " variant (often prefixed BADI_BD_ or starting BD_). The Fiori app
    " "Custom Fields and Logic" generates the correct skeleton — copy
    " THIS body into THAT generated class.
    INTERFACES if_ex_bd_mmpur_final_check_po.

  PRIVATE SECTION.

    " Communication Arrangement name created in step 1 above. Customer
    " edits this if they used a different name.
    CONSTANTS gc_comm_scenario TYPE if_a4c_cp_communication=>ty_scenario_id
                VALUE 'SAP_COM_0276'.

    "! Resolve the supplier's country + tax ID from the cloud-released
    "! supplier CDS view I_Supplier. On-prem code reads LFA1 directly;
    "! cloud code MUST go through I_Supplier (or a custom CDS exposure).
    METHODS read_supplier_facts
      IMPORTING
        iv_supplier  TYPE c LENGTH 10
      EXPORTING
        ev_country   TYPE c LENGTH 3
        ev_tax_ref   TYPE c LENGTH 30
        ev_name      TYPE c LENGTH 80.

    "! Make the HTTPS call to api.qubiton.com via the configured
    "! Communication Arrangement. Returns abap_true when the supplier
    "! is on a sanctions list and the verdict is BLOCK.
    METHODS call_qubiton_sanctions
      IMPORTING
        iv_country     TYPE c LENGTH 3
        iv_name        TYPE c LENGTH 80
      RETURNING
        VALUE(rv_hit)  TYPE abap_bool.

ENDCLASS.


CLASS zcl_qubiton_cloud_po_check IMPLEMENTATION.

  METHOD if_ex_bd_mmpur_final_check_po~check.
    " The cloud BAdI passes a PO header context (IS_HEADER), the line
    " items (IT_ITEMS), and an OUTPUT message table (CT_MESSAGES) we
    " append to. Setting message type = 'E' on a row in CT_MESSAGES is
    " how Public Cloud blocks the PO save — there is NO ch_failed flag
    " in the cloud variant.

    DATA lv_country TYPE c LENGTH 3.
    DATA lv_tax_ref TYPE c LENGTH 30.
    DATA lv_name    TYPE c LENGTH 80.
    DATA lv_blocked TYPE abap_bool.

    " Master kill switch — on-prem reads ZQUBITON_CONFIG; cloud reads
    " a Custom Business Object or a tenant-scoped variable. Replace
    " this constant with whatever your tenant uses.
    CONSTANTS lc_enabled TYPE abap_bool VALUE abap_true.
    IF lc_enabled <> abap_true.
      RETURN.
    ENDIF.

    " is_header is the BAdI's PO header context structure. The exact
    " field name for the supplier in your tenant may be Supplier,
    " SupplierID, or LIFNR depending on the released version.
    IF is_header-supplier IS INITIAL.
      RETURN.   " stock transfer / no vendor — nothing to validate
    ENDIF.

    read_supplier_facts(
      EXPORTING iv_supplier = is_header-supplier
      IMPORTING
        ev_country = lv_country
        ev_tax_ref = lv_tax_ref
        ev_name    = lv_name ).

    IF lv_name IS INITIAL.
      RETURN.   " supplier master not retrievable — fail open
    ENDIF.

    lv_blocked = call_qubiton_sanctions(
      iv_country = lv_country
      iv_name    = lv_name ).

    IF lv_blocked = abap_true.
      " Block the save by appending a type-E message. Public Cloud
      " surfaces this in the PO Fiori app as a hard error.
      APPEND VALUE #(
        msgty = 'E'
        msgid = 'ZQUBITON_CLOUD'
        msgno = '001'
        msgv1 = is_header-supplier
        msgv2 = lv_country
      ) TO ct_messages.
    ENDIF.
  ENDMETHOD.


  METHOD read_supplier_facts.
    " Cloud-released CDS view for supplier master. The view's exact
    " field names vary by release wave — confirm in your tenant.
    SELECT SINGLE
        Country,
        TaxJurisdiction,
        SupplierName
      FROM i_supplier
      WHERE Supplier = @iv_supplier
      INTO ( @ev_country, @ev_tax_ref, @ev_name ).
  ENDMETHOD.


  METHOD call_qubiton_sanctions.
    " Cloud HTTPS via Communication Arrangement.
    " Released alternative to cl_http_client.

    DATA lo_dest    TYPE REF TO if_a4c_cp_destination_factory.
    DATA lo_http    TYPE REF TO if_web_http_client.
    DATA lo_request TYPE REF TO if_web_http_request.
    DATA lv_body    TYPE string.
    DATA lv_resp    TYPE string.

    TRY.
        " Resolve the destination from the Communication Arrangement.
        " The exact factory class name is cloud-release-dependent; the
        " variants seen in the wild are CL_HTTP_DESTINATION_PROVIDER
        " and CL_A4C_CP_DESTINATION_FACTORY. Pick the one available
        " in your tenant's released-API set.
        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
          comm_scenario  = gc_comm_scenario
          comm_system_id = 'QUBITON_API' ).

        lo_http = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).

        " Build the JSON request body. Keep this minimal — the cloud
        " released JSON helpers are limited; use simple concatenation
        " with the cloud-released cl_abap_json class if available.
        lv_body = |\{ "name": "{ iv_name }", "country": "{ iv_country }" \}|.

        lo_request = lo_http->get_http_request( ).
        lo_request->set_header_fields( VALUE #(
          ( name = 'Content-Type' value = 'application/json' )
        ) ).
        lo_request->set_uri_path( i_uri_path = '/api/sanctions/check' ).
        lo_request->set_text( lv_body ).

        DATA(lo_response) = lo_http->execute( i_method = if_web_http_client=>post ).

        IF lo_response->get_status( )-code <> 200.
          " Fail open on API error — log and allow PO save. The
          " on-prem BAdI policy can be flipped to fail-closed via
          " ZQUBITON_SCREEN_CFG.ON_ERROR='E'; the cloud equivalent
          " requires a Custom Business Object / Fiori app rule.
          rv_hit = abap_false.
          RETURN.
        ENDIF.

        lv_resp = lo_response->get_text( ).

        " Pure-string check on the JSON for the cloud's tightly
        " constrained ABAP. If you have access to released JSON
        " parsing (XCO_CP_JSON in newer waves) prefer that.
        IF lv_resp CS '"hit":true'.
          rv_hit = abap_true.
        ENDIF.

      CATCH cx_root.
        " Any failure → fail open. Customer raises the bar by
        " returning abap_true here when their policy is
        " strict-fail-closed.
        rv_hit = abap_false.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
