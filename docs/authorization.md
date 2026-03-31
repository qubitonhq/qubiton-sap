# Authorization (ZQUBITON_API)

The connector includes an optional custom authorization object `ZQUBITON_API` with granular activity control. Enable it by passing `iv_check_auth = abap_true` to the constructor.

## Activity Values (ZQBT_ACTVT)

| Activity | Value | Methods Covered |
|----------|-------|-----------------|
| Validate | `01` | `validate_address`, `validate_tax`, `validate_tax_format`, `validate_bank_account`, `validate_bank_pro`, `validate_email`, `validate_phone`, `validate_peppol`, `validate_npi`, `validate_medpass`, `validate_certification`, `validate_india_identity`, `validate_ariba_supplier` |
| Lookup | `02` | `lookup_business_registration`, `lookup_epa_prosecution`, `lookup_healthcare_exclusion`, `lookup_credit_analysis`, `lookup_beneficial_ownership`, `lookup_corporate_hierarchy`, `lookup_duns`, `lookup_hierarchy`, `lookup_certification`, `lookup_business_classification`, `lookup_dot_carrier`, `lookup_ariba_supplier`, `lookup_exchange_rates`, `lookup_esg_score`, `lookup_credit_score`, `lookup_fail_rate` |
| Screen | `03` | `check_sanctions`, `screen_pep`, `check_directors`, `check_epa_prosecution`, `check_healthcare_exclusion`, `check_ip_quality` |
| Risk | `04` | `check_bankruptcy_risk`, `assess_entity_risk`, `domain_security_report` |
| Financial | `05` | `analyze_payment_terms` |
| Reference | `06` | `get_supported_tax_formats`, `get_peppol_schemes`, `identify_gender` |

## Setup

1. **SU21**: Create authorization object `ZQUBITON_API` with field `ZQBT_ACTVT` (or import `src/zqubiton_api.suso.xml` via abapGit)
2. **PFCG**: Add `ZQUBITON_API` to the appropriate role with desired activities (e.g., `01`+`02` for validate+lookup, or `*` for all)
3. Pass `iv_check_auth = abap_true` when creating the client instance

If `ZQUBITON_API` is not registered in SU21 yet, the check automatically falls back to `S_RFC` (generic RFC authorization).

> **Note**: The current implementation performs a single check for activity `01` at construction time (all-or-nothing). Users assigned activity `01` or `*` pass the check; the per-category activities (02-06) are documented for future per-method enforcement. For now, assign `*` (all) or `01` in PFCG roles.

```abap
" Enforce authorization — only users with ZQUBITON_API role can call
DATA(lo_api) = NEW zcl_qubiton(
  iv_apikey     = 'your-api-key'
  iv_check_auth = abap_true ).
```

## Application Logging (SLG1)

Every API call is automatically logged to the SAP Application Log (BAL). View logs via transaction **SLG1**.

### What Gets Logged

| Field | Content | Example |
|-------|---------|---------|
| Object | `ZQUBITON` | Fixed |
| Subobject | `ZAPI_CALL` | Fixed |
| Message | Method, path, elapsed ms, HTTP status | `POST /api/address/validate completed in 245 ms (HTTP 200)` |
| Message Type | `I` (success) or `E` (error) | `I` for 2xx, `E` for failures |
| User | `sy-uname` | Current SAP user |
| Program | `sy-repid` | Calling program |
| External ID | Session identifier | `QubitOn API 20260330 143022` |

### Setup

Register the log object in **SLG0** before first use:

1. Open transaction **SLG0**
2. Create object: `ZQUBITON` (text: "QubitOn API Connector")
3. Create subobject: `ZAPI_CALL` (text: "QubitOn API Call Log")

Or import `src/zqubiton_bal.slog.xml` via abapGit.

### Viewing Logs

```
Transaction SLG1:
  Object:    ZQUBITON
  Subobject: ZAPI_CALL
  From date: (today)
  To date:   (today)
  -> Execute
```

### Batch Log Flushing

Logs are auto-saved after each API call. For batch scenarios where you want explicit control:

```abap
DATA(lo_api) = NEW zcl_qubiton(
  iv_apikey      = 'your-api-key'
  iv_log_enabled = abap_true ).

" ... many API calls ...

" Explicitly flush to database (also happens automatically per call)
lo_api->flush_log( ).
```

To disable logging entirely (e.g., performance-sensitive batch):

```abap
DATA(lo_api) = NEW zcl_qubiton(
  iv_apikey      = 'your-api-key'
  iv_log_enabled = abap_false ).
```
