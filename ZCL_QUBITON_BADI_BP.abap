"! <p class="shorttext synchronized">QubitOn BAdI: Business Partner Validation</p>
"! Implements IF_EX_BUS1006_CHECK to validate BP data (tax, address, sanctions)
"! on save in BP transaction (S/4HANA Business Partner).
"!
"! Note: BADI_BUS1006_CHECK does not provide bank data in its interface.
"! Bank validation for BP requires a separate user exit or enhancement
"! that reads from BUT100/BPBK tables directly.
"!
"! Activate in SE19 for BAdI BADI_BUS1006_CHECK.
"! Configuration: table ZQUBITON_SCREEN_CFG controls which validations run.
"!
"! @version 1.2.0
"! @author  QubitOn
CLASS zcl_qubiton_badi_bp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_ex_bus1006_check.

ENDCLASS.


CLASS zcl_qubiton_badi_bp IMPLEMENTATION.

  METHOD if_ex_bus1006_check~check.
    " Called on Business Partner save in S/4HANA.
    " Parameters (from BAdI BADI_BUS1006_CHECK):
    "   iv_partner    TYPE bu_partner     — BP number
    "   is_but000     TYPE bus000_data    — Central data
    "   it_bpadtel    TYPE bpad_tel_t     — Telephone numbers
    "   it_bpadaddr   TYPE bpad_addr_t    — Address data
    "   it_bptax      TYPE bptax_t        — Tax data
    "   et_return     TYPE bapiret2_tab   — Return messages

    DATA ls_bp TYPE zcl_qubiton_screen=>ty_bp_data.

    " Map central BP data
    ls_bp-partner    = iv_partner.
    ls_bp-name_org1  = is_but000-name_org1.
    ls_bp-name_org2  = is_but000-name_org2.
    ls_bp-name_last  = is_but000-name_last.
    ls_bp-name_first = is_but000-name_first.
    ls_bp-bpkind     = is_but000-bpkind.
    ls_bp-bu_group   = is_but000-bu_group.

    " Map primary address (first entry)
    IF it_bpadaddr IS NOT INITIAL.
      READ TABLE it_bpadaddr INTO DATA(ls_addr) INDEX 1.
      IF sy-subrc = 0.
        ls_bp-country    = ls_addr-country.
        ls_bp-street     = ls_addr-street.
        ls_bp-city       = ls_addr-city1.
        ls_bp-region     = ls_addr-region.
        ls_bp-postl_cod1 = ls_addr-post_code1.
      ENDIF.
    ENDIF.

    " Map primary tax data (first entry)
    IF it_bptax IS NOT INITIAL.
      READ TABLE it_bptax INTO DATA(ls_tax) INDEX 1.
      IF sy-subrc = 0.
        ls_bp-taxnum  = ls_tax-taxnum.
        ls_bp-taxtype = ls_tax-taxtype.
      ENDIF.
    ENDIF.

    " Map primary phone (first entry)
    IF it_bpadtel IS NOT INITIAL.
      READ TABLE it_bpadtel INTO DATA(ls_tel) INDEX 1.
      IF sy-subrc = 0.
        ls_bp-tel_number = ls_tel-tel_number.
      ENDIF.
    ENDIF.

    TRY.
        DATA(lo_screen) = NEW zcl_qubiton_screen(
          iv_apikey = zcl_qubiton_screen=>get_apikey( ) ).

        " Call individual methods directly — validate_bp_all uses MESSAGE statements
        " which would duplicate the BAPI et_return messages below.
        DATA(lt_config) = lo_screen->get_active_config( ).

        LOOP AT lt_config INTO DATA(ls_cfg).

          " Country filter
          IF ls_cfg-country_filter IS NOT INITIAL AND ls_cfg-country_filter <> ls_bp-country.
            CONTINUE.
          ENDIF.

          DATA ls_result TYPE zcl_qubiton=>ty_result.
          CLEAR ls_result.

          CASE ls_cfg-val_type.
            WHEN zcl_qubiton_screen=>gc_val_tax.
              ls_result = lo_screen->validate_bp_tax( is_bp = ls_bp ).

            WHEN zcl_qubiton_screen=>gc_val_bank.
              " BADI_BUS1006_CHECK does not provide bank data — skip
              CONTINUE.

            WHEN zcl_qubiton_screen=>gc_val_address.
              ls_result = lo_screen->validate_bp_address( is_bp = ls_bp ).

            WHEN zcl_qubiton_screen=>gc_val_sanct.
              ls_result = lo_screen->check_bp_sanctions( is_bp = ls_bp ).

            WHEN OTHERS.
              CONTINUE.
          ENDCASE.

          " Build BAPI return messages — this is the ONLY messaging path for BP
          DATA ls_return TYPE bapiret2.
          CLEAR ls_return.

          IF ls_result-success = abap_false.
            " API error
            CASE ls_cfg-on_error.
              WHEN 'E'.
                ls_return-type       = 'E'.
                ls_return-id         = zcl_qubiton=>gc_msgid.
                ls_return-number     = '003'.
                ls_return-message_v1 = ls_cfg-val_type.
                ls_return-message    = ls_result-message.
                APPEND ls_return TO et_return.
              WHEN 'W'.
                ls_return-type       = 'W'.
                ls_return-id         = zcl_qubiton=>gc_msgid.
                ls_return-number     = '003'.
                ls_return-message_v1 = ls_cfg-val_type.
                ls_return-message    = ls_result-message.
                APPEND ls_return TO et_return.
              WHEN OTHERS.
                " Silent — no return message
            ENDCASE.

          ELSEIF ls_result-is_valid = abap_false.
            " Validation failure
            CASE ls_cfg-on_invalid.
              WHEN 'E'.
                ls_return-type       = 'E'.
                ls_return-id         = zcl_qubiton=>gc_msgid.
                ls_return-number     = '002'.
                ls_return-message_v1 = ls_cfg-val_type.
                ls_return-message    = ls_result-message.
                APPEND ls_return TO et_return.
              WHEN 'W'.
                ls_return-type       = 'W'.
                ls_return-id         = zcl_qubiton=>gc_msgid.
                ls_return-number     = '002'.
                ls_return-message_v1 = ls_cfg-val_type.
                ls_return-message    = ls_result-message.
                APPEND ls_return TO et_return.
              WHEN OTHERS.
                " Silent
            ENDCASE.
          ENDIF.
          " Success: no BAPI return message needed

        ENDLOOP.

      CATCH zcx_qubiton INTO DATA(lx_err).
        DATA ls_warn TYPE bapiret2.
        ls_warn-type    = 'W'.
        ls_warn-id      = zcl_qubiton=>gc_msgid.
        ls_warn-number  = '003'.
        ls_warn-message = |QubitOn validation unavailable: { lx_err->get_text( ) }|.
        APPEND ls_warn TO et_return.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
