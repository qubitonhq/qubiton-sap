# Transaction-Level Validation

Inline validation of QubitOn API checks during transactional document entry — purchase orders, vendor invoices, outgoing payments, payment proposals — in addition to the master-data save hooks already shipped (XK01/XK02, FK01/FK02, BP).

This guide covers:

- **When to use which hook** (inline vs batch, blocking vs warning)
- **How to wire the BAdI / enhancement per SAP version**
- **The kill switches and per-transaction config knobs**
- **Reference implementations** that you copy and adapt

## Why this exists

The master-data BAdIs (`ZCL_QUBITON_BADI_VENDOR`, `..._CUSTOMER`, `..._BP`) catch issues when a record is created, but a vendor's risk posture changes constantly:

- A supplier that was clean six months ago may show up on an OFAC sanctions list today
- A vendor's domain may have been compromised since onboarding
- A subcontractor's beneficial owner may have changed

Re-validating at the **point of transaction** (PO save, invoice posting, payment release) catches these without requiring a re-screening of every active vendor every night. The user's experience is unchanged — they enter a PO normally — but the system blocks or warns based on the current risk picture.

## On / off control

Two layers, both administrator-controlled, no transports needed:

### 1. Master kill switch — `ZQUBITON_CONFIG.TXN_VALIDATION_ENABLED`

```sql
-- Turn ON every transactional BAdI in the connector
UPDATE zqubiton_config SET config_value = 'X'
 WHERE config_key = 'TXN_VALIDATION_ENABLED'.

-- Turn OFF every transactional BAdI in the connector
UPDATE zqubiton_config SET config_value = ''
 WHERE config_key = 'TXN_VALIDATION_ENABLED'.
```

Each transactional BAdI checks this row at the very start of its `CHECK` method. When disabled the BAdI returns immediately — no LFA1 read, no API call, no log write. **Use this as the emergency-off lever.**

The master-data BAdIs (`VENDOR_ADD_DATA_CS`, etc.) are not affected by this switch — they have their own toggles via `ZQUBITON_SCREEN_CFG`.

### 2. Per-transaction config — `ZQUBITON_SCREEN_CFG`

Granular control. One row per `(tcode, val_type)` pair:

| TCODE  | VAL_TYPE | ACTIVE | ON_INVALID | ON_ERROR | Use case |
|--------|----------|:------:|:----------:|:--------:|----------|
| ME21N  | SANCTION | X      | E          | W        | PO save: block on sanctions match, warn on API outage |
| ME21N  | CYBER    | X      | W          | S        | PO save: warn on low cyber score, silent on API outage |
| MIRO   | SANCTION | X      | E          | W        | Invoice posting: block on sanctions |
| MIRO   | UBO      |        | W          | S        | Disabled — UBO check on invoice would be too noisy |
| F-58   | SANCTION | X      | E          | E        | Payment release: block on sanctions AND on API outage |
| F110   | SANCTION | X      | S          | S        | Payment proposal: silently filter sanctioned payees from the run |

Maintain via SM30 → table `ZQUBITON_SCREEN_CFG`. Records go on a customizing transport request and follow the standard CTS pipeline (DEV → QAS → PRD).

## Inline vs batch — pick the right hook

### Decision matrix

| Stake level | Recommended pattern | Hook | User experience |
|---|---|---|---|
| **Block-the-bad-actor** (sanctions, blacklist) | **Inline blocking** (`ON_INVALID = 'E'`) | BAdI `CHECK` method on the relevant transaction | User sees red error message, save aborts |
| **Warn-and-route** (cyber, risk score, beneficial-owner change) | **Inline warning** (`ON_INVALID = 'W'`) + standard SAP release strategy | BAdI `CHECK` + Z-field on header for downstream release-strategy criterion | User sees yellow warning, save proceeds, release rule kicks in |
| **Telemetry / quality** (address completeness, phone format) | **Inline silent** (`ON_INVALID = 'S'`) | BAdI `CHECK`, write to BAL / Z-table | Save proceeds normally, ops team reviews via SLG1 |
| **Cleanup / mass screening** (every-vendor sanctions sweep) | **Batch** | Background job or BDC over `LFA1` / `LFB1` / open POs / open invoices | No user impact; nightly summary email |

