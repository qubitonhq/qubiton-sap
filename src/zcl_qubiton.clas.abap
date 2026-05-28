class ZCL_QUBITON definition
  public
  final
  create public .

public section.

  types:
    tr_partner TYPE RANGE OF partner .
  types:
    BEGIN OF ty_adrc,
        partner    TYPE partner,
        addrnumber TYPE adrc-addrnumber,
        name1      TYPE adrc-name1,
        name2      TYPE adrc-name1,
        name3      TYPE adrc-name1,
        name4      TYPE adrc-name1,
        city1      TYPE adrc-city1,
        post_code1 TYPE adrc-post_code1,
        street     TYPE adrc-street,
        str_suppl1 TYPE adrc-str_suppl1,
        str_suppl2 TYPE adrc-str_suppl1,
        str_suppl3 TYPE adrc-str_suppl1,
        location   TYPE ad_lctn,
        country    TYPE adrc-country,
        langu      TYPE adrc-langu,
        region     TYPE adrc-region,
        addr_group TYPE adrc-addr_group,
        fax_number TYPE adrc-fax_number,
        tel_number TYPE adrc-tel_number,
        po_box     TYPE adrc-po_box,
        po_box_loc TYPE adrc-po_box_loc,
        post_code2 TYPE adrc-post_code2,
        po_box_reg TYPE adrc-po_box_reg,
        sort1      TYPE adrc-sort1,
      END OF ty_adrc .
  types:
    tty_adrc TYPE TABLE OF ty_adrc .
  types:
    BEGIN OF ty_bank,
        partner TYPE partner,
        banks   TYPE  but0bk-banks,
        bankl   TYPE  but0bk-bankl,
        banka   TYPE  bnka-banka,
        iban    TYPE  but0bk-iban,
        koinh   TYPE  but0bk-koinh,
        bankn   TYPE  but0bk-bankn,
        swift   TYPE bnka-swift,
        taxtype TYPE dfkkbptaxnum-taxtype,
        taxnum  TYPE dfkkbptaxnum-taxnum,
      END OF ty_bank .
  types:
    tty_bank TYPE TABLE OF ty_bank .
  types:
    BEGIN OF ty_tax,
        partner   TYPE partner,
        taxtype   TYPE dfkkbptaxnum-taxtype,
        taxnum    TYPE dfkkbptaxnum-taxnum,
        country   TYPE adrc-country,
        name_org1 TYPE but000-name_org1,
        name_org2 TYPE but000-name_org2,
      END OF ty_tax .
  types:
    tty_tax TYPE TABLE OF ty_tax .
  types:
    BEGIN OF ty_name_value,
        name  TYPE string,
        value TYPE string,
        type  TYPE char1,  " S=string (default), N=number, B=boolean
      END OF ty_name_value .
  types:
    tt_name_value TYPE STANDARD TABLE OF ty_name_value WITH EMPTY KEY .
  types:
      "! Parsed API result — use instead of raw JSON when you want built-in message handling
    BEGIN OF ty_result,
        success       TYPE abap_bool,  " API call succeeded (HTTP 2xx)
        is_valid      TYPE abap_bool,  " Validation passed (isValid/found/hasMatches from response)
        field_missing TYPE abap_bool,  " True when the expected validity field is absent from response
        message       TYPE string,     " Human-readable message for UI display
        raw_json      TYPE string,     " Full JSON response for further processing
      END OF ty_result .
  types:
    tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY .

  class-data MV_TIMEOUT type I .
  class-data MV_APIKEY type STRING value '<APIKEY>' ##NO_TEXT.
    " ── JSON Field Type Constants ───────────────────────────────────────────
  constants GC_TYPE_STRING type CHAR1 value 'S' ##NO_TEXT.       " Default — JSON string (quoted)
  constants GC_TYPE_NUMBER type CHAR1 value 'N' ##NO_TEXT.       " JSON number (unquoted)
  constants GC_TYPE_BOOLEAN type CHAR1 value 'B' ##NO_TEXT.       " JSON boolean (unquoted true/false)
    " ── Error Handling Mode Constants ───────────────────────────────────────
  constants GC_ON_ERROR_STOP type CHAR1 value 'E' ##NO_TEXT.       " Hard stop — raise exception (block save)
  constants GC_ON_ERROR_WARN type CHAR1 value 'W' ##NO_TEXT.       " Soft warning — show message, let user proceed
  constants GC_ON_ERROR_SILENT type CHAR1 value 'S' ##NO_TEXT.       " Silent — log only, no user message
    " ── Validation Failure Mode Constants ───────────────────────────────────
  constants GC_ON_INVALID_STOP type CHAR1 value 'E' ##NO_TEXT.       " Block save when validation returns isValid=false
  constants GC_ON_INVALID_WARN type CHAR1 value 'W' ##NO_TEXT.       " Warn but allow save
  constants GC_ON_INVALID_SILENT type CHAR1 value 'S' ##NO_TEXT.       " Silent — caller checks result
    " ── Message Class Constants (SE91: ZCL_QUBITON_MSG) ───────────────────
  constants GC_MSGID type SYMSGID value 'ZCL_QUBITON_MSG' ##NO_TEXT.       " Message class for translatable messages
    " ── BAL Log Object Constants (SLG0: ZQUBITON) ─────────────────────────
  constants GC_BAL_OBJECT type BALOBJ_D value 'ZQUBITON' ##NO_TEXT.
  constants GC_BAL_SUBOBJECT type BALSUBOBJ value 'ZAPI_CALL' ##NO_TEXT.
  class-data MV_DESTINATION type STRING value 'QUBITON' ##NO_TEXT.
