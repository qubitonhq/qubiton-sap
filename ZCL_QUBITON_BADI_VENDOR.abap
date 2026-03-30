"! <p class="shorttext synchronized">QubitOn BAdI: Vendor Master Validation</p>
"! Implements IF_EX_VENDOR_ADD_DATA_CS to validate vendor data
"! (tax, bank, address, sanctions) on save in XK01/XK02/FK01/FK02.
"!
"! Activate in SE19 for BAdI VENDOR_ADD_DATA_CS.
"! Configuration: table ZQUBITON_SCREEN_CFG controls which validations run.
"!
"! @version 1.2.0
"! @author  QubitOn
CLASS zcl_qubiton_badi_vendor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_ex_vendor_add_data_cs.

ENDCLASS.


CLASS zcl_qubiton_badi_vendor IMPLEMENTATION.

  METHOD if_ex_vendor_add_data_cs~check_data_consistency.
    " Called when the user saves a vendor master record.
    " Parameters (from BAdI VENDOR_ADD_DATA_CS):
    "   i_lfa1  TYPE lfa1     — Vendor general data
    "   i_lfbk  TYPE lfbk     — Vendor bank detail (single row)
    "   i_lfb1  TYPE lfb1     — Vendor company code data
    "   e_check TYPE c        — Set to 'X' to block save

    DATA ls_vendor TYPE zcl_qubiton_screen=>ty_vendor_data.
    DATA ls_bank   TYPE zcl_qubiton_screen=>ty_vendor_bank.

    " Map LFA1 fields to our structure
    ls_vendor-lifnr = i_lfa1-lifnr.
    ls_vendor-land1 = i_lfa1-land1.
    ls_vendor-name1 = i_lfa1-name1.
    ls_vendor-name2 = i_lfa1-name2.
    ls_vendor-stras = i_lfa1-stras.
    ls_vendor-ort01 = i_lfa1-ort01.
    ls_vendor-regio = i_lfa1-regio.
    ls_vendor-pstlz = i_lfa1-pstlz.
    ls_vendor-stceg = i_lfa1-stceg.
    ls_vendor-stcd1 = i_lfa1-stcd1.
    ls_vendor-stcd2 = i_lfa1-stcd2.
    ls_vendor-telf1 = i_lfa1-telf1.
    ls_vendor-adrnr = i_lfa1-adrnr.

    " Map all bank fields including IBAN, SWIFT, and account holder
    IF i_lfbk IS NOT INITIAL.
      ls_bank-lifnr = i_lfbk-lifnr.
      ls_bank-banks = i_lfbk-banks.
      ls_bank-bankl = i_lfbk-bankl.
      ls_bank-bankn = i_lfbk-bankn.
      ls_bank-bkont = i_lfbk-bkont.
      ls_bank-iban  = i_lfbk-iban.
      ls_bank-swift = i_lfbk-swift.
      ls_bank-koinh = i_lfbk-koinh.
    ENDIF.

    " Run all active validations
    TRY.
        DATA(lo_screen) = NEW zcl_qubiton_screen(
          iv_apikey = zcl_qubiton_screen=>get_apikey( ) ).

        DATA(lt_results) = lo_screen->validate_vendor_all(
          is_vendor = ls_vendor
          is_bank   = ls_bank ).

        " Block save if any validation issued MESSAGE TYPE 'E'
        LOOP AT lt_results INTO DATA(ls_res) WHERE blocked = abap_true.
          e_check = 'X'.
          EXIT.
        ENDLOOP.

      CATCH zcx_qubiton INTO DATA(lx_err).
        " Validation unavailable — warn and allow save
        MESSAGE w003(zcl_qubiton_msg) WITH lx_err->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD if_ex_vendor_add_data_cs~fill_default_fields.
    " Not used — we only validate, we don't auto-fill
  ENDMETHOD.


  METHOD if_ex_vendor_add_data_cs~modify_screen.
    " Not used — no screen modifications needed
  ENDMETHOD.

ENDCLASS.
