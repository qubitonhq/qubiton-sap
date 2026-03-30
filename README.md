# QubitOn API -- SAP S/4HANA Native Connector

ABAP class for calling the **QubitOn API** from SAP S/4HANA, ECC, or BTP.
Full API coverage with 41 methods across validation, compliance, risk, and more.

## Why Use This Connector

| Benefit | Description |
|---------|-------------|
| **Native SAP integration** | Pure ABAP — no middleware, no external runtimes, no Java stack. Runs inside the ABAP application server alongside your business logic. |
| **Zero-code error handling** | Configure stop/warn/silent behavior via constructor parameters. SAP admins control what happens on API errors or validation failures — no TRY/CATCH needed for standard use. |
| **Real-time and batch** | Use in BADIs, user exits, and screen PAI for real-time validation during data entry. Use in reports and BDCs for mass cleansing. Same class, different config. |
| **Audit trail built in** | Every API call is logged to SAP Application Log (SLG1) with method, path, HTTP status, and elapsed time. Viewable via SLG1 — no custom logging code. |
| **SAP authorization model** | Optional `ZQUBITON_API` authorization object with per-category activity values. Control who can validate vs. screen vs. look up, enforced by PFCG roles. |
| **Translatable messages** | All user-facing messages use SE91 message class `ZCL_QUBITON_MSG` — translatable to any language via SE63. |
| **abapGit deployable** | Full abapGit-compatible package structure. One-click import into any ABAP system. |
| **No external dependencies** | Uses only `cl_http_client` and `if_http_client` (available since NW 7.0). No `/ui5/`, no CDS, no RAP, no oData. |

### How It Works in SAP

```
┌─────────────────────────────────────────────────────────────┐
│  SAP S/4HANA / ECC / BTP                                    │
│                                                             │
│  ┌──────────────┐    ┌──────────────────┐                   │
│  │ Your Code    │───►│ ZCL_QUBITON      │                   │
│  │ (BADI, exit, │    │                  │                   │
│  │  report, CPI)│    │ • build_json()   │                   │
│  └──────────────┘    │ • send_request() │──── HTTPS ────┐   │
│                      │ • parse_result() │               │   │
│  ┌──────────────┐    │ • log_api_call() │               │   │
│  │ SLG1 App Log │◄───│ • handle_result()│               │   │
│  └──────────────┘    └──────────────────┘               │   │
│                                                         │   │
│  ┌──────────────┐    ┌──────────────────┐               │   │
│  │ PFCG Roles   │───►│ ZQUBITON_API     │               │   │
│  │              │    │ (auth object)    │               │   │
│  └──────────────┘    └──────────────────┘               │   │
│                                                         │   │
│  ┌──────────────┐                                       │   │
│  │ SM59 / BTP   │─── RFC Destination "QubitOn" ────┐    │   │
│  │ Destination  │    (type G, SSL, port 443)       │    │   │
│  └──────────────┘                                  │    │   │
└────────────────────────────────────────────────────┼────┼───┘
                                                     │    │
                                                     ▼    ▼
                                          ┌──────────────────┐
                                          │ api.qubiton.com  │
                                          │ (QubitOn API)    │
                                          └──────────────────┘
```

**Data flow**: Your ABAP code → `ZCL_QUBITON` builds JSON → sends HTTPS POST/GET via `cl_http_client` through an RFC destination → receives JSON response → optionally parses validity and issues SAP messages → logs to BAL.

### Common SAP Integration Points

| Integration Point | Example | Recommended Config |
|-------------------|---------|-------------------|
| **Vendor master BADI** | Validate tax ID and bank account on save | `on_error='W'`, `on_invalid='E'` (block save on invalid) |
| **Purchase order user exit** | Screen supplier against sanctions lists | `on_error='W'`, `on_invalid='E'` |
| **Mass data report** | Cleanse 10,000 vendor addresses overnight | `on_error='S'`, `on_invalid='S'` (silent, check results) |
| **Fiori app (OData)** | Real-time address validation in UI5 | Raw JSON mode, return to frontend |
| **CPI iFlow** | Validate bank accounts from Ariba/Fieldglass | REST adapter to BTP destination |
| **BDC / LSMW** | Validate during legacy data migration | Silent mode, log errors to ALV |

## Platform Compatibility

| Platform | Version | Connectivity | Deployment |
|----------|---------|--------------|------------|
| **SAP S/4HANA** (on-prem) | 1709+ | RFC destination (SM59 type G, SSL) | SE24 or ADT |
| **SAP S/4HANA Cloud** | Any | SAP BTP Destination service | ADT or gCTS |
| **SAP ECC** | 6.0 EHP5+ | RFC destination (SM59 type G, SSL) | SE24 |
| **SAP BTP ABAP Environment** | Any | Communication Arrangement / Destination | ADT |
| **SAP CPI / Integration Suite** | Any | REST adapter with BTP destination | iFlow import |

The class uses only standard ABAP APIs (`cl_http_client`, `if_http_client`) available on all platforms. No S/4HANA-specific APIs, no CDS views, no RAP dependencies.