### Why batch matters even when inline exists

- **Sanctions lists change every day**, but a vendor used in last month's PO is still in your books. Inline catches new POs; batch catches existing exposure.
- **API outages**: inline calls degrade to "warn + allow" by default. Batch re-runs catch what was missed during the outage.
- **Bulk-load scenarios** (LSMW, EDI, CPI inbound) bypass the dialog screens — inline BAdIs don't fire on batch input. Catch these via batch.

### Recommended pattern: inline + nightly batch

```text
On-line dialog flow      ┌──────────────────────────┐
   ME21N save  ────────► │ ZCL_QUBITON_BADI_PO      │
   MIRO save   ────────► │ (inline CHECK; high-     │
   F-58 save   ────────► │  stakes only — sanctions)│
                         └──────────────────────────┘

Bulk / EDI / migration    ┌──────────────────────────┐
   IDoc inbound ─────────►│ NO BAdI fires            │
   CPI inbound  ─────────►│  (legitimately bypassed) │
                         └──────────────────────────┘
                                     │
                                     ▼
Nightly batch job        ┌──────────────────────────┐
   /USR1/ZQUBITON_SWEEP  │ Walks open POs / invoices │
   (background, silent)  │ Re-runs sanctions check  │
                         │ Posts SLG1 entries on    │
                         │ misses; emails ops       │
                         └──────────────────────────┘
```

