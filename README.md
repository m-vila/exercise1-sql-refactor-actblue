# Data Analyst Technical Assessment

## Exercise One: SQL Refactor
### Refactoring Explained Step by Step
### Step 1: Fix CTE Structure and Format

**Original query:**
```sql
with most_recent_filing_id as (
select filer_committee_id_number
,coverage_from_date
,coverage_through_date 
,max(fec_report_id) as report_id 
from f3x_fecfile 
where filer_committee_id_number='C00401224'
and coverage_from_date between '2020-01-01' and '2020-03-31'
group by 1,2,3)
```

**Refactored query:**
```sql
-- Step 1: Find the most recent FEC report ID for ActBlue in Q1 2020
WITH most_recent_filing_id AS (
   SELECT 
      filer_committee_id_number,
      coverage_from_date,
      coverage_through_date,
      MAX(fec_report_id) AS report_id
   FROM f3x_fecfile
   WHERE filer_committee_id_number='C00401224' -- ActBlue's FEC Committee ID
     AND coverage_from_date BETWEEN '2020-01-01' AND '2020-03-31' -- The date range captures Feb, Mar, Apr monthly reports for 2020
   GROUP BY filer_committee_id_number,
            coverage_from_date,
            coverage_through_date
),
```

**Changes made:**
* Added a comment explaining the purpose of the CTE
* Used proper indentation and capitalized SQL keywords to make the structure clearer
* A quick Google search revealed that 'C00401224' represents ActBlue's FEC Committee ID and added a comment for clarification
* Changed GROUP BY 1,2,3 to column names for clarity (both options are correct, though)
* Added a comma after the CTE for consistency with multiple CTEs
* I assumed the original data range is correct based on my understanding of how FEC filings work (monthly reports typically cover activity from the previous month)


### Step 2: Fix the Missing Table Reference and Data Logic

**Original query:**
```sql
select sa.fec_report_id
,sa.date_report_received
,sa.form_type
,sa.filer_committee_id_number
,sa.transaction_id
,sa.entity_type
,sa.contributor_last_name
,sa.contributor_first_name 
,sa.contributor_street_1
,sa.contributor_city
,sa.contributor_state
,sa.contributor_zip_code
,sa.contribution_date
,sa.contribution_amount::text
,sa.contribution_aggregate::text 
,sa.contribution_purpose_descrip
,sa.contributor_employer
,sa.contributor_occupation
,sa.memo_text_description
from sa_fecfile sa
join lr on sa.fec_report_id=lr.report_id
where upper(sa.form_type)='SA11AI'
order by random()
limit 1600000
), 
```

**Refactored query:**
```sql
-- Step 2: Extract contribution data from ActBlue's most recent filings
contribution_data AS ( 
   SELECT 
      sa.fec_report_id,
      sa.date_report_received,
      sa.form_type,
      sa.filer_committee_id_number,
      sa.transaction_id,
      sa.entity_type,
      sa.contributor_last_name,
      sa.contributor_first_name ,
      sa.contributor_street_1,
      sa.contributor_city,
      sa.contributor_state,
      sa.contributor_zip_code,
      sa.contribution_date,
      sa.contribution_amount::TEXT, -- Note: Investigate why this is cast to TEXT
      sa.contribution_aggregate::TEXT, -- Note: Investigate why this is cast to TEXT
      sa.contribution_purpose_descrip,
      sa.contributor_employer,
      sa.contributor_occupation,
      sa.memo_text_description
   FROM sa_fecfile sa
   JOIN most_recent_filing_id mrf ON sa.fec_report_id=mrf.report_id -- Note: Changed 'lr' to most_recent_filing_id based on context
   WHERE UPPER(sa.form_type)='SA11AI' -- Individual contribution records to political committees
   ORDER BY RANDOM() -- Note: Check if this step is necessary
   LIMIT 1600000 -- Note: This is an unusually large limit, verify if needed
), 
```
**Changes made:**
* Added a comment explaining the purpose of the CTE
* Used proper indentation and capitalized SQL keywords to make the structure clearer
* Wrapped section in a CTE named contribution_data
* Changed undefined table reference 'lr' to 'mrf' for 'most_recent_filing_id' and added table alias 'mrf' for clarity
* A quick Google search revealed that 'SA11AI' refers to a specific item type on FEC Form 3X, which is the standard report that federal political committees file with the FEC

**Questions and Clarifications:**
* I assumed that the RANDOM() clause is deliberate and the purpose is to randomize data for the technical assessment, but it may be inefficient for large datasets and can consume massive resources
* The LIMIT is set to 1.6 million rows, this seems very specific and unusually large. As mentioned before, randomizing such a large number of entries will be resource-intensive. I would verify with the team if this is necessary.
* There are two fields for monetary values (sa.contribution_amount and sa.contribution_aggregate) that are cast to text, which makes no sense. The prompt clearly stated: "All of the where clauses, and table sources are correct and don't need to be updated." For this reason I left it as is. I would verify this with the owner of the query to double-check.
* I would suggest changing the field 'sa.contribution_purpose_descrip' to sa.contribution_purpose_description' for consistency reasons

### Step 3: CTE Formatting

**Original query:**
```sql
), FEC_Committee_Data_2020 as (
select * from fec_committees where bg_cycle=2020
)
```
**Refactored query:**
```sql
-- Step 3: Load FEC committee data for 2020 election cycle
fec_committee_data_2020 AS (
   SELECT *
   FROM fec_committees
   WHERE bg_cycle = 2020
),
```
**Changes made:**
* Added a comment explaining the purpose of the CTE
* Used proper indentation and capitalized SQL keywords to make the structure clearer
* Lowercased CTE name for consistency with snake_case convention
* Added a comma after the CTE for consistency with multiple CTEs