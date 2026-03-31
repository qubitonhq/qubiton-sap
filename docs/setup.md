# Setup & Connectivity

## Getting an API Key

1. Sign up for a free account at [www.qubiton.com](https://www.qubiton.com/auth/register)
2. Navigate to **API Keys** and generate a new key.
3. Copy the key -- you will need it when configuring the destination.

## Option A: SAP BTP Destination (Cloud)

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

> **Security note**: For production use, store the API key in the BTP Destination
> Service's credential store or an external secrets manager — not as a plaintext
> additional property. The `btp-destination.json` template uses plaintext for
> quick-start convenience only.

## Option B: ABAP RFC Destination (On-Premise S/4HANA / ECC)

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

Deploy classes from the `src/` directory via **SE24** or **ADT** (ABAP Development Tools).

## Option C: SAP CPI / Integration Suite iFlow

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
