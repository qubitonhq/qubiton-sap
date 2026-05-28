class ZCL_IM_APEX_ADDR_CHECK definition
  public
  final
  create public .

public section.

  interfaces IF_EX_BUPA_ADDR_CHECK .
protected section.
private section.
ENDCLASS.



CLASS ZCL_IM_APEX_ADDR_CHECK IMPLEMENTATION.


  METHOD if_ex_bupa_addr_check~check.
    DATA:
      iv_country       TYPE string,
      iv_address_line1 TYPE string,
      iv_address_line2 TYPE string,
      iv_city          TYPE string,
      iv_state         TYPE string,
      iv_postal_code   TYPE string,
      iv_company_name  TYPE string,
      ls_return        TYPE bapiret2,
      lv_score_found   TYPE abap_bool,
      lv_score         TYPE i,
      lv_json          TYPE string.

    iv_country        = is_address-country.
    iv_address_line1  = is_address-street.
    iv_address_line2  = is_address-str_suppl1.
    iv_city           = is_address-city.
    iv_state          = is_address-region.
    iv_postal_code    = is_address-postl_cod1.
    iv_company_name   = is_but000-name_org1.

    IF is_address IS INITIAL.
      RETURN.
    ENDIF.

    zcl_qubiton=>validate_address(
      EXPORTING
        iv_country       = iv_country
        iv_address_line1 = iv_address_line1
        iv_address_line2 = iv_address_line2
        iv_city          = iv_city
        iv_state         = iv_state
        iv_postal_code   = iv_postal_code
        iv_company_name  = iv_company_name
      RECEIVING
        rv_json          = lv_json
    ).

    zcl_qubiton=>extract_score_from_json(
      EXPORTING iv_json  = lv_json
      IMPORTING ev_found = lv_score_found
                ev_score = lv_score
    ).

    ls_return-id = 'ZQUBITON'.
    IF lv_score_found = abap_false.
      " API returned no top-level "score" field (network failure, auth
      " failure, or unexpected JSON shape). Fail closed so the BP save
      " is blocked rather than silently accepting unverified data — the
      " full request / response is in SLG1 / ZQUBITON for triage.
      ls_return-number = '007'.
      ls_return-type   = 'E'.
    ELSEIF lv_score = 100.
      ls_return-number = '002'.
      ls_return-type   = 'S'.
    ELSE.
      ls_return-number = '001'.
      ls_return-type   = 'E'.
    ENDIF.
    APPEND ls_return TO et_return.
  ENDMETHOD.
ENDCLASS.
