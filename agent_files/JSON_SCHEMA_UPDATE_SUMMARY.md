# JSON Schema Update Summary

## File Updated
`System Prompts/CPD_BOT_PROGRAM_INFO_EXTRACTOR_OUTPUT_SCHEMA.json`

## Changes Made

### 1. Organization Structure Change ✓
**Before**: `organizations` was an array
```json
"organizations": [
  {
    "Name": "...",
    "HQ_Location": "...",
    ...
  }
]
```

**After**: `organization` is now a single object
```json
"organization": {
  "Name": "...",
  "HQ_Location": "...",
  ...
}
```

**Rationale**: Since there is always exactly one organization in context per extraction, using a single object is more appropriate and simplifies the structure.

### 2. Removed Deprecated Fields from Program Object ✓
Removed the following fields from the program schema since they are now top-level entities:
- `Capital_Provider_Org` - Replaced by top-level `organization` object
- `Contacts` - Replaced by top-level `contacts` array

These fields were embedded in each program object in the old schema but are now extracted as separate top-level entities.

### 3. Enhanced JSON Schema Structure ✓

#### Top-Level Properties
The schema now has three top-level properties:

**a) programs** (array)
- Type: Array of program objects
- Description: "Array of lending programs extracted from the source material"
- Contains all program details with all validation rules preserved

**b) organization** (object)
- Type: Single object
- Description: "Single organization object representing the capital provider. There is always exactly one organization in context per extraction."
- Properties:
  - `Name` (string, required): Legal entity name
  - `HQ_Location` (string): Headquarters location in format 'City, State'
  - `Organization_Type` (string): Type of organization (Bank, Fund, REIT, etc.)
  - `Website_URL` (string or null): Organization website
  - `Parent_Organization` (string or null): Parent organization name if applicable
  - `Notes` (string or null): Additional notes

**c) contacts** (array)
- Type: Array of contact objects
- Description: "Array of contact objects representing individuals associated with the organization"
- Properties per contact:
  - `Name` (string, required): Full name
  - `Title` (string or null): Job title or role
  - `Email` (string or null): Email address with format validation
  - `Phone` (string or null): Phone number in format XXX-XXX-XXXX
  - `Organization_Name` (string or null): Organization affiliation
  - `LinkedIn` (string or null): LinkedIn profile URL or username
  - `Location` (string or null): Geographic location
  - `Timezone` (string or null): Timezone (e.g., 'EST', 'PST')
  - `Notes` (string or null): Additional notes

### 4. Updated Required Fields ✓
**Before**: Only `programs` was required
```json
"required": ["programs"]
```

**After**: All three top-level entities are required
```json
"required": ["programs", "organization", "contacts"]
```

**Note**: The `contacts` array can be empty if no contacts are found, but the field must be present.

### 5. Enhanced Descriptions ✓
Added comprehensive descriptions to all top-level properties and key fields:
- Program_Name: "Formal program name using format '[Provider Name] [Program Type]'"
- organization: "Single organization object representing the capital provider. There is always exactly one organization in context per extraction."
- contacts: "Array of contact objects representing individuals associated with the organization"
- All organization fields have descriptive text
- All contact fields have descriptive text

## Validation Rules Preserved

All existing validation rules from the original schema have been maintained:

### Program Object
- All Asset_Parameters validations intact
- All Deal_Parameters validations intact
- All Sizing validations intact
- All Sponsor_Requirements validations intact
- All Guarantor_Requirements validations intact
- All Program_Term_Details validations intact
- All Pricing validations intact
- Marketing_Description and Notes fields preserved

### Organization Object
- Name is required
- Organization_Type uses same enum as Program_Type
- All optional fields allow null values

### Contacts Array
- Name is required for each contact
- Email has format validation
- All other fields are optional and allow null values

## Backward Compatibility

### Breaking Changes
- ✓ `Capital_Provider_Org` field removed from program object
- ✓ `Contacts` field removed from program object
- ✓ `organizations` array changed to `organization` object

### Migration Path
If you have existing code consuming the old schema:

1. **Organization data**: Move from `programs[i].Capital_Provider_Org` to top-level `organization`
2. **Contacts data**: Move from `programs[i].Contacts` to top-level `contacts`
3. **Array access**: Change from `organizations[0]` to `organization` (no array indexing)

## Example Output Structure

```json
{
  "programs": [
    {
      "Program_Name": "ABC Bank Senior Debt",
      "Asset_Parameters": {...},
      "Deal_Parameters": {...},
      "Sizing": {...},
      "Sponsor_Requirements": {...},
      "Guarantor_Requirements": {...},
      "Program_Term_Details": {...},
      "Program_Type": "Bank",
      "Marketing_Description": "...",
      "Notes": "...",
      "Pricing": {...}
    }
  ],
  "organization": {
    "Name": "ABC Bank",
    "HQ_Location": "Boston, MA",
    "Organization_Type": "Bank",
    "Website_URL": "https://www.abcbank.com",
    "Parent_Organization": null,
    "Notes": "Extracted from program context"
  },
  "contacts": [
    {
      "Name": "John Smith",
      "Title": "SVP, Head of Lending",
      "Email": "john.smith@abcbank.com",
      "Phone": "617-555-1234",
      "Organization_Name": "ABC Bank",
      "LinkedIn": "https://linkedin.com/in/johnsmith",
      "Location": "Boston, MA",
      "Timezone": "EST",
      "Notes": "Extracted from email signature"
    }
  ]
}
```

## Validation

The updated schema is valid JSON Schema (draft 2020-12) and can be used to validate CPD-Bot output using any standard JSON Schema validator.

### Key Validation Points
- ✓ All required fields are specified
- ✓ All enum values are properly defined
- ✓ All type definitions are correct
- ✓ All descriptions are clear and actionable
- ✓ Null types are properly specified where optional
- ✓ Email format validation is included
- ✓ Nested object structures are properly defined

## Testing Recommendations

1. **Validate existing extractions** against the new schema
2. **Test with empty contacts array** to ensure it's handled correctly
3. **Test with minimal organization data** (only Name required)
4. **Test with all optional fields** populated
5. **Test with all optional fields** as null
6. **Validate email format** for contact emails
7. **Verify phone number format** matches XXX-XXX-XXXX pattern

## Files Affected

- ✓ `System Prompts/CPD_BOT_PROGRAM_INFO_EXTRACTOR_OUTPUT_SCHEMA.json` - Updated
- Related: `System Prompts/CPD_BOT_PROGRAM_INFO_EXTRACTOR.md` - Already updated with three-entity structure

## Status

✓ Schema update complete
✓ All validation rules preserved
✓ Backward compatibility documented
✓ Example output provided
✓ Ready for deployment

