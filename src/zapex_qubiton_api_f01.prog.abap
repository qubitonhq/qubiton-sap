*----------------------------------------------------------------------*
***INCLUDE ZAPEX_QUBITON_API_F01.
*----------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Form read_results
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> LV_JSON
*&---------------------------------------------------------------------*
FORM read_results.
  CLEAR: lv_offset.
  FIND FIRST OCCURRENCE OF '"score":' IN lv_json MATCH OFFSET lv_offset.
  IF sy-subrc IS INITIAL.
    CLEAR: lv_result, lv_name, lv_value.
    lv_result = lv_json+lv_offset(15).
    SPLIT lv_result AT ':' INTO lv_name lv_value.
    REPLACE ALL OCCURRENCES OF ',' IN lv_value WITH space.
    REPLACE ALL OCCURRENCES OF '#' IN lv_value WITH space.
    CONDENSE lv_value NO-GAPS.
    ls_data-score = lv_value.
  ENDIF.
  FIND FIRST OCCURRENCE OF '"validationPass":' IN lv_json MATCH OFFSET lv_offset.
  IF sy-subrc IS INITIAL.
    CLEAR: lv_result, lv_name, lv_value.
    lv_result = lv_json+lv_offset(30).
    SPLIT lv_result AT ':' INTO lv_name lv_value.
    REPLACE ALL OCCURRENCES OF ',' IN lv_value WITH space.
    REPLACE ALL OCCURRENCES OF '"' IN lv_value WITH space.
    CONDENSE lv_value NO-GAPS.
    ls_data-validationPass = lv_value.
  ENDIF.
  FIND FIRST OCCURRENCE OF '"validationDescription":' IN lv_json MATCH OFFSET lv_offset.
  IF sy-subrc IS INITIAL.
    CLEAR: lv_result, lv_name, lv_value.
    lv_result = lv_json+lv_offset(35).
    SPLIT lv_result AT ':' INTO lv_name lv_value.
    REPLACE ALL OCCURRENCES OF ',' IN lv_value WITH space.
    REPLACE ALL OCCURRENCES OF '"' IN lv_value WITH space.
    CONDENSE lv_value NO-GAPS.
    ls_data-Description = lv_value.
  ENDIF.
  IF ls_data-score(1) = '0' or ls_data-score is initial .
    ls_data-icon = icon_led_red.
  ELSEIF ls_data-score(3) = '100'.
    ls_data-icon = icon_led_green.
  ELSE.
    ls_data-icon = icon_led_yellow.
  ENDIF.
*CASE ls_data-score.
*  WHEN '0'.
*    ls_data-icon = icon_led_red.
*  WHEN '100'.
*    ls_data-icon = icon_led_green.
*  WHEN OTHERS.
*    ls_data-icon = icon_led_yellow.
*ENDCASE.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form alv_display
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> GT_DATA
*&---------------------------------------------------------------------*
FORM alv_display  USING    pt_data.
  DATA lo_column TYPE REF TO cl_salv_column_table.
  cl_salv_table=>factory(
    IMPORTING
      r_salv_table   = DATA(go_alv)                          " Basis Class Simple ALV Tables
    CHANGING
      t_table        = pt_data
  ).
  go_alv->get_functions( )->set_all( if_salv_c_bool_sap=>true ).
  DATA(lo_columns) = go_alv->get_columns( ).
  lo_columns->set_optimize( abap_true ).
  DATA(lo_display) = go_alv->get_display_settings( ).
  lo_display->set_striped_pattern( abap_true ).
  TRY.
      lo_column ?= lo_columns->get_column( columnname = 'ICON' ).
      lo_column->set_short_text( 'Status' ).
      lo_column->set_medium_text( 'Status' ).
      lo_column->set_long_text( 'Status' ).
      lo_column->set_icon( if_salv_c_bool_sap=>true ).

      lo_column ?= lo_columns->get_column( columnname = 'SCORE' ).
      lo_column->set_short_text( 'Score' ).
      lo_column->set_medium_text( 'Score' ).
      lo_column->set_long_text( 'Score' ).

      lo_column ?= lo_columns->get_column( columnname = 'VALIDATIONPASS' ).
      lo_column->set_short_text( 'Pass' ).
      lo_column->set_medium_text( 'Pass' ).
      lo_column->set_long_text( 'Pass' ).

      lo_column ?= lo_columns->get_column( columnname = 'DESCRIPTION' ).
      lo_column->set_short_text( 'Desc' ).
      lo_column->set_medium_text( 'Desc' ).
      lo_column->set_long_text( 'Description' ).

      lo_column ?= lo_columns->get_column( columnname = 'PATH' ).
      lo_column->set_short_text( 'Path' ).
      lo_column->set_medium_text( 'File Path' ).
      lo_column->set_long_text( 'File Path' ).
    CATCH cx_salv_msg.

  ENDTRY.

  go_alv->display( ).
ENDFORM.
