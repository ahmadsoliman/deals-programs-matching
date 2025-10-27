# CPD-Bot System Prompt Improvements Summary

## Overview
Updated the CPD-Bot system prompt to incorporate intelligent inference, graceful handling of missing data, entity type detection, and enhanced extraction quality standards while maintaining compatibility with the existing Supabase schema and matching algorithm.

## Key Improvements

### 1. Entity Type Detection (NEW)
- **Automatic entity classification**: Bot now identifies whether messages contain updates for Programs, Organizations, or Contacts
- **Multi-entity handling**: Properly structures messages that update multiple entity types simultaneously
- **Relationship maintenance**: Maintains relationships between entities (e.g., contact belongs to organization, program belongs to organization)
- **Separate output arrays**: Programs, organizations, and contacts are now extracted into separate arrays in the JSON output

### 2. Intelligent Inference & Context-Based Reasoning (NEW)
Implemented a 4-tier inference hierarchy:

#### Tier 1: Context Clues from Message Content
- Asset type inference from lending focus ("we typically lend on multifamily" → Apartments)
- Capital stack inference from program descriptions ("mezzanine financing" → Mezzanine)
- Recourse inference from loan terms ("full recourse loans" → Always Full Recourse)
- Geographic inference from market focus ("Northeast focus" → NY, NJ, CT, MA, NH, PA)
- Leverage inference (LTC mentioned → likely Senior capital stack)
- Amortization inference ("30-year mortgages" → 30)

#### Tier 2: Industry Standards & Defaults
- Capital stack mapping with common variations (Senior debt, First Mortgage, Mezzanine, Mez, etc.)
- Recourse defaults (assume Selective unless stated otherwise)
- US citizenship defaults (assume required unless stated otherwise)
- Loan term defaults (bridge: 1-3 years, permanent: 5-15 years, construction: 1-3 years)
- Check size inference using industry-standard ranges

#### Tier 3: Related Field Inference
- LTC mentioned → likely Senior capital stack
- DSCR requirement → likely Senior or Subordinate capital stack
- Equity check size → likely Equity capital stack
- Property type → infer compatible asset types
- Geographic focus → infer target locations

#### Tier 4: Accuracy Priority
- **Critical rule**: Prioritize accuracy over completeness
- Leave fields empty rather than fabricate data
- Only make inferences with reasonable confidence
- Document speculative inferences in Notes field

### 3. Graceful Handling of Missing Data (NEW)
- **Distinction between "not mentioned" vs. "explicitly N/A"**:
  - Not mentioned: field not discussed → leave empty
  - Explicitly N/A: source states field doesn't apply → note in Notes field
- **Missing data strategy**: Extract available data → apply confident inferences → leave uncertain fields empty → document ambiguities
- **Notes field usage**: Document ambiguities, inferences, missing information, program quirks, and data quality issues

### 4. Extraction Quality Standards (ENHANCED)

#### Value Normalization
- **Geographic**: Convert to proper format, use USPS state codes, standardize MSA names
- **Capital Stack**: Standardize to exact schema values with variation mapping
- **Asset Types**: Map to schema values (Multifamily → Apartments, Hospitality → Hotel, etc.)
- **Recourse**: Standardize to Non-Recourse, Selective, or Always Full Recourse
- **Amortization**: Extract as year strings with min/max for ranges

#### Format Handling
- Parse bullet points, prose, tables, email signatures
- Extract implicit information from context and email domains

#### Implicit Information Extraction
- **Email signature**: Extract contact details + organization information
- **Email domain**: Infer organization from domain (john@bankname.com → Bank Name)
- **Message context**: Infer program characteristics from discussion
- **Sender role**: Infer title from context ("head of lending" → Head of Lending)

### 5. Enhanced Output Structure (NEW)
Changed from single-array output to three-array structure:
```json
{
    "programs": [...],
    "organizations": [...],
    "contacts": [...]
}
```

Each array may be empty if no data of that type is found. This enables:
- Separate tracking of organizations and contacts
- Relationship maintenance between entities
- Better data organization and reusability
- Alignment with Supabase schema (programs, organizations, contacts tables)

### 6. Validation Checklist (ENHANCED)
Added comprehensive validation checklist:
- Monetary values are digit-only strings
- Percentages are decimal strings (0.75 not 75%)
- State codes are two-letter USPS codes
- Capital stack values match schema exactly
- Asset types match schema exactly
- Empty fields use empty string "" not null
- Contact emails exclude internal domains
- Program names follow naming convention
- Geographic data is normalized and consistent

## Compatibility

### Supabase Schema Alignment
- Programs table: All program fields properly normalized
- Organizations table: New organization extraction with HQ_Location, Organization_Type
- Contacts table: New contact extraction with proper relationship to organizations
- Maintains compatibility with existing matching algorithm (rpc_match_program_current.sql)

### Backward Compatibility
- All existing extraction rules preserved
- New capabilities are additive, not replacing
- Existing field mappings unchanged
- Capital stack values remain compatible with matching algorithm

## Implementation Notes

### Key Reminders for CPD-Bot
1. Apply intelligent inference based on context, industry standards, and related fields
2. Prioritize accuracy over completeness—leave fields empty when uncertain
3. Normalize all values to match database schema exactly
4. Extract implicit information from signatures, domains, and context
5. Distinguish between "not mentioned" (empty) and "explicitly N/A" (note in Notes)
6. Document ambiguities and inferences in the Notes field
7. Exclude internal contacts (saltandwisdom.com, ludianadvisors.com domains)

### Testing Recommendations
- Test with email threads containing multiple entity types
- Verify inference accuracy with ambiguous program descriptions
- Validate normalization against database schema
- Test implicit information extraction from signatures
- Verify relationship maintenance between entities