*    DATA mv_apikey       TYPE string.
  class-data MV_ON_ERROR type CHAR1 .
  class-data MV_ON_INVALID type CHAR1 .
  class-data MV_CHECK_AUTH type ABAP_BOOL .
  class-data MV_LOG_ENABLED type ABAP_BOOL .
  class-data MV_KEEP_ALIVE type ABAP_BOOL .
*    DATA mv_timeout      TYPE i.
  class-data MV_LOG_HANDLE type BALLOGHNDL .
  class-data MO_CLIENT type ref to IF_HTTP_CLIENT .
  class-data MT_ADRC type TTY_ADRC .
  class-data MV_JSON type STRING .
  class-data MV_CODE type I .
  class-data MV_REASON type STRING .
  class-data MT_BANK type TTY_BANK .
  class-data MT_TAX type TTY_TAX .

  methods CONSTRUCTOR
    importing
      !IV_APIKEY type STRING optional
      !IV_TIMEOUT type I default 30
      !IV_LOG_ENABLED type ABAP_BOOL default 'X' .
  class-methods VALIDATE_ADDRESS
    importing
      !IV_COUNTRY type STRING
      !IV_ADDRESS_LINE1 type STRING optional
      !IV_ADDRESS_LINE2 type STRING optional
      !IV_CITY type STRING optional
      !IV_STATE type STRING optional
      !IV_POSTAL_CODE type STRING optional
      !IV_COMPANY_NAME type STRING optional
    returning
      value(RV_JSON) type STRING
    raising
      CX_ROOT .
  class-methods POST
    importing
      !IV_PATH type STRING default '/api/address/validate?apikey=<APIKEY>'
      !IV_BODY type STRING
    returning
      value(RV_JSON) type STRING .
  class-methods BUILD_ADDRESS_BODY
    importing
      !IV_COUNTRY type STRING
      !IV_ADDRESS_LINE1 type STRING optional
      !IV_ADDRESS_LINE2 type STRING optional
      !IV_CITY type STRING optional
      !IV_STATE type STRING optional
      !IV_POSTAL_CODE type STRING optional
      !IV_COMPANY_NAME type STRING optional
    returning
      value(RV_JSON) type STRING .
  class-methods BUILD_JSON
    importing
      !IT_FIELDS type TT_NAME_VALUE
    returning
      value(RV_JSON) type STRING .
  class-methods ESCAPE_JSON_VALUE
    importing
      !IV_VALUE type STRING
    returning
      value(RV_ESCAPED) type STRING .
  class-methods SEND_REQUEST
    importing
      !IV_PATH type STRING
      !IV_METHOD type STRING
      !IV_BODY type STRING optional
    returning
      value(RV_JSON) type STRING .
  class-methods LOG_API_CALL
    importing
      !IV_METHOD type STRING
      !IV_PATH type STRING
      !IV_STATUS type I
      !IV_ELAPSED type I
      !IV_MSGTYPE type SYMSGTY default 'I' .
  class-methods SAVE_LOG .
  class-methods GET_BP_ADDRESS
    importing
      !IR_PARTNER type TR_PARTNER .
  class-methods APPLICATION_LOG
    importing
      !IV_JSON type STRING
      !IV_PARTNER type PARTNER
    returning
      value(RV_PATH) type STRING .
  class-methods VALIDATE_BANK_PRO
    importing
      !IV_BUSINESS_ENTITY_TYPE type STRING optional
      !IV_COUNTRY type STRING
      !IV_BANK_ACCOUNT_HOLDER type STRING
      !IV_ACCOUNT_NUMBER type STRING optional
      !IV_BANK_CODE type STRING optional
      !IV_IBAN type STRING optional
      !IV_SWIFT_CODE type STRING optional
      !IV_TAXIDNUMBER type STRING
    returning
      value(RV_JSON) type STRING .
  class-methods BUILD_BANK_PRO_BODY
    importing
      !IV_BUSINESS_ENTITY_TYPE type STRING
      !IV_COUNTRY type STRING
      !IV_BANK_ACCOUNT_HOLDER type STRING
      !IV_ACCOUNT_NUMBER type STRING optional
      !IV_BANK_CODE type STRING optional
      !IV_IBAN type STRING optional
      !IV_SWIFT_CODE type STRING optional
      !IV_TAXIDNUMBER type STRING
    returning
      value(RV_JSON) type STRING .
  class-methods GET_BANK_DETAILS
    importing
      !IR_PARTNER type TR_PARTNER .
  class-methods VALIDATE_TAX
    importing
      !IV_TAX_NUMBER type STRING
      !IV_TAX_TYPE type STRING
      !IV_COUNTRY type STRING
      !IV_COMPANY_NAME type STRING
      !IV_BUSINESS_ENTITY_TYPE type STRING optional
      !IV_ENTITY_NAME type STRING
    returning
      value(RV_JSON) type STRING .
  class-methods BUILD_TAX_BODY
    importing
      !IV_TAX_NUMBER type STRING
      !IV_TAX_TYPE type STRING
      !IV_COUNTRY type STRING
      !IV_COMPANY_NAME type STRING
      !IV_BUSINESS_ENTITY_TYPE type STRING optional
      !IV_ENTITY_NAME type STRING optional
    returning
      value(RV_JSON) type STRING .
  class-methods OPEN_LOG .
  class-methods GET_TAX_DETAILS
    importing
      !IR_PARTNER type TR_PARTNER .
