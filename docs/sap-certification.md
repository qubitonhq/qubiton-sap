# SAP Certification & Marketplace Readiness

This connector is designed for SAP certification (ICC) and SAP Store / SAP Business Technology Platform marketplace distribution.

## SAP Certification Requirements

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

## SAP Store / Marketplace Publishing

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

## Object Inventory

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

## Complete Setup Steps

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
13. **PFCG** — Assign `ZQUBITON_API` authorization to user roles (activities: 01-06 or `*`)
14. Run ABAP Unit tests via **SE80** or `Ctrl+Shift+F10` in ADT

## Running Unit Tests

```
" Via ADT (ABAP Development Tools in Eclipse):
Right-click ZCL_QUBITON_TEST -> Run As -> ABAP Unit Test
Right-click ZCL_QUBITON_SCREEN_TEST -> Run As -> ABAP Unit Test

" Via SE80:
Navigate to package ZQUBITON -> Run All Unit Tests

" Expected: 71 tests, 0 failures
```
