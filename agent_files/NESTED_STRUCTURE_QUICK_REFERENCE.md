# Nested Structure Quick Reference

## Correct Output Structure

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
      "Pricing": {...},
      "Capital_Provider_Org": {
        "Name": "ABC Bank",
        "HQ_Location": "Boston, MA",
        "Organization_Type": "Bank",
        "Website_URL": "https://www.abcbank.com",
        "Parent_Organization": null,
        "Notes": "..."
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
          "Notes": "..."
        }
      ]
    }
  ]
}
```

## Key Points

### Top-Level
- Only `programs` array at top level
- No top-level `organization` or `contacts`

### Each Program Contains
- All program details (Program_Name, Asset_Parameters, etc.)
- `Capital_Provider_Org` object (organization information)
- `Contacts` array (contact information)

### Capital_Provider_Org
- Required field: `Name`
- Optional fields: HQ_Location, Organization_Type, Website_URL, Parent_Organization, Notes
- Represents the lender/investor providing this program

### Contacts Array
- Can be empty if no contacts found
- Each contact requires: `Name`
- Optional fields: Title, Email, Phone, Organization_Name, LinkedIn, Location, Timezone, Notes

## Multiple Programs Example

```json
{
  "programs": [
    {
      "Program_Name": "ABC Bank Senior Debt",
      "Capital_Provider_Org": {
        "Name": "ABC Bank",
        "Organization_Type": "Bank"
      },
      "Contacts": [
        {
          "Name": "John Smith",
          "Email": "john.smith@abcbank.com"
        }
      ]
    },
    {
      "Program_Name": "XYZ Fund Mezzanine",
      "Capital_Provider_Org": {
        "Name": "XYZ Fund",
        "Organization_Type": "Debt Fund"
      },
      "Contacts": [
        {
          "Name": "Jane Doe",
          "Email": "jane.doe@xyzfund.com"
        }
      ]
    }
  ]
}
```

## Why Nested?

1. **Multiple Organizations**: Each program can be from a different organization
2. **Contextual Relationships**: Organization and contacts belong to specific programs
3. **Flexibility**: Each program maintains its own context
4. **Scalability**: Easy to handle complex scenarios

## Common Mistakes to Avoid

### ❌ WRONG: Top-Level Organization
```json
{
  "programs": [...],
  "organization": {...},
  "contacts": [...]
}
```

### ✓ CORRECT: Nested Organization
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

### ❌ WRONG: Missing Capital_Provider_Org
```json
{
  "programs": [
    {
      "Program_Name": "...",
      "Contacts": [...]
    }
  ]
}
```

### ✓ CORRECT: Include Capital_Provider_Org
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

## Field Requirements

### Capital_Provider_Org
- `Name`: **REQUIRED** (string)
- `HQ_Location`: Optional (string, format: "City, State")
- `Organization_Type`: Optional (enum: Bank, Fund, REIT, etc.)
- `Website_URL`: Optional (string, URL format)
- `Parent_Organization`: Optional (string)
- `Notes`: Optional (string)

### Contact
- `Name`: **REQUIRED** (string)
- `Title`: Optional (string)
- `Email`: Optional (string, email format)
- `Phone`: Optional (string, format: XXX-XXX-XXXX)
- `Organization_Name`: Optional (string)
- `LinkedIn`: Optional (string)
- `Location`: Optional (string)
- `Timezone`: Optional (string)
- `Notes`: Optional (string)

## Validation Checklist

- [ ] Top-level contains only `programs` array
- [ ] Each program has `Capital_Provider_Org` object
- [ ] Each program has `Contacts` array
- [ ] Capital_Provider_Org has `Name` field
- [ ] Each contact has `Name` field
- [ ] Email addresses are valid format
- [ ] Phone numbers are XXX-XXX-XXXX format
- [ ] Organization_Type is valid enum value
- [ ] All optional fields are either string or null
- [ ] No extra fields present

## Code Examples

### Accessing Organization
```javascript
const program = data.programs[0];
const org = program.Capital_Provider_Org;
console.log(org.Name); // "ABC Bank"
```

### Accessing Contacts
```javascript
const program = data.programs[0];
const contacts = program.Contacts;
contacts.forEach(contact => {
  console.log(contact.Name); // "John Smith"
});
```

### Iterating All Programs
```javascript
data.programs.forEach(program => {
  const orgName = program.Capital_Provider_Org.Name;
  const contactCount = program.Contacts.length;
  console.log(`${program.Program_Name} from ${orgName} (${contactCount} contacts)`);
});
```

### Database Insert Pattern
```javascript
for (const program of data.programs) {
  // Insert program
  const programId = await db.programs.insert(program);
  
  // Insert organization
  const orgId = await db.organizations.insert({
    ...program.Capital_Provider_Org,
    program_id: programId
  });
  
  // Insert contacts
  for (const contact of program.Contacts) {
    await db.contacts.insert({
      ...contact,
      organization_id: orgId
    });
  }
}
```

## Files to Reference

- **Schema**: `System Prompts/CPD_BOT_PROGRAM_INFO_EXTRACTOR_OUTPUT_SCHEMA.json`
- **System Prompt**: `System Prompts/CPD_BOT_PROGRAM_INFO_EXTRACTOR.md`
- **Detailed Guide**: `agent_files/SCHEMA_REVERSION_SUMMARY.md`
- **Complete Status**: `agent_files/REVERSION_COMPLETE.md`

## Summary

✓ Organization and contacts are **nested within each program**
✓ Each program maintains its own context
✓ Supports multiple programs from different organizations
✓ Flexible and scalable architecture
✓ This is the correct and final structure

