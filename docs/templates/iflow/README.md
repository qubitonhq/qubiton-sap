# Reference iFlow — `qubiton_po_sanctions.iflw`

Cloud Pattern A reference for SAP Integration Suite / SAP Cloud
Integration. Receives the S/4HANA Cloud "Purchase Order Created"
business event over an HTTPS sender adapter (the released
Communication Arrangement webhook), calls
`api.qubiton.com/api/sanctions/check`, writes a Z-flag back via
OData, and notifies AP via Microsoft Teams.

> **Sender adapter — `HTTPS`, not AdvancedEventMesh.** S/4HANA Cloud
> Public Edition publishes business events through either an HTTPS
> webhook (the simplest option, configured via a Communication
> Arrangement on the S/4 side) or SAP Event Mesh (AMQP). The iFlow
> XML in this directory uses the HTTPS sender adapter on path
> `/qubiton/po-sanctions`. AdvancedEventMesh is a separate SAP
> product (Solace) and is NOT what S/4 Cloud uses by default.

## Files

| File | Purpose |
|---|---|
| `qubiton_po_sanctions.iflw` | BPMN-XML iFlow definition (the file the SAP Cloud Integration designer reads/writes). |

A complete iFlow package on disk is a ZIP with this structure:

```
qubiton_po_sanctions/
├── META-INF/
│   └── MANIFEST.MF
├── src/
│   └── main/
│       └── resources/
│           ├── scenarioflows/
│           │   └── integrationflow/
│           │       └── qubiton_po_sanctions.iflw    ← this file
│           ├── parameters.prop
│           └── parameters.propdef
└── .project
```

You don't need to assemble the ZIP by hand. Either:

- **Easy path**: Open SAP Cloud Integration → Design → Create → paste
  the iFlow XML into the designer (Source View). Save. The designer
  generates `parameters.prop`, manifest, and project files for you.
- **Power-user path**: Add this file to the `scenarioflows/integrationflow/`
  path inside an existing iFlow package, set the externalised
  parameters in `parameters.prop` (see below), zip, import.

## Externalised parameters

These four parameters MUST be set per tenant via the iFlow's
*Configuration* tab (or directly in `parameters.prop` if you're
assembling the ZIP manually):

| Parameter | Example | Description |
|---|---|---|
| `apikey`             | `qbn_live_…`                              | QubitOn API key |
| `qubiton_base_url`   | `https://api.qubiton.com`                  | QubitOn API base URL |
| `s4_tenant_url`      | `https://my-tenant.s4hana.cloud.sap`        | S/4HANA Cloud tenant URL for OData writeback |
| `teams_webhook_url`  | `https://outlook.office.com/webhook/…`      | Microsoft Teams incoming-webhook URL |

`parameters.prop` line example:

```
apikey=
qubiton_base_url=https://api.qubiton.com
s4_tenant_url=https://my-tenant.s4hana.cloud.sap
teams_webhook_url=
```

`parameters.propdef` (data-type metadata) entry for `apikey`:

```
apikey=Mandatory:String:custom:apikey:::
```

`Mandatory` makes the deploy fail if it's left blank — protects against
accidentally going live with an empty key.

## Steps the iFlow performs

```
[Sender HTTPS] /qubiton/po-sanctions       ← S/4 Cloud webhook (JSON)
   │
   ▼
[Content Modifier] Set headers             apikey + Content-Type
   │
   ▼
[JSON-to-XML Converter] Inbound body       JSON event → XML for XPath
   │
   ▼
[Content Modifier] Capture                 PO + Supplier + Country into properties (XPath)
   │
   ▼
[Content Modifier] Build body              JSON for /api/sanctions/check
   │
   ▼
[Request-Reply] HTTP receiver              POST {{qubiton_base_url}}/api/sanctions/check
   │
   ▼
[JSON-to-XML Converter] QubitOn response   JSON response → XML for XPath
   │
   ▼
[Content Modifier] Extract hit             property QubitOnHit = //hit/text() (XPath)
   │
   ▼
[Router] QubitOnHit == 'true' ?
   │            │
   │ no         │ yes
   │            ▼
   │      [Request-Reply] HTTP receiver    PATCH /A_PurchaseOrder
   │            │
   │            ▼
   │      [Request-Reply] HTTP receiver    POST teams webhook
   │            │
   ▼            ▼
[End]        [End]
```

