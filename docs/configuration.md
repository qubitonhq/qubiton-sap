# Configuration

The class supports configurable error handling and validation behavior via constructor parameters. This lets SAP admins control what happens on API errors or validation failures — no try/catch code needed.

## Constructor Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `iv_destination` | RFC dest name | `'QubitOn'` | SM59 or BTP destination |
| `iv_apikey` | API key string | *(empty)* | Overrides destination header if supplied |
| `iv_on_error` | `'E'`, `'W'`, `'S'` | `'W'` | What to do on HTTP/network failure |
| `iv_on_invalid` | `'E'`, `'W'`, `'S'` | `'W'` | What to do when validation fails (isValid=false) |
| `iv_check_auth` | `abap_true/false` | `abap_false` | Check `ZQUBITON_API` authorization before API calls (falls back to `S_RFC`) |
| `iv_log_enabled` | `abap_true/false` | `abap_true` | Write API calls to BAL Application Log (SLG1) |

## Error/Validation Modes

| Mode | Constant | Behavior |
|------|----------|----------|
| **Stop** | `gc_on_error_stop` / `gc_on_invalid_stop` (`'E'`) | `MESSAGE TYPE 'E'` — blocks save/post, user cannot proceed |
| **Warn** | `gc_on_error_warn` / `gc_on_invalid_warn` (`'W'`) | `MESSAGE TYPE 'W'` — shows warning, user can proceed |
| **Silent** | `gc_on_error_silent` / `gc_on_invalid_silent` (`'S'`) | No message — caller checks `rs_result` programmatically |

## Configuration Examples

```abap
" Hard stop on errors AND validation failures (strictest — blocks save)
DATA(lo_api) = NEW zcl_qubiton(
  iv_apikey     = 'your-api-key'
  iv_on_error   = zcl_qubiton=>gc_on_error_stop
  iv_on_invalid = zcl_qubiton=>gc_on_invalid_stop ).

" Warn on validation failures, silent on errors (lenient — never blocks)
DATA(lo_api) = NEW zcl_qubiton(
  iv_apikey     = 'your-api-key'
  iv_on_error   = zcl_qubiton=>gc_on_error_silent
  iv_on_invalid = zcl_qubiton=>gc_on_invalid_warn ).

" Default behavior (warn on both)
DATA(lo_api) = NEW zcl_qubiton( iv_apikey = 'your-api-key' ).
```

## Using handle_result (Safe Wrapper)

Instead of calling API methods with `TRY`/`CATCH`, use `handle_result` to get automatic messaging based on your configuration:

```abap
DATA lv_json TYPE string.

" Step 1: Call the API method (returns raw JSON, may raise zcx_qubiton on network failure)
TRY.
    lv_json = lo_api->validate_address(
      iv_address_line1 = '123 Main St'
      iv_city          = 'Springfield'
      iv_state         = 'IL'
      iv_postal_code   = '62701'
      iv_country       = 'US' ).
  CATCH zcx_qubiton.
    CLEAR lv_json.  " Empty JSON → handle_result treats as API error
ENDTRY.

" Step 2: handle_result parses the JSON and issues SAP messages per your config
DATA(ls_result) = lo_api->handle_result(
  iv_json  = lv_json
  iv_field = 'isValid'
  iv_label = 'Address' ).

" If iv_on_invalid = 'E', execution stops here on failure (MESSAGE TYPE 'E').
" If iv_on_invalid = 'W', user sees a warning but code continues.
" If iv_on_invalid = 'S', no message — check ls_result-is_valid yourself.

IF ls_result-is_valid = abap_true.
  " Proceed with validated address
ENDIF.
```

## Real-Time vs. Batch Usage

**Real-time (e.g., BADI, user exit, screen PAI)**:
Use `handle_result` so the class handles messaging and stop/continue behavior automatically:

```abap
DATA(lo_api) = NEW zcl_qubiton(
  iv_apikey     = 'your-api-key'
  iv_on_error   = zcl_qubiton=>gc_on_error_warn     " Don't block if API is down
  iv_on_invalid = zcl_qubiton=>gc_on_invalid_stop ). " Block save on invalid data

DATA lv_json TYPE string.

TRY.
    lv_json = lo_api->validate_tax(
      iv_tax_number   = lv_tax_id
      iv_tax_type     = 'VAT'
      iv_country      = 'DE'
      iv_company_name = lv_name ).
  CATCH zcx_qubiton.
    CLEAR lv_json.  " Empty JSON → handle_result treats as API error
ENDTRY.

lo_api->handle_result(
  iv_json  = lv_json
  iv_field = 'isValid'
  iv_label = 'Tax ID' ).
" If API failed → on_error config applies (warn = user sees warning, can proceed)
" If invalid   → on_invalid config applies (stop = MESSAGE TYPE 'E' blocks save)
```

**Batch (e.g., report, BDC, mass upload)**:
Use silent mode and check results programmatically:

```abap
DATA(lo_api) = NEW zcl_qubiton(
  iv_apikey     = 'your-api-key'
  iv_on_error   = zcl_qubiton=>gc_on_error_silent
  iv_on_invalid = zcl_qubiton=>gc_on_invalid_silent ).

LOOP AT lt_vendors INTO DATA(ls_vendor).
  TRY.
      DATA(lv_json) = lo_api->validate_bank_account(
        iv_business_entity_type = 'Business'
        iv_country              = ls_vendor-country
        iv_bank_account_holder  = ls_vendor-name
        iv_account_number       = ls_vendor-account ).

      DATA(ls_result) = lo_api->parse_result(
        iv_json  = lv_json
        iv_field = 'isValid'
        iv_label = 'Bank Account' ).

      IF ls_result-is_valid = abap_false.
        WRITE: / 'INVALID:', ls_vendor-lifnr, ls_result-message.
      ENDIF.
    CATCH zcx_qubiton INTO DATA(lx_err).
      WRITE: / 'ERROR:', ls_vendor-lifnr, lx_err->get_text( ).
  ENDTRY.
ENDLOOP.
```

## Parsing JSON Responses

Use `/ui2/cl_json` to deserialize into an ABAP structure:

```abap
TYPES:
  BEGIN OF ty_address_result,
    isvalid       TYPE abap_bool,
    addressline1  TYPE string,
    city          TYPE string,
    state         TYPE string,
    postalcode    TYPE string,
    country       TYPE string,
  END OF ty_address_result.

DATA ls_result TYPE ty_address_result.

/ui2/cl_json=>deserialize(
  EXPORTING json = lv_result
  CHANGING  data = ls_result ).

IF ls_result-isvalid = abap_true.
  WRITE: / 'Address is valid'.
ENDIF.
```

## Error Handling

All methods raise `zcx_qubiton` exceptions on failure. The exception class provides:
- `http_status` — HTTP status code (0 if connection failed before response)
- `error_text` — Human-readable error description including method, path, and status
- `get_text()` — Returns the error text (standard ABAP exception method)

```abap
TRY.
    DATA(lv_result) = lo_api->validate_tax( ... ).
  CATCH zcx_qubiton INTO DATA(lx_err).
    WRITE: / 'HTTP Status:', lx_err->http_status.
    WRITE: / 'Error:', lx_err->get_text( ).
ENDTRY.
```

Common causes:

| Symptom | Resolution |
|---|---|
| `ICM_HTTP_SSL_PEER_CERT_UNTRUSTED` | Import the CA certificate via STRUST |
| HTTP 401 | Verify your API key is correct |
| HTTP 429 | You have exceeded your rate limit; wait or upgrade your plan |
| Connection timeout | Check SM59 destination, proxy settings, firewall rules |