protected section.
private section.
ENDCLASS.



CLASS ZCL_QUBITON IMPLEMENTATION.


  METHOD application_log.
    DATA: ls_str_log    TYPE bal_s_log,
          lv_timestamp  TYPE tzntstmps,
          lv_timezone   TYPE timezone VALUE 'UTC+8',
          lv_log_handle TYPE balloghndl,
          lv_message type char255,
          lv_msgtyp     TYPE symsgty.
    CONVERT DATE sy-datum TIME sy-uzeit INTO TIME STAMP lv_timestamp TIME ZONE lv_timezone.
    DATA(lv_externalid) = |{ lv_timestamp }| && |{ iv_partner }|.
    ls_str_log-extnumber = lv_externalid.
    CONDENSE ls_str_log-extnumber.
    ls_str_log-object = 'ZQUBITON'.
    ls_str_log-subobject = 'ZQUBITON_ADDR'.
    ls_str_log-aldate_del = sy-datum + 5.
    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log                 = ls_str_log
      IMPORTING
        e_log_handle            = lv_log_handle
      EXCEPTIONS
        log_header_inconsistent = 1
        OTHERS                  = 2.
    IF sy-subrc = 0.
       DATA(lv_msg) = |{ mv_code }| && |{ mv_reason }| &&  |{ iv_partner }|.
      IF mv_code < 200 OR mv_code  >= 300.
        lv_msgtyp = 'S'.
      ELSE.
        lv_msgtyp = 'E'.
      ENDIF.
      lv_message = lv_msg.
      CALL FUNCTION 'BAL_LOG_MSG_ADD_FREE_TEXT'
        EXPORTING