**ABAP language level**: Compatible with ABAP 7.40+ (inline declarations, string templates). For older ECC systems on 7.02–7.31, replace `DATA(...)` inline declarations with explicit `DATA` statements.

## API Coverage (41 methods)

| Category | Methods | Description |
|----------|---------|-------------|
| Address | `validate_address` | Postal address validation (249 countries) |
| Tax | `validate_tax`, `validate_tax_format` | Tax ID validation with live checks + format/checksum |
| Bank | `validate_bank_account`, `validate_bank_pro` | Bank validation + premium ownership verification |
| Email & Phone | `validate_email`, `validate_phone` | Deliverability and carrier validation |
| Business Registration | `lookup_business_registration` | Official registration records |
| Peppol | `validate_peppol` | Peppol participant ID validation (70+ ICD schemes) |
| Sanctions & Compliance | `check_sanctions`, `screen_pep`, `check_directors` | OFAC/EU/UN screening, PEP, disqualified directors |
| EPA | `check_epa_prosecution`, `lookup_epa_prosecution` | EPA criminal prosecution records |
| Healthcare | `check_healthcare_exclusion`, `lookup_healthcare_exclusion` | Provider exclusion lists |
| Risk & Financial | `check_bankruptcy_risk`, `lookup_credit_score`, `lookup_fail_rate`, `assess_entity_risk`, `lookup_credit_analysis` | Bankruptcy, credit, fail rate, fraud risk |
| ESG & Cybersecurity | `lookup_esg_score`, `domain_security_report`, `check_ip_quality` | ESG scores, domain security, IP fraud |
| Corporate Structure | `lookup_beneficial_ownership`, `lookup_corporate_hierarchy`, `lookup_duns`, `lookup_hierarchy` | UBO, hierarchy, DUNS |
| Industry | `validate_npi`, `validate_medpass`, `lookup_dot_carrier`, `validate_india_identity` | Healthcare NPI, Medpass, DOT carrier, India ID |
| Certification | `validate_certification`, `lookup_certification` | Diversity certifications (MBE, WBE, DBE) |
| Classification | `lookup_business_classification` | NAICS/SIC codes |
| Financial Ops | `analyze_payment_terms`, `lookup_exchange_rates` | Payment optimization, FX rates |
| Supplier | `lookup_ariba_supplier`, `validate_ariba_supplier` | SAP Ariba supplier profiles |
| Gender | `identify_gender` | Name-based gender prediction |
| Reference | `get_supported_tax_formats`, `get_peppol_schemes` | Supported countries/schemes |

## MCP Protocol Support

