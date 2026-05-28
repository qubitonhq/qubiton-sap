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
| **Zero-code error handling** | Configure stop/warn/silent behavior via constructor parameters. SAP admins control what happens on API errors or validation failures -- no TRY/CATCH needed for standard use. |
| **Real-time and batch** | BAdIs validate during Business Partner save (real-time). Report `ZAPEX_QUBITON_API` validates existing master data in bulk. Same class -- flip `iv_on_error` and `iv_on_invalid` for silent or strict mode. |
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
|  +-------------------+  | - send_request() |               |
|                         | - parse_result() |               |
|  +-------------------+  | - log_api_call() |               |
|  | Business Partner  |  | - handle_result()|               |
|  | (BUPA)            |  +------------------+               |
|  +-------------------+          |                          |
|          ^                      v                          |
|  +-------------------+  +------------------+               |
|  | BAdI Implementations|<-| ZIM_*            |               |
|  | (addr/bank/update)  |  | (SXCI BAdIs)     |               |
|  +-------------------+  +------------------+               |
|                                                             |
|  +--------------+                                           |
|  | SM59 / BTP   |--- RFC Destination "QubitOn" ---+        |
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

**Data flow**: Your ABAP code -> `ZCL_QUBITON` builds JSON -> sends HTTPS POST/GET via `cl_http_client` through an RFC destination -> receives JSON response -> parses validity -> logs to BAL.

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

```abap
" 1. Create instance with your API key
DATA(lo_api) = NEW zcl_qubiton( iv_apikey = 'your-api-key' ).

" 2. Validate an address
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

| Integration Point | Example | Recommended Config |
|-------------------|---------|---------------------|
| **Business Partner create/change (BP)** | Real-time address validation during BP save | `on_error='W'`, `on_invalid='E'` |
| **Vendor master (XK01/XK02)** | Address + bank check on vendor save via address BAdI | `on_error='W'`, `on_invalid='E'` |
| **Customer master update** | Tax number format check | `on_error='W'`, `on_invalid='W'` |
| **Batch data cleanse** | Validate 10,000 existing BP records overnight | `on_error='S'`, `on_invalid='S'` |

## License

[MIT](LICENSE) -- Copyright (c) 2026 Apex Analytix, LLC
