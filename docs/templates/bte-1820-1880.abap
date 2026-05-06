"! <p class="shorttext synchronized">QubitOn BTE Function Module Skeleton</p>
"!
"! Reference function modules for SAP Business Transaction Events (BTE)
"! commonly used in FI / AP transactional flows. BTEs are an alternative
"! to BAdIs for older ECC releases (or for FI events where no BAdI exists)
"! and are registered via transaction FIBF.
"!
"! Two reference processes are wired here:
"!   * BTE 1820 — Document Posting (FI document save)
"!   * BTE 1880 — Invoice Posting (MIRO / FB60 alternative path)
"!
"! Customer setup:
"!   1. SE80 → create function group ZQUBITON_BTE
"!   2. Copy the function modules below into your namespace
"!   3. Transaction FIBF → Settings → P/S Modules → Of an SAP Application
"!      register Z_QUBITON_BTE_1820 against process 1820, application FI
"!   4. Activate the BTE process for your client
"!   5. The function module fires automatically on FI document post
"!
"! Why BTE alongside BAdIs?
"!   * Some FI/AP events have no BAdI at all (e.g. open-item posting)
"!   * BTEs survive across upgrades better than BAdIs in older ECC
"!   * BTE registration is per-client; BAdIs are cross-client
"!
"! ── On / off ──────────────────────────────────────────────────────
"!   Both function modules check ZQUBITON_CONFIG.TXN_VALIDATION_ENABLED
"!   first. Disabled = function returns immediately, no API call.
"!
"! @version 1.0.0
"! @author  QubitOn

"-----------------------------------------------------------------------
" FUNCTION Z_QUBITON_BTE_1820
"-----------------------------------------------------------------------
"!
"! BTE 1820 — Document Posting. Fires for every FI document save (BAPI
"! and dialog), including AP invoices and outgoing payments. Use when
"! you need a single hook that catches every document-create path
"! regardless of which transaction the user used.
"!
"! Signature is fixed by the FIBF process definition — do not change it.
"!
"! @parameter I_BKPF | Document header (BKPF structure)
"! @parameter T_BSEG | Document line items (BSEG table)
"!
"FUNCTION Z_QUBITON_BTE_1820.
"*"----------------------------------------------------------------------
"*"*"Local Interface:
"*"  IMPORTING
"*"     VALUE(I_BKPF) TYPE  BKPF
"*"  TABLES
"*"      T_BSEG STRUCTURE  BSEG
"*"----------------------------------------------------------------------
"
"  " ── Master kill switch ─────────────────────────────────────────
"  IF zcl_qubiton_screen=>get_config_value( 'TXN_VALIDATION_ENABLED' ) <> 'X'.
"    RETURN.
"  ENDIF.
"
"  " Skip when there's no AP/AR posting in this document
"  DATA lv_lifnr TYPE lifnr.
"  DATA lv_kunnr TYPE kunnr.
"
"  LOOP AT t_bseg INTO DATA(ls_bseg) WHERE koart = 'K' OR koart = 'D'.
"    IF ls_bseg-koart = 'K'. lv_lifnr = ls_bseg-lifnr. ENDIF.
"    IF ls_bseg-koart = 'D'. lv_kunnr = ls_bseg-kunnr. ENDIF.
"  ENDLOOP.
"
"  IF lv_lifnr IS INITIAL AND lv_kunnr IS INITIAL.
"    RETURN.   " no AP/AR partner — nothing to validate
"  ENDIF.
"
"  TRY.
"      DATA(lo_screen) = NEW zcl_qubiton_screen(
"        iv_apikey = zcl_qubiton_screen=>get_apikey( ) ).
"
"      IF lv_lifnr IS NOT INITIAL.
"        " Read LFA1 → ty_vendor_data → run sanctions
"        " (see zcl_qubiton_badi_po for the mapping pattern)
"      ENDIF.
"
"      " On a sanctions hit, raise MESSAGE TYPE 'E' to abort the
"      " posting. The BTE framework propagates this as a transaction
"      " rollback in dialog mode and as a BAPI return code in batch.
"
"    CATCH zcx_qubiton INTO DATA(lx_err).
"      " API unreachable — log and allow posting (fail-open default).
"      " Set ZQUBITON_CONFIG.TXN_FAIL_MODE = 'CLOSED' to flip this.
"      MESSAGE w003(zcl_qubiton_msg) WITH lx_err->get_text( ).
"  ENDTRY.
"
"ENDFUNCTION.

"-----------------------------------------------------------------------
" FUNCTION Z_QUBITON_BTE_1880
"-----------------------------------------------------------------------
"!
"! BTE 1880 — Invoice Posting. Specifically for invoice receipt
"! (MIRO + variants). More targeted than 1820 but with a richer
"! invoice context.
"!
"FUNCTION Z_QUBITON_BTE_1880.
"*"----------------------------------------------------------------------
"*"*"Local Interface:
"*"  IMPORTING
"*"     VALUE(I_RBKP) TYPE  RBKP
"*"  TABLES
"*"      T_RSEG STRUCTURE  RSEG
"*"----------------------------------------------------------------------
"
"  " Same kill-switch pattern as 1820, customised for invoice context.
"  IF zcl_qubiton_screen=>get_config_value( 'TXN_VALIDATION_ENABLED' ) <> 'X'.
"    RETURN.
"  ENDIF.
"
"  IF i_rbkp-lifnr IS INITIAL.
"    RETURN.
"  ENDIF.
"
"  " ... call zcl_qubiton_screen->check_vendor_sanctions and raise
"  " MESSAGE TYPE 'E' on a hit ...
"
"ENDFUNCTION.
