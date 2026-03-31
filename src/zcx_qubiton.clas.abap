"! <p class="shorttext synchronized">QubitOn API Exception</p>
"! Exception raised when the QubitOn API call fails.
CLASS zcx_qubiton DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_t100_message.

    DATA http_status TYPE i READ-ONLY.
    DATA error_text  TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        textid      LIKE if_t100_message=>t100key OPTIONAL
        previous    TYPE REF TO cx_root OPTIONAL
        http_status TYPE i DEFAULT 0
        error_text  TYPE string OPTIONAL.

    METHODS get_text REDEFINITION.

ENDCLASS.


CLASS zcx_qubiton IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    me->http_status = http_status.
    me->error_text  = error_text.
    IF textid IS SUPPLIED.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

  METHOD get_text.
    IF error_text IS NOT INITIAL.
      result = error_text.
    ELSE.
      result = |QubitOn API error (HTTP { http_status })|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
