# JSON Schema Validation Guide

## Overview
This guide explains how to validate CPD-Bot output against the updated JSON schema.

## Schema Location
`System Prompts/CPD_BOT_PROGRAM_INFO_EXTRACTOR_OUTPUT_SCHEMA.json`

## Top-Level Structure

### Required Fields
All three top-level fields are required:
```json
{
  "programs": [...],      // Required: Array of programs
  "organization": {...},  // Required: Single organization object
  "contacts": [...]       // Required: Array of contacts (can be empty)
}
```

## Programs Array

### Structure
```json
"programs": [
  {
    "Program_Name": "string",
    "Asset_Parameters": {...},
    "Deal_Parameters": {...},
    "Sizing": {...},
    "Sponsor_Requirements": {...},
    "Guarantor_Requirements": {...},
    "Program_Term_Details": {...},
    "Program_Type": "string",
    "Marketing_Description": "string",
    "Notes": "string",
    "Pricing": {...}
  }
]
```

### Validation Rules

#### Program_Name
- Type: string
- Required: No (but recommended)
- Format: "[Provider Name] [Program Type]"
- Example: "ABC Bank Senior Debt"

#### Asset_Parameters
- Type: object
- Contains:
  - `Asset_Types`: array of strings from predefined enum
  - `Commercial_Tenancy`: "Single tenant" | "Multi-tenant" | "Any"
  - `Single_Tenant_list`: string
  - `Single_Tenant_Min_Bond_Credit_Rating`: Moody's rating or null
  - `Hotel_Flag_required`: boolean
  - `Hotel_Flag_list`: string
  - `Ground_Lease`: "Leasehold" | "Leased Fee" | "Fee Simple" | null
  - `Min_Occupancy`: string
  - `Target_Property_Locations`: array of location objects

#### Deal_Parameters
- Type: object
- Contains:
  - `Transaction_Types`: array of ["Acquisition", "New Development", "Redevelopment", "Refinance"]
  - `Term_Length`: string
  - `Investment_Strategy`: "Core" | "Core Plus" | "Value-Add" | "Opportunistic" | null

#### Sizing
- Type: object
- Contains:
  - `Minimum_Check_Size`: string (digit-only format)
  - `Maximum_Check_Size`: string (digit-only format)
  - `Capital_Stack`: array of ["Senior", "Mezzanine", "Preferred Equity", "LP Equity", "Co-GP Equity", "PACE", "Line of Credit", "Note Purchase"]
  - `Leverage_Constraints`: object with LTV, DSCR, LTC, etc.

#### Sponsor_Requirements
- Type: object
- Contains:
  - `Location`: string
  - `Experience_Level`: string
  - `AUM`: string (digit-only format)
  - `US_Citizenship_Required`: boolean (default: true)

#### Guarantor_Requirements
- Type: object
- Contains:
  - `Min_Credit_Score`: number | string | null
  - `Min_Net_Worth`: number | string | null
  - `Min_Net_Worth_Ratio`: number | string | null
  - `Min_Liquidity`: number | string | null
  - `Min_Liquidity_Ratio`: number | string | null
  - `Guarantor_Type`: "Warm Body" | "Corporation OK"

#### Program_Term_Details
- Type: object
- Contains:
  - `Recourse`: "Always Full Recourse" | "Always Non-recourse" | "Selective" | null
  - `Accepts_PACE_financing`: "Yes" | "No" | "Unknown"
  - `Typical_Amortization`: array of ["15", "20", "25", "30", "35", "40", "Self-Amortizing", "Interest Only"] | null
  - `Prepayment_Penalty`: "None" | "Stepdown" | "Lockout" | "Defeasance" | "Yield Maintenance" | null
  - `Typical_Days_to_Close`: string

#### Program_Type
- Type: string
- Enum: "Bank" | "Credit Union" | "Agency" | "Life Co" | "CMBS" | "SBA" | "Debt Fund" | "Family Office" | "Private Equity" | "Private Debt" | "REIT" | "Other"

#### Pricing
- Type: object
- Contains:
  - `Interest_Rate_Details`: object with Rate_Type, Rate_Index, Minimum_Spread, Maximum_Spread
  - `Typical_Fees`: string | null

## Organization Object

### Structure
```json
"organization": {
  "Name": "string",                    // Required
  "HQ_Location": "string",             // Optional
  "Organization_Type": "string",       // Optional
  "Website_URL": "string" | null,      // Optional
  "Parent_Organization": "string" | null,  // Optional
  "Notes": "string" | null             // Optional
}
```

### Validation Rules

#### Name
- Type: string
- Required: Yes
- Description: Legal entity name of the organization
- Example: "ABC Bank"

#### HQ_Location
- Type: string
- Required: No
- Format: "City, State" (e.g., "Boston, MA")
- Example: "Boston, MA"

#### Organization_Type
- Type: string
- Enum: "Bank" | "Credit Union" | "Agency" | "Life Co" | "CMBS" | "SBA" | "Debt Fund" | "Family Office" | "Private Equity" | "Private Debt" | "REIT" | "Other"

