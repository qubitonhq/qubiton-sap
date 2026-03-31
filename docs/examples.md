# ABAP Usage Examples

The methods below return raw JSON strings. Use `handle_result` (see [Configuration](configuration.md)) for automatic
error/validation handling, or process the JSON yourself with `/ui2/cl_json`.

## Validate an Address

```abap
DATA(lo_api) = NEW zcl_qubiton( iv_apikey = 'your-api-key' ).

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

## Validate a Tax ID

```abap
DATA(lv_result) = lo_api->validate_tax(
  iv_tax_number   = '12-3456789'
  iv_tax_type     = 'EIN'
  iv_country      = 'US'
  iv_company_name = 'Acme Corporation'
).
```

## Validate Tax ID Format (Offline)

```abap
DATA(lv_result) = lo_api->validate_tax_format(
  iv_tax_number = 'DE123456789'
  iv_tax_type   = 'VAT'
  iv_country    = 'DE'
).
```

## Validate a Bank Account

```abap
DATA(lv_result) = lo_api->validate_bank_account(
  iv_business_entity_type = 'Business'
  iv_country              = 'US'
  iv_bank_account_holder  = 'Acme Corp'
  iv_account_number       = '1234567890'
  iv_bank_code            = '021000021'
).
```

## Premium Bank Validation (BankPro)

```abap
DATA(lv_result) = lo_api->validate_bank_pro(
  iv_business_entity_type = 'Business'
  iv_country              = 'GB'
  iv_bank_account_holder  = 'Acme Ltd'
  iv_iban                 = 'GB29NWBK60161331926819'
).
```

## Validate Email

```abap
DATA(lv_result) = lo_api->validate_email(
  iv_email_address = 'john@example.com'
).
```

## Validate Phone

```abap
DATA(lv_result) = lo_api->validate_phone(
  iv_phone_number = '+14155551234'
  iv_country      = 'US'
).
```

## Look Up Business Registration

```abap
DATA(lv_result) = lo_api->lookup_business_registration(
  iv_company_name = 'Acme Corporation'
  iv_country      = 'US'
  iv_state        = 'DE'
).
```

## Validate Peppol ID

```abap
DATA(lv_result) = lo_api->validate_peppol(
  iv_participant_id   = '0088:1234567890128'
  iv_directory_lookup = 'X'  " sends JSON boolean true
).
```

## Screen for Sanctions

```abap
DATA(lv_result) = lo_api->check_sanctions(
  iv_company_name = 'Acme Trading Ltd'
  iv_country      = 'US'
).
```

## Screen for PEP (Politically Exposed Persons)

```abap
DATA(lv_result) = lo_api->screen_pep(
  iv_name    = 'John Smith'
  iv_country = 'US'
).
```

## Check Disqualified Directors

```abap
DATA(lv_result) = lo_api->check_directors(
  iv_first_name = 'John'
  iv_last_name  = 'Doe'
  iv_country    = 'GB'
).
```

## Check EPA Prosecution

```abap
DATA(lv_result) = lo_api->check_epa_prosecution(
  iv_name  = 'Acme Chemical Corp'
  iv_state = 'TX'
).
```

## Check Healthcare Exclusion

```abap
DATA(lv_result) = lo_api->check_healthcare_exclusion(
  iv_healthcare_type = 'HCP'
  iv_last_name       = 'Smith'
  iv_first_name      = 'John'
  iv_state           = 'CA'
).
```

## Check Bankruptcy Risk

```abap
DATA(lv_result) = lo_api->check_bankruptcy_risk(
  iv_company_name = 'Acme Corporation'
  iv_country      = 'US'
).
```

## Look Up Credit Score

```abap
DATA(lv_result) = lo_api->lookup_credit_score(
  iv_company_name = 'Acme Corporation'
  iv_country      = 'US'
).
```

## Assess Entity Risk

```abap
DATA(lv_result) = lo_api->assess_entity_risk(
  iv_company_name = 'Acme Corporation'
  iv_country      = 'US'
  iv_category     = 'Financial'
).
```

## Look Up Credit Analysis

```abap
DATA(lv_result) = lo_api->lookup_credit_analysis(
  iv_company_name  = 'Acme Corporation'
  iv_address_line1 = '123 Main St'
  iv_city          = 'Wilmington'
  iv_state         = 'DE'
  iv_country       = 'US'
).
```

## Look Up ESG Score

```abap
DATA(lv_result) = lo_api->lookup_esg_score(
  iv_company_name = 'Acme Corporation'
  iv_country      = 'US'
).
```

## Domain Security Report

```abap
DATA(lv_result) = lo_api->domain_security_report(
  iv_domain_name = 'example.com'
).
```

## Check IP Quality

```abap
DATA(lv_result) = lo_api->check_ip_quality(
  iv_ip_address = '203.0.113.42'
).
```

## Look Up Beneficial Ownership

```abap
DATA(lv_result) = lo_api->lookup_beneficial_ownership(
  iv_company_name = 'Acme Corporation'
  iv_country_iso2 = 'US'
).
```

## Look Up Corporate Hierarchy

```abap
DATA(lv_result) = lo_api->lookup_corporate_hierarchy(
  iv_company_name  = 'Acme Corporation'
  iv_address_line1 = '123 Main St'
  iv_city          = 'Wilmington'
  iv_state         = 'DE'
  iv_zip_code      = '19801'
).
```

## Look Up DUNS Number

```abap
DATA(lv_result) = lo_api->lookup_duns(
  iv_duns_number = '123456789'
).
```

## Validate NPI

```abap
DATA(lv_result) = lo_api->validate_npi(
  iv_npi       = '1234567890'
  iv_last_name = 'Smith'
).
```

## Look Up DOT Carrier

```abap
DATA(lv_result) = lo_api->lookup_dot_carrier(
  iv_dot_number = '12345'
).
```

## Validate Certification

```abap
DATA(lv_result) = lo_api->validate_certification(
  iv_company_name       = 'Acme Corp'
  iv_country            = 'US'
  iv_certification_type = 'MBE'
).
```

## Look Up Business Classification

```abap
DATA(lv_result) = lo_api->lookup_business_classification(
  iv_company_name = 'Acme Corporation'
  iv_city         = 'Wilmington'
  iv_state        = 'DE'
  iv_country      = 'US'
).
```

## Analyze Payment Terms

```abap
DATA(lv_result) = lo_api->analyze_payment_terms(
  iv_current_pay_term = '30'
  iv_annual_spend     = '1000000'
  iv_avg_days_pay     = '45'
  iv_savings_rate     = '0.02'
  iv_threshold        = '10'
).
```

## Look Up Exchange Rates

```abap
DATA(lv_result) = lo_api->lookup_exchange_rates(
  iv_base_currency = 'USD'
  iv_dates         = '2024-01-15,2024-01-16'
).
```

## Look Up SAP Ariba Supplier

```abap
DATA(lv_result) = lo_api->lookup_ariba_supplier(
  iv_anid = 'AN01234567890'
).
```

## Identify Gender

```abap
DATA(lv_result) = lo_api->identify_gender(
  iv_name    = 'Andrea'
  iv_country = 'IT'
).
```

## Get Supported Tax Formats

```abap
DATA(lv_result) = lo_api->get_supported_tax_formats( ).
```

## Look Up EPA Prosecution

```abap
DATA(lv_result) = lo_api->lookup_epa_prosecution(
  iv_company_name = 'Acme Chemical Corp'
  iv_state        = 'TX'
).
```

## Look Up Healthcare Exclusion

```abap
DATA(lv_result) = lo_api->lookup_healthcare_exclusion(
  iv_last_name  = 'Smith'
  iv_first_name = 'John'
  iv_state      = 'FL'
).
```

## Look Up Fail Rate

```abap
DATA(lv_result) = lo_api->lookup_fail_rate(
  iv_company_name = 'Acme Corp'
  iv_country      = 'US'
  iv_state        = 'TX'
  iv_city         = 'Houston'
).
```

## Look Up Company Hierarchy

```abap
DATA(lv_result) = lo_api->lookup_hierarchy(
  iv_identifier      = '123456789'
  iv_identifier_type = 'DUNS'
  iv_country         = 'US'
).
```

## Validate Medpass

```abap
DATA(lv_result) = lo_api->validate_medpass(
  iv_id                   = '1234567890'
  iv_business_entity_type = 'Business'
  iv_company_name         = 'ABC Medical Supplies'
  iv_country              = 'US'
  iv_state                = 'CA'
).
```

## Validate India Identity

```abap
DATA(lv_result) = lo_api->validate_india_identity(
  iv_identity_number      = 'ABCDE1234F'
  iv_identity_number_type = 'PAN'
  iv_entity_name          = 'Rajesh Kumar'
).
```

## Look Up Certification

```abap
DATA(lv_result) = lo_api->lookup_certification(
  iv_company_name        = 'ABC Enterprises'
  iv_country             = 'US'
  iv_state               = 'CA'
  iv_certification_type  = 'MBE'
  iv_certification_group = 'NMSDC'
).
```

## Validate SAP Ariba Supplier

```abap
DATA(lv_result) = lo_api->validate_ariba_supplier(
  iv_anid = 'AN01234567890'
).
```

## Get Peppol Schemes

```abap
DATA(lv_result) = lo_api->get_peppol_schemes( ).
```
