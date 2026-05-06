"! <p class="shorttext synchronized">QubitOn Cloud BAdI: PO Final Check (Pattern B)</p>
"!
"! Reference implementation of the released cloud BAdI
"! BD_MMPUR_FINAL_CHECK_PO (BAdI definition; the implementation
"! interface is IF_EX_MMPUR_FINAL_CHECK_PO — no `BD_` prefix on the
"! interface side) for SAP S/4HANA Cloud Public Edition. This is the
"! cloud-tier equivalent
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
"!     by appending to the BAdI's MESSAGES (CHANGING) table.
"!   * Cannot call BAL Application Log directly — use the released
"!     CL_BALI_LOG_DB_ACCESS interface, or accept that logging happens
"!     server-side at api.qubiton.com.
"!
"! ── Verification status (read this before adopting) ───────────────────
"! The released-BAdI catalogue for Public Cloud is not consolidated in
"! one place by SAP. The exact interface signature for
"! BD_MMPUR_FINAL_CHECK_PO has varied across cloud release waves
"! (CE 2308 / 2402 / 2502+). This template is INFORMED BY (not
"! validated against) the public SAP Help portal as of 2026-05; we
"! do NOT have cloud sandbox access to verify it end-to-end.
"! Customers adopting this template MUST:
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

    " The released-BAdI catalogue lists the implementation INTERFACE
    " as `IF_EX_MMPUR_FINAL_CHECK_PO` (no `BD_` prefix — `BD_` is on
    " the BAdI DEFINITION name, not on the implementation interface).
    " A prior cut of this template referenced `IF_EX_BD_MMPUR_...`
    " — that interface does not exist and would not activate.
    " The Fiori app "Custom Fields and Logic" generates the correct
    " skeleton — copy THIS body into THAT generated class and remove
    " the placeholder INTERFACES line if your tenant's skeleton
    " already declares it.
    INTERFACES if_ex_mmpur_final_check_po.

  PRIVATE SECTION.

    " Communication Arrangement name created in step 1 above. Customer
    " edits this if they used a different name.  Typed STRING because
    " the older if_a4c_cp_communication=>ty_scenario_id alias was
    " removed in newer cloud release waves; STRING is universally
    " accepted by cl_http_destination_provider.
    CONSTANTS gc_comm_scenario TYPE string VALUE 'SAP_COM_0276'.

    "! Resolve the supplier's country + name from the cloud-released
    "! supplier CDS view I_Supplier. On-prem code reads LFA1 directly;
    "! cloud code MUST go through I_Supplier (or a custom CDS exposure).
    METHODS read_supplier_facts
      IMPORTING
        iv_supplier  TYPE c LENGTH 10
      EXPORTING
        ev_country   TYPE c LENGTH 3
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

  METHOD if_ex_mmpur_final_check_po~check.
    " The cloud BAdI passes a flat `PURCHASEORDER` structure
    " (IMPORTING), a `PURCHASEORDERITEMS` table (IMPORTING — note
    " plural, no `IT_` prefix), and a CHANGING `MESSAGES` table.
    "
    " This is NOT the on-prem `IF_EX_ME_PROCESS_PO_CUST` shape
    " (`IM_HEADER` object reference + `CH_FAILED` flag) — those
    " mechanics don't exist on the cloud BAdI.  Setting `msgty='E'`
    " (or `'A'`) on a row appended to `MESSAGES` is how Public Cloud
    " blocks the PO save.
    "
    " The exact DDIC types for `PURCHASEORDER` /
    " `PURCHASEORDERITEMS` / `MESSAGES` are tenant + release-wave
    " specific (`MMPUR_S_*` / `MMPUR_T_*` namespace).  Customers
    " regenerate the skeleton in their tenant via Fiori app
    " "Custom Fields and Logic" → BAdIs tab → BD_MMPUR_FINAL_CHECK_PO
    " → Create — that auto-generates the implementation class with
    " the wave-correct types, then they paste the body below into
    " the generated CHECK method.  See SAP KBA 2893882 + 3558790
    " for the canonical lookup path.

    DATA lv_country TYPE c LENGTH 3.
    DATA lv_name    TYPE c LENGTH 80.
    DATA lv_blocked TYPE abap_bool.

    " Master kill switch (cloud equivalent of ZQUBITON_CONFIG.TXN_VALIDATION_ENABLED):
    " Public Cloud has no per-tenant key-value table.  Customer wires
    " this to whatever their tenant uses (a Custom Business Object,
    " a Maintenance Object, or a tenant variable read via the
    " released SAP_API_SETTING service).  The simplest version is
    " a hardcoded constant edited at activation time and re-deployed
    " through the Fiori "Custom Fields and Logic" flow.
    " Example with a Custom Business Object lookup is in:
    "   docs/transaction-validation.md → "Cloud kill switch options"
    " For now, leaving this template unconditional — fail-safe is to
    " ship it with the BAdI implementation DEACTIVATED in the Fiori
    " app and only activate after the Communication Arrangement is in
    " place.

    " `purchaseorder-supplier` reads the supplier field off the
    " flat header structure.  Field name is `Supplier` on the cloud-
    " released structure (matches the API_PURCHASEORDER_PROCESS_SRV
    " entity); confirm via the Fiori-generated skeleton in your
    " tenant if your release wave exposes it under a different
    " name (e.g. `SupplierID`).
    IF purchaseorder-supplier IS INITIAL.
      RETURN.   " stock transfer / no vendor — nothing to validate
    ENDIF.

    read_supplier_facts(
      EXPORTING iv_supplier = purchaseorder-supplier
      IMPORTING
        ev_country = lv_country
        ev_name    = lv_name ).

    IF lv_name IS INITIAL.
      RETURN.   " supplier master not retrievable — fail open
    ENDIF.

    lv_blocked = call_qubiton_sanctions(
      iv_country = lv_country
      iv_name    = lv_name ).

    IF lv_blocked = abap_true.
      " Block the save by appending a type-E message to the CHANGING
      " MESSAGES table.  Public Cloud surfaces this in the PO Fiori
      " app as a hard error.  No `ch_failed` flag, no exception —
      " just the message row.
      "
      " Field names below (`msgty` / `msgid` / `msgno` / `msgv1` /
      " `msgv2`) match the SYMSG-style line type used in SAP-published
      " examples for this BAdI (community.sap.com .../ba-p/13537724
      " and SAP KBA 2893882).  If your release wave's MMPUR_*
      " message-table type uses BAPIRET2-style names (`type` / `id` /
      " `number` / `message_v1` / `message_v2`), rename the fields in
      " this VALUE constructor to match — the ADT skeleton in your
      " tenant is the source of truth.
      APPEND VALUE #(
        msgty = 'E'
        msgid = 'ZQUBITON_CLOUD'
        msgno = '001'
        msgv1 = purchaseorder-supplier
        msgv2 = lv_country
      ) TO messages.
    ENDIF.
  ENDMETHOD.


  METHOD read_supplier_facts.
    " Cloud-released CDS path for supplier name + country.  Per SAP
    " KBA 3536295 ("Retrieving Multiple Addresses of Business Partners
    " via CDS View") and KBA 3649550, the canonical released path is:
    "
    "   I_Supplier (Supplier → BusinessPartner)
    "      → I_BusinessPartner (BusinessPartner → AddressID, the
    "                            standard "default" address pointer)
    "      → I_BUSPARTADDRESS  (BusinessPartner+AddressID → AddressID
    "                            into the Address master)
    "      → I_Address_2       (AddressID → Country, Region, etc.)
    "
    " I_Supplier itself does NOT expose a Country field, and the view
    " name `I_SupplierAddress` is NOT in the released CDS catalog —
    " an earlier draft of this method used it and would not activate.
    "
    " Tax-related fields are exposed via I_BusinessPartnerTaxNumber on
    " newer waves and are NOT pulled here (we don't need them for
    " sanctions-only screening).
    DATA lv_business_partner TYPE c LENGTH 10.
    DATA lv_address_id       TYPE c LENGTH 10.

    " Step 1 — supplier name + business-partner key.
    SELECT SINGLE FROM i_supplier
      FIELDS SupplierName, BusinessPartner
      WHERE Supplier = @iv_supplier
      INTO ( @ev_name, @lv_business_partner ).

    IF sy-subrc <> 0.
      CLEAR: ev_name, ev_country.
      RETURN.
    ENDIF.

    IF lv_business_partner IS INITIAL.
      CLEAR ev_country.
      RETURN.
    ENDIF.

    " Step 2 — default address ID for the business partner.
    SELECT SINGLE FROM i_businesspartner
      FIELDS AddressID
      WHERE BusinessPartner = @lv_business_partner
      INTO @lv_address_id.

    IF sy-subrc <> 0 OR lv_address_id IS INITIAL.
      CLEAR ev_country.
      RETURN.
    ENDIF.

    " Step 3 — country for the default address.  Join via
    " I_BUSPARTADDRESS (released BP-side address table) to
    " I_Address_2 (the released Address master with Country).
    SELECT SINGLE FROM i_buspartaddress AS bpa
      INNER JOIN i_address_2 AS addr
        ON addr~AddressID = bpa~AddressID
      FIELDS addr~Country
      WHERE bpa~BusinessPartner = @lv_business_partner
        AND bpa~AddressID       = @lv_address_id
      INTO @ev_country.

    IF sy-subrc <> 0.
      CLEAR ev_country.
    ENDIF.
  ENDMETHOD.


  METHOD call_qubiton_sanctions.
    " Cloud HTTPS via Communication Arrangement.
    " Released alternative to cl_http_client.

    DATA lo_http    TYPE REF TO if_web_http_client.
    DATA lo_request TYPE REF TO if_web_http_request.
    DATA lv_body    TYPE string.
    DATA lv_resp    TYPE string.
    DATA lv_name_e  TYPE string.

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

        " JSON-escape the supplier name.  iv_country is constrained to
        " ISO-3166 (3 chars, alphanumeric) so it doesn't need escaping;
        " iv_name can contain ", \, control chars and would produce
        " malformed JSON if concatenated raw.  Order matters: the
        " backslash replacement MUST run first or it will double-escape
        " the backslashes inserted by the quote replacement.
        lv_name_e = iv_name.
        REPLACE ALL OCCURRENCES OF `\` IN lv_name_e WITH `\\`.
        REPLACE ALL OCCURRENCES OF `"` IN lv_name_e WITH `\"`.
        REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN lv_name_e WITH `\n`.
        REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN lv_name_e WITH `\n`.
        REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN lv_name_e WITH `\t`.

        lv_body = |\{ "name": "{ lv_name_e }", "country": "{ iv_country }" \}|.

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

        " Match `"hit":true` only on the top-level field, not as a
        " substring of e.g. `"nothit":true` or `"hit":truemarker`.
        " The QubitOn API normalises whitespace, so checking for both
        " `"hit":true` and `"hit": true` (one space) covers it without
        " needing a JSON parser.  When the cloud release exposes
        " xco_cp_json this should be replaced with proper parsing.
        FIND REGEX `[,{]\s*"hit"\s*:\s*true(\s|,|\})`
             IN lv_resp.
        IF sy-subrc = 0.
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
