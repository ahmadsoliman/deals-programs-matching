# CPD-Bot Example Scenarios

## Scenario 1: Email with Implicit Information

### Input
```
From: john.smith@capitalbank.com
Subject: Our Multifamily Lending Program

Hi,

We're Capital Bank and we specialize in senior debt for multifamily and office properties. 
We typically lend up to 75% LTV with 25-year amortization. Minimum check size is $2M, 
maximum is $50M. We focus on the Northeast and Mid-Atlantic regions.

Best regards,
John Smith
SVP, Head of Lending
Capital Bank
Boston, MA
(617) 555-1234
```

### Expected Output

**Programs Array**:
- Program_Name: "Capital Bank Senior Debt"
- Asset_Types: ["Apartments", "Office"]
- Capital_Stack: ["Senior"]
- Maximum_LTV: "0.75"
- Typical_Amortization: ["25"]
- Minimum_Check_Size: "2000000"
- Maximum_Check_Size: "50000000"
- Target_Property_Locations: ["MA", "CT", "NY", "NJ", "PA", "MD", "VA"]
- Notes: "Inferred Northeast and Mid-Atlantic regions from context"

**Organizations Array**:
- Name: "Capital Bank"
- HQ_Location: "Boston, MA"
- Organization_Type: "Bank"
- Notes: "Extracted from email signature and domain"

**Contacts Array**:
- Name: "John Smith"
- Title: "SVP, Head of Lending"
- Email: "john.smith@capitalbank.com"
- Phone: "617-555-1234"
- Organization_Name: "Capital Bank"
- Notes: "Extracted from email signature"

---

## Scenario 2: Ambiguous Program Description

### Input
```
We provide flexible financing solutions. Our typical deals are in the $5-20M range. 
We can do senior or mezzanine depending on the deal. Recourse varies. 
We're open to most property types but prefer stabilized assets.
```

### Expected Output

**Programs Array**:
- Program_Name: "" (no provider name given)
- Asset_Types: [] (too vague, no specific types mentioned)
- Capital_Stack: ["Senior", "Mezzanine"] (both mentioned)
- Minimum_Check_Size: "5000000"
- Maximum_Check_Size: "20000000"
- Recourse: "" (explicitly varies, can't determine)
- Notes: "Program description is vague. Asset types not specified; 'most property types' is too broad. Recourse explicitly varies by deal; no default specified. Recommend requesting more details."

**Organizations Array**: [] (no organization name provided)

**Contacts Array**: [] (no contact information provided)

---

## Scenario 3: Multi-Entity Message

### Input
```
Hi Team,

ABC Equity Partners is expanding our co-GP equity program. We're looking to invest 
$10-50M in value-add multifamily and mixed-use properties across the Sun Belt. 
We require sponsors with at least $100M AUM and 10+ years of experience.

Contact our investment team:
- Sarah Johnson, Managing Director (sarah.johnson@abcequity.com, 212-555-0100)
- Mike Chen, Investment Officer (mike.chen@abcequity.com, 212-555-0101)

ABC Equity Partners
New York, NY
```

### Expected Output

**Programs Array**:
- Program_Name: "ABC Equity Partners Co-GP Equity"
- Asset_Types: ["Apartments", "Mixed-Use"]
- Capital_Stack: ["Co-GP Equity"]
- Minimum_Check_Size: "10000000"
- Maximum_Check_Size: "50000000"
- Target_Property_Locations: ["TX", "FL", "GA", "NC", "SC", "AZ"] (Sun Belt states)
- Sponsor_Requirements: {Min_AUM: "100000000", Experience_Level: "Established"}
- Notes: "Sun Belt region inferred from context. Sponsor experience requirement of 10+ years maps to 'Established' level."

**Organizations Array**:
- Name: "ABC Equity Partners"
- HQ_Location: "New York, NY"
- Organization_Type: "Fund"
- Notes: "Extracted from message content and contact signatures"

**Contacts Array**:
- Contact 1:
  - Name: "Sarah Johnson"
  - Title: "Managing Director"
  - Email: "sarah.johnson@abcequity.com"
  - Phone: "212-555-0100"
  - Organization_Name: "ABC Equity Partners"
- Contact 2:
  - Name: "Mike Chen"
  - Title: "Investment Officer"
  - Email: "mike.chen@abcequity.com"
  - Phone: "212-555-0101"
  - Organization_Name: "ABC Equity Partners"

---

## Scenario 4: Incomplete Data with Inference

### Input
```
We do bridge loans. Typical terms are 18-24 months. We lend on office and retail. 
Minimum deal size is $3M. We're selective recourse. 
We can go up to 70% LTC on stabilized properties.
```

### Expected Output

**Programs Array**:
- Program_Name: "" (no provider name)
- Asset_Types: ["Office", "Retail"]
- Capital_Stack: ["Senior"] (bridge loans are senior debt)
- Minimum_Check_Size: "3000000"
- Maximum_Check_Size: "" (not mentioned)
- Recourse: "Selective"
- Maximum_LTC: "0.70"
- Term_Length: "1.5-2 years" (18-24 months converted)
- Notes: "Bridge loan inferred as Senior capital stack. LTC mentioned without explicit LTV; assumed Senior. Maximum check size not specified. Geographic focus not mentioned."

**Organizations Array**: [] (no organization name)

**Contacts Array**: [] (no contact information)

---

## Scenario 5: Explicitly N/A Fields

### Input
```
We're a nationwide lender. We don't have geographic restrictions. 
We lend on any commercial property type. We don't require US citizenship.
```

### Expected Output

**Programs Array**:
- Asset_Types: [] (explicitly "any" - too broad to list)
- Target_Property_Locations: [] (nationwide, no restrictions)
- US_Citizenship_Required: false
- Notes: "Nationwide program with no geographic restrictions. Accepts any commercial property type; specific asset types not listed. US citizenship explicitly not required."

**Organizations Array**: [] (no organization name)

**Contacts Array**: [] (no contact information)