The reference inline BAdI (`ZCL_QUBITON_BADI_PO`) is shipped in this connector. The batch sweep is a customer-specific report that you build using `ZCL_QUBITON->check_sanctions(...)` over a SELECT on `EKKO`/`RBKP`/`PAYR`. A skeleton is in [#batch-sweep-skeleton](#batch-sweep-skeleton) below.

## Per-document hooks

### Purchase Order — `ME21N` / `ME22N` / `ME29N`

**BAdI**: `ME_PROCESS_PO_CUST`  → interface `IF_EX_ME_PROCESS_PO_CUST`
**Reference class**: [`ZCL_QUBITON_BADI_PO`](../src/zcl_qubiton_badi_po.clas.abap)

The `CHECK` method receives `IM_HEADER` (`REF TO IF_PURCHASE_ORDER_MM`); call `IM_HEADER->get_data( )` to get the `MEPOHEADER` structure (vendor LIFNR, company code, doc date, PO type). Set `CH_FAILED = abap_true` to block save.

```abap
METHOD if_ex_me_process_po_cust~check.
  IF zcl_qubiton_screen=>get_config_value( 'TXN_VALIDATION_ENABLED' ) <> 'X'.
    RETURN.
  ENDIF.

  DATA(ls_header) = im_header->get_data( ).
  IF ls_header-lifnr IS INITIAL. RETURN. ENDIF.   " stock transfer — skip

  IF check_po_vendor( iv_lifnr = ls_header-lifnr
                      iv_bukrs = ls_header-bukrs ) = abap_true.
    ch_failed = abap_true.
  ENDIF.
ENDMETHOD.
```

**Activation**: SE19 → BAdI Implementation → BAdI definition `ME_PROCESS_PO_CUST` → name `ZIM_QUBITON_PO` → implementing class `ZCL_QUBITON_BADI_PO`.

The interface has 13 methods. The reference class implements only `CHECK` meaningfully; the other 12 are required empty stubs (the BAdI framework requires every interface method to be implemented, even when no logic runs).

### Vendor invoice — `MIRO` / `FB60`

**BAdI**: `INVOICE_UPDATE` (`IF_EX_INVOICE_UPDATE`) — `CHANGE_AT_SAVE` method.

Get the invoice via the `IM_RBKPV` import structure (vendor LIFNR is `IM_RBKPV-LIFNR`). Block save by raising `MESSAGE TYPE 'E'` from the method body — the framework propagates it as a save failure.

Pattern (you build this in your project):

```abap
METHOD if_ex_invoice_update~change_at_save.
  IF zcl_qubiton_screen=>get_config_value( 'TXN_VALIDATION_ENABLED' ) <> 'X'.
    RETURN.
  ENDIF.

  IF check_invoice_vendor( iv_lifnr = im_rbkpv-lifnr ) = abap_true.
    MESSAGE e007(zcl_qubiton_msg) WITH im_rbkpv-lifnr.   " your project's text
  ENDIF.
ENDMETHOD.
```

> **Note**: `INVOICE_UPDATE` differs from `MRM_HEADER_CHECK` (older ECC 6.0) and `MRMP_BAPI_BADI` (BAPI flow). In modern S/4HANA on-prem, `INVOICE_UPDATE` covers MIRO, MIR4 (park), and FB60. Verify which BAdI is firing in your release using SE18 → BAdI definition → "Display where used".

### Outgoing payment — `F-58` / `FBZ8`

**Two viable hooks depending on your release:**

| Release | BAdI / exit |
|---|---|
| ECC 6.0 EHP5+ | `BADI_LAYER_PAYMENT_DOCUMENT` (`IF_EX_BADI_LAYER_PAYMENT_DOC`) |
| S/4HANA on-prem 1709+ | `FAGL_PAYMENT_BUNDLE` plus `FI_PAYMENT_DOCUMENT_BADI` |

Read the payee from the payment document header (`PAYR-LIFNR` for vendor payments). Block by raising MESSAGE TYPE 'E' on a sanctions hit. **Recommended `ON_INVALID = 'E'` AND `ON_ERROR = 'E'` for payment** — this is the last chance to stop a sanctioned payment from leaving the bank.

### Payment proposal — `F110`

**BAdI**: `BADI_PAYMENT_RECOMMENDATION` (modern). Legacy ECC: function-module exit `F110_USER_EXIT_004` in enhancement project `RFFOX011`.

Unlike PO/invoice/payment-entry, the right pattern here is **silent filter**, not block:

```abap
METHOD if_ex_payment_recommendation~filter.
  " Drop sanctioned payees from the proposal silently.  Do NOT abort the
  " whole F110 run — that would block hundreds of legitimate payees too.
  LOOP AT ct_payment_recommendation INTO DATA(ls_pmt).
    IF check_pmt_sanctions( iv_lifnr = ls_pmt-lifnr ) = abap_true.
      DELETE ct_payment_recommendation.
      " Append to a Z-log table so AP can see why.
      INSERT VALUE #( lifnr = ls_pmt-lifnr reason = 'SANCTIONED' ts = sy-uzeit ) INTO TABLE gt_blocked_log.
    ENDIF.
  ENDLOOP.
ENDMETHOD.
```

This way the F110 run completes; sanctioned vendors are simply excluded; AP gets a daily report of who got dropped and why.

## Best-practice fail-mode policy

Different transactions have different risk tolerances. The connector defaults shown below are reasonable starting points; tune them for your business:

| Transaction | SANCTION on_invalid | CYBER on_invalid | API on_error | Rationale |
|---|:---:|:---:|:---:|---|
| ME21N PO save | E (block) | W (warn) | W (warn, allow) | PO is reversible. Allow save when API is down; manual review later. |
| MIRO invoice | E (block) | S (silent) | W (warn, allow) | Block sanctioned payees. Cyber risk doesn't add new info at invoice time. |
| F-58 payment release | E (block) | E (block) | **E (block)** | Last chance. Even if API is down, hold the payment. |
| F110 proposal | filter | warn | filter (drop) | Filter pattern — never abort the run. |
| Mass batch | E (log) | W (log) | W (log) | Off-line — log everything, alert ops. |

## Caching

Don't re-screen the same vendor 100 times during a multi-line PO save. The reference BAdI calls `validate_vendor_all` once per `CHECK` invocation; if you have multiple BAdIs that all want the sanctions check on the same vendor in the same dialog step, add a session cache keyed on `(LIFNR, validation type)` with a 5-minute TTL.

```abap
" Sketch — full implementation in your project
DATA(lv_cache_key) = |{ iv_lifnr }-SANCTION|.
DATA(lv_cached) = SY-CPROG. " or use SHARED MEMORY / cl_abap_session_cache
" check the cache before calling the API
```

For batch jobs, the QubitOn API itself caches results server-side for 24 hours per (vendor, validation type). Re-running the nightly sweep is cheap.

## Approval routing instead of hard-block

For warning-tier validations (cyber score below threshold, beneficial-owner change since last screening), prefer **routing the document into an additional release tier** rather than hard-blocking. SAP's standard release-strategy framework covers this for POs (release codes), invoices (block-and-release), and payments (payment block).

**Pattern**: BAdI sets a Z-field on the PO header with the risk verdict, the standard release-strategy classification reads that Z-field, the strategy routes the PO to a higher-tier approver. The user is never blocked — they save normally — but the PO can't get to the supplier without the approver's sign-off.

This is the right pattern for "scary but not deal-breaking" signals. It keeps the connector out of the procurement-policy debate.

## Batch sweep skeleton

For nightly batch validation of open documents:

```abap
REPORT  Z_QUBITON_NIGHTLY_SWEEP.

PARAMETERS p_dryrun TYPE flag DEFAULT 'X'.   " safe-mode default

DATA: lt_lifnr_open TYPE TABLE OF lifnr.

" 1. Pull all unpaid open POs, invoices, payment recs from the last 30 days
SELECT DISTINCT lifnr FROM ekko
  INTO TABLE lt_lifnr_open
  WHERE bedat >= sy-datum - 30
    AND loekz = ''.

" 2. Run sanctions on each, write SLG1 entries
DATA(lo_api) = NEW zcl_qubiton(
  iv_apikey      = zcl_qubiton_screen=>get_apikey( )
  iv_on_error    = 'S'
  iv_on_invalid  = 'S'
  iv_log_enabled = abap_true ).

LOOP AT lt_lifnr_open INTO DATA(lv_lifnr).
  " ... map LFA1 → ty_vendor_data, call check_vendor_sanctions ...
  " ... emit BAL log entry on each match for ops review
ENDLOOP.
```

Schedule via SM37 to run daily. Send a summary email to the AP team using `BCS_API` or `BCS_EXAMPLE_*`.

## Per-version compatibility

| Release | `ME_PROCESS_PO_CUST` | `INVOICE_UPDATE` | `BADI_LAYER_PAYMENT_DOCUMENT` | `BADI_PAYMENT_RECOMMENDATION` |
|---|:---:|:---:|:---:|:---:|
| ECC 6.0 EHP5+ | ✅ | ✅ (alongside `MRM_HEADER_CHECK`) | ✅ | ❌ — use `F110_USER_EXIT_004` |
| S/4HANA on-prem 1709+ | ✅ | ✅ | ✅ (renamed in 2023; check SE18) | ✅ |
| **S/4HANA Cloud Private Edition** | ✅ same as on-prem | ✅ same as on-prem | ✅ same as on-prem | ✅ same as on-prem |
| **S/4HANA Cloud Public Edition** | use cloud-released equivalent — see below | not yet released — use Integration Suite pattern | not released — use Integration Suite | not released — use Integration Suite |

**The reference classes shipped here target ECC, on-prem, and Private Cloud.** Public Cloud requires a different approach — see the next section.

## S/4HANA Cloud Public Edition — three viable patterns

Public Cloud restricts the classic enhancement framework. The on-prem `ME_PROCESS_PO_CUST` BAdI is **not in the released-BAdI set**, and HTTPS callouts from inside released BAdIs are tightly constrained (need a registered Communication Arrangement; direct `cl_http_client` is blocked). Three patterns work for Cloud Public Edition customers, ranked by recommendation:

### Pattern A (preferred) — async via SAP Integration Suite

The pattern SAP itself recommends for transaction-time validation in Cloud Public Edition. No ABAP development required.

```
┌──────────────┐    Event         ┌────────────────────┐   HTTPS    ┌─────────────────┐
│ S/4HANA      │  (PO created /   │  SAP Integration   │ ─────────► │ QubitOn API     │
│ Public Cloud │   changed —      │  Suite (CPI iFlow) │            │ /api/sanctions  │
│              │   business event)│                    │ ◄───────── │                 │
└──────┬───────┘                  └────────┬───────────┘   verdict  └─────────────────┘
       │                                   │
       │  (a) write back to                │
       │      PO header Z-field            │
       │  (b) raise standard release       │
       │      strategy on threshold        │
       │  (c) post a workflow              │
       │      task for high-risk POs       │
       │◄──────────────────────────────────┘
       │
       ▼
   PO is now in
   "pending review"
   release tier
```

What you build:
- An iFlow on SAP Integration Suite that subscribes to the `Sales/Procurement Event` topic
- The iFlow calls `https://api.qubiton.com/api/sanctions/check` (or any other QubitOn API method) with vendor data extracted from the event
- On a sanctions hit, the iFlow either (a) posts back to the PO via OData updating a Z-extension field, (b) sends a Workflow task to the AP team for review, or (c) emits a notification

**Why this is the recommended cloud pattern**: it does not require modifying the released ABAP layer, it scales independently, and it's the official SAP architecture for cross-system validation in Public Cloud.

### Pattern B — released cloud BAdI (PO save only, currently)

For purchase orders, SAP did release a cloud-extensible BAdI: `BD_MMPUR_FINAL_CHECK_PO` (interface `IF_EX_BD_MMPUR_FINAL_CHECK_PO`). Customers register implementations via the Fiori app *Custom Fields and Logic*.

> **Verification status — read this before adopting**: the released-BAdI catalogue for Public Cloud is not consolidated in one place by SAP, and the exact interface signature varies across cloud release waves (CE 2308 / 2402 / 2502+). The QubitOn team has not validated this BAdI against a specific cloud system — adopt with care, confirm the interface in your tenant's Fiori app *Custom Fields and Logic*, and test in a sandbox release before promoting. We have an open work item to ship a verified cloud-tested reference; track it in the [SAP Certification doc](sap-certification.md).

What you'd do (pattern, not verified code):

1. In Fiori app *Custom Fields and Logic* → BAdIs tab → search `BD_MMPUR_FINAL_CHECK_PO`
2. Create an implementation, paste the cloud-restricted ABAP
3. The cloud implementation cannot use `cl_http_client` directly; instead it consumes a **Communication Arrangement** that proxies to the QubitOn API
4. Communication Arrangement uses Communication Scenario `SAP_COM_0276` (HTTP Outbound) pointing at `https://api.qubiton.com`
5. The cloud BAdI calls the proxy; on a sanctions hit raises a message that S/4 Cloud surfaces in the PO Fiori app

For invoice and payment, **no released cloud BAdI is currently available**. Use Pattern A (Integration Suite) for those.

### Pattern C — side-by-side extension on SAP BTP

For more complex flows (e.g. multi-step risk scoring with internal approval routing), build a side-by-side extension app on SAP BTP ABAP Environment (Steampunk) or BTP Cloud Foundry. Subscribe to S/4 Cloud business events, run the validation logic in your own runtime, post results back via OData to S/4 Cloud Z-extension fields.

This is the most flexible but also the most expensive pattern. Recommended only when you need stateful logic across multiple validations.

### Cloud Public Edition decision tree

```
Validation event happens in S/4 Cloud Public Edition
                    │
        ┌───────────┴───────────┐
        │                       │
   Synchronous block            │
   absolutely required?         │
        │                       │
       Yes                      No
        │                       │
   Pattern B                    │
   (released BAdI               │
    if available;               │
    PO save only today)         │
                                │
                  ┌─────────────┴─────────────┐
                  │                           │
            Simple verdict                 Complex
            write-back?                    workflow?
                  │                           │
            Pattern A                     Pattern C
            (Integration                  (BTP side-by-side
             Suite iFlow)                  extension)
```

### Workflow integration — SWIE, BRF+, BTE

The reference BAdIs above can block a save with a hard `MESSAGE TYPE 'E'`. For everything in between (route, approve, soft-warn-with-policy), the connector now ships three additional integration helpers that plug in alongside the BAdIs:

### SWIE — Workflow event raiser (`zcl_qubiton_workflow`)

Raises a SAP Business Workflow event when a validation produces a "warn" or "route" verdict. A customer-defined workflow template picks up the event and routes a decision task to the right approver group, instead of the user being hard-blocked.

```abap
" Inside a BAdI's CHECK method, when sanctions verdict is "route, don't block":
DATA(lo_wf) = NEW zcl_qubiton_workflow( ).
lo_wf->raise_po_risk(
  iv_ebeln  = ls_header-ebeln
  is_result = ls_validation_result ).
" PO save proceeds normally; the workflow template now owns the approval flow.
```

What the customer wires up:

1. **Object type** — SE11/SWO1 → activate `ZQUBITON_DOC` (or `_PO`/`_INV`/`_PAY` per document)
2. **Event linkage** — SWE2 → register `ZQUBITON_PO/RISK_DETECTED` against your workflow template (`WS9000xxxx`)
3. **Workflow template** — PFTC → build a template that:
   - Reads the validation result from the event container
   - Branches on severity (sanctions = stop, cyber = approve, ubo = review)
   - Creates a decision task assigned to the right org unit
4. **On / off** — `ZQUBITON_CONFIG.WORKFLOW_ENABLED = 'X'`. Disabled = no event raised, BAdI surfaces the warning to the user inline instead.

The reference helper raises events via `SAP_WAPI_CREATE_EVENT` with the validation outcome packed into the event container as named parameters (`MESSAGE`, `IS_VALID`, `EVENT_NAME`).

### BRF+ — Declarative risk-policy decisions (`zcl_qubiton_brfplus`)

Lets BAdI implementations delegate the "block / warn / route / silent" decision to a customer-maintained BRF+ application instead of hardcoded ABAP policy. Non-developer admins (BRF+ workbench users) can tune policy without touching code.

```abap
" Inside a BAdI's CHECK method:
DATA(lo_rules) = NEW zcl_qubiton_brfplus( ).
DATA(lv_verdict) = lo_rules->get_verdict(
  is_input = VALUE #(
    vendor_country = ls_lfa1-land1
    sanctions_hit  = abap_true
    cyber_score    = 42
    ubo_flagged    = abap_false ) ).

CASE lv_verdict.
  WHEN zcl_qubiton_brfplus=>gc_verdict_block.  ch_failed = abap_true.
  WHEN zcl_qubiton_brfplus=>gc_verdict_route.  lo_wf->raise_po_risk( ... ).
  WHEN zcl_qubiton_brfplus=>gc_verdict_warn.   MESSAGE w007 ...
  WHEN zcl_qubiton_brfplus=>gc_verdict_silent. " log only
  WHEN OTHERS.                                 " BRF+ disabled — fall back to ZQUBITON_SCREEN_CFG
ENDCASE.
```

What the customer wires up:

1. Transaction **BRFPLUS** → create application `ZQUBITON_RULES`
2. Inside the application, create a **Function** `DECIDE_VENDOR_RISK_VERDICT` returning a verdict element (CHAR1 with fixed values E/W/S/R)
3. Add input data objects: `VENDOR_COUNTRY` (CHAR3), `SANCTIONS_HIT` (BOOL), `CYBER_SCORE` (INT4), `UBO_FLAGGED` (BOOL), and any custom fields you need
4. Build a **Decision Table** mapping inputs to verdict (the high-value step — your business owners maintain this)
5. Activate the function — note its UUID
6. `ZQUBITON_CONFIG.BRFPLUS_FUNCTION_ID = "<UUID>"` and `BRFPLUS_ENABLED = 'X'`

When BRF+ is disabled (`BRFPLUS_ENABLED = ''`), the BAdI falls back to the simpler `ZQUBITON_SCREEN_CFG` row policy — BRF+ is purely additive.

The shipped helper has the FDT_FUNCTION_PROCESS plumbing scaffolded but not fully populated; customers complete the call site per their BRF+ release. Reference: SAP help → BRFplus → API → `FDT_FUNCTION_PROCESS`.

### BTE — FI/AP function-module exits (`Z_QUBITON_BTE_1820`, `Z_QUBITON_BTE_1880`)

Function-module-based exits registered via FIBF. Use BTEs when:

- You need a hook in older ECC where no BAdI exists (e.g. open-item posting)
- The BAdI fires too late or too early in the transaction lifecycle
- You want client-specific activation (BTEs are per-client; BAdIs are cross-client)

Two reference processes are shipped as templates:

| BTE | Process | Fires on |
|---|---|---|
| 1820 | Document Posting | Every FI document save (BAPI + dialog) — broad catch-all |
| 1880 | Invoice Posting | MIRO / FB60 specifically — richer invoice context |

What the customer wires up:

1. SE80 → create function group `ZQUBITON_BTE`, copy templates from `src/z_qubiton_bte.fugr.abap`
2. Transaction **FIBF** → Settings → P/S Modules → Of an SAP Application:
   - Process `1820`, Application `FI`, Function module `Z_QUBITON_BTE_1820`
   - Process `1880`, Application `FI`, Function module `Z_QUBITON_BTE_1880`
3. Activate the BTE process for your client (FIBF → "Active")

Both function modules check `ZQUBITON_CONFIG.TXN_VALIDATION_ENABLED` first — same kill switch as the BAdIs. Disabled = function returns immediately, no API call.

### Decision matrix — SWIE vs BRF+ vs BTE vs BAdI

| Need | Use |
|---|---|
| Inline block on PO/invoice/payment save | **BAdI** (`zcl_qubiton_badi_po`, etc.) |
| Route to approver instead of blocking | **SWIE** (`zcl_qubiton_workflow`) — BAdI raises the event, workflow does the routing |
| Risk-policy is complex (country exceptions, threshold rules) | **BRF+** (`zcl_qubiton_brfplus`) — BAdI delegates the verdict to BRF+ rules |
| BAdI doesn't exist for the event you care about | **BTE** (`z_qubiton_bte_1820`/`1880`) — function-module hook via FIBF |
| Older ECC, customer doesn't have BAdI framework activated | **BTE** as the primary integration |

Combine freely: BAdI → calls BRF+ for the verdict → on "route" calls SWIE to raise the workflow event → standard workflow handles approval.

## Cloud roadmap for this connector

We're tracking three workstreams for Cloud Public Edition:

| Workstream | Status | Owner |
|---|---|---|
| Reference iFlow templates for Pattern A (PO, invoice, payment) | planned | QubitOn |
| Verified `BD_MMPUR_FINAL_CHECK_PO` reference implementation (Pattern B) | open work item | QubitOn (need cloud sandbox access) |
| BTP side-by-side reference app (Pattern C) | not started | — |

Customers on Public Cloud who need this today should start with Pattern A (Integration Suite). The reference iFlow XML is in the QubitOn knowledge base — request it via support.

## See also

- [Screen Enhancements](screen-enhancements.md) — master-data save-time validations (already shipped)
- [Configuration](configuration.md) — constructor parameters, error modes, `handle_result`
- [Authorization & Logging](authorization.md) — `ZQUBITON_API` PFCG roles, BAL Application Log
- [Setup](setup.md) — RFC destination, BTP destination, CPI iFlow

## FAQ-style quick answers

### Will this slow down PO save?

The added latency is one HTTP roundtrip per PO save (~200–500 ms) plus ~20 ms ABAP overhead. For high-volume batch entry this can be noticeable; turn it off via the kill switch during mass loads, or use `iv_keep_alive = abap_true` for connection reuse.

### Can I run inline AND batch on the same documents?

Yes, and it's recommended. Inline catches new entries; batch catches what slipped through (API outages, bulk loads, post-save changes). They use the same underlying `zcl_qubiton` API so the wire contract is identical.

### How do I disable just one validation on just one transaction?

Set `ZQUBITON_SCREEN_CFG.ACTIVE = ''` on the matching `(tcode, val_type)` row. Other transactions are unaffected.

### What if the API is down during PO save?

Default behaviour is **fail-open** (warn, allow save). Override per-transaction with `ZQUBITON_SCREEN_CFG.ON_ERROR = 'E'` if your policy requires fail-closed. The reference BAdI catches `zcx_qubiton` and surfaces a yellow warning via SE91 message class `ZCL_QUBITON_MSG`.

### Does this work in S/4HANA Cloud?

Public Edition: not yet — see the per-version compatibility matrix above. Private Cloud: yes, same as on-prem.

### How do I see who got blocked / warned?

Every API call lands in SLG1 under object `ZQUBITON`, subobject `ZAPI_CALL`. Each entry has the method, path, HTTP status, elapsed time, and the user / transaction context. Block decisions also write a `MESSAGE` to the user's status bar via SE91.
