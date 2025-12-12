# Schema Validation Checklist

## Pre-Deployment Validation

### JSON Syntax ✓
- [x] Valid JSON format
- [x] All brackets balanced
- [x] All quotes matched
- [x] No trailing commas
- [x] Proper indentation
- [x] File ends with newline

### Schema Structure ✓
- [x] Top-level: `programs` array only
- [x] Each program contains all required fields
- [x] Capital_Provider_Org nested in each program
- [x] Contacts array nested in each program
- [x] No top-level organization or contacts objects

### Type Definitions ✓
- [x] All string fields: `"type": "string"` or `["string", "null"]`
- [x] All numeric fields: `["number", "string", "null"]`
- [x] All boolean fields: `["boolean", "null"]`
- [x] All array fields: `"type": "array"` with items
- [x] All object fields: `"type": "object"` with properties

### Null Value Handling ✓
- [x] All optional fields allow null
- [x] Null placed first in enum arrays
- [x] No required fields marked as optional
- [x] Required fields: Program_Name, Capital_Provider_Org.Name, Contact.Name, programs

### Empty Array Support ✓
- [x] Asset_Types: Can be empty
- [x] Transaction_Types: Can be empty
- [x] Capital_Stack: Can be empty
- [x] Typical_Amortization: Can be empty
- [x] Target_Property_Locations: Can be empty
- [x] Contacts: Can be empty

### Enum Values ✓
- [x] All enums have null as first value (where applicable)
- [x] No duplicate enum values
- [x] All enum values are strings
- [x] Enum values match expected domain values

### Field Descriptions ✓
- [x] Every field has a description
- [x] Descriptions are clear and concise
- [x] Format guidance provided (e.g., "City, State")
- [x] No placeholder descriptions

### Required Fields ✓
- [x] Program_Name: Required
- [x] Capital_Provider_Org: Required object
- [x] Capital_Provider_Org.Name: Required
- [x] Contact.Name: Required
- [x] programs: Required at top level
- [x] All other fields: Optional

## Test Data Validation

### Minimal Valid Program
```json
{
  "programs": [
    {
      "Program_Name": "Test Program",
      "Capital_Provider_Org": {
        "Name": "Test Organization"
      },
      "Contacts": []
    }
  ]
}
```
- [x] Passes schema validation
- [x] All required fields present
- [x] Optional fields can be omitted

### Complete Program
```json
{
  "programs": [
    {
      "Program_Name": "ABC Bank Senior Debt",
      "Asset_Parameters": {
        "Asset_Types": ["Apartments", "Office"],
        "Commercial_Tenancy": "Multi-tenant",
        "Single_Tenant_list": null,
        "Single_Tenant_Min_Bond_Credit_Rating": "Aaa",
        "Hotel_Flag_required": null,
        "Hotel_Flag_list": null,
        "Ground_Lease": "Fee Simple",
        "Min_Occupancy": "85%",
        "Target_Property_Locations": []
      },
      "Deal_Parameters": {
        "Transaction_Types": ["Acquisition", "Refinance"],
        "Term_Length": "10 years",
        "Investment_Strategy": "Core"
      },
      "Sizing": {
        "Minimum_Check_Size": "5000000",
        "Maximum_Check_Size": "50000000",
        "Capital_Stack": ["Senior"],
        "Leverage_Constraints": {
          "Maximum_LTV": "0.75",
          "Minimum_DSCR": "1.25",
          "Minimum_Debt_Yield": null,
          "Maximum_LTC": null,
          "Maximum_As-Stabilized_LTV": null,
          "Minimum_As-Stabilized_Debt_Yield": null,
          "Minimum_Equity_Multiple": null,
          "Minimum_Equity_IRR": null
        }
      },
      "Sponsor_Requirements": {
        "Location": "US",
        "Experience_Level": "Experienced",
        "AUM": "100000000",
        "US_Citizenship_Required": true
      },
      "Guarantor_Requirements": {
        "Min_Credit_Score": "700",
        "Min_Net_Worth": "5000000",
        "Min_Net_Worth_Ratio": null,
        "Min_Liquidity": null,
        "Min_Liquidity_Ratio": null,
        "Guarantor_Type": "Warm Body"
      },
      "Program_Term_Details": {
        "Recourse": "Selective",
        "Accepts_PACE_financing": "No",
        "Typical_Amortization": ["20", "25"],
        "Prepayment_Penalty": "Stepdown",
        "Typical_Days_to_Close": "45"
      },
      "Program_Type": "Bank",
      "Marketing_Description": "Flexible commercial mortgage financing",
      "Notes": "Non-recourse available for strong sponsors",
      "Pricing": {
        "Interest_Rate_Details": {
          "Rate_Type": "Fixed",
          "Rate_Index": "Fixed",
          "Minimum_Spread": "2.5%",
          "Maximum_Spread": "4.0%"
        },
        "Typical_Fees": "1.0% origination"
      },
      "Capital_Provider_Org": {
        "Name": "ABC Bank",
        "HQ_Location": "Boston, MA",
        "Organization_Type": "Bank",
        "Website_URL": "https://www.abcbank.com",
        "Parent_Organization": null,
        "Notes": "Regional bank with strong CRE focus"
      },
      "Contacts": [
        {
          "Name": "John Smith",
          "Title": "SVP, Head of Lending",
          "Email": "john.smith@abcbank.com",
          "Phone": "617-555-1234",
          "Organization_Name": "ABC Bank",
          "LinkedIn": "https://linkedin.com/in/johnsmith",
          "Location": "Boston, MA",
          "Timezone": "EST",
          "Notes": "Primary contact for new deals"
        }
      ]
    }
  ]
}
```
- [x] Passes schema validation
- [x] All fields properly typed
- [x] Null values accepted
- [x] Empty arrays accepted

