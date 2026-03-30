# QubitOn API -- SAP S/4HANA Native Connector

ABAP class for calling the **QubitOn API** from SAP S/4HANA, ECC, or BTP.
Full API coverage with 41 methods across validation, compliance, risk, and more.

## Table of Contents

- [Why Use This Connector](#why-use-this-connector)
- [How It Works](#how-it-works)
- [Platform Compatibility](#platform-compatibility)
- [API Coverage (41 methods)](#api-coverage-41-methods)
- [MCP Protocol Support](#mcp-protocol-support)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Documentation](#documentation)
- [License](#license)

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

## How It Works

```
+-------------------------------------------------------------+
|  SAP S/4HANA / ECC / BTP                                    |
|                                                              |
|  +--------------+    +------------------+                    |
|  | Your Code    |--->| ZCL_QUBITON      |                    |
|  | (BADI, exit, |    |                  |                    |
|  |  report, CPI)|    | - build_json()   |---- HTTPS ---+    |
|  +--------------+    | - send_request() |              |    |
|                      | - parse_result() |              |    |
|  +--------------+    | - log_api_call() |              |    |
|  | SLG1 App Log |<---| - handle_result()|              |    |
|  +--------------+    +------------------+              |    |
|                                                        |    |
|  +--------------+    +------------------+              |    |
|  | PFCG Roles   |--->| ZQUBITON_API     |              |    |
|  +--------------+    | (auth object)    |              |    |
|                      +------------------+              |    |
|  +--------------+                                      |    |
|  | SM59 / BTP   |--- RFC Destination "QubitOn" ---+    |    |
|  | Destination  |    (type G, SSL, port 443)      |    |    |
|  +--------------+                                 |    |    |
+---------------------------------------------------+----+----+
                                                    |    |
                                                    v    v
                                         +------------------+
                                         | api.qubiton.com  |
                                         | (QubitOn API)    |
                                         +------------------+
```

**Data flow**: Your ABAP code -> `ZCL_QUBITON` builds JSON -> sends HTTPS POST/GET via `cl_http_client` through an RFC destination -> receives JSON response -> optionally parses validity and issues SAP messages -> logs to BAL.

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

**ABAP language level**: Compatible with ABAP 7.40+ (inline declarations, string templates). For older ECC systems on 7.02-7.31, replace `DATA(...)` inline declarations with explicit `DATA` statements.

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
      iv_country       = 'US' ).
    WRITE: / lv_result.
  CATCH zcx_qubiton INTO DATA(lx_err).
    WRITE: / 'Error:', lx_err->get_text( ).
ENDTRY.
```

Get your free API key at [www.qubiton.com](https://www.qubiton.com/auth/register).

## Installation

### abapGit (Recommended)

[abapGit](https://abapGit.org) is the de facto package manager for ABAP open source.

1. Open transaction **ZABAPGIT** (standalone) or **SE38 -> ZABAPGIT_STANDALONE**.
2. Click **+ Online** and enter the repository URL:
   ```
   https://github.com/qubitonhq/qubiton-sap.git
   ```
3. Select a target package (e.g., `ZQUBITON`) and click **Pull**.
4. Activate all imported objects.

This imports all classes, message class, config tables, authorization object, and application log object in one step.

### Manual (SE24)

1. Download the latest [release](https://github.com/qubitonhq/qubiton-sap/releases).
2. Create each class in **SE24** in dependency order:
   - `ZCX_QUBITON` — Exception class
   - `ZCL_QUBITON` — Core API client
   - `ZCL_QUBITON_SCREEN` — Screen enhancement orchestrator
   - `ZCL_QUBITON_BADI_VENDOR` — Vendor BAdI
   - `ZCL_QUBITON_BADI_CUSTOMER` — Customer BAdI
   - `ZCL_QUBITON_BADI_BP` — Business Partner BAdI
3. Create message class `ZCL_QUBITON_MSG` in **SE91**, config tables in **SE11**, auth object in **SU21**.

### ADT (Eclipse)

1. In Eclipse with ADT, open **Window > Show View > Other > abapGit Repositories**.
2. Click **+** and enter `https://github.com/qubitonhq/qubiton-sap.git`.
3. Select target package and pull.

## Documentation

| Document | Description |
|----------|-------------|
| [Setup & Connectivity](docs/setup.md) | API key, BTP destination, RFC destination (SM59), CPI iFlow |
| [Configuration](docs/configuration.md) | Constructor params, error modes, handle_result, real-time vs. batch, JSON parsing |
| [Usage Examples](docs/examples.md) | ABAP code examples for all 41 API methods |
| [Screen Enhancements](docs/screen-enhancements.md) | BAdI setup, config table (SM30), tax auto-detection, bank field mapping |
| [Authorization & Logging](docs/authorization.md) | ZQUBITON_API auth object, SLG1 application logging |
| [SAP Certification](docs/sap-certification.md) | ICC readiness, marketplace publishing, object inventory, complete setup steps |

## License

[MIT](LICENSE) -- Copyright (c) 2026 apexanalytix
