# QubitOn API -- SAP S/4HANA Native Connector

ABAP class for calling the **QubitOn API** from SAP S/4HANA, ECC, or BTP.
Full API coverage with 42 methods across validation, compliance, risk, and more.

## Table of Contents

- [Why Use This Connector](#why-use-this-connector)
- [How It Works](#how-it-works)
- [Platform Compatibility](#platform-compatibility)
- [API Coverage (42 methods)](#api-coverage-42-methods)
- [MCP Protocol Support](#mcp-protocol-support)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Documentation](#documentation)
- [Other Integrations](#other-integrations)
- [FAQ](#faq)
- [License](#license)

## Why Use This Connector

| Benefit | Description |
|---------|-------------|
| **Native SAP integration** | Pure ABAP — no middleware, no external runtimes, no Java stack. Runs inside the ABAP application server alongside your business logic. |
| **Zero-code error handling** | Configure stop/warn/silent behavior via constructor parameters. SAP admins control what happens on API errors or validation failures — no TRY/CATCH needed for standard use. |
| **Real-time and batch** | Use in BADIs, user exits, and screen PAI for real-time validation during data entry. Use in reports and BDCs for mass cleansing. Same class — flip `iv_keep_alive=abap_true` for batch connection reuse, `iv_on_invalid='S'` for silent mode. |
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

## API Coverage (42 methods)

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
2. Create each class in **SE24** using the ABAP source files from the `src/` directory, in dependency order:
   - `ZCX_QUBITON` — Exception class (`src/zcx_qubiton.clas.abap`)
   - `ZCL_QUBITON` — Core API client (`src/zcl_qubiton.clas.abap`)
   - `ZCL_QUBITON_SCREEN` — Screen enhancement orchestrator (`src/zcl_qubiton_screen.clas.abap`)
   - `ZCL_QUBITON_BADI_VENDOR` — Vendor BAdI (`src/zcl_qubiton_badi_vendor.clas.abap`)
   - `ZCL_QUBITON_BADI_CUSTOMER` — Customer BAdI (`src/zcl_qubiton_badi_customer.clas.abap`)
   - `ZCL_QUBITON_BADI_BP` — Business Partner BAdI (`src/zcl_qubiton_badi_bp.clas.abap`)
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
| [Usage Examples](docs/examples.md) | ABAP code examples for all 42 API methods |
| [Screen Enhancements](docs/screen-enhancements.md) | BAdI setup, config table (SM30), tax auto-detection, bank field mapping |
| [Authorization & Logging](docs/authorization.md) | ZQUBITON_API auth object, SLG1 application logging |
| [SAP Certification](docs/sap-certification.md) | ICC readiness, marketplace publishing, object inventory, complete setup steps |

## Other Integrations

QubitOn provides native connectors and SDKs for other platforms:

| Connector | Platform | Language | Repo |
|-----------|----------|----------|------|
| **Go SDK** | Any platform | Go | [qubiton-go](https://github.com/qubitonhq/qubiton-go) |
| **Oracle** | Oracle DB 11g+, EBS, Fusion | PL/SQL | [qubiton-oracle](https://github.com/qubitonhq/qubiton-oracle) |
| **NetSuite** | All NetSuite editions | SuiteScript 2.1 | [qubiton-netsuite](https://github.com/qubitonhq/qubiton-netsuite) |
| **QuickBooks Online** | QuickBooks Online | TypeScript | [qubiton-quickbooks](https://github.com/qubitonhq/qubiton-quickbooks) |

Plus 30+ pre-built integrations for Salesforce, HubSpot, Snowflake, Databricks, Zapier, Make, and more at [www.qubiton.com/integrations](https://www.qubiton.com/integrations).

## FAQ

### Does it support real-time and batch processing?

Yes — same `ZCL_QUBITON` class, different config. For real-time, use one of the three pre-built BAdIs (`ZCL_QUBITON_BADI_VENDOR`, `..._CUSTOMER`, `..._BP`) which hook into XK01/XK02/FK01/FK02 (and BP) save events and can block the save when validation fails. For batch (mass cleansing reports, BDC, LSMW), instantiate the class with `iv_keep_alive = abap_true` for HTTP connection reuse across thousands of records and `iv_on_invalid = 'S'` for silent mode where the report checks results itself instead of issuing user messages.

See [docs/configuration.md](docs/configuration.md) for the full constructor parameter list.

### How customizable is the workflow integration?

Two layers: config-driven at runtime, plus open extension points for deeper customization.

- **Configuration (no code)**: SM30 tables `ZQUBITON_CONFIG` and `ZQUBITON_SCREEN_CFG` control which validators run on save and how SAP fields map to API parameters. Per-call result policy is parameterised — `'E'` block save, `'W'` warn but allow, `'S'` silent (caller checks result). Same three modes apply to API errors so a transient network outage can soft-warn instead of blocking the user.
- **Extension (small ABAP)**: The three BAdI implementations are open extension points — copy them into your own Z-class and add custom field mapping, conditional skip logic, or downstream actions (workflow trigger, ALV log, IDoc post-processing). The shared `ZCL_QUBITON_SCREEN->validate_vendor_all()` orchestrator can also be called directly from any user exit, BTE, or report.

See [docs/screen-enhancements.md](docs/screen-enhancements.md) for BAdI activation steps and config table fields.

### What happens if `api.qubiton.com` is unreachable?

The connector degrades by config. With `iv_on_error = 'W'` (default), the user sees a warning message and the transaction continues — vendor master save proceeds without validation. With `iv_on_error = 'S'`, no message is issued and the failure is logged silently to SLG1. Set `iv_on_error = 'E'` only if validation is mandatory and you'd rather block the save than risk an unvalidated record.

### How is access controlled?

Two mechanisms. The optional ABAP authorization object `ZQUBITON_API` (PFCG-managed) gates which user roles can call which validation categories — validate vs. screen vs. lookup. Underneath, the QubitOn API key itself is plan-gated; endpoint access depends on subscription tier.

### Where's the audit trail?

Every API call is logged to SAP Application Log (SLG1) under object `ZQUBITON`, subobject `ZAPI_CALL`. Each entry captures method name, endpoint path, HTTP status, elapsed time, and the user/transaction context. View via SLG1 transaction or query table `BAL_HDR` directly. No custom logging code required.

### How do I configure SSL trust for `api.qubiton.com` in STRUST?

`api.qubiton.com` uses Let's Encrypt certificates which rotate every ~90 days. To avoid re-importing the leaf certificate every quarter, import the **Let's Encrypt CA chain** into STRUST once — ISRG Root X1 (root) and the active intermediate (R10/R11). Both are stable for years. Once the chain is trusted, every leaf rotation is transparent and no manual update is needed.

Steps:

1. Download the root and intermediate from [letsencrypt.org/certificates/](https://letsencrypt.org/certificates/) (use the `.der` or `.pem` files, not a browser-exported leaf cert)
2. STRUST → SSL Client (Anonymous) → Import Certificate → select each file → Add to Certificate List → Save
3. Restart ICM (`SMICM` → Administration → ICM → Exit Soft Global)

This is the same pattern SAP shops use to trust Salesforce, AWS, Ariba, and any other public HTTPS endpoint. Trust the CA, not the leaf.

### What's the per-call latency? Will it slow down vendor save?

Typical end-to-end roundtrip is 200-500 ms (HTTPS POST + JSON parse + API processing + return), plus ~10-20 ms ABAP overhead inside the BAdI. For batch jobs, set `iv_keep_alive = abap_true` to reuse the HTTPS connection across calls — eliminates the TLS handshake (~100 ms saved per record after the first). For very large batches (10K+ records), call the API in groups of 50-100 records using the bulk endpoints where available (`validate_address` accepts an array via the bulk variant).

If validation latency is unacceptable for interactive transactions, use `iv_on_error = 'W'` and run validation asynchronously via a background job (e.g., scheduled hourly batch over recent vendor master changes via `LFA1.UPDAT`).

### How do I transport SM30 config from DEV to QAS to PRD?

Tables `ZQUBITON_CONFIG` and `ZQUBITON_SCREEN_CFG` are delivered as customizing tables (delivery class C). When you maintain entries via SM30, SAP prompts for a customizing transport request — record entries on a customizing request and release through the standard CTS pipeline (DEV → QAS → PRD).

The class itself, BAdI implementations, message class, auth object, and SLG application log object are workbench objects (delivery class A) — recorded on workbench transports during abapGit pull or SE24/SE19 changes.

If you've cloned the BAdIs into your own namespace (recommended for production), record those Z-classes on workbench requests too.

### Where is data sent? Is it logged with PII?

Every API call goes to `https://api.qubiton.com` (TLS 1.2+, US/EU regions depending on subscription). The connector sends only the fields required for the specific validation — vendor name + tax ID for tax validation, account number + bank routing for bank validation, etc. SLG1 logs do not include request/response payloads by default; only method, path, HTTP status, and elapsed time. If you need full payload logging for debugging, set `iv_log_enabled = abap_true` and review the BAL configuration in [docs/authorization.md](docs/authorization.md).

For GDPR and data residency: data sent to QubitOn is processed under our [Privacy Policy](https://www.apexanalytix.com/privacy-policy/).

### Does it work in S/4HANA Public Cloud (RISE / Cloud Public Edition)?

Yes. Configure connectivity via the SAP BTP Destination service rather than SM59 (which isn't available in Cloud Public Edition). Create an HTTP destination named `QubitOn` pointing at `https://api.qubiton.com` with the API key in a `Authorization: Bearer <key>` header property. The connector picks up the destination by name regardless of whether it resolves to SM59 (on-prem) or BTP (cloud).

The BAdI implementations work unchanged on Cloud Public Edition — `IF_EX_VENDOR_ADD_DATA_CS` and equivalents are released cloud-compatible BAdIs. Custom Z-extensions need to be deployed via gCTS or ADT (no SE19 in cloud).

See [docs/setup.md](docs/setup.md) for BTP destination setup.

## License

[MIT](LICENSE) -- Copyright (c) 2026 apexanalytix