*         I_LOG_HANDLE  =
          i_msgty       = lv_msgtyp
          i_text        = lv_message
        EXCEPTIONS
          log_not_found = 0
          OTHERS        = 1.
      IF sy-subrc = 0.
        CALL FUNCTION 'BAL_DB_SAVE'
          EXPORTING
            i_save_all       = abap_true
          EXCEPTIONS
            log_not_found    = 1
            save_not_allowed = 2
            numbering_error  = 3
            OTHERS           = 4.
      ENDIF.

    ENDIF.
    IF zcl_qubiton=>mv_json IS NOT INITIAL.
      DATA(lv_ap_server_path) = |/usr/sap/trans/Apex/| && |{ lv_externalid }| && |.txt|.
      OPEN DATASET lv_ap_server_path FOR OUTPUT IN TEXT MODE
                        ENCODING DEFAULT
                        IGNORING CONVERSION ERRORS MESSAGE lv_msg.
      IF sy-subrc IS INITIAL.
        TRANSFER zcl_qubiton=>mv_json TO lv_ap_server_path.
        rv_path = lv_ap_server_path.
      ENDIF.
      CLOSE DATASET lv_ap_server_path.
    ENDIF.
  ENDMETHOD.


  METHOD build_address_body.

    rv_json = build_json( VALUE #(
      ( name = 'country'      value = iv_country )
      ( name = 'addressLine1' value = iv_address_line1 )
      ( name = 'addressLine2' value = iv_address_line2 )
      ( name = 'city'         value = iv_city )
      ( name = 'state'        value = iv_state )
      ( name = 'postalCode'   value = iv_postal_code )
      ( name = 'companyName'  value = iv_company_name )
      ( name = 'RequestedByClient'  value = sy-uname ) ) ).

  ENDMETHOD.


  METHOD build_bank_pro_body.
    rv_json = build_json( VALUE #(
  ( name = 'businessEntityType' value = iv_business_entity_type )
  ( name = 'country'            value = iv_country )
  ( name = 'bankAccountHolder'  value = iv_bank_account_holder )
  ( name = 'accountNumber'      value = iv_account_number )
  ( name = 'bankCode'           value = iv_bank_code )
  ( name = 'iban'               value = iv_iban )
  ( name = 'swiftCode'          value = iv_swift_code )
  ( name = 'TaxIdNumber'          value = iv_taxidnumber ) "TaxIdNumber
   ( name = 'RequestedByClient'  value = sy-uname ) ) ).
  ENDMETHOD.


  method BUILD_JSON.

  " Builds a flat JSON object from name/value pairs, skipping blank values.
    " Supports typed values: S=string (quoted), N=number (unquoted), B=boolean (unquoted).
    DATA lv_sep TYPE string.

    rv_json = `{`.
    lv_sep  = ``.

    LOOP AT it_fields INTO DATA(ls_field).
      IF ls_field-value IS NOT INITIAL.
        rv_json = rv_json && lv_sep && `"` && ls_field-name && `":`.

        CASE ls_field-type.
          WHEN gc_type_number.
            " Numeric value — no quotes; validate to prevent JSON injection
            DATA(lv_num) = ls_field-value.
            CONDENSE lv_num.
            " Strip leading/trailing whitespace and verify it looks numeric
            IF lv_num CO '0123456789.-+eE'.
              rv_json = rv_json && lv_num.
            ELSE.
              " Non-numeric value — emit as quoted string to prevent malformed JSON
              rv_json = rv_json && `"` && escape_json_value( ls_field-value ) && `"`.
            ENDIF.
          WHEN gc_type_boolean.
            " Boolean — emit true/false without quotes
            IF ls_field-value = 'true' OR ls_field-value = 'X' OR ls_field-value = '1'.
              rv_json = rv_json && `true`.
            ELSE.
              rv_json = rv_json && `false`.
            ENDIF.
          WHEN OTHERS.
            " String — escape quotes, backslashes, and control characters
            rv_json = rv_json && `"` && escape_json_value( ls_field-value ) && `"`.
        ENDCASE.

        lv_sep = `,`.
      ENDIF.
    ENDLOOP.

    rv_json = rv_json && `}`.

  endmethod.


  METHOD build_tax_body.
    rv_json = build_json( VALUE #(
      ( name = 'identityNumber'     value = iv_tax_number )
      ( name = 'identityNumberType' value = iv_tax_type )
      ( name = 'country'            value = iv_country )
      ( name = 'companyName'        value = iv_company_name )
      ( name = 'businessEntityType' value = iv_business_entity_type )
      ( name = 'entityName'         value = iv_entity_name )
      ( name = 'RequestedByClient'  value = sy-uname ) ) ).
  ENDMETHOD.


  METHOD constructor.

