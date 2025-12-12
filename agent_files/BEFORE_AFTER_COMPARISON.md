# CPD-Bot System Prompt - Before & After Comparison

## Overview

This document shows the key differences between the original and updated system prompt.

## 1. Core Objective

### BEFORE
```
Transform any unstructured lender or investor program information into a single, 
comprehensive JSON object that captures all relevant program details, requirements, 
and contact information in a standardized format.
```

### AFTER
```
Transform any unstructured lender or investor program information into a single, 
comprehensive JSON object that captures all relevant program details, requirements, 
and contact information in a standardized format. When data is incomplete or ambiguous, 
apply intelligent inference based on context clues, industry standards, and related 
fields to make educated guesses while maintaining accuracy as the top priority.
```

**Change**: Added explicit guidance on intelligent inference and accuracy priority.

---

## 2. Entity Type Detection

### BEFORE
- Not explicitly documented
- Assumed single program extraction per message

### AFTER
- **NEW SECTION**: Entity Type Detection
- Explicitly identifies Programs, Organizations, and Contacts
- Documents multi-entity message handling
- Explains relationship maintenance between entities

**Impact**: Bot now extracts and structures multiple entity types separately.

---

## 3. Intelligent Inference

### BEFORE
- Minimal guidance on handling incomplete data
- Relied on explicit information only

### AFTER
- **NEW SECTION**: Intelligent Inference & Context-Based Reasoning
- Four-tier inference hierarchy:
  1. Context clues from message content
  2. Industry standards & defaults
  3. Related field inference
  4. Accuracy priority
- Specific examples for each inference type
- Clear guidance on when NOT to infer

**Impact**: Bot can now make educated guesses while maintaining accuracy.

---

## 4. Missing Data Handling

### BEFORE
- Generic guidance: "Leave fields empty when they clearly don't apply"
- No distinction between different types of missing data

### AFTER
- **NEW SECTION**: Graceful Handling of Missing Data
- Clear distinction between "not mentioned" vs. "explicitly N/A"
- Five-step missing data strategy
- Specific Notes field usage guidelines
- Examples of each scenario

**Impact**: Bot now handles ambiguous situations more intelligently.

---

## 5. Extraction Quality

### BEFORE
- Basic normalization rules
- Limited guidance on format handling

### AFTER
- **ENHANCED SECTION**: Extraction Quality Standards
- Comprehensive value normalization (geographic, capital stack, asset types, recourse, amortization, monetary)
- Format handling for various input types (bullet points, prose, tables, signatures)
- Implicit information extraction (signatures, domains, context, roles)
- Validation checklist with 10 items

**Impact**: Bot now produces more consistent, normalized output.

---

## 6. Output Structure

### BEFORE
```json
{
    "programs": [...]
}
```

### AFTER
```json
{
    "programs": [...],
    "organizations": [...],
    "contacts": [...]
}
```

**Change**: Added separate arrays for organizations and contacts.

**Impact**: 
- Better data organization
- Enables relationship tracking
- Aligns with Supabase schema
- Supports multi-entity extraction

---

## 7. Inference Examples

### BEFORE
- No explicit inference examples
- Relied on general industry knowledge

### AFTER
- **NEW**: Specific inference examples for:
  - Asset types ("We typically lend on multifamily" → Apartments)
  - Capital stack ("We provide mezzanine financing" → Mezzanine)
  - Recourse ("Full recourse loans" → Always Full Recourse)
  - Geographic ("We focus on the Northeast" → Northeast states)
  - Leverage (LTC mentioned → likely Senior)
  - Amortization ("30-year mortgages" → 30)

**Impact**: Bot has clear guidance on what inferences to make.

---

## 8. Industry Standards

### BEFORE
- Mentioned but not comprehensive
- Limited mapping of variations

### AFTER
- **COMPREHENSIVE**: Capital stack mapping with all variations:
  - Senior debt / First Mortgage → "Senior"
  - Mezzanine / Mez → "Mezzanine"
  - Preferred equity → "Preferred Equity"
  - Co-GP / JV Equity → "Co-GP Equity"
  - LP / Limited Partner → "LP Equity"
  - PACE → "PACE"
  - Ground lease → "Ground Lease Buyer"
- Loan term defaults (bridge, permanent, construction)
- Recourse defaults

**Impact**: Bot can now handle more variations of terminology.

---

## 9. Implicit Information Extraction

### BEFORE
- Not explicitly documented
- Limited guidance on extracting from signatures

### AFTER
- **NEW SECTION**: Implicit Information Extraction
- Email signature → Contact + Organization
- Email domain → Organization inference
- Message context → Program details
- Sender role → Contact title

**Impact**: Bot can now extract information not explicitly stated.

---

## 10. Validation Checklist

### BEFORE
- Generic quality assurance principles
- No specific checklist

### AFTER
- **NEW**: 10-item validation checklist:
  - Monetary values are digit-only strings
  - Percentages are decimal strings
  - State codes are USPS codes
  - Capital stack values match schema
  - Asset types match schema
  - Empty fields use empty string
  - Contact emails exclude internal domains
  - Program names follow convention
  - Geographic data is normalized
  - Ambiguities documented

**Impact**: Bot has clear quality standards to follow.

---

## 11. Key Reminders

### BEFORE
- Generic quality assurance principles
- No specific action items

### AFTER
- **NEW**: 7 key reminders:
  1. Apply intelligent inference
  2. Prioritize accuracy over completeness
  3. Normalize all values
  4. Extract implicit information
  5. Distinguish "not mentioned" vs. "explicitly N/A"
  6. Document ambiguities
  7. Exclude internal contacts

**Impact**: Bot has clear priorities and guidelines.

---

## Summary of Changes

| Aspect | Before | After | Impact |
|--------|--------|-------|--------|
| Entity Types | Programs only | Programs, Organizations, Contacts | Better data organization |
| Inference | Minimal | Four-tier hierarchy | More intelligent extraction |
| Missing Data | Generic | Explicit strategy | Better handling of ambiguity |
| Quality Standards | Basic | Comprehensive | More consistent output |
| Output Structure | Single array | Three arrays | Aligns with schema |
| Examples | Few | Many | Clearer guidance |
| Validation | Generic | Specific checklist | Better quality control |
| Implicit Info | Not documented | Explicitly documented | Captures more data |

## Backward Compatibility

✓ All existing extraction rules preserved
✓ New capabilities are additive
✓ Existing field mappings unchanged
✓ Capital stack values remain compatible with matching algorithm
✓ No breaking changes to output format (only additions)

## Testing Impact

- More comprehensive test cases needed
- Need to test multi-entity extraction
- Need to test inference accuracy
- Need to validate normalization
- Need to test implicit information extraction
- Need to verify relationship maintenance