This API is available as a native [Model Context Protocol](https://modelcontextprotocol.io) (MCP) server.

### Tools (37), Prompts (20), Resources (7)

| Category | Count | Description |
|----------|-------|-------------|
| MCP Tools | 37 | 1:1 mapped to API endpoints — same auth, rate limits, and plan access |
| MCP Prompts | 20 | Multi-tool workflow templates (onboarding, compliance, risk, payment) |
| MCP Resources | 7 | Reference datasets (tool inventory, risk categories, country coverage) |

Prompts may be plan-gated. See [Pricing](https://www.qubiton.com/pricing) for details.

- [MCP Manifest](https://mcp.qubiton.com/.well-known/mcp.json)
- [Resource Content](https://mcp.qubiton.com/api/portal/mcp/resources/{name})

## Getting an API Key

1. Sign up for a free account at [www.qubiton.com](https://www.qubiton.com/auth/register)
2. Navigate to **API Keys** and generate a new key.
3. Copy the key -- you will need it when configuring the destination.

## Setup Options

### Option A: SAP BTP Destination (Cloud)

Import `btp-destination.json` into your BTP subaccount or create the
destination manually:

1. Open **SAP BTP Cockpit > Connectivity > Destinations**.
2. Click **Import Destination** and select `btp-destination.json`.
3. Replace `YOUR_API_KEY` with your actual API key.
4. Save the destination.

| Property | Value |
|---|---|
| Name | `QubitOn` |
| URL | `https://api.qubiton.com` |
| Authentication | `NoAuthentication` |
| Proxy Type | `Internet` |
| Type | `HTTP` |

The API key is passed as a custom header `apikey` via the
`URL.headers.apikey` additional property.

### Option B: ABAP RFC Destination (On-Premise S/4HANA / ECC)

1. Open transaction **SM59**.
2. Create a new destination of type **G** (HTTP connection to external server).

| Field | Value |
|---|---|
| RFC Destination | `QubitOn` |
| Host | `api.qubiton.com` |
| Port | `443` |
| Path Prefix | *(leave blank)* |
| SSL | Active, SSL Client `DEFAULT` or `ANONYM` |

3. On the **Logon & Security** tab, set SSL to **Active**.
4. Import the TLS certificate via **STRUST** (transaction) if your system
   does not already trust the public CA chain.

Deploy `ZCL_QUBITON.abap` via **SE24** or **ADT** (ABAP Development Tools).

### Option C: SAP CPI / Integration Suite iFlow

Create a REST adapter channel pointing to the BTP destination:

```
Sender: your system
  |
  v
[Content Modifier]          -- Set header "apikey" from externalized parameter
  |
  v
[Request-Reply]
  +-- HTTP Adapter
        Address: /api/address/validate   (or other endpoint)
        Method:  POST
        Destination: QubitOn
  |
  v
[Content Modifier]          -- Map response to target format
  |
  v
Receiver: your system
```

**iFlow externalized parameters:**

| Parameter | Description |
|---|---|
| `apikey` | Your QubitOn API key |
| `endpoint_path` | API path, e.g. `/api/address/validate` |

In the Content Modifier before the HTTP adapter, add a header:

| Action | Name | Source Type | Source Value |
|---|---|---|---|
| Create | `apikey` | External Parameter | `{{apikey}}` |
| Create | `Content-Type` | Constant | `application/json` |

## Configuration

The class supports configurable error handling and validation behavior via constructor parameters. This lets SAP admins control what happens on API errors or validation failures — no try/catch code needed.

### Constructor Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `iv_destination` | RFC dest name | `'QubitOn'` | SM59 or BTP destination |
| `iv_apikey` | API key string | *(empty)* | Overrides destination header if supplied |
| `iv_on_error` | `'E'`, `'W'`, `'S'` | `'W'` | What to do on HTTP/network failure |
| `iv_on_invalid` | `'E'`, `'W'`, `'S'` | `'W'` | What to do when validation fails (isValid=false) |
| `iv_check_auth` | `abap_true/false` | `abap_false` | Check `ZQUBITON_API` authorization before API calls (falls back to `S_RFC`) |
| `iv_log_enabled` | `abap_true/false` | `abap_true` | Write API calls to BAL Application Log (SLG1) |

### Error/Validation Modes

| Mode | Constant | Behavior |
|------|----------|----------|
| **Stop** | `gc_on_error_stop` / `gc_on_invalid_stop` (`'E'`) | `MESSAGE TYPE 'E'` — blocks save/post, user cannot proceed |
| **Warn** | `gc_on_error_warn` / `gc_on_invalid_warn` (`'W'`) | `MESSAGE TYPE 'W'` — shows warning, user can proceed |
| **Silent** | `gc_on_error_silent` / `gc_on_invalid_silent` (`'S'`) | No message — caller checks `rs_result` programmatically |

### Configuration Examples

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

### Using handle_result (Safe Wrapper)

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

### Real-Time vs. Batch Usage

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

## ABAP Usage Examples (Raw JSON)

The methods below return raw JSON strings. Use `handle_result` (above) for automatic
error/validation handling, or process the JSON yourself with `/ui2/cl_json`.

### Validate an Address

```abap
DATA(lo_api) = NEW zcl_qubiton( iv_apikey = 'your-api-key' ).

TRY.
    DATA(lv_result) = lo_api->validate_address(
      iv_address_line1 = '123 Main St'
      iv_city          = 'Springfield'
      iv_state         = 'IL'
      iv_postal_code   = '62701'
      iv_country       = 'US'
    ).
    WRITE: / lv_result.
  CATCH zcx_qubiton INTO DATA(lx_err).
    WRITE: / 'Error:', lx_err->get_text( ).
ENDTRY.
```

### Validate a Tax ID

```abap
DATA(lv_result) = lo_api->validate_tax(
  iv_tax_number   = '12-3456789'
  iv_tax_type     = 'EIN'
  iv_country      = 'US'
  iv_company_name = 'Acme Corporation'
).
```

### Validate Tax ID Format (Offline)

```abap
DATA(lv_result) = lo_api->validate_tax_format(
  iv_tax_number = 'DE123456789'
  iv_tax_type   = 'VAT'
  iv_country    = 'DE'
).
```

### Validate a Bank Account

```abap
DATA(lv_result) = lo_api->validate_bank_account(
  iv_business_entity_type = 'Business'
  iv_country              = 'US'
  iv_bank_account_holder  = 'Acme Corp'
  iv_account_number       = '1234567890'
  iv_bank_code            = '021000021'
).
```

### Premium Bank Validation (BankPro)

```abap
DATA(lv_result) = lo_api->validate_bank_pro(
  iv_business_entity_type = 'Business'
  iv_country              = 'GB'
  iv_bank_account_holder  = 'Acme Ltd'
  iv_iban                 = 'GB29NWBK60161331926819'
).
```

### Validate Email

```abap
DATA(lv_result) = lo_api->validate_email(
  iv_email_address = 'john@example.com'
).
```

### Validate Phone

```abap
DATA(lv_result) = lo_api->validate_phone(
  iv_phone_number = '+14155551234'
  iv_country      = 'US'
).
```

### Look Up Business Registration

```abap
DATA(lv_result) = lo_api->lookup_business_registration(
  iv_company_name = 'Acme Corporation'
  iv_country      = 'US'
  iv_state        = 'DE'
).
```

### Validate Peppol ID

```abap
DATA(lv_result) = lo_api->validate_peppol(
  iv_participant_id   = '0088:1234567890128'
  iv_directory_lookup = 'X'  " sends JSON boolean true
).
```

### Screen for Sanctions

```abap
DATA(lv_result) = lo_api->check_sanctions(
  iv_company_name = 'Acme Trading Ltd'
  iv_country      = 'US'
).
```

### Screen for PEP (Politically Exposed Persons)

```abap
DATA(lv_result) = lo_api->screen_pep(
  iv_name    = 'John Smith'
  iv_country = 'US'
).
```

### Check Disqualified Directors

```abap
DATA(lv_result) = lo_api->check_directors(
  iv_first_name = 'John'
  iv_last_name  = 'Doe'
  iv_country    = 'GB'
).
```

### Check EPA Prosecution

```abap
DATA(lv_result) = lo_api->check_epa_prosecution(
  iv_name  = 'Acme Chemical Corp'
  iv_state = 'TX'
).
```

### Check Healthcare Exclusion

```abap
DATA(lv_result) = lo_api->check_healthcare_exclusion(
  iv_healthcare_type = 'HCP'
  iv_last_name       = 'Smith'
  iv_first_name      = 'John'
  iv_state           = 'CA'
).
```

### Check Bankruptcy Risk

```abap
DATA(lv_result) = lo_api->check_bankruptcy_risk(
  iv_company_name = 'Acme Corporation'
  iv_country      = 'US'
).
```

### Look Up Credit Score

```abap
DATA(lv_result) = lo_api->lookup_credit_score(
  iv_company_name = 'Acme Corporation'
  iv_country      = 'US'
).
```

### Assess Entity Risk

```abap
DATA(lv_result) = lo_api->assess_entity_risk(
  iv_company_name = 'Acme Corporation'
  iv_country      = 'US'
  iv_category     = 'Financial'
).
```

### Look Up Credit Analysis

```abap
DATA(lv_result) = lo_api->lookup_credit_analysis(
  iv_company_name  = 'Acme Corporation'
  iv_address_line1 = '123 Main St'
  iv_city          = 'Wilmington'
  iv_state         = 'DE'
  iv_country       = 'US'
).
```

### Look Up ESG Score

```abap
DATA(lv_result) = lo_api->lookup_esg_score(
  iv_company_name = 'Acme Corporation'
  iv_country      = 'US'
).
```

### Domain Security Report

```abap
DATA(lv_result) = lo_api->domain_security_report(
  iv_domain_name = 'example.com'
).
```

### Check IP Quality

```abap
DATA(lv_result) = lo_api->check_ip_quality(
  iv_ip_address = '203.0.113.42'
).
```

### Look Up Beneficial Ownership

```abap
DATA(lv_result) = lo_api->lookup_beneficial_ownership(
  iv_company_name = 'Acme Corporation'
  iv_country_iso2 = 'US'
).
```

### Look Up Corporate Hierarchy

```abap
DATA(lv_result) = lo_api->lookup_corporate_hierarchy(
  iv_company_name  = 'Acme Corporation'
  iv_address_line1 = '123 Main St'
  iv_city          = 'Wilmington'
  iv_state         = 'DE'
  iv_zip_code      = '19801'
).
```

### Look Up DUNS Number

```abap
DATA(lv_result) = lo_api->lookup_duns(
  iv_duns_number = '123456789'
).
```

### Validate NPI

```abap
DATA(lv_result) = lo_api->validate_npi(
  iv_npi       = '1234567890'
  iv_last_name = 'Smith'
).
```

### Look Up DOT Carrier

```abap
DATA(lv_result) = lo_api->lookup_dot_carrier(
  iv_dot_number = '12345'
).
```

### Validate Certification

```abap
DATA(lv_result) = lo_api->validate_certification(
  iv_company_name       = 'Acme Corp'
  iv_country            = 'US'
  iv_certification_type = 'MBE'
).
```

### Look Up Business Classification

```abap
DATA(lv_result) = lo_api->lookup_business_classification(
  iv_company_name = 'Acme Corporation'
  iv_city         = 'Wilmington'
  iv_state        = 'DE'
  iv_country      = 'US'
).
```

### Analyze Payment Terms

```abap
DATA(lv_result) = lo_api->analyze_payment_terms(
  iv_current_pay_term = '30'
  iv_annual_spend     = '1000000'
  iv_avg_days_pay     = '45'
  iv_savings_rate     = '0.02'
  iv_threshold        = '10'
).
```

### Look Up Exchange Rates

```abap
DATA(lv_result) = lo_api->lookup_exchange_rates(
  iv_base_currency = 'USD'
  iv_dates         = '2024-01-15,2024-01-16'
).
```

### Look Up SAP Ariba Supplier

```abap
DATA(lv_result) = lo_api->lookup_ariba_supplier(
  iv_anid = 'AN01234567890'
).
```

### Identify Gender

```abap
DATA(lv_result) = lo_api->identify_gender(
  iv_name    = 'Andrea'
  iv_country = 'IT'
).
```

### Get Supported Tax Formats

```abap
DATA(lv_result) = lo_api->get_supported_tax_formats( ).
```

### Get Peppol Schemes

```abap
DATA(lv_result) = lo_api->get_peppol_schemes( ).
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

## Authorization (ZQUBITON_API)

The connector includes an optional custom authorization object `ZQUBITON_API` with granular activity control. Enable it by passing `iv_check_auth = abap_true` to the constructor.

### Activity Values (ZQBT_ACTVT)

| Activity | Value | Methods Covered |
|----------|-------|-----------------|
| Validate | `01` | `validate_address`, `validate_tax`, `validate_tax_format`, `validate_bank_account`, `validate_bank_pro`, `validate_email`, `validate_phone`, `validate_peppol`, `validate_npi`, `validate_medpass`, `validate_certification`, `validate_india_identity`, `validate_ariba_supplier` |
| Lookup | `02` | `lookup_business_registration`, `lookup_epa_prosecution`, `lookup_healthcare_exclusion`, `lookup_credit_analysis`, `lookup_beneficial_ownership`, `lookup_corporate_hierarchy`, `lookup_duns`, `lookup_hierarchy`, `lookup_certification`, `lookup_business_classification`, `lookup_dot_carrier`, `lookup_ariba_supplier`, `lookup_exchange_rates`, `lookup_esg_score`, `lookup_credit_score`, `lookup_fail_rate` |
| Screen | `03` | `check_sanctions`, `screen_pep`, `check_directors`, `check_epa_prosecution`, `check_healthcare_exclusion`, `check_ip_quality` |
| Risk | `04` | `check_bankruptcy_risk`, `assess_entity_risk`, `domain_security_report` |
| Financial | `05` | `analyze_payment_terms`, `lookup_exchange_rates` |
| Reference | `06` | `get_supported_tax_formats`, `get_peppol_schemes`, `identify_gender` |

### Setup

1. **SU21**: Create authorization object `ZQUBITON_API` with field `ZQBT_ACTVT` (or import `src/zqubiton_api.suso.xml` via abapGit)
2. **PFCG**: Add `ZQUBITON_API` to the appropriate role with desired activities (e.g., `01`+`02` for validate+lookup, or `*` for all)
3. Pass `iv_check_auth = abap_true` when creating the client instance

If `ZQUBITON_API` is not registered in SU21 yet, the check automatically falls back to `S_RFC` (generic RFC authorization).

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
  → Execute
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

## Screen Enhancements (Automatic Validation on Save)

The connector includes pre-built BAdI implementations that automatically validate data when users save vendor master, customer master, or Business Partner records. SAP admins control exactly which validations run via a configuration table — no ABAP development needed to turn validations on or off.

### Supported Screens

| Master Data | Transaction Codes | BAdI | Implementation Class |
|-------------|------------------|------|---------------------|
| **Vendor Master** | XK01, XK02, FK01, FK02, MK01, MK02 | `VENDOR_ADD_DATA_CS` | `ZCL_QUBITON_BADI_VENDOR` |
| **Customer Master** | XD01, XD02, FD01, FD02, VD01, VD02 | `CUSTOMER_ADD_DATA_CS` | `ZCL_QUBITON_BADI_CUSTOMER` |
| **Business Partner** (S/4HANA) | BP | `BADI_BUS1006_CHECK` | `ZCL_QUBITON_BADI_BP` |

### Available Validations per Screen

| Validation | Vendor | Customer | Business Partner | What It Checks |
|------------|--------|----------|------------------|----------------|
| **TAX** | STCEG / STCD1 / STCD2 | STCEG / STCD1 / STCD2 | TAXNUM / TAXTYPE | Tax ID validity via live authority check |
| **BANK** | BANKN / IBAN / SWIFT / BANKL | BANKN / IBAN / SWIFT / BANKL | BANKN / IBAN / SWIFT / BANKL | Bank account, routing/sort code, IBAN, SWIFT validation |
| **ADDRESS** | STRAS / ORT01 / REGIO / PSTLZ | STRAS / ORT01 / REGIO / PSTLZ | STREET / CITY / REGION / POSTL_COD1 | Postal address validation (249 countries) |
| **SANCTION** | NAME1 + address fields | NAME1 + address fields | NAME_ORG1/NAME_LAST + address | OFAC, EU, UN sanctions/prohibited list screening |
| **EMAIL** | *(planned)* | *(planned)* | *(planned)* | Email deliverability validation |
| **PHONE** | *(planned)* | *(planned)* | *(planned)* | Phone number carrier validation |

### How It Works

```
User saves vendor/customer/BP
  │
  ▼
BAdI fires (e.g., VENDOR_ADD_DATA_CS)
  │
  ▼
ZCL_QUBITON_BADI_VENDOR reads screen fields
  │
  ▼
ZCL_QUBITON_SCREEN reads ZQUBITON_SCREEN_CFG table
  │  ├── Is TAX validation active for this tcode? → validate tax
  │  ├── Is BANK validation active for this tcode? → validate bank
  │  ├── Is ADDRESS validation active for this tcode? → validate address
  │  ├── Is SANCTION screening active for this tcode? → check sanctions
  │  └── Country filter match? → skip if country doesn't match
  │
  ▼
Each active validation → ZCL_QUBITON API call
  │
  ▼
Result → SAP MESSAGE (E=block save, W=warn, S=silent)
  │
  ▼
User sees validation result in status bar
```

### Configuration Table (ZQUBITON_SCREEN_CFG)

SAP admins maintain this table via **SM30** (table maintenance). Each row enables or disables one validation for one transaction code.

| Field | Type | Key | Description |
|-------|------|-----|-------------|
| `MANDT` | MANDT | Yes | Client |
| `TCODE` | TCODE | Yes | Transaction code (XK01, XK02, FK01, BP, etc.) |
| `VAL_TYPE` | CHAR10 | Yes | Validation type: `TAX`, `BANK`, `ADDRESS`, `SANCTION`, `EMAIL`, `PHONE` |
| `ACTIVE` | CHAR1 | | `X` = active, blank = disabled |
| `ON_INVALID` | CHAR1 | | What to do when validation fails: `E`=block save, `W`=warn, `S`=silent |
| `ON_ERROR` | CHAR1 | | What to do on API error: `E`=block save, `W`=warn, `S`=silent |
| `COUNTRY_FILTER` | LAND1 | | Optional: only validate for this country (blank = all countries) |

#### Example Configuration

| TCODE | VAL_TYPE | ACTIVE | ON_INVALID | ON_ERROR | COUNTRY_FILTER | Effect |
|-------|----------|--------|------------|----------|----------------|--------|
| XK01 | TAX | X | E | W | | Block vendor create if tax ID invalid |
| XK01 | BANK | X | E | W | | Block vendor create if bank invalid |
| XK01 | ADDRESS | X | W | S | | Warn on bad address, don't block |
| XK02 | TAX | X | W | S | | Warn on tax change, don't block |
| FK01 | TAX | X | E | W | US | Block only US vendors with bad tax |
| XK01 | SANCTION | X | E | W | | Block vendor create if on sanctions list |
| BP | TAX | X | E | W | | Block BP save if tax invalid |
| BP | ADDRESS | X | W | W | | Warn on bad BP address |
| BP | SANCTION | X | E | W | | Block BP save if on sanctions list |

#### Admin Toggle: Turn Validations On/Off

To **enable** a validation: set `ACTIVE = 'X'` in SM30.
To **disable** a validation: clear `ACTIVE` (set to blank) or delete the row.
To **enable for specific countries only**: set `COUNTRY_FILTER` (e.g., `US` for US vendors only).

```
Transaction SM30 → Table ZQUBITON_SCREEN_CFG → Maintain

┌────────┬──────────┬────────┬────────────┬──────────┬────────────────┐
│ TCODE  │ VAL_TYPE │ ACTIVE │ ON_INVALID │ ON_ERROR │ COUNTRY_FILTER │
├────────┼──────────┼────────┼────────────┼──────────┼────────────────┤
│ XK01   │ TAX      │   X    │     E      │    W     │                │
│ XK01   │ BANK     │   X    │     E      │    W     │                │
│ XK01   │ ADDRESS  │        │     W      │    S     │                │  ← disabled
│ XK01   │ SANCTION │   X    │     E      │    W     │                │
│ XK02   │ TAX      │   X    │     W      │    S     │                │
│ BP     │ TAX      │   X    │     E      │    W     │                │
│ BP     │ ADDRESS  │   X    │     W      │    W     │                │
│ BP     │ SANCTION │   X    │     E      │    W     │                │
└────────┴──────────┴────────┴────────────┴──────────┴────────────────┘
```

### General Configuration Table (ZQUBITON_CONFIG)

Stores the API key and other settings. Maintained via SM30.

| CONFIG_KEY | CONFIG_VALUE | Description |
|------------|-------------|-------------|
| `APIKEY` | `your-api-key-here` | QubitOn API key (shared by all BAdIs) |
| `CHECK_AUTH` | `X` | Enable ZQUBITON_API authorization check (optional, blank = skip) |

### Tax Type Auto-Detection

The orchestrator automatically maps SAP country codes to the correct QubitOn tax type:

| Country | Tax Type | Field Preference |
|---------|----------|-----------------|
| US | EIN | STCD1 → STCEG |
| DE, FR, IT, NL, ... (EU) | VAT | STCEG → STCD1 |
| BR | CNPJ | STCD1 → STCEG |
| IN | GSTIN | STCD1 → STCEG |
| AU | ABN | STCD1 → STCEG |
| CA | BN | STCD1 → STCEG |
| GB | UTR | STCD1 → STCEG |
| MX | RFC | STCD1 → STCEG |
| JP | CN | STCD1 → STCEG |
| KR | BRN | STCD1 → STCEG |
| RU | INN | STCD1 → STCEG |
| ZA | TIN | STCD1 → STCEG |

For Business Partner, the explicit `TAXTYPE` field from `BPTAX` is used if populated. Otherwise, country-based detection applies.

### Bank Field Mapping

SAP's `BANKL` field stores different bank routing codes depending on the country:

| SAP Field | QubitOn API Field | Description |
|-----------|-------------------|-------------|
| `BANKL` | `bankCode` | US routing number, UK sort code, MX CLABE, AU BSB, etc. |
| `BANKN` | `accountNumber` | Bank account number |
| `IBAN` | `iban` | International Bank Account Number (Europe, international) |
| `SWIFT` | `swiftCode` | SWIFT/BIC code |
| `KOINH` | `bankAccountHolder` | Account holder name (falls back to vendor/customer name) |
| `BANKS` | `country` | Bank country key |

The screen enhancement also passes `businessName` and `taxIdNumber` (when available) for enhanced validation accuracy.

**Note on bank ownership verification**: The standard `validate_bank_account` method validates that the account exists and matches the provided details. Premium ownership verification (confirming the account holder matches) is available via the `validate_bank_pro` method but is not exposed in screen enhancements — use it directly for enhanced due diligence.

### BP Bank Data Limitation

The `BADI_BUS1006_CHECK` interface does not provide bank data in its parameters. Bank validation for Business Partners requires a custom enhancement that reads from BP bank tables (`BUT100`/`BPBK`) directly, or use of a separate BAdI/user exit that fires during bank data entry.

### Screen Enhancement Setup

1. **SE11** — Activate tables `ZQUBITON_SCREEN_CFG` and `ZQUBITON_CONFIG` (or import via abapGit)
2. **SE55** — Generate table maintenance dialog for both tables (function group `ZQUBITON_TMG`)
3. **SM30** — Add API key to `ZQUBITON_CONFIG` (CONFIG_KEY = `APIKEY`)
4. **SM30** — Configure validations in `ZQUBITON_SCREEN_CFG` (see example above)
5. **SE19** — Create BAdI implementations:
   - BAdI `VENDOR_ADD_DATA_CS` → Implementation class `ZCL_QUBITON_BADI_VENDOR`
   - BAdI `CUSTOMER_ADD_DATA_CS` → Implementation class `ZCL_QUBITON_BADI_CUSTOMER`
   - BAdI `BADI_BUS1006_CHECK` → Implementation class `ZCL_QUBITON_BADI_BP`
6. **SE19** — Activate the BAdI implementations
7. Test by creating/changing a vendor, customer, or BP

### Screen Enhancement Code Examples

#### Direct Use (without BAdI)

You can also call the screen orchestrator directly from your own code:

```abap
" Validate a vendor's tax ID programmatically
TRY.
    DATA(lo_screen) = NEW zcl_qubiton_screen( iv_apikey = 'your-key' ).

    DATA(ls_vendor) = VALUE zcl_qubiton_screen=>ty_vendor_data(
      lifnr = '0001000001'
      land1 = 'US'
      name1 = 'Acme Corporation'
      stcd1 = '12-3456789' ).

    DATA(ls_result) = lo_screen->validate_vendor_tax( ls_vendor ).

    IF ls_result-is_valid = abap_false.
      WRITE: / 'Tax ID invalid:', ls_result-message.
    ENDIF.

  CATCH zcx_qubiton INTO DATA(lx_err).
    WRITE: / lx_err->get_text( ).
ENDTRY.
```

#### Validate All (Config-Driven)

```abap
" Run all active validations for a vendor (reads ZQUBITON_SCREEN_CFG)
TRY.
    DATA(lo_screen) = NEW zcl_qubiton_screen( iv_apikey = 'your-key' ).

    DATA(lt_results) = lo_screen->validate_vendor_all(
      is_vendor = ls_vendor
      is_bank   = ls_bank ).

    LOOP AT lt_results INTO DATA(ls_res).
      WRITE: / ls_res-val_type, ':', ls_res-result-message.
      IF ls_res-blocked = abap_true.
        WRITE: / '  → Save blocked'.
      ENDIF.
    ENDLOOP.

  CATCH zcx_qubiton INTO DATA(lx_err).
    WRITE: / lx_err->get_text( ).
ENDTRY.
```

## SAP Certification & Marketplace Readiness

This connector is designed for SAP certification (ICC) and SAP Store / SAP Business Technology Platform marketplace distribution.

### SAP Certification Requirements

| Requirement | Implementation | Status |
|-------------|---------------|--------|
| **Message class (SE91)** | `ZCL_QUBITON_MSG` — 10 translatable messages, no hardcoded strings in MESSAGE statements | Ready |
| **Package assignment** | `ZQUBITON` package with abapGit metadata (`src/zqubiton.devc.xml`) | Ready |
| **ABAP Unit tests** | `ZCL_QUBITON_TEST` — 30 tests + `ZCL_QUBITON_SCREEN_TEST` — 41 tests = **71 total** | Ready |
| **SE61 documentation** | Class documentation object (`src/zcl_qubiton.clas.docu.xml`) | Ready |
| **Authorization check** | Custom `ZQUBITON_API` auth object with per-category activities (falls back to `S_RFC`) | Ready |
| **Application logging (BAL)** | SLG1 logging under object `ZQUBITON` / subobject `ZAPI_CALL` with method, path, elapsed time, HTTP status | Ready |
| **Customizing tables** | `ZQUBITON_CONFIG` (general config), `ZQUBITON_SCREEN_CFG` (screen validation config) — both with SM30 maintenance | Ready |
| **Table maintenance dialog** | SM30-maintainable via generated function group `ZQUBITON_TMG` | Manual step |
| **abapGit metadata** | `.abapgit.xml` + class/exception/message/table XML descriptors in `src/` | Ready |
| **Transport request** | All objects assignable to transport via SE09 | Manual step |
| **No hardcoded URLs** | API endpoint uses RFC destination (SM59) or BTP Destination — no hardcoded `api.qubiton.com` | Ready |
| **No hardcoded credentials** | API key stored in `ZQUBITON_CONFIG` table, read at runtime | Ready |
| **Multi-client safe** | All tables include `MANDT` field, config is client-dependent | Ready |
| **Namespace-clean** | All objects use `Z` prefix (customer namespace) | Ready |

### SAP Store / Marketplace Publishing

For SAP Store distribution, the following additional items are needed:

| Requirement | Status | Notes |
|-------------|--------|-------|
| **SAP Partner Center account** | Required | Register at [SAP Partner Center](https://partneredge.sap.com) |
| **ICC (Integration Certification Center) certification** | Required | Submit for SAP ICC certification — all technical prerequisites above are met |
| **Partner namespace** | Recommended | Replace `Z` prefix with assigned `/QUBITON/` namespace from SAP for marketplace distribution |
| **Solution documentation** | Required | Installation guide, configuration guide, operations guide — covered in this README |
| **Support contact** | Required | Define L1/L2 support process and SLA |
| **License model** | Required | Define pricing (per-API-call, subscription tier, etc.) — aligns with QubitOn plan model |
| **Test landscape** | Required | Provide SAP ICC with test system access for certification testing |
| **Data protection** | Required | GDPR compliance documentation — no PII stored locally, all data sent to API over TLS |

### Object Inventory

| Object Type | Object Name | Description |
|-------------|-------------|-------------|
| Class | `ZCL_QUBITON` | Core API client (41 methods) |
| Class | `ZCL_QUBITON_SCREEN` | Screen enhancement orchestrator |
| Class | `ZCL_QUBITON_BADI_VENDOR` | Vendor master BAdI implementation |
| Class | `ZCL_QUBITON_BADI_CUSTOMER` | Customer master BAdI implementation |
| Class | `ZCL_QUBITON_BADI_BP` | Business Partner BAdI implementation |
| Class | `ZCL_QUBITON_TEST` | API client unit tests (30 methods) |
| Class | `ZCL_QUBITON_SCREEN_TEST` | Screen enhancement unit tests (41 methods) |
| Exception | `ZCX_QUBITON` | Custom exception class |
| Message Class | `ZCL_QUBITON_MSG` | 10 translatable messages |
| Auth Object | `ZQUBITON_API` | Authorization with 6 activity categories |
| Table | `ZQUBITON_CONFIG` | General configuration (API key, etc.) |
| Table | `ZQUBITON_SCREEN_CFG` | Screen validation configuration |
| Log Object | `ZQUBITON` / `ZAPI_CALL` | Application log object + subobject |
| Package | `ZQUBITON` | Development package |

### Complete Setup Steps

1. **SE80** — Create package `ZQUBITON` and assign to a transport request
2. Import all objects via **abapGit** or **SE24/ADT**
3. **SE11** — Activate tables `ZQUBITON_CONFIG` and `ZQUBITON_SCREEN_CFG`
4. **SE55** — Generate table maintenance dialogs for both tables
5. **SU21** — Register authorization object `ZQUBITON_API` with field `ZQBT_ACTVT` (or import via abapGit)
6. **SLG0** — Register BAL log object `ZQUBITON` with subobject `ZAPI_CALL`
7. **SE91** — Verify message class `ZCL_QUBITON_MSG` (imported via abapGit)
8. **SM59** — Create RFC destination `QubitOn` (type G, SSL, host `api.qubiton.com`, port 443)
9. **STRUST** — Import TLS certificate if needed
10. **SM30** — Add API key to `ZQUBITON_CONFIG` (key = `APIKEY`)
11. **SM30** — Configure screen validations in `ZQUBITON_SCREEN_CFG`
12. **SE19** — Create and activate BAdI implementations for vendor, customer, and/or BP
13. **PFCG** — Assign `ZQUBITON_API` authorization to user roles (activities: 01–06 or `*`)
14. Run ABAP Unit tests via **SE80** or `Ctrl+Shift+F10` in ADT

### Running Unit Tests

```
" Via ADT (ABAP Development Tools in Eclipse):
Right-click ZCL_QUBITON_TEST → Run As → ABAP Unit Test
Right-click ZCL_QUBITON_SCREEN_TEST → Run As → ABAP Unit Test

" Via SE80:
Navigate to package ZQUBITON → Run All Unit Tests

" Expected: 71 tests, 0 failures
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

## License

Copyright QubitOn. All rights reserved.
