# CPD-Bot Quick Reference Guide

## Entity Types to Extract

### Programs
Lending products, loan terms, capital stack offerings, underwriting criteria, leverage constraints, recourse terms, amortization schedules, closing timelines, program-specific requirements.

### Organizations
Lender/investor company information, legal entity names, headquarters locations, company type (Bank, Fund, REIT, etc.), organizational structure details.

### Contacts
Individual people, titles/roles, email addresses, phone numbers, organizational affiliations. Extract from signatures, sender information, and message content.

## Inference Hierarchy

### 1. Context Clues
- "We typically lend on multifamily" → Asset_Types: ["Apartments"]
- "We provide mezzanine financing" → Capital_Stack: ["Mezzanine"]
- "Full recourse loans" → Recourse: "Always Full Recourse"
- "We focus on the Northeast" → Target_Property_Locations: [Northeast states]

### 2. Industry Standards
- Senior debt → "Senior"
- Mezzanine → "Mezzanine"
- Preferred equity → "Preferred Equity"
- Co-GP / JV Equity → "Co-GP Equity"
- LP / Limited Partner → "LP Equity"
- PACE → "PACE"
- Ground lease → "Ground Lease Buyer"

### 3. Related Fields
- LTC mentioned → likely Senior capital stack
- DSCR requirement → likely Senior or Subordinate
- Equity check size → likely Equity capital stack

### 4. Accuracy Priority
**Leave empty if uncertain. Don't fabricate data.**

## Normalization Rules

### Geographic
- "California" → "CA" (USPS code)
- "new york" → "New York" (proper case)
- "LA" → "Los Angeles" (MSA name)

### Capital Stack
- "First Lien" → "Senior"
- "Mez" → "Mezzanine"
- "JV Equity" → "Co-GP Equity"

### Asset Types
- "Multifamily" → "Apartments"
- "Hospitality" → "Hotel"
- "Warehouse" → "Light Industrial"
- "Industrial" → "Light Industrial"

### Recourse
- "Full recourse" → "Always Full Recourse"
- "Limited recourse" → "Selective"
- Default: "Selective" (if not mentioned)

### Monetary Values
- "$5,000,000" → "5000000" (digits only)
- "$50M" → "50000000"

### Percentages
- "75%" → "0.75" (decimal string)
- "60 percent" → "0.60"

## Missing Data Strategy

### Not Mentioned (Leave Empty)
- Field not discussed in message
- No context clues available
- Example: No mention of amortization → Typical_Amortization: ""

### Explicitly N/A (Note in Notes Field)
- Source explicitly states field doesn't apply
- Example: "We don't have geographic restrictions" → Notes: "Nationwide program"

## Implicit Information Extraction

### Email Signature
Extract: Name, Title, Email, Phone, Organization

### Email Domain
john@bankname.com → Organization: "Bank Name"

### Message Context
"I'm the head of lending" → Title: "Head of Lending"

## Output Structure

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
            "Capital_Provider_Org": {...},
            "Program_Type": "...",
            "Contacts": [...],
            "Marketing_Description": "...",
            "Notes": "..."
        }
    ],
    "organizations": [
        {
            "Name": "...",
            "HQ_Location": "...",
            "Organization_Type": "...",
            "Notes": "..."
        }
    ],
    "contacts": [
        {
            "Name": "...",
            "Title": "...",
            "Email": "...",
            "Phone": "...",
            "Organization_Name": "...",
            "Notes": "..."
        }
    ]
}
```

## Validation Checklist

- [ ] Monetary values are digit-only strings (no $ or commas)
- [ ] Percentages are decimal strings (0.75 not 75%)
- [ ] State codes are two-letter USPS codes
- [ ] Capital stack values match schema exactly
- [ ] Asset types match schema exactly
- [ ] Empty fields use empty string "" not null
- [ ] Contact emails exclude internal domains (saltandwisdom.com, ludianadvisors.com)
- [ ] Program names follow "[Provider Name] [Program Type]" format
- [ ] Geographic data is normalized and consistent
- [ ] Ambiguities documented in Notes field

## Exclusion Rules

**Do NOT extract contacts with emails containing:**
- "salt and wisdom"
- "saltandwisdom.com"
- "ludian"
- "ludianadvisors.com"

## Key Principles

1. **Accuracy > Completeness**: Leave fields empty rather than guess
2. **Inference with Confidence**: Only infer when reasonable confidence exists
3. **Document Ambiguities**: Use Notes field for unclear information
4. **Normalize Everything**: Match database schema exactly
5. **Extract Relationships**: Maintain links between entities
6. **Handle Multiple Entities**: Extract programs, organizations, and contacts separately

