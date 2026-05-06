# Workflow Template — `WS_QUBITON_RISK_REVIEW`

Reference SAP Business Workflow definition that picks up SWIE events
raised by `zcl_qubiton_workflow` (`ZQUBITON_PO/RISK_DETECTED`,
`ZQUBITON_INV/RISK_DETECTED`, `ZQUBITON_PAY/REVIEW_REQUIRED`) and routes
the document to the right approver group instead of hard-blocking the
user.

PFTC workflow templates are stored as binary `swdd` artefacts in SAP and
cannot be portably checked into git. This file documents the template's
**design** so a customer can build it through `PFTC` (or import a
client copy via `RSWUWFML2` / SE38 transport). Once built, the template
gets a runtime number in the `WS9000xxxx` range — the exact number is
assigned by the customer's customising client.

## Activation order

1. Create the object types referenced below (`SE11` / `SWO1`)
2. Build the workflow template in `PFTC` per the spec below
3. Activate it (`PFTC` → menu Workflow → Activate)
4. Wire SWIE event linkage (`SWE2`) so the event you raise from
   `zcl_qubiton_workflow` triggers the template
5. Maintain agent assignment per task (`PFTC` → step → Agent
   determination → role / position / org unit)
6. Set `ZQUBITON_CONFIG.WORKFLOW_ENABLED = 'X'` so the BAdIs raise
   events; until then the BAdIs no-op the workflow path

## Object type definitions (BOR / `SE11` ABAP Objects)

### `ZQUBITON_PO`

| Attribute | Type | Source |
|---|---|---|
| `Ebeln`              | `EBELN`   | PO header |
| `Lifnr`              | `LIFNR`   | PO header |
| `Land1`              | `LAND1`   | LFA1 |
| `Name1`              | `NAME1_GP` | LFA1 |
| `RiskCategory`       | CHAR10    | event container |
| `Verdict`            | CHAR1     | event container |
| `Severity`           | CHAR10    | event container |
| `ApiResponseExtract` | STRING    | event container |

Methods: standard `Display` (calls `BAPI_PO_GETDETAIL1` + `ME23N`),
`SetReleaseStatus` (calls `BAPI_PO_RELEASE`), `Hold` (sets release
indicator).

### `ZQUBITON_INV`

| Attribute | Type | Source |
|---|---|---|
| `Belnr`              | `RBKP-BELNR` | invoice header |
| `Gjahr`              | `GJAHR`   | invoice header |
| `Lifnr`              | `LIFNR`   | invoice |
| `Land1`              | `LAND1`   | LFA1 |
| `Verdict`            | CHAR1     | event container |
| `Severity`           | CHAR10    | event container |
| `ApiResponseExtract` | STRING    | event container |

Methods: `Display` (`MIR4`), `Hold` (`BAPI_INCOMINGINVOICE_BLOCK`),
`Release` (`BAPI_INCOMINGINVOICE_RELEASE`).

### `ZQUBITON_PAY`

| Attribute | Type | Source |
|---|---|---|
| `Laufd` | `LAUFD` | F110 run |
| `Laufi` | `LAUFI` | F110 run |
| `Lifnr` | `LIFNR` | payment proposal |
| `Verdict` | CHAR1 | event container |
| `Severity` | CHAR10 | event container |
| `ApiResponseExtract` | STRING | event container |

Methods: `Display` (`F110`), `Hold` (set payment block).

## Event coupling

Each object type exposes the events the connector raises. Event names
are case-sensitive — they MUST match `zcl_qubiton_workflow`'s
constants exactly (`RISK_DETECTED` not `RiskDetected`):

