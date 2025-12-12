# JSON Schema Structure Comparison

## Overview
This document shows the structural changes from the old schema to the new schema.

## Old Schema Structure

### Top-Level
```json
{
  "programs": [...]
}
```

### Program Object (Old)
```json
{
  "Program_Name": "string",
  "Asset_Parameters": {...},
  "Deal_Parameters": {...},
  "Sizing": {...},
  "Sponsor_Requirements": {...},
  "Guarantor_Requirements": {...},
  "Program_Term_Details": {...},
  "Capital_Provider_Org": {
    "Name": "string",
    "Website_URL": "string",
    "HQ_Location": "string",
    "Parent_Organization": "string"
  },
  "Program_Type": "string",
  "Contacts": [
    {
      "Name": "string",
      "Email": "string",
      "Phone": "string",
      "Title": "string",
      "LinkedIn": "string",
      "Location": "string",
      "Timezone": "string",
      "Notes": "string"
    }
  ],
  "Marketing_Description": "string",
  "Notes": "string",
  "Pricing": {...}
}
```

### Issues with Old Structure
1. **Redundancy**: Organization data repeated in every program (if multiple programs)
2. **Inflexibility**: Contacts embedded in programs, not accessible separately
3. **Scalability**: Difficult to query or filter by organization or contact
4. **Normalization**: Violates database normalization principles
5. **Complexity**: Nested structure makes validation and processing harder

## New Schema Structure

### Top-Level
```json
{
  "programs": [...],
  "organization": {...},
  "contacts": [...]
}
```

### Program Object (New)
```json
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
```

### Organization Object (New)
```json
{
  "Name": "string",
  "HQ_Location": "string",
  "Organization_Type": "string",
  "Website_URL": "string" | null,
  "Parent_Organization": "string" | null,
  "Notes": "string" | null
}
```

### Contacts Array (New)
```json
[
  {
    "Name": "string",
    "Title": "string" | null,
    "Email": "string" | null,
    "Phone": "string" | null,
    "Organization_Name": "string" | null,
    "LinkedIn": "string" | null,
    "Location": "string" | null,
    "Timezone": "string" | null,
    "Notes": "string" | null
  }
]
```

## Side-by-Side Comparison

| Aspect | Old Schema | New Schema | Benefit |
|--------|-----------|-----------|---------|
| **Top-level structure** | Single array | Three separate entities | Better organization |
| **Organization data** | Embedded in each program | Top-level object | No redundancy |
| **Contacts data** | Embedded in each program | Top-level array | Separate access |
| **Organization_Type** | Not present | Included | Better classification |
| **Contact.Organization_Name** | Not present | Included | Explicit relationship |
| **Required fields** | Only programs | programs, organization, contacts | Explicit requirements |
| **Scalability** | Limited | Excellent | Easier to extend |
| **Database alignment** | Poor | Excellent | Matches Supabase schema |
| **Validation** | Complex | Simple | Easier to validate |

## Data Migration Example

### Old Output
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
      "Capital_Provider_Org": {
        "Name": "ABC Bank",
        "Website_URL": "https://www.abcbank.com",
        "HQ_Location": "Boston, MA",
        "Parent_Organization": null
      },
      "Program_Type": "Bank",
      "Contacts": [
        {
          "Name": "John Smith",
          "Email": "john.smith@abcbank.com",
          "Phone": "617-555-1234",
          "Title": "SVP, Head of Lending",
          "LinkedIn": "https://linkedin.com/in/johnsmith",
          "Location": "Boston, MA",
          "Timezone": "EST",
          "Notes": "Extracted from email signature"
        }
      ],
      "Marketing_Description": "...",
      "Notes": "...",
      "Pricing": {...}
    }
  ]
}
```

### New Output
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

## Key Improvements

### 1. Reduced Redundancy
- **Old**: Organization data repeated in every program
- **New**: Single organization object shared across all programs
- **Benefit**: Smaller JSON, easier to update

### 2. Better Separation of Concerns
- **Old**: Programs, organizations, and contacts mixed together
- **New**: Each entity type has its own top-level array/object
- **Benefit**: Cleaner structure, easier to process

### 3. Improved Relationships
- **Old**: Implicit relationships (contacts in programs)
- **New**: Explicit relationships (Organization_Name in contacts)
- **Benefit**: Clearer data model, easier to validate

### 4. Enhanced Flexibility
- **Old**: Fixed structure with embedded data
- **New**: Flexible structure with separate entities
- **Benefit**: Easier to add new programs or contacts

### 5. Database Alignment
- **Old**: Doesn't match Supabase schema
- **New**: Aligns with programs, organizations, contacts tables
- **Benefit**: Direct mapping to database

### 6. Validation Simplicity
- **Old**: Complex nested validation
- **New**: Simple flat validation for each entity
- **Benefit**: Easier to validate and debug

## Backward Compatibility

### Breaking Changes
1. ✗ `Capital_Provider_Org` removed from programs
2. ✗ `Contacts` removed from programs
3. ✗ `organizations` array changed to `organization` object

### Migration Path
```javascript
// Old code
const org = data.programs[0].Capital_Provider_Org;
const contacts = data.programs[0].Contacts;

// New code
const org = data.organization;
const contacts = data.contacts;
```

## Performance Implications

### Old Schema
- Larger JSON size (redundant organization data)
- Slower to parse (nested structures)
- Harder to query (need to traverse programs)

### New Schema
- Smaller JSON size (no redundancy)
- Faster to parse (flat structure)
- Easier to query (direct access to entities)

## Validation Complexity

### Old Schema
```
Root
├── programs (array)
│   └── [0] (object)
│       ├── Program_Name
│       ├── Asset_Parameters
│       ├── ...
│       ├── Capital_Provider_Org (object)
│       │   ├── Name
│       │   ├── Website_URL
│       │   ├── HQ_Location
│       │   └── Parent_Organization
│       └── Contacts (array)
│           └── [0] (object)
│               ├── Name
│               ├── Email
│               └── ...
```

### New Schema
```
Root
├── programs (array)
│   └── [0] (object)
│       ├── Program_Name
│       ├── Asset_Parameters
│       └── ...
├── organization (object)
│   ├── Name
│   ├── HQ_Location
│   ├── Organization_Type
│   └── ...
└── contacts (array)
    └── [0] (object)
        ├── Name
        ├── Title
        └── ...
```

## Summary

The new schema provides:
- ✓ Better organization of data
- ✓ Reduced redundancy
- ✓ Improved scalability
- ✓ Alignment with database schema
- ✓ Simpler validation
- ✓ Clearer relationships
- ✓ Better performance
- ✓ More flexible structure

All validation rules and field definitions from the old schema have been preserved and enhanced.