> **Why the JSON-to-XML converter steps?** Per SAP's documented
> Content Modifier types (Constant / XPath / Expression / Header /
> Property), only XPath supports body field access — and XPath
> operates on XML only. The HTTPS sender adapter and the QubitOn
> HTTP receiver both deliver bodies as JSON, so a Content Modifier
> with `Type=xpath` against the raw JSON would resolve to nothing.
> The JSON-to-XML Converter step (released CPI step type) wraps each
> JSON object under a `<root>` element so XPath expressions like
> `//hit/text()` work. Earlier drafts used a `${jsonPath:$.field}`
> placeholder on the Property tab — that's not a valid CPI
> expression (neither Camel-canonical nor SAP-documented) and would
> resolve to the literal string. Alternative: a Groovy script step
> using `JsonSlurper`; the converter approach keeps the iFlow
> declarative.

## Adapting for invoice / payment

Two derivative iFlows follow the same shape but listen for different
S/4 Cloud events and call different QubitOn endpoints:

| Source iFlow | S/4 Cloud business event | Sender path | QubitOn endpoint |
|---|---|---|---|
| `qubiton_po_sanctions.iflw`        | `PurchaseOrder.Created`     | `/qubiton/po-sanctions`      | `/api/sanctions/check` |
| `qubiton_invoice_sanctions.iflw` (derive) | `SupplierInvoice.Created`   | `/qubiton/invoice-sanctions` | `/api/sanctions/check` |
| `qubiton_payment_sanctions.iflw` (derive) | `PaymentRun.Approved`       | `/qubiton/payment-sanctions` | `/api/sanctions/check` |

Copy this iFlow, change the sender path so it doesn't collide with
the PO flow, point the matching S/4 Cloud Communication Arrangement
at the new path, and update the *Capture* step's XPath expressions
to read the right fields out of the new event payload.

## Authentication

`apikey` is sent as an HTTP header (not Basic Auth). The iFlow's
HTTP receiver adapter does not encrypt the header at rest — store the
production `apikey` in CPI's *Security Material → Secure Parameters*
and reference it via `{{apikey}}` rather than typing it directly into
`parameters.prop`. The deploy will pull from the secure store at
runtime and the value never appears in logs.

## OData writeback details

The sample writeback PATCHes `A_PurchaseOrder` with a custom Z-extension
field, e.g.:

```json
{
  "YY1_QubitonRiskFlag_PUH": "SANCTIONED",
  "YY1_QubitonRiskCheckedAt_PUH": "2026-05-06T10:00:00Z"
}
```

`YY1_QubitonRiskFlag_PUH` and `YY1_QubitonRiskCheckedAt_PUH` are custom
fields the customer creates via Fiori app *Custom Fields and Logic*
(*Custom Fields* tab) on the *Purchase Order Header* business context.
Adjust the field names to match your tenant.

## Test plan

1. Deploy the iFlow to a non-prod CPI tenant
2. In Cloud Integration's *Monitoring → Manage Integration Content* —
   confirm status is *Started*
3. In S/4 Cloud, create a PO with a known sanctions-list supplier
4. Inspect *Monitoring → Message Processing*: the iFlow should show a
   completed run within ~5 seconds of PO save
5. Open the PO in the *Manage Purchase Orders* Fiori app — the Z-flag
   field should now show `SANCTIONED`
6. Check the configured Teams channel — incoming-webhook message should
   have arrived

## See also

- [`docs/transaction-validation.md`](../../transaction-validation.md) — full design including the on-prem BAdI variant
- [`docs/templates/cloud/zcl_qubiton_cloud_po_check.clas.abap`](../cloud/zcl_qubiton_cloud_po_check.clas.abap) — Pattern B (released cloud BAdI) reference
- [`docs/templates/workflow/ws_qubiton_risk_review.md`](../workflow/ws_qubiton_risk_review.md) — workflow template spec for the on-prem path
