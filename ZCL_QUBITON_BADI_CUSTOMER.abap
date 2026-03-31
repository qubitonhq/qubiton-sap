"! <p class="shorttext synchronized">QubitOn BAdI: Customer Master Validation</p>
"! Implements IF_EX_CUSTOMER_ADD_DATA_CS to validate customer data
"! (tax, bank, address, sanctions) on save in XD01/XD02/FD01/FD02.
"!
"! Activate in SE19 for BAdI CUSTOMER_ADD_DATA_CS.
"! Configuration: table ZQUBITON_SCREEN_CFG controls which validations run.
"!
"! @version 1.2.0
"! @author  QubitOn
CLASS zcl_qubiton_badi_customer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_ex_customer_add_data_cs.

ENDCLASS.


CLASS zcl_qubiton_badi_customer IMPLEMENTATION.

  METHOD if_ex_customer_add_data_cs~check_data_consistency.
    " Called on customer master save.
    " Parameters (from BAdI CUSTOMER_ADD_DATA_CS):
    "   i_kna1  TYPE kna1     — Customer general data
    "   i_knbk  TYPE knbk     — Customer bank detail (single row)
    "   e_check TYPE c        — Set to 'X' to block save

    DATA ls_customer TYPE zcl_qubiton_screen=>ty_customer_data.
    DATA ls_bank     TYPE zcl_qubiton_screen=>ty_customer_bank.

    " Map KNA1 fields
    ls_customer-kunnr = i_kna1-kunnr.
    ls_customer-land1 = i_kna1-land1.
    ls_customer-name1 = i_kna1-name1.
    ls_customer-name2 = i_kna1-name2.
    ls_customer-stras = i_kna1-stras.
    ls_customer-ort01 = i_kna1-ort01.
    ls_customer-regio = i_kna1-regio.
    ls_customer-pstlz = i_kna1-pstlz.
    ls_customer-stceg = i_kna1-stceg.
    ls_customer-stcd1 = i_kna1-stcd1.
    ls_customer-stcd2 = i_kna1-stcd2.
    ls_customer-telf1 = i_kna1-telf1.
    ls_customer-adrnr = i_kna1-adrnr.

    " Read primary email from ADR6 (address-linked SMTP)
    IF i_kna1-adrnr IS NOT INITIAL.
      SELECT SINGLE smtp_addr FROM adr6
        INTO ls_customer-email
        WHERE addrnumber = i_kna1-adrnr
          AND flgdefault = 'X'.
    ENDIF.

    " Map bank fields including IBAN, SWIFT, and account holder
    IF i_knbk IS NOT INITIAL.
      ls_bank-kunnr = i_knbk-kunnr.
      ls_bank-banks = i_knbk-banks.
      ls_bank-bankl = i_knbk-bankl.
      ls_bank-bankn = i_knbk-bankn.
      ls_bank-bkont = i_knbk-bkont.
      ls_bank-iban  = i_knbk-iban.
      ls_bank-swift = i_knbk-swift.
      ls_bank-koinh = i_knbk-koinh.
    ENDIF.

    TRY.
        DATA(lo_screen) = NEW zcl_qubiton_screen(
          iv_apikey = zcl_qubiton_screen=>get_apikey( ) ).

        DATA(lt_results) = lo_screen->validate_customer_all(
          is_customer = ls_customer
          is_bank     = ls_bank ).

        LOOP AT lt_results INTO DATA(ls_res) WHERE blocked = abap_true.
          e_check = 'X'.
          EXIT.
        ENDLOOP.

      CATCH zcx_qubiton INTO DATA(lx_err).
        " Validation unavailable — warn and allow save
        MESSAGE w003(zcl_qubiton_msg) WITH lx_err->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD if_ex_customer_add_data_cs~fill_default_fields.
    " Not used
  ENDMETHOD.


  METHOD if_ex_customer_add_data_cs~modify_screen.
    " Not used
  ENDMETHOD.

ENDCLASS.
