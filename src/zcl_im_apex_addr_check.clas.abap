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
    DATA :
      iv_country       TYPE string,
      iv_address_line1 TYPE string,
      iv_address_line2 TYPE string,
      iv_city          TYPE string,
      iv_state         TYPE string,
      iv_postal_code   TYPE string,
      iv_company_name  TYPE string,
      lv_offset        TYPE i,
      lv_name          TYPE c LENGTH 20,
      lv_value         TYPE c LENGTH 20,
      lv_result        TYPE c LENGTH 40,
      ls_return        TYPE bapiret2.

    iv_country        = is_address-country.
    iv_address_line1  = is_address-street.
    iv_address_line2  = is_address-str_suppl1.
    iv_city           = is_address-city.
    iv_state          = is_address-region.
    iv_postal_code    = is_address-postl_cod1.
    iv_company_name   = is_but000-name_org1.

    IF NOT is_address IS INITIAL.
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
          rv_json          = DATA(lv_json)
      ).

      CLEAR: lv_offset.
      FIND FIRST OCCURRENCE OF '"score":' IN lv_json MATCH OFFSET lv_offset.
      IF sy-subrc IS INITIAL.
        CLEAR: lv_result, lv_name, lv_value.
        lv_result = lv_json+lv_offset(15).
        SPLIT lv_result AT ':' INTO lv_name lv_value.
        REPLACE ALL OCCURRENCES OF ',' IN lv_value WITH space.
        REPLACE ALL OCCURRENCES OF '#' IN lv_value WITH space.
        CONDENSE lv_value NO-GAPS.
        IF lv_value(3) NE '100'.
*          ls_return-message_v1 = 'QubitOn Address Validation Failed - Enter Valid Address'.
          ls_return-id = 'ZQUBITON'.
          ls_return-number = '001'.
          ls_return-type = 'E'.
          APPEND ls_return TO et_return.
        ELSE.
          ls_return-id = 'ZQUBITON'.
          ls_return-number = '002'.
          ls_return-type = 'S'.
          APPEND ls_return TO et_return.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