#### Website_URL
- Type: string | null
- Format: Valid URL
- Example: "https://www.abcbank.com"

#### Parent_Organization
- Type: string | null
- Description: Name of parent organization if applicable
- Example: "ABC Financial Group"

#### Notes
- Type: string | null
- Description: Additional notes about the organization
- Example: "Extracted from program context and contact signature"

## Contacts Array

### Structure
```json
"contacts": [
  {
    "Name": "string",                      // Required
    "Title": "string" | null,              // Optional
    "Email": "string" | null,              // Optional (email format)
    "Phone": "string" | null,              // Optional
    "Organization_Name": "string" | null,  // Optional
    "LinkedIn": "string" | null,           // Optional
    "Location": "string" | null,           // Optional
    "Timezone": "string" | null,           // Optional
    "Notes": "string" | null               // Optional
  }
]
```

### Validation Rules

#### Name
- Type: string
- Required: Yes
- Description: Full name of the contact
- Example: "John Smith"

#### Title
- Type: string | null
- Description: Job title or role
- Example: "SVP, Head of Lending"

#### Email
- Type: string | null
- Format: Valid email address
- Example: "john.smith@abcbank.com"
- Validation: Must exclude internal domains (saltandwisdom.com, ludianadvisors.com)

#### Phone
- Type: string | null
- Format: XXX-XXX-XXXX
- Example: "617-555-1234"

#### Organization_Name
- Type: string | null
- Description: Name of the organization the contact belongs to
- Example: "ABC Bank"

#### LinkedIn
- Type: string | null
- Description: LinkedIn profile URL or username
- Example: "https://linkedin.com/in/johnsmith"

#### Location
- Type: string | null
- Description: Geographic location of the contact
- Example: "Boston, MA"

#### Timezone
- Type: string | null
- Format: Standard timezone abbreviation
- Example: "EST" | "PST" | "CST"

#### Notes
- Type: string | null
- Description: Additional notes about the contact
- Example: "Extracted from email signature"

## Validation Checklist

### Programs Array
- [ ] Array is present and is an array type
- [ ] Each program has a Program_Name
- [ ] Asset_Types contains valid enum values
- [ ] Capital_Stack contains valid enum values
- [ ] Monetary values are digit-only strings (no $ or commas)
- [ ] Percentages are decimal strings (0.75 not 75%)
- [ ] Program_Type is valid enum value
- [ ] All nested objects have correct structure

### Organization Object
- [ ] Object is present and is an object type (not array)
- [ ] Name field is present and is a string
- [ ] HQ_Location is in "City, State" format if present
- [ ] Organization_Type is valid enum value if present
- [ ] Website_URL is valid URL format if present
- [ ] All optional fields are either string or null

### Contacts Array
- [ ] Array is present and is an array type
- [ ] Can be empty array if no contacts found
- [ ] Each contact has a Name field
- [ ] Email addresses are valid format if present
- [ ] Email addresses exclude internal domains
- [ ] Phone numbers are XXX-XXX-XXXX format if present
- [ ] All optional fields are either string or null

## Common Validation Errors

### Error: "programs is required"
**Cause**: Missing programs array
**Fix**: Ensure programs array is present (can be empty)

### Error: "organization is required"
**Cause**: Missing organization object
**Fix**: Ensure organization object is present with at least Name field

### Error: "contacts is required"
**Cause**: Missing contacts array
**Fix**: Ensure contacts array is present (can be empty)

### Error: "Invalid enum value"
**Cause**: Value not in predefined list
**Fix**: Check enum values and use exact match

### Error: "Invalid email format"
**Cause**: Email doesn't match email format
**Fix**: Ensure email is valid format (user@domain.com)

### Error: "Type mismatch"
**Cause**: Field has wrong type (e.g., string instead of number)
**Fix**: Check field type definition and convert value

## Testing with JSON Schema Validators

### Online Validators
- https://www.jsonschemavalidator.net/
- https://json-schema.org/

### Command Line (Node.js)
```bash
npm install ajv ajv-cli
ajv validate -s schema.json -d data.json
```

### Python
```python
import jsonschema
import json

with open('schema.json') as f:
    schema = json.load(f)

with open('data.json') as f:
    data = json.load(f)

jsonschema.validate(instance=data, schema=schema)
```

## Migration from Old Schema

If migrating from the old schema where organization and contacts were embedded in programs:

### Old Structure
```json
{
  "programs": [
    {
      "Program_Name": "...",
      "Capital_Provider_Org": {...},
      "Contacts": [...]
    }
  ]
}
```

### New Structure
```json
{
  "programs": [
    {
      "Program_Name": "..."
    }
  ],
  "organization": {...},
  "contacts": [...]
}
```

### Migration Steps
1. Extract `programs[0].Capital_Provider_Org` → `organization`
2. Extract `programs[0].Contacts` → `contacts`
3. Remove these fields from program objects
4. Ensure all three top-level fields are present

