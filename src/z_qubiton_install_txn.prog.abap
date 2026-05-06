*&---------------------------------------------------------------------*
*& Report  Z_QUBITON_INSTALL_TXN
*&
*& One-time setup report that seeds the four new ZQUBITON_CONFIG rows
*& required by the transactional-validation feature
*& (BAdIs / SWIE workflow / BRF+ rule integration / BTE FI exits).
*&
*& All rows default to DISABLED so installing the connector has no
*& runtime impact until an admin explicitly turns features on.
*&
*& Run interactively:
*&   1. SE38 → enter Z_QUBITON_INSTALL_TXN → Execute (F8)
*&   2. The report INSERTs missing rows and reports the result.
*&
*& Run from a transport request (recommended for QAS/PRD):
*&   1. SE38 → execute, capture the resulting WRITE: output
*&   2. Maintain via SM30 on a customizing transport so the rows
*&      flow through CTS to QAS / PRD
*&
*& Re-runnable: existing rows are NOT overwritten (idempotent).
*&
*& @author  QubitOn
*& @version 1.0.0
*&---------------------------------------------------------------------*
REPORT z_qubiton_install_txn.

PARAMETERS:
  p_dryrun TYPE flag DEFAULT 'X'  AS CHECKBOX,   " Dry run — preview only
  p_force  TYPE flag DEFAULT ''   AS CHECKBOX.   " Overwrite existing rows

TYPES:
  BEGIN OF ty_seed,
    config_key   TYPE c LENGTH 30,
    config_value TYPE string,
    purpose      TYPE string,
  END OF ty_seed.

DATA lt_seed TYPE STANDARD TABLE OF ty_seed.

START-OF-SELECTION.

  " ── Default config rows for the transactional-validation feature ──────
  " All start DISABLED. Admin flips to 'X' (or to a valid UUID for the
  " BRF+ function ID) once they're ready to use the feature.
  APPEND VALUE #(
    config_key   = 'TXN_VALIDATION_ENABLED'
    config_value = ''
    purpose      = 'Master kill switch for every transactional BAdI in this connector.' &&
                   ' Set to ''X'' to enable PO / invoice / payment validation hooks;' &&
                   ' blank or ''N'' = disabled.'
  ) TO lt_seed.

  APPEND VALUE #(
    config_key   = 'WORKFLOW_ENABLED'
    config_value = ''
    purpose      = 'SWIE workflow event raising. Set to ''X'' to enable' &&
                   ' ZCL_QUBITON_WORKFLOW raising SAP_WAPI_CREATE_EVENT;' &&
                   ' blank = no events fired.'
  ) TO lt_seed.

  APPEND VALUE #(
    config_key   = 'BRFPLUS_ENABLED'
    config_value = ''
    purpose      = 'BRF+ rule integration. Set to ''X'' to delegate' &&
                   ' block / warn / route / silent verdicts to a customer' &&
                   ' BRF+ application; blank = falls back to ZQUBITON_SCREEN_CFG policy.'
  ) TO lt_seed.

  APPEND VALUE #(
    config_key   = 'BRFPLUS_FUNCTION_ID'
    config_value = ''
    purpose      = 'UUID of the customer-maintained BRF+ Function that returns the' &&
                   ' verdict. Required when BRFPLUS_ENABLED = ''X''. Get it from' &&
                   ' transaction BRFPLUS → your function → Properties.'
  ) TO lt_seed.

  WRITE: / 'QubitOn — Transactional Validation Config Seeding'.
  WRITE: / '═══════════════════════════════════════════════════'.
  WRITE: /.

  IF p_dryrun = 'X'.
    WRITE: / 'DRY RUN — no rows will be written. Uncheck p_dryrun and re-run to apply.'.
    WRITE: /.
  ENDIF.

  DATA lv_inserted TYPE i.
  DATA lv_skipped  TYPE i.
  DATA lv_updated  TYPE i.
  DATA lv_existing TYPE c LENGTH 1024.

  LOOP AT lt_seed INTO DATA(ls_seed).
    " Probe for existing row using the same dynamic SELECT pattern used by
    " zcl_qubiton_screen=>get_config_value (so behaviour is symmetric)
    DATA lv_count TYPE i.
    TRY.
        SELECT COUNT(*) FROM ('ZQUBITON_CONFIG')
          INTO @lv_count
          WHERE ('CONFIG_KEY') = @ls_seed-config_key.
      CATCH cx_root INTO DATA(lx_select).
        WRITE: / '✗ Cannot read ZQUBITON_CONFIG —', lx_select->get_text( ).
        WRITE: / '  (Table may not exist yet. Run the standard installer first.)'.
        RETURN.
    ENDTRY.

    IF lv_count > 0 AND p_force = ''.
      lv_skipped = lv_skipped + 1.
      WRITE: / '○ SKIP   ', ls_seed-config_key, '  — already exists (use p_force to overwrite)'.
      CONTINUE.
    ENDIF.

    IF p_dryrun = 'X'.
      WRITE: / '+ WOULD ', ls_seed-config_key, ' = ''',
               COND #( WHEN ls_seed-config_value IS INITIAL THEN '<blank>'
                       ELSE CONV string( ls_seed-config_value ) ), ''''.
      WRITE: /(50) ls_seed-purpose, sy-vline.
      CONTINUE.
    ENDIF.

    " Real run — INSERT or UPDATE
    TRY.
        IF lv_count > 0.
          UPDATE ('ZQUBITON_CONFIG')
             SET ('CONFIG_VALUE') = @ls_seed-config_value
           WHERE ('CONFIG_KEY')   = @ls_seed-config_key.
          lv_updated = lv_updated + 1.
          WRITE: / '↻ UPDATE ', ls_seed-config_key.
        ELSE.
          " Use a static INSERT path that the connector's runtime expects
          INSERT ('ZQUBITON_CONFIG')
            VALUES @( VALUE #(
              " mandt is set automatically by the framework
              ('CONFIG_KEY')   = ls_seed-config_key
              ('CONFIG_VALUE') = ls_seed-config_value ) ).
          lv_inserted = lv_inserted + 1.
          WRITE: / '+ INSERT ', ls_seed-config_key.
        ENDIF.

      CATCH cx_root INTO DATA(lx_dml).
        WRITE: / '✗ FAILED ', ls_seed-config_key, '  — ', lx_dml->get_text( ).
    ENDTRY.
  ENDLOOP.

  IF p_dryrun = '' AND lv_inserted > 0.
    COMMIT WORK.
  ENDIF.

  WRITE: /.
  WRITE: / '═══════════════════════════════════════════════════'.
  WRITE: / 'Inserted:', lv_inserted.
  WRITE: / 'Updated: ', lv_updated.
  WRITE: / 'Skipped: ', lv_skipped.
  WRITE: /.
  WRITE: / 'Next steps:'.
  WRITE: / '  1. Open SM30 → table ZQUBITON_CONFIG'.
  WRITE: / '  2. Set TXN_VALIDATION_ENABLED = ''X'' to enable transactional BAdIs'.
  WRITE: / '  3. (optional) Set WORKFLOW_ENABLED / BRFPLUS_ENABLED for the helpers'.
  WRITE: / '  4. Activate BAdI implementation ZIM_QUBITON_PO in SE19'.
  WRITE: / '  5. See docs/transaction-validation.md for the full setup'.
