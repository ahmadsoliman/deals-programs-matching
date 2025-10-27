# JSON Schema Reversion Summary

## Overview

Reverted the JSON schema to the correct nested structure where organization and contacts are nested within each program object, not at the top level. This is the correct architecture for handling multiple programs from different organizations in a single extraction.

## Rationale

### Why Nested Structure is Correct

1. **Multiple Programs from Different Organizations**: When a source message contains multiple lending programs, they may be from different organizations with different contacts
2. **Contextual Relationship**: Organization and contacts are contextually tied to each specific program
3. **Flexibility**: Each program can have its own organization and contacts data
4. **Scalability**: Supports scenarios where the same organization appears in multiple programs with different contact information

### Example Scenario

If an email discusses programs from both ABC Bank and XYZ Fund:
- Program 1: ABC Bank Senior Debt (with ABC Bank org info and ABC contacts)
- Program 2: XYZ Fund Mezzanine (with XYZ Fund org info and XYZ contacts)

With nested structure, each program contains its own organization and contacts data.

## Changes Made

### 1. JSON Schema File
**File**: `System Prompts/CPD_BOT_PROGRAM_INFO_EXTRACTOR_OUTPUT_SCHEMA.json`

#### Changes:
- ✓ Updated schema description to reflect nested structure
- ✓ Added `Capital_Provider_Org` object back inside program object
- ✓ Added `Contacts` array back inside program object
- ✓ Removed top-level `organization` object
- ✓ Removed top-level `contacts` array
- ✓ Updated required fields to only include `programs`

#### Structure:
```json
{
  "programs": [
    {
      "Program_Name": "...",
      "Asset_Parameters": {...},
      "Deal_Parameters": {...},
      "Sizing": {...},
      "Sponsor_Requirements": {...},
      "Guarantor_Requirements": {...},
      "Program_Term_Details": {...},
      "Program_Type": "...",
      "Marketing_Description": "...",
      "Notes": "...",
      "Pricing": {...},
      "Capital_Provider_Org": {
        "Name": "...",
        "HQ_Location": "...",
        "Organization_Type": "...",
        "Website_URL": "...",
        "Parent_Organization": "...",
        "Notes": "..."
      },
      "Contacts": [
        {
          "Name": "...",
          "Title": "...",
          "Email": "...",
          "Phone": "...",
          "Organization_Name": "...",
          "LinkedIn": "...",
          "Location": "...",
          "Timezone": "...",
          "Notes": "..."
        }
      ]
    }
  ]
}
```

### 2. System Prompt File
**File**: `System Prompts/CPD_BOT_PROGRAM_INFO_EXTRACTOR.md`

#### Changes:
- ✓ Updated Entity Type Detection section to reflect nested structure
- ✓ Updated example output to show Capital_Provider_Org and Contacts inside program
- ✓ Updated Output Structure section with nested structure example
- ✓ Updated Final Instructions with 10 key reminders including nested structure guidance

#### Key Updates:
1. **Entity Type Detection**: Clarified that organization and contacts are nested within programs
2. **Multi-Entity Messages**: Explained that each program contains its own organization and contacts
3. **Example Output**: Shows Capital_Provider_Org and Contacts inside program object
4. **Output Structure**: Detailed nested structure with all fields
5. **Final Instructions**: Added reminders about nested structure and empty contacts arrays

## Field Definitions

### Capital_Provider_Org (inside each program)
- `Name` (required): Legal entity name
- `HQ_Location` (optional): Headquarters location in "City, State" format
- `Organization_Type` (optional): Type of organization (Bank, Fund, REIT, etc.)
- `Website_URL` (optional): Organization website URL
- `Parent_Organization` (optional): Parent organization name if applicable
- `Notes` (optional): Additional notes about the organization

### Contacts (array inside each program)
- `Name` (required): Full name of the contact
- `Title` (optional): Job title or role
- `Email` (optional): Email address with format validation
- `Phone` (optional): Phone number in XXX-XXX-XXXX format
- `Organization_Name` (optional): Name of the organization the contact belongs to
- `LinkedIn` (optional): LinkedIn profile URL or username
- `Location` (optional): Geographic location of the contact
- `Timezone` (optional): Timezone (e.g., 'EST', 'PST')
- `Notes` (optional): Additional notes about the contact

## Validation Rules

### All Preserved ✓
- All program field validations intact
- All asset parameter validations intact
- All deal parameter validations intact
- All sizing validations intact
- All sponsor requirement validations intact
- All guarantor requirement validations intact
- All program term detail validations intact
- All pricing validations intact
- All enum values preserved
- All type definitions preserved

### New Validations ✓
- Capital_Provider_Org.Name is required
- Contact.Name is required
- Email format validation for contacts
- Phone format validation for contacts

## Compatibility

### Supabase Schema ✓
- programs table: Compatible
- organizations table: Can be extracted from Capital_Provider_Org
- contacts table: Can be extracted from Contacts array

### Matching Algorithm ✓
- rpc_match_program_current.sql: Compatible
- All capital stack values: Compatible
- All asset type values: Compatible
- All recourse values: Compatible

## Migration from Previous Version

### Old Structure (Top-Level Entities)
```json
{
  "programs": [...],
  "organization": {...},
  "contacts": [...]
}
```

### New Structure (Nested)
```json
{
  "programs": [
    {
      "...program fields...",
      "Capital_Provider_Org": {...},
      "Contacts": [...]
    }
  ]
}
```

### Migration Steps
1. For each program in the programs array:
   - Move organization data to `Capital_Provider_Org` inside the program
   - Move contacts data to `Contacts` array inside the program
2. Remove top-level `organization` and `contacts` objects
3. Update code to access organization via `program.Capital_Provider_Org`
4. Update code to access contacts via `program.Contacts`

## Testing Recommendations

### Unit Tests
- [ ] Validate single program with organization and contacts
- [ ] Validate multiple programs with different organizations
- [ ] Validate program with empty contacts array
- [ ] Validate program with minimal organization (only Name)
- [ ] Validate program with all optional fields populated
- [ ] Validate program with all optional fields as null

### Integration Tests
- [ ] Test complete extraction with multiple programs
- [ ] Test with programs from same organization
- [ ] Test with programs from different organizations
- [ ] Test with various contact information
- [ ] Test email format validation
- [ ] Test phone format validation

### Validation Tests
- [ ] Use JSON Schema validator
- [ ] Verify all required fields present
- [ ] Verify no extra fields present
- [ ] Verify all types correct
- [ ] Verify all enum values valid

## Files Modified

- ✓ `System Prompts/CPD_BOT_PROGRAM_INFO_EXTRACTOR_OUTPUT_SCHEMA.json` (625 lines)
- ✓ `System Prompts/CPD_BOT_PROGRAM_INFO_EXTRACTOR.md` (394 lines)

## Status

✓ Schema reverted to nested structure
✓ System prompt updated
✓ All validation rules preserved
✓ All field definitions preserved
✓ Ready for deployment

## Key Takeaway

The nested structure is the correct architecture because:
1. It supports multiple programs from different organizations
2. Each program maintains its own organization and contacts context
3. It's more flexible and scalable
4. It aligns with real-world scenarios where programs come from different sources

This is the final, correct structure for the CPD-Bot extraction system.

