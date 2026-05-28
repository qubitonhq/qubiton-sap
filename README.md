# QubitOn SAP S/4HANA Native Connector

ABAP class and integration suite for calling the **QubitOn API** from SAP S/4HANA, ECC, or BTP. Real-time validation, batch cleansing, and master-data BAdI integration for address, bank account, and tax verification.

## Table of Contents

- [Why Use This Connector](#why-use-this-connector)
- [How It Works](#how-it-works)
- [Platform Compatibility](#platform-compatibility)
- [API Coverage (6 methods)](#api-coverage-6-methods)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [SAP Integration Points](#sap-integration-points)
- [License](#license)

## Why Use This Connector

| Benefit | Description |
|---------|-------------|
| **Native SAP integration** | Pure ABAP -- no middleware, no external runtimes, no Java stack. Runs inside the ABAP application server alongside your business logic. |
| **Predictable error surface** | The BAdI implementations (`ZCL_IM_APEX_ADDR_CHECK`, `ZCL_IM_APEX_BANK_CHECK`) append entries to `et_return` with message class `ZQUBITON`. Score = 100 → success (`type = 'S'`); score < 100 or no score field in the response → error (`type = 'E'`) and the BP save is blocked. |
| **Real-time and batch** | BAdIs validate during Business Partner save (real-time). Report `ZAPEX_QUBITON_API` validates existing master data in bulk. Both paths share the same `ZCL_QUBITON` class — set `iv_log_enabled = abap_false` in the report for quiet batch runs. |
| **Audit trail built in** | Every API call is logged to SAP Application Log (SLG1) with method, path, HTTP status, and elapsed time. Viewable via SLG1 -- no custom logging code. |
| **ABAP types for BPP data** | Native `TY_ADRC`, `TY_BANK`, `TY_TAX` structures for direct mapping to Business Partner address, bank, and tax data. |
| **abapGit deployable** | Full abapGit-compatible package structure. One-click import into any ABAP system. |
| **No external dependencies** | Uses only `cl_http_client` and `if_http_client` (available since NW 7.0). No `/ui5/`, no CDS, no RAP, no oData. |

## How It Works

```
+-------------------------------------------------------------+
| SAP S/4HANA / ECC / BTP                                     |
|                                                             |
|  +-------------------+  +------------------+               |
|  | Your Code         |  | ZCL_QUBITON      |               |
|  | (BAdI, exit,      |->|                  |               |
|  |  report)          |  | - build_json()   |---- HTTPS ---+|
|  +-------------------+  | - build_*_body() |               |
|                         | - send_request() |               |
|  +-------------------+  | - validate_*()   |               |
|  | Business Partner  |  | - log_api_call() |               |
|  | (BUPA)            |  +------------------+               |
|  +-------------------+          |                          |
|          ^                      v                          |
|  +-------------------+  +------------------+               |
|  | BAdI Implementations|<-| ZIM_*            |               |
|  | (addr/bank/update)  |  | (SXCI BAdIs)     |               |
|  +-------------------+  +------------------+               |
|                                                             |
|  +--------------+                                           |
|  | SM59 / BTP   |--- RFC Destination "QUBITON" ---+        |
|  | Destination  | (type G, SSL, port 443)          |        |
|  +--------------+                                 |        |
+---------------------------------------------------|----+----+
                                                    |    |
                                                    v    v
                                            +------------------+
                                            | api.qubiton.com  |
                                            | (QubitOn API)    |
                                            +------------------+
```

**Data flow**: Your ABAP code → `ZCL_QUBITON` builds the JSON body via the per-endpoint `build_*_body` helpers → sends HTTPS POST via `cl_http_client` through the `QUBITON` RFC destination → receives JSON response → returns the raw JSON to the caller while writing an audit entry (HTTP status + elapsed time) to SLG1 under object `ZQUBITON`.

### Supported Integration Layers

| Integration Point | Class / Object | Description |
|-------------------|--------------|-------------|
| **Address Check BAdI** | `ZCL_IM_APEX_ADDR_CHECK` | `IF_EX_BUPA_ADDR_CHECK~CHECK` -- validates address on BP save |
| **Bank Account Check BAdI** | `ZCL_IM_APEX_BANK_CHECK` | `IF_EX_BUPA_BANK_CHECK~CHECK` -- validates bank account on BP save |
| **General Update BAdI** | `ZCL_IM_IMBP_GENERAL_UPDATE` | `IF_EX_BUPA_GENERAL_UPDATE~CHANGE_BEFORE_UPDATE` -- lifecycle validation |
| **Further Checks** | `ZCL_IM_IM_BUPA_CHECKS` | `IF_EX_BUPA_FURTHER_CHECKS~CHECK_CENTRAL` -- extension point |
| **Batch Report** | `ZAPEX_QUBITON_API` | ALV report for bulk validation of existing master data |

## Platform Compatibility

| Platform | Version | Connectivity | Deployment |
|----------|---------|--------------|------------|
| **SAP S/4HANA** (on-prem) | 1709+ | RFC destination (SM59 type G, SSL) | SE24 or ADT |
| **SAP S/4HANA Cloud** | Any | SAP BTP Destination service | ADT or gCTS |
| **SAP ECC** | 6.0 EHP5+ | RFC destination (SM59 type G, SSL) | SE24 |
| **SAP BTP ABAP Environment** | Any | Communication Arrangement / Destination | ADT |

The class uses only standard ABAP APIs (`cl_http_client`, `if_http_client`) available on all platforms.

**ABAP language level**: Compatible with ABAP 7.40+ (inline declarations, string templates).

## API Coverage (6 methods)

| Category | Method | Description |
|----------|--------|-------------|
| Address | `validate_address` | Postal address validation for 249 countries |
| Bank | `validate_bank_pro` | Bank account validation + premium ownership verification |
| Tax | `validate_tax` | Tax ID validation with live checks and format verification |
| Data Access | `get_bank_details` | Retrieve bank details from Business Partner |
| Data Access | `get_bp_address` | Retrieve address from Business Partner |
| Data Access | `get_tax_details` | Retrieve tax numbers from Business Partner |

> **Note**: This branch (`SAP-S4`) contains a focused subset of the QubitOn API surface scoped to Business Partner validation. The full upstream connector ships 42+ methods across compliance, risk, financial, and ESG categories. See [qubiton-sap/main](https://github.com/qubitonhq/qubiton-sap) for the complete feature set.

### ABAP Types

```abap
" Address structure -- maps to ADRC fields + score/validation result
DATA(ls_addr) = VALUE zcl_qubiton=>ty_adrc(
  country    = 'US'
  street     = '123 Main St'
  city1      = 'Springfield'
  post_code1 = '62701'
  region     = 'IL'
  name1      = 'Apex Analytix, LLC'
).

" Bank structure -- maps to BUPA bank data + score/validation result
DATA(ls_bank) = VALUE zcl_qubiton=>ty_bank(
  banks = 'US'
  bankl = '021000021'
  iban  = 'US64SVBKUS6S3300958879'
).

" Tax structure -- maps to BUPA tax data + score/validation result
DATA(ls_tax) = VALUE zcl_qubiton=>ty_tax(
  taxtype = 'US01'
  taxnum  = '12-3456789'
  country = 'US'
).
```

## Quick Start

The public surface of `ZCL_QUBITON` is exposed as `class-methods` (static), so
calls do not require instantiation. The class-data API key can be set once
at session start (via `CONSTRUCTOR` or by direct assignment) and reused
across every validate call in the same work process.

```abap
" 1. Set the API key once. Either pass it through CONSTRUCTOR ...
NEW zcl_qubiton( iv_apikey = 'your-api-key' ).

"    ... or assign the class-data directly when you don't need to
"    construct an instance (BAdI implementations typically do this
"    in their first call):
zcl_qubiton=>mv_apikey = 'your-api-key'.

" 2. Validate an address — static call, returns the raw JSON string.
DATA(lv_result) = zcl_qubiton=>validate_address(
  iv_address_line1 = '123 Main St'
  iv_city          = 'Springfield'
  iv_state         = 'IL'
  iv_postal_code   = '62701'
  iv_country       = 'US'
).
WRITE: / lv_result.

" 3. Every call writes an audit entry to SLG1 with HTTP status and
"    elapsed time. View via transaction SLG1, object ZQUBITON.
```

The CONSTRUCTOR accepts:

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| `iv_apikey` | `string` | empty | API key (set into `mv_apikey` class-data) |
| `iv_timeout` | `i` | `30` | HTTP request timeout in seconds |
| `iv_log_enabled` | `abap_bool` | `'X'` | Set to `abap_false` to suppress SLG1 logging |

The class is `final` and exposes only static methods after construction, so
you don't need to keep the reference around — calls go through the class
name (`zcl_qubiton=>...`).

Get your API key at [www.qubiton.com](https://www.qubiton.com/auth/register).

## Installation

### abapGit (Recommended)

[abapGit](https://abapGit.org) is the standard package manager for ABAP open source.

1. Open transaction **ZABAPGIT** (standalone) or **SE38 -> ZABAPGIT_STANDALONE**.
2. Click **+ Online** and enter the repository URL:
   ```
   https://github.com/qubitonhq/qubiton-sap.git
   ```
3. Switch to the **SAP-S4** branch and pull.
4. Select a target package (e.g., `ZQUBITON`) and click **Pull**.
5. Activate all imported objects. Activate BAdI implementations via **SE19** (`ZIM_APEX_ADDR_CHECK`, `ZIM_APEX_BANK_CHECK`, `ZIMBP_GENERAL_UPDATE`).

### Manual (SE24)

1. Create the exception class `ZCX_QUBITON` from `src/zcx_qubiton.clas.abap`.
2. Create the core class `ZCL_QUBITON` from `src/zcl_qubiton.clas.abap`.
3. Create BAdI implementation classes:
   - `ZCL_IM_APEX_ADDR_CHECK` -- `src/zcl_im_apex_addr_check.clas.abap`
   - `ZCL_IM_APEX_BANK_CHECK` -- `src/zcl_im_apex_bank_check.clas.abap`
   - `ZCL_IM_IMBP_GENERAL_UPDATE` -- `src/zcl_im_imbp_general_update.clas.abap`
4. Create enhancement projects via **SE19** and activate BAdIs.
5. Create report `ZAPEX_QUBITON_API` from `src/zapex_qubiton_api.prog.abap`.

## SAP Integration Points

| Integration Point | Example | Notes |
|-------------------|---------|-------|
| **Business Partner create/change (BP)** | Real-time address validation during BP save | Wired through `ZCL_IM_APEX_ADDR_CHECK` (BAdI `BUPA_ADDR_CHECK`) — fail-closed: score < 100 or no score in response blocks the save with message `ZQUBITON-001`. |
| **Vendor master (XK01/XK02)** | Bank account + tax number check on vendor save | `ZCL_IM_APEX_BANK_CHECK` (BAdI `BUPA_BANK_CHECK`) calls `validate_bank_pro`, then `validate_tax` if a tax record exists for the partner. |
| **Customer master update** | Tax number format check | Same BAdI path as vendor master, gated by activity `'02'`. |
| **Batch data cleanse** | Validate existing BP records overnight | `ZAPEX_QUBITON_API` ALV report. Select by partner range / created-on / role, choose Address / Bank / Tax mode, run interactively or via SM36 batch job. |

## License

[MIT](LICENSE) -- Copyright (c) 2026 Apex Analytix, LLC
