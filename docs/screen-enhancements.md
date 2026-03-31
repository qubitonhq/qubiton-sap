# Screen Enhancements (Automatic Validation on Save)

The connector includes pre-built BAdI implementations that automatically validate data when users save vendor master, customer master, or Business Partner records. SAP admins control exactly which validations run via a configuration table — no ABAP development needed to turn validations on or off.

## Supported Screens

| Master Data | Transaction Codes | BAdI | Implementation Class |
|-------------|------------------|------|---------------------|
| **Vendor Master** | XK01, XK02, FK01, FK02, MK01, MK02 | `VENDOR_ADD_DATA_CS` | `ZCL_QUBITON_BADI_VENDOR` |
| **Customer Master** | XD01, XD02, FD01, FD02, VD01, VD02 | `CUSTOMER_ADD_DATA_CS` | `ZCL_QUBITON_BADI_CUSTOMER` |
| **Business Partner** (S/4HANA) | BP | `BADI_BUS1006_CHECK` | `ZCL_QUBITON_BADI_BP` |

## Available Validations per Screen

| Validation | Vendor | Customer | Business Partner | What It Checks |
|------------|--------|----------|------------------|----------------|
| **TAX** | STCEG / STCD1 / STCD2 | STCEG / STCD1 / STCD2 | TAXNUM / TAXTYPE | Tax ID validity via live authority check |
| **BANK** | BANKN / IBAN / SWIFT / BANKL | BANKN / IBAN / SWIFT / BANKL | BANKN / IBAN / SWIFT / BANKL | Bank account, routing/sort code, IBAN, SWIFT validation |
| **ADDRESS** | STRAS / ORT01 / REGIO / PSTLZ | STRAS / ORT01 / REGIO / PSTLZ | STREET / CITY / REGION / POSTL_COD1 | Postal address validation (249 countries) |
| **SANCTION** | NAME1 + address fields | NAME1 + address fields | NAME_ORG1/NAME_LAST + address | OFAC, EU, UN sanctions/prohibited list screening |
| **EMAIL** | ADR6 (SMTP_ADDR) | ADR6 (SMTP_ADDR) | *(BAdI lacks SMTP data — skips unless caller populates)* | Email deliverability validation |
| **PHONE** | TELF1 | TELF1 | TEL_NUMBER | Phone number carrier validation |

## How It Works

```
User saves vendor/customer/BP
  |
  v
BAdI fires (e.g., VENDOR_ADD_DATA_CS)
  |
  v
ZCL_QUBITON_BADI_VENDOR reads screen fields
  |
  v
ZCL_QUBITON_SCREEN reads ZQUBITON_SCREEN_CFG table
  |  +-- Is TAX validation active for this tcode? -> validate tax
  |  +-- Is BANK validation active for this tcode? -> validate bank
  |  +-- Is ADDRESS validation active for this tcode? -> validate address
  |  +-- Is SANCTION screening active for this tcode? -> check sanctions
  |  +-- Is EMAIL validation active for this tcode? -> validate email
  |  +-- Is PHONE validation active for this tcode? -> validate phone
  |  +-- Country filter match? -> skip if country doesn't match
  |
  v
Each active validation -> ZCL_QUBITON API call
  |
  v
Result -> SAP MESSAGE (E=block save, W=warn, S=silent)
  |
  v
User sees validation result in status bar
```

## Configuration Table (ZQUBITON_SCREEN_CFG)

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

### Example Configuration

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

### Admin Toggle: Turn Validations On/Off

To **enable** a validation: set `ACTIVE = 'X'` in SM30.
To **disable** a validation: clear `ACTIVE` (set to blank) or delete the row.
To **enable for specific countries only**: set `COUNTRY_FILTER` (e.g., `US` for US vendors only).

```
Transaction SM30 -> Table ZQUBITON_SCREEN_CFG -> Maintain

+--------+----------+--------+------------+----------+----------------+
| TCODE  | VAL_TYPE | ACTIVE | ON_INVALID | ON_ERROR | COUNTRY_FILTER |
+--------+----------+--------+------------+----------+----------------+
| XK01   | TAX      |   X    |     E      |    W     |                |
| XK01   | BANK     |   X    |     E      |    W     |                |
| XK01   | ADDRESS  |        |     W      |    S     |                |  <- disabled
| XK01   | SANCTION |   X    |     E      |    W     |                |
| XK02   | TAX      |   X    |     W      |    S     |                |
| BP     | TAX      |   X    |     E      |    W     |                |
| BP     | ADDRESS  |   X    |     W      |    W     |                |
| BP     | SANCTION |   X    |     E      |    W     |                |
+--------+----------+--------+------------+----------+----------------+
```

## General Configuration Table (ZQUBITON_CONFIG)

Stores the API key and other settings. Maintained via SM30.

| CONFIG_KEY | CONFIG_VALUE | Description |
|------------|-------------|-------------|
| `APIKEY` | `your-api-key-here` | QubitOn API key (shared by all BAdIs) |
| `CHECK_AUTH` | `X` | Enable ZQUBITON_API authorization check (optional, blank = skip) |

## Tax Type Auto-Detection

The orchestrator automatically maps SAP country codes to the correct QubitOn tax type:

| Country | Tax Type |
|---------|----------|
| US | EIN |
| DE, FR, IT, NL, ... (EU) | VAT |
| BR | CNPJ |
| IN | GSTIN |
| AU | ABN |
| CA | BN |
| GB | UTR |
| MX | RFC |
| JP | CN |
| KR | BRN |
| RU | INN |
| ZA | TIN |

Field priority is the same for all countries: **STCEG → STCD1 → STCD2** (first non-empty field wins).

For Business Partner, the explicit `TAXTYPE` field from `BPTAX` is used if populated. Otherwise, country-based detection applies.

## Bank Field Mapping

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

## BP Bank Data Limitation

The `BADI_BUS1006_CHECK` interface does not provide bank data in its parameters. Bank validation for Business Partners requires a custom enhancement that reads from BP bank tables (`BUT100`/`BPBK`) directly, or use of a separate BAdI/user exit that fires during bank data entry.

## Setup

1. **SE11** — Activate tables `ZQUBITON_SCREEN_CFG` and `ZQUBITON_CONFIG` (or import via abapGit)
2. **SE55** — Generate table maintenance dialog for both tables (function group `ZQUBITON_TMG`)
3. **SM30** — Add API key to `ZQUBITON_CONFIG` (CONFIG_KEY = `APIKEY`)
4. **SM30** — Configure validations in `ZQUBITON_SCREEN_CFG` (see example above)
5. **SE19** — Create BAdI implementations:
   - BAdI `VENDOR_ADD_DATA_CS` -> Implementation class `ZCL_QUBITON_BADI_VENDOR`
   - BAdI `CUSTOMER_ADD_DATA_CS` -> Implementation class `ZCL_QUBITON_BADI_CUSTOMER`
   - BAdI `BADI_BUS1006_CHECK` -> Implementation class `ZCL_QUBITON_BADI_BP`
6. **SE19** — Activate the BAdI implementations
7. Test by creating/changing a vendor, customer, or BP

## Code Examples

### Direct Use (without BAdI)

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

### Validate All (Config-Driven)

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
        WRITE: / '  -> Save blocked'.
      ENDIF.
    ENDLOOP.

  CATCH zcx_qubiton INTO DATA(lx_err).
    WRITE: / lx_err->get_text( ).
ENDTRY.
```