*    mv_destination  = iv_destination.
    mv_apikey       = iv_apikey.
*    mv_on_error     = iv_on_error.
*    mv_on_invalid   = iv_on_invalid.
*    mv_check_auth   = iv_check_auth.
    mv_log_enabled  = iv_log_enabled.
*    mv_keep_alive   = iv_keep_alive.
    mv_timeout      = iv_timeout.

    " S_RFC authorization check (optional — required for SAP certification)
*    IF mv_check_auth = abap_true.
*      check_authority( ).
*    ENDIF.

*    " Open BAL application log session
    IF mv_log_enabled = abap_true.
      open_log( ).
    ENDIF.

  ENDMETHOD.


  METHOD escape_json_value.

    " Escape a string for safe embedding in a JSON value.
    " Handles: backslash, double quote, and all control characters per RFC 8259.
    DATA lv_cr    TYPE c LENGTH 1.
    DATA lv_char  TYPE c LENGTH 1.
    DATA lv_code  TYPE i.
    DATA lv_len   TYPE i.
    DATA lv_idx   TYPE i.
    DATA lv_out   TYPE string.

    rv_escaped = iv_value.
    " Backslash first (before introducing new backslashes)
    rv_escaped = replace( val = rv_escaped sub = `\` with = `\\` occ = 0 ).
    " Double quote
    rv_escaped = replace( val = rv_escaped sub = `"` with = `\"` occ = 0 ).
    " Control characters — CR+LF must be replaced before standalone LF and CR
    rv_escaped = replace( val = rv_escaped sub = cl_abap_char_utilities=>cr_lf   with = `\r\n` occ = 0 ).
    rv_escaped = replace( val = rv_escaped sub = cl_abap_char_utilities=>newline with = `\n`   occ = 0 ).
    lv_cr = cl_abap_char_utilities=>cr_lf(1). " Extract standalone CR character
    rv_escaped = replace( val = rv_escaped sub = lv_cr with = `\r` occ = 0 ).
    rv_escaped = replace( val = rv_escaped sub = cl_abap_char_utilities=>horizontal_tab with = `\t` occ = 0 ).

    " Escape remaining control characters U+0000-U+001F as \uXXXX (RFC 8259)
    lv_len = strlen( rv_escaped ).
    lv_idx = 0.
    CLEAR lv_out.
    WHILE lv_idx < lv_len.
      lv_char = rv_escaped+lv_idx(1).
      lv_code = cl_abap_conv_out_ce=>uccpi( lv_char ).
      IF lv_code >= 0 AND lv_code <= 31.
        " Already handled: \n (10), \r (13), \t (9) — but those are already replaced above
        " This catches null (0), backspace (8), form feed (12), and other rare control chars
        " Convert code point to hex via arithmetic (safe across all ABAP releases)
        CONSTANTS lc_hex TYPE string VALUE `0123456789abcdef`.
        DATA(lv_hi) = lv_code DIV 16.
        DATA(lv_lo) = lv_code MOD 16.
        lv_out = lv_out && `\u00` && lc_hex+lv_hi(1) && lc_hex+lv_lo(1).
      ELSE.
*        lv_out = |{ lv_out }{ lv_char }| RESPECTING BLANKS.."lv_out && lv_char.
        CONCATENATE lv_out lv_char INTO lv_out RESPECTING BLANKS.
      ENDIF.
      lv_idx = lv_idx + 1.
    ENDWHILE.
    rv_escaped = lv_out.
  ENDMETHOD.


  METHOD get_bank_details.
    SELECT
      b~partner,
     bk~banks,
     bk~bankl,
     bn~banka,
     bk~iban,
     bk~koinh,
     bk~bankn,
     bn~swift,
      t~taxtype,
      t~taxnum
     FROM but000 AS b
     INNER JOIN dfkkbptaxnum AS t ON b~partner = t~partner
     INNER JOIN but0bk AS bk ON b~partner = bk~partner
     LEFT JOIN bnka AS bn ON bk~banks = bn~banks AND bk~bankl = bn~bankl
     INTO TABLE @mt_bank
     WHERE b~partner IN @ir_partner.
  ENDMETHOD.


  method GET_BP_ADDRESS.
      SELECT a~partner,
         bpkind,
         bu_group,
         bu_sort1,
         bu_sort2,
         name_org1,
         name_org2,
         name_org3,
         name_org4,
         crusr,
         crdat,
         addrcomm,
         natpers,
         addrnumber
    FROM but000 AS a
        INNER JOIN but020 AS b
                ON a~partner EQ b~partner
        INTO TABLE @DATA(gt_but000)
             WHERE a~partner IN @ir_partner.
  IF sy-subrc IS INITIAL.
    SELECT b~partner,
           a~addrnumber,                           "#EC CI_NO_TRANSFORM
           name1,
           name2,
           name3,
           name4,
           city1,
           post_code1,
           street,
           str_suppl1,
           str_suppl2,
           str_suppl3,
           location,
           country,
           langu,
           region,
           addr_group,
           fax_number,
           tel_number,
           po_box,
           po_box_loc,
           post_code2,
           po_box_reg,
           sort1
      FROM adrc AS a
        INNER JOIN @gt_but000 AS b
                ON a~addrnumber = b~addrnumber
        INTO TABLE @mt_adrc.
  ENDIF.

  endmethod.


  METHOD get_tax_details.
    SELECT a~partner,
             bpkind,
             bu_group,
             bu_sort1,
             bu_sort2,
             name_org1,
             name_org2,
             name_org3,
             name_org4,
             crusr,
             crdat,
             addrcomm,
             natpers,
             b~addrnumber,
             name1,
             country
        FROM but000 AS a
  INNER JOIN but020 AS b
          ON a~partner EQ b~partner
  INNER JOIN adrc AS c ON b~addrnumber EQ c~addrnumber
  INTO TABLE @DATA(gt_but000)
       WHERE a~partner IN @ir_partner.
*---Read tax details
    SELECT
          a~partner,
            taxtype,
            taxnum,
            country,
          b~name_org1,
          b~name_org2
       FROM dfkkbptaxnum AS a
 INNER JOIN @gt_but000 AS b
         ON a~partner EQ b~partner
 INTO TABLE @mt_tax.


  ENDMETHOD.


  method LOG_API_CALL.
   DATA: ls_msg TYPE bal_s_msg.

    IF mv_log_enabled = abap_false OR mv_log_handle IS INITIAL.
      RETURN.
    ENDIF.

    ls_msg-msgty = iv_msgtype.
    ls_msg-msgid = gc_msgid.
    ls_msg-msgno = '010'.            " &1 &2 completed in &3 ms (HTTP &4)
    ls_msg-msgv1 = iv_method.
    ls_msg-msgv2 = iv_path.
    ls_msg-msgv3 = |{ iv_elapsed }|.
    ls_msg-msgv4 = |{ iv_status }|.

    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        i_log_handle = mv_log_handle
        i_s_msg      = ls_msg
      EXCEPTIONS
        OTHERS       = 1.

    " Non-fatal if logging fails — ignore errors
  endmethod.


  method OPEN_LOG.
    DATA: ls_log TYPE bal_s_log.

    IF mv_log_enabled = abap_false.
      RETURN.
      ENDIF.

    ls_log-object    = gc_bal_object.
    ls_log-subobject = gc_bal_subobject.
    ls_log-aluser    = sy-uname.
    ls_log-alprog    = sy-repid.
    ls_log-extnumber = |QubitOn API { sy-datum } { sy-uzeit }|.

    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING
        i_s_log      = ls_log
      IMPORTING
        e_log_handle = mv_log_handle
      EXCEPTIONS
        OTHERS       = 1.

    IF sy-subrc <> 0.
      " Logging failure is non-fatal — clear handle, calls will skip logging
      CLEAR mv_log_handle.
    ENDIF.
  endmethod.


  method POST.
    rv_json = send_request( iv_path   = iv_path
                            iv_method = 'POST'
                            iv_body   = iv_body ).

  endmethod.


  METHOD save_log.
    DATA: lt_handles TYPE bal_t_logh.

    IF mv_log_enabled = abap_false OR mv_log_handle IS INITIAL.
      RETURN.
    ENDIF.

    APPEND mv_log_handle TO lt_handles.

    CALL FUNCTION 'BAL_DB_SAVE'
      EXPORTING
        i_t_log_handle = lt_handles
      EXCEPTIONS
        OTHERS         = 1.

    " Non-fatal if save fails
  ENDMETHOD.


  METHOD send_request.

    DATA: lo_client  TYPE REF TO if_http_client,
          lv_status  TYPE i,
          lv_reason  TYPE string,
          lv_start   TYPE i,
          lv_end     TYPE i,
          lv_elapsed TYPE i.

    " Capture start time for BAL logging
    GET RUN TIME FIELD lv_start.

    " Create or reuse HTTP client
    IF mv_keep_alive = abap_true AND mo_client IS BOUND.
      lo_client = mo_client.
      " Clear previous request body to prevent stale POST data on subsequent GET calls
      lo_client->request->set_cdata( '' ).
    ELSE.
      " Create HTTP client from RFC destination
      cl_http_client=>create_by_destination(
        EXPORTING
          destination              = CONV rfcdest( mv_destination )
        IMPORTING
          client                   = lo_client
        EXCEPTIONS
          argument_not_found       = 1
          destination_not_found    = 2
          destination_no_authority = 3
          plugin_not_active        = 4
          internal_error           = 5
          OTHERS                   = 6 ).

      IF sy-subrc <> 0 OR lo_client IS NOT BOUND.
        log_api_call( iv_method = iv_method iv_path = iv_path iv_status = 0 iv_elapsed = 0 iv_msgtype = 'E' ).
        save_log( ).
*        RAISE EXCEPTION TYPE zcx_qubiton
*          EXPORTING
*            error_text = |Failed to create HTTP client for destination "{ mv_destination }" (sy-subrc={ sy-subrc })|.
      ENDIF.

      IF mv_keep_alive = abap_true.
        mo_client = lo_client.
      ENDIF.
    ENDIF.

    " Set URI path
    cl_http_utility=>set_request_uri(
      request = lo_client->request
      uri     = iv_path ).

    " Set HTTP method
    CASE iv_method.
      WHEN 'GET'.
        lo_client->request->set_method( if_http_request=>co_request_method_get ).
      WHEN OTHERS.
        lo_client->request->set_method( if_http_request=>co_request_method_post ).
    ENDCASE.

    " Headers
    lo_client->request->set_header_field(
      name  = 'Content-Type'
      value = 'application/json' ).

    lo_client->request->set_header_field(
      name  = 'Accept'
      value = 'application/json' ).

    " API key header (explicit key overrides destination-level header)
    IF mv_apikey IS NOT INITIAL.
      lo_client->request->set_header_field(
        name  = 'apikey'
        value = mv_apikey ).
    ENDIF.

    " Request body (POST only)
    IF iv_body IS NOT INITIAL.
      lo_client->request->set_cdata( iv_body ).
    ENDIF.

    " Send (with timeout to prevent freezing dialog work processes)
    lo_client->send(
      EXPORTING
        timeout                    = mv_timeout
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).

    IF sy-subrc <> 0.
      DATA(lv_subrc_send) = sy-subrc.
      lo_client->close( ).
      CLEAR mo_client.
      GET RUN TIME FIELD lv_end.
      lv_elapsed = ( lv_end - lv_start ) / 1000. " microseconds → milliseconds
      log_api_call( iv_method = iv_method iv_path = iv_path iv_status = 0 iv_elapsed = lv_elapsed iv_msgtype = 'E' ).
      save_log( ).
*      RAISE EXCEPTION TYPE zcx_qubiton
*        EXPORTING
*          error_text = |{ iv_method } { iv_path }: send failed (sy-subrc={ lv_subrc_send })|.
    ENDIF.

    " Receive (with timeout)
    lo_client->receive(
*      EXPORTING
*        timeout                    = mv_timeout
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4 ).

    IF sy-subrc <> 0.
      DATA(lv_subrc_recv) = sy-subrc.
      lo_client->close( ).
      CLEAR mo_client.
      GET RUN TIME FIELD lv_end.
      lv_elapsed = ( lv_end - lv_start ) / 1000.
      log_api_call( iv_method = iv_method iv_path = iv_path iv_status = 0 iv_elapsed = lv_elapsed iv_msgtype = 'E' ).
      save_log( ).
*      RAISE EXCEPTION TYPE zcx_qubiton
*        EXPORTING
*          error_text = |{ iv_method } { iv_path }: receive failed (sy-subrc={ lv_subrc_recv })|.
    ENDIF.

    " Check HTTP status
    lo_client->response->get_status(
      IMPORTING
        code   = lv_status
        reason = lv_reason ).
    mv_code = lv_status.
    mv_reason = lv_reason.
    rv_json = lo_client->response->get_cdata( ).

    " Close connection unless keep-alive is enabled
    IF mv_keep_alive = abap_false.
      lo_client->close( ).
    ENDIF.

    " Capture elapsed time
    GET RUN TIME FIELD lv_end.
    lv_elapsed = ( lv_end - lv_start ) / 1000. " microseconds → milliseconds

    IF lv_status < 200 OR lv_status >= 300.
      log_api_call( iv_method = iv_method iv_path = iv_path iv_status = lv_status iv_elapsed = lv_elapsed iv_msgtype = 'E' ).
      save_log( ).
*      RAISE EXCEPTION TYPE zcx_qubiton
*        EXPORTING
*          http_status = lv_status
*          error_text  = |{ iv_method } { iv_path }: HTTP { lv_status } { lv_reason }|.
    ENDIF.

    " Success — log informational
    log_api_call( iv_method = iv_method iv_path = iv_path iv_status = lv_status iv_elapsed = lv_elapsed iv_msgtype = 'I' ).

    " Persist log entries after each call (ensures SLG1 visibility)
    save_log( ).

  ENDMETHOD.


  METHOD validate_address.

    rv_json = post( iv_path = '/api/address/validate?apikey=<APIKEY>'
                    iv_body = build_address_body(
                      iv_country       = iv_country
                      iv_address_line1 = iv_address_line1
                      iv_address_line2 = iv_address_line2
                      iv_city          = iv_city
                      iv_state         = iv_state
                      iv_postal_code   = iv_postal_code
                      iv_company_name  = iv_company_name ) ).
    mv_json = rv_json.
  ENDMETHOD.


  method VALIDATE_BANK_PRO.

    rv_json = post( iv_path = '/api/bankaccount/pro/validate'
                    iv_body = build_bank_pro_body(
                      iv_business_entity_type = iv_business_entity_type
                      iv_country              = iv_country
                      iv_bank_account_holder  = iv_bank_account_holder
                      iv_account_number       = iv_account_number
                      iv_bank_code            = iv_bank_code
                      iv_iban                 = iv_iban
                      iv_swift_code           = iv_swift_code
                      iv_taxidnumber          = iv_taxidnumber ) ).
mv_json = rv_json.
  endmethod.


  method VALIDATE_TAX.
    rv_json = post( iv_path = '/api/tax/validate'
                    iv_body = build_tax_body(
                      iv_tax_number          = iv_tax_number
                      iv_tax_type            = iv_tax_type
                      iv_country             = iv_country
                      iv_company_name        = iv_company_name
                      iv_business_entity_type = iv_business_entity_type
                      iv_entity_name = iv_entity_name ) ).
    mv_json = rv_json.
  endmethod.
ENDCLASS.