| Event | Object type | Triggered by |
|---|---|---|
| `RISK_DETECTED`    | `ZQUBITON_PO`  | `zcl_qubiton_workflow=>raise_po_risk` (and direct `raise_event` with `gc_event_risk`) |
| `RISK_DETECTED`    | `ZQUBITON_INV` | direct `raise_event` from invoice BAdI |
| `PAYMENT_BLOCKED`  | `ZQUBITON_PAY` | direct `raise_event` with `gc_event_blocked` |
| `REVIEW_REQUIRED`  | `ZQUBITON_PO` / `_INV` / `_PAY` | `gc_event_review` (this is what `zcl_qubiton_badi_po`'s "route" verdict raises today) |

## Event-container elements

`zcl_qubiton_workflow.raise_event` packs the validation outcome into
a `swcont` table with these element names. The receiving workflow
template MUST bind to these exact names — anything else, and the
container binding is empty at runtime:

| Element name | Type    | Always present? | Source |
|---|---|---|---|
| `EVENT_NAME` | CHAR    | yes              | `iv_event` parameter (the `gc_event_*` constant value) |
| `MESSAGE`    | STRING  | when set         | `is_result-message` (only appended when not initial) |
| `IS_VALID`   | CHAR1   | when set         | `is_result-is_valid` ('X' / blank) — only appended when `is_result-success = abap_true` |

To carry verdict / severity / API response excerpt the connector does
NOT pack them today. If you need them in the workflow, extend
`zcl_qubiton_workflow.raise_event` to append additional `swcont` rows,
or fetch them in a workflow background step that re-reads
`ZQUBITON_BAL` (BAL log) keyed by the event timestamp. This is a
known design gap — see the "Future enhancements" section below.

## Workflow-template container elements (recommended set)

Beyond the event container, the template itself defines container
elements for inter-step bindings. These do not need to match event
container names — pick whatever makes sense for your steps:

| Element name | Type | Origin |
|---|---|---|
| `EventObject`     | object reference (the `Z*` object type) | event linkage (object key) |
| `EventName`       | CHAR | bound from event container `EVENT_NAME` |
| `EventMessage`    | STRING | bound from event container `MESSAGE` |
| `IsValid`         | CHAR1 | bound from event container `IS_VALID` |
| `ApproverDecision`| CHAR10 (`APPROVE`/`REJECT`/`ESCALATE`) | step result |
| `ApproverComment` | STRING | step result |

## Step diagram (top-level)

The diagram below references a `Severity` field. The connector does
NOT emit severity in the event container today — it emits
`EVENT_NAME`/`MESSAGE`/`IS_VALID`. To use this diagram as drawn,
either (a) extend `zcl_qubiton_workflow.raise_event` to pack
severity from the validation result, or (b) collapse Step 2 into a
single User Decision routed by approval-rule lookup tables instead
of branching on Severity.

```
                                 [Start]
                                    │
                                    ▼
                          ┌─────────────────────┐
                          │ Step 1: Notify AP   │     bind: Severity, RiskCategory
                          │ (SendMail / Teams)  │     agent: Org Unit ZQUBITON_AP
                          └─────────┬───────────┘
                                    ▼
                          ┌─────────────────────┐
                          │ Step 2: Branch on   │
                          │       Severity      │
                          └─┬───────┬─────────┬─┘
                  HIGH      │   MEDIUM │   LOW │
                            ▼          ▼       ▼
                    ┌──────────────┐  ┌─────────┐  ┌────────────┐
                    │ Compliance   │  │ AP Lead │  │ Auto-      │
                    │ Officer      │  │ Decision│  │  approve   │
                    │ Decision     │  │ (UD)    │  │  (silent)  │
                    │ (UD task)    │  └────┬────┘  └─────┬──────┘
                    └──────┬───────┘       │             │
                           │               │             │
                           ▼               ▼             ▼
                  ┌────────────────────────────────────────┐
                  │ Step 3: Apply approver decision        │
                  │   APPROVE  → release block on document │
                  │   REJECT   → keep block + notify user  │
                  │   ESCALATE → re-route to next tier     │
                  └────────────────────┬───────────────────┘
                                       ▼
                                     [End]
```

## Step details

### Step 1 — Notify AP

| Property | Value |
|---|---|
| Step type | Mail (`SOSEND_S` task) or Microsoft Teams notification |
| Agents    | Org Unit `ZQUBITON_AP` (customer creates in `PPOC`) |
| Outcome   | none — informational, completes immediately |

### Step 2 — Severity branch

| Property | Value |
|---|---|
| Step type | Multiple Conditions |
| Condition 1 | `&Severity& = 'HIGH'` → Compliance Officer Decision |
| Condition 2 | `&Severity& = 'MEDIUM'` → AP Lead Decision |
| Condition 3 | `&Severity& = 'LOW'`  → Auto-approve |

### Step 3a — Compliance Officer Decision (User Decision)

| Property | Value |
|---|---|
| Step type | User Decision (`TS01000058` standard task) |
| Agents    | Role `ZQUBITON_COMPLIANCE` |
| Outcomes  | `APPROVE` / `REJECT` / `ESCALATE` |
| Container | reads `EventObject`, `Verdict`, `Severity`, `ApiResponseExtract` |
| Result    | writes `ApproverDecision`, `ApproverComment` |

### Step 3b — AP Lead Decision

Same shape as 3a but agent role `ZQUBITON_AP_LEAD`. Customers usually
collapse 3a + 3b into one User Decision task with role determination
based on `&Severity&`.

### Step 4 — Apply decision

| Property | Value |
|---|---|
| Step type | Activity → calls a method on `EventObject` |
| Method    | `Hold` / `Release` / `SetReleaseStatus` (per object type) |
| Inputs    | `ApproverDecision`, `ApproverComment` |
| Outcome   | success / failure → end branch |

## Sample SWIE event linkage (`SWE2`)

After the template is activated and gets a runtime number (let's say
`WS90000123`), wire the event linkage:

```abap
" Run as a one-time setup report or via SWE2 transaction.
" This example wires the PO RiskDetected event.
DATA ls_link TYPE swetypecou.
ls_link-objtype     = 'ZQUBITON_PO'.
ls_link-event       = 'RISK_DETECTED'.
ls_link-recname     = 'WORKFLOW'.
ls_link-recfb       = 'SWW_WI_CREATE_VIA_EVENT_IBF'.
ls_link-rectype     = 'WS90000123'.   " <-- your activated template number
ls_link-linked      = abap_true.
ls_link-mandt       = sy-mandt.

CALL FUNCTION 'SWE_EVENT_TYPE_LINKAGE_INSERT'
  EXPORTING
    type_linkage_model = ls_link
  EXCEPTIONS
    OTHERS             = 1.
COMMIT WORK.
```

Customers usually build a small setup report that calls this for each
`(object type, event)` pair the connector emits.

## Agent determination patterns

Three common ways customers wire agents:

| Pattern | When to use | Where to configure |
|---|---|---|
| Role + responsibility rule | Simple "Compliance Officer" group | `PFAC` → `ZQUBITON_COMPLIANCE` |
| Org unit                   | Fixed AP team mailbox            | `PPOC` → `ZQUBITON_AP` org unit |
| Function module agent      | Routing depends on PO value, vendor country, severity etc. | `PFTC` step → Agent determination → "Function" |

For multi-country / multi-business-unit customers, the function-module
pattern is usually right. The function module receives the event
container as input and returns an agent table.

## Test plan (in customer tenant)

1. `SE19` → Implement BAdI `ME_PROCESS_PO_CUST` with
   `ZCL_QUBITON_BADI_PO`, activate
2. `SM30` → `ZQUBITON_CONFIG`:
   - `TXN_VALIDATION_ENABLED = X`
   - `WORKFLOW_ENABLED = X`
3. `SM30` → `ZQUBITON_SCREEN_CFG`: row for tcode `ME21N` /
   val_type `SANCTION` with `ON_INVALID = 'W'` (warn — so we go to
   workflow path, not block)
4. `ME21N` → create a PO with a known sanctions-list vendor
5. After save, check `SBWP` → workflow inbox of
   `ZQUBITON_COMPLIANCE` user — should see the User Decision task
6. Approve / reject — verify the document state changes accordingly
7. `SWI1` → audit trail of the workflow instance

## Customisation points

| Need | Where |
|---|---|
| Add a new severity tier (e.g. CRITICAL) | Step 2 — Multiple Conditions |
| Notify Slack instead of email | Step 1 — replace mail step with HTTP-call task |
| Auto-escalate after N days | Step 3 → Latest end → forward action |
| Capture approver decision in the document | Step 4 method body |
| Support languages other than EN | `SE63` → translate task and message texts |

## Relationship with the on-prem BAdI

The BAdI raises the event with `zcl_qubiton_workflow=>raise_event`
ONLY when `WORKFLOW_ENABLED='X'` and the verdict is "route". For
"block" the BAdI sets `CH_FAILED = abap_true` and no workflow
fires; for "warn" / "silent" the BAdI emits a status-bar message
and no workflow fires either.

In other words: **the workflow is the path for documents that
need approval routing**, not for documents that should just be
blocked or silently logged. Don't expect a workflow instance for
every PO — only the routed minority.

## See also

- [`zcl_qubiton_workflow.clas.abap`](../../src/zcl_qubiton_workflow.clas.abap) — the SWIE event raiser
- [`zcl_qubiton_badi_po.clas.abap`](../../src/zcl_qubiton_badi_po.clas.abap) — caller (on-prem PO BAdI)
- [`docs/transaction-validation.md`](../../transaction-validation.md) — full design