### Multiple Programs
```json
{
  "programs": [
    {
      "Program_Name": "ABC Bank Senior",
      "Capital_Provider_Org": {"Name": "ABC Bank"},
      "Contacts": []
    },
    {
      "Program_Name": "XYZ Fund Mezzanine",
      "Capital_Provider_Org": {"Name": "XYZ Fund"},
      "Contacts": []
    }
  ]
}
```
- [x] Multiple programs supported
- [x] Each program has own organization
- [x] Each program has own contacts

## Edge Cases

### Null Values ✓
- [x] All optional string fields accept null
- [x] All optional numeric fields accept null
- [x] All optional boolean fields accept null
- [x] Null values in enums accepted

### Empty Arrays ✓
- [x] Asset_Types: [] accepted
- [x] Transaction_Types: [] accepted
- [x] Capital_Stack: [] accepted
- [x] Typical_Amortization: [] accepted
- [x] Target_Property_Locations: [] accepted
- [x] Contacts: [] accepted

### Empty Strings ✓
- [x] String fields accept empty strings ""
- [x] Empty strings treated as valid values
- [x] Distinct from null values

### Missing Optional Fields ✓
- [x] Optional fields can be omitted entirely
- [x] Schema doesn't require all fields
- [x] Only required fields must be present

## Compatibility Checks

### Supabase Schema ✓
- [x] programs table: Compatible
- [x] organizations table: Can extract from Capital_Provider_Org
- [x] contacts table: Can extract from Contacts array
- [x] All field types compatible

### Matching Algorithm ✓
- [x] Capital_Stack values: Compatible
- [x] Asset_Types values: Compatible
- [x] Recourse values: Compatible
- [x] All enum values valid

### System Prompt ✓
- [x] Schema matches system prompt examples
- [x] Nested structure documented
- [x] Output format consistent

## Performance Considerations

- [x] Schema is reasonably sized (780 lines)
- [x] No circular references
- [x] No deeply nested structures
- [x] Validation should be fast

## Documentation

- [x] All fields documented
- [x] All enums documented
- [x] All types documented
- [x] Format guidance provided
- [x] Examples provided

## Sign-Off

**Schema Status**: ✓ READY FOR PRODUCTION

**Validation Date**: 2025-10-27

**Validated By**: Augment Agent

**Key Improvements**:
1. ✓ Comprehensive null value handling
2. ✓ Empty array support
3. ✓ Complete field descriptions
4. ✓ Consistent enum patterns
5. ✓ Improved boolean fields
6. ✓ Format validations preserved
7. ✓ Required fields verified
8. ✓ Nested structure maintained
9. ✓ Backward compatible
10. ✓ Production ready

**Next Steps**:
1. Deploy schema to production
2. Update any consuming code if needed
3. Monitor for validation issues
4. Collect feedback from users

