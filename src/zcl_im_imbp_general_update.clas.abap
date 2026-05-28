class ZCL_IM_IMBP_GENERAL_UPDATE definition
  public
  final
  create public .

public section.

  interfaces IF_EX_BUPA_GENERAL_UPDATE .
protected section.
private section.
ENDCLASS.



CLASS ZCL_IM_IMBP_GENERAL_UPDATE IMPLEMENTATION.


  METHOD if_ex_bupa_general_update~change_before_update.
    DATA: lt_but0id   TYPE STANDARD TABLE OF but0id,
          lt_but000   TYPE STANDARD TABLE OF bus000___i,
          lt_taxc     TYPE bup_tt_taxc,
          lt_taxc_old TYPE bup_tt_taxc,
          lt_taxn     TYPE bup_tt_taxn,
          lt_taxn_old TYPE bup_tt_taxn.
    READ TABLE it_changed_instances INTO DATA(ls_changed_instances) INDEX 1.
    IF sy-subrc IS INITIAL.
      CALL FUNCTION 'BUP_BUPA_MEMORY_GET_ALL'
        EXPORTING
          i_xwa    = 'X'
        TABLES
          t_but000 = lt_but000
*         T_BUT000_TD          =
*         T_BUT001 =
*         T_BUT0BK_ALIAS       =
*         T_BUT0BK =
*         T_BUT100 =
*         T_BUT0CC =
*         T_BUT0IS =
          t_but0id = lt_but0id
*         T_PARTNER_EXT        =
*         T_PARTNERROLES       =
*         T_BUTDC  =
        .
      IF lt_but000 IS NOT INITIAL.
        READ TABLE lt_but000 INTO DATA(ls_but000) INDEX 1.
        CALL FUNCTION 'BUPA_MEMORY_TAXC_GET'
          EXPORTING
            iv_partner_guid = ls_changed_instances
          IMPORTING
            et_taxc         = lt_taxc
            et_taxc_old     = lt_taxc_old
*           EV_FOUND        =
          .
        CALL FUNCTION 'BUPA_MEMORY_TAX_GET'
          EXPORTING
            iv_partner  = ls_but000-partner
          IMPORTING
            et_taxn     = lt_taxn
            et_taxn_old = lt_taxn_old
*           EV_FOUND    =
          .

      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
