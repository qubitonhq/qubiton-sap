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
  " Reset all output fields on every call — without this, score /
  " validationPass / Description from the previous iteration would
  " leak into the current row when the current JSON omits any of them.
  CLEAR ls_data.

  " Parse the top-level response with /ui2/cl_json. A typed probe
  " structure makes the lookup field-name aware — a nested "score"
  " inside a "detail" or "components" object can't shadow the top-
  " level field, which the previous FIND-OFFSET approach could not
  " guarantee.
  DATA: BEGIN OF ls_probe,
          score                 TYPE string,
          validationpass        TYPE string,
          validationdescription TYPE string,
        END OF ls_probe.

  TRY.
      /ui2/cl_json=>deserialize(
        EXPORTING json = lv_json
        CHANGING  data = ls_probe ).
    CATCH cx_root.
      " Malformed or non-JSON response — leave ls_data initial; the
      " caller sees an empty row and the LED below renders red.
  ENDTRY.

  ls_data-score          = ls_probe-score.
  ls_data-validationpass = ls_probe-validationpass.
  ls_data-description    = ls_probe-validationdescription.

  " Right-pad before substring so 1-digit scores (e.g. "0") don't
  " trip CX_SY_RANGE_OUT_OF_BOUNDS on the (3) comparison.
  DATA(lv_score_padded) = ls_data-score.
  IF strlen( lv_score_padded ) < 3.
    lv_score_padded = lv_score_padded && '   '.
  ENDIF.
  IF ls_data-score IS INITIAL OR lv_score_padded(1) = '0'.
    ls_data-icon = icon_led_red.
  ELSEIF lv_score_padded(3) = '100'.
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
