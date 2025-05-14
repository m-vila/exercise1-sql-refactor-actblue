# Data Analyst Technical Assessment

## Exercise One: SQL Refactor

### Final Result: Refactored Query

```sql
/*
Purpose: This query analyzes ActBlue's campaign contributions for Q1 2020,
calculating the in-state versus out-of-state contribution totals and percentage.

Parameters:
@filer_committee_id - Committee ID to analyze ('C00401224' for ActBlue)
@start_date - Beginning of analysis period ('2020-01-01')
@end_date - End of analysis period ('2020-03-31')
@form_type - Form type to filter ('SA11AI' for individual contributions)
@committee_name - Committee name to filter in final results ('ACTBLUE')
*/

-- Define parameters with default values
DECLARE @filer_committee_id VARCHAR(9) = 'C00401224'; -- ActBlue's FEC Committee ID
DECLARE @start_date DATE = '2020-01-01';
DECLARE @end_date DATE = '2020-03-31';
DECLARE @form_type VARCHAR(10) = 'SA11AI'; -- Individual contribution records
DECLARE @committee_name VARCHAR(100) = 'ACTBLUE'; -- Committee name

-- Step 1: Find the most recent FEC report ID for ActBlue in Q1 2020
WITH most_recent_filing_id AS (
   SELECT 
      filer_committee_id_number,
      coverage_from_date,
      coverage_through_date,
      MAX(fec_report_id) AS report_id
   FROM f3x_fecfile
   WHERE filer_committee_id_number = @filer_committee_id -- ActBlue's FEC Committee ID
     AND coverage_from_date BETWEEN @start_date AND @end_date -- Q1 2020 
   GROUP BY filer_committee_id_number,
            coverage_from_date,
            coverage_through_date
),

-- Step 2: Extract contribution data from ActBlue's filings
ds_technical_112221 AS ( 
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
   WHERE UPPER(sa.form_type) = @form_type 
   ORDER BY RANDOM() -- Note: Check if this step is necessary
   LIMIT 1600000 -- Note: This is an unusually large limit, verify if needed
), 

-- Step 3: Load FEC committee data for 2020 election cycle
fec_committee_data_2020 AS (
   SELECT *
   FROM fec_committees
   WHERE bg_cycle = 2020
),

-- Step 4: Total contributions data per committee and state
contributions_by_state AS (
    SELECT 
        ds.filer_committee_id_number,
        ds.contributor_state,
        SUM(ds.contribution_aggregate::NUMERIC) AS total -- Note: This needs to be cast to NUMERIC to perform SUM
    FROM ds_technical_112221 ds
    GROUP BY ds.filer_committee_id_number, 
             ds.contributor_state
),

-- Step 5: Calculate in-state vs out-of-state contributions
joined_contributions AS (
    SELECT
        fc.cmte_nm,
        fc.cmte_st,
        cbs.contributor_state,
        (fc.cmte_st = cbs.contributor_state) AS instate,
        cbs.total
    FROM contributions_by_state cbs
    JOIN fec_committee_data_2020 fc
        ON fc.cmte_id = cbs.filer_committee_id_number
)

-- Final Step: Calculate in-state vs out-of-state contribution totals and percentage
SELECT
    cmte_nm,
    SUM(CASE WHEN instate THEN total ELSE 0 END) AS instate,
    SUM(CASE WHEN NOT instate THEN total ELSE 0 END) AS outofstate,
    COALESCE(
        SUM(CASE WHEN instate = TRUE THEN total ELSE 0 END)::NUMERIC /
        NULLIF(SUM(total)::NUMERIC, 0) * 100,
        0
    ) AS instate_pct
FROM joined_contributions
WHERE cmte_nm = @committee_name
GROUP BY cmte_nm;
```

## Refactoring Explained Step by Step
### Step 1: Fix CTE Structure and Format

**Original Query:**
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

**Refactored Query:**
```sql
-- Define parameters with default values
DECLARE @filer_committee_id VARCHAR(9) = 'C00401224'; -- ActBlue's FEC Committee ID
DECLARE @start_date DATE = '2020-01-01';
DECLARE @end_date DATE = '2020-03-31';

-- Step 1: Find the most recent FEC report ID for ActBlue in Q1 2020
WITH most_recent_filing_id AS (
   SELECT 
      filer_committee_id_number,
      coverage_from_date,
      coverage_through_date,
      MAX(fec_report_id) AS report_id
   FROM f3x_fecfile
   WHERE filer_committee_id_number = @filer_committee_id -- ActBlue's FEC Committee ID
     AND coverage_from_date BETWEEN @start_date AND @end_date -- Q1 2020 
   GROUP BY filer_committee_id_number,
            coverage_from_date,
            coverage_through_date
),
```

**Changes Made:**
* Added a comment explaining the purpose of the CTE
* Used proper indentation and capitalized SQL keywords to make the structure clearer
* Created parameters for the committee ID and the start and end date to make the query more flexible.
* A quick Google search revealed that 'C00401224' represents ActBlue's FEC Committee ID and added a comment for clarification
* Changed GROUP BY 1,2,3 to column names for clarity (both options are correct, though)
* Added a comma after the CTE for consistency with multiple CTEs

**Questions, Clarifications or Assumptions:**
* I assumed the original data range is correct based on my understanding of how FEC filings work (monthly reports typically cover activity from the previous month)


### Step 2: Fix the Missing Table Reference and Data Logic

**Original Query:**
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

**Refactored Query:**
```sql
-- Define parameters with default values
DECLARE @filer_committee_id VARCHAR(9) = 'C00401224'; -- ActBlue's FEC Committee ID
DECLARE @start_date DATE = '2020-01-01';
DECLARE @end_date DATE = '2020-03-31';
DECLARE @form_type VARCHAR(10) = 'SA11AI'; -- Individual contribution records

(...)

-- Step 2: Extract contribution data from ActBlue's filings
ds_technical_112221 AS ( 
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
   WHERE UPPER(sa.form_type) = @form_type 
   ORDER BY RANDOM() -- Note: Check if this step is necessary
   LIMIT 1600000 -- Note: This is an unusually large limit, verify if needed
), 
```
**Changes Made:**
* Added a comment explaining the purpose of the CTE
* Used proper indentation and capitalized SQL keywords to make the structure clearer
* Created a parameter for the form type to make the query more flexible.
* Wrapped section in a CTE named ds_technical_112221 for consistency with step 4
* Changed undefined table reference 'lr' to 'mrf' for 'most_recent_filing_id' and added table alias 'mrf' for clarity
* A quick Google search revealed that 'SA11AI' refers to a specific item type on FEC Form 3X, which is the standard report that federal political committees file with the FEC

**Questions, Clarifications or Assumptions:**
* I assumed that the RANDOM() clause is deliberate and the purpose is to randomize data for the technical assessment, but it may be inefficient for large datasets and can consume massive resources
* The LIMIT is set to 1.6 million rows, this seems very specific and unusually large. As mentioned before, randomizing such a large number of entries will be resource-intensive. I would verify with the team if this is necessary.
* There are two fields for monetary values (contribution_amount and contribution_aggregate) that are cast to text, which makes no sense. The prompt clearly stated: "All of the where clauses, and table sources are correct and don't need to be updated." For this reason I left it as is. I would verify this with the owner of the query to double-check.
* I would suggest changing the field 'contribution_purpose_descrip' to 'contribution_purpose_description' for consistency reasons
* I would suggest changing the name of the CTE to something more descriptive, like 'contribution_data'. I decided to keep it as is since it was stated that they do not needed to be updated.

### Step 3: CTE Formatting

**Original Query:**
```sql
), FEC_Committee_Data_2020 as (
select * from fec_committees where bg_cycle=2020
)
```

**Refactored Query:**
```sql
-- Step 3: Load FEC committee data for 2020 election cycle
fec_committee_data_2020 AS (
   SELECT *
   FROM fec_committees
   WHERE bg_cycle = 2020
),
```
**Changes Made:**
* Added a comment explaining the purpose of the CTE
* Used proper indentation and capitalized SQL keywords to make the structure clearer
* Lowercased CTE name for consistency with snake_case convention
* Added a comma after the CTE for consistency with multiple CTEs

### Step 4: CTE Extraction for Modularity

**Original Query:**
```sql
from (SELECT a.filer_committee_id_number
    ,a.contributor_state
    ,sum(a.contribution_aggregate) total
from DS_technical_112221 a
group by 1,2) b

```

**Refactored Query:**
```sql
-- Step 4: Total contributions data per committee and state
contributions_by_state AS (
    SELECT 
        ds.filer_committee_id_number,
        ds.contributor_state,
        SUM(ds.contribution_aggregate::NUMERIC) AS total -- Note: This needs to be cast to NUMERIC to perform SUM
    FROM ds_technical_112221 ds
    GROUP BY ds.filer_committee_id_number, 
             ds.contributor_state
),
```
**Changes Made:**
* Added a comment explaining the purpose of the CTE
* Used proper indentation and capitalized SQL keywords to make the structure clearer
* Lowercased 'ds_technical_112221' following snake_case convention
* Cast 'contribution_aggregate' field to be able to perform the SUM function
* Changed GROUP BY 1,2 to column names for clarity (both options are correct, though)

### Step 5: CTE Extraction and Final In-State vs. Out-of-State Contribution Calculations

**Original Query:**
```sql
SELECT cmte_nm
    ,sum(case when instate=TRUE then total end) as instate
    ,sum(case when instate=FALSE then total end) as outofstate
    ,sum(case when instate=TRUE then total end)::numeric / sum(total)::numeric as instate_pct
    
from (
SELECT c.cmte_nm
    ,c.cmte_st
    ,b.contributor_state
    ,c.cmte_st = b.contributor_state as instate
    ,b.total
    
from contributions_by_state b
    ,fec_committee_data_2020 as c
)
group by 1
having cmte_nm = 'ACTBLUE';
```

**Refactored Query:**
```sql
-- Define parameters with default values
DECLARE @filer_committee_id VARCHAR(9) = 'C00401224'; -- ActBlue's FEC Committee ID
DECLARE @start_date DATE = '2020-01-01';
DECLARE @end_date DATE = '2020-03-31';
DECLARE @form_type VARCHAR(10) = 'SA11AI'; -- Individual contribution records
DECLARE @committee_name VARCHAR(100) = 'ACTBLUE'; -- Committee name

(...)

-- Step 5: Calculate in-state vs out-of-state contributions
joined_contributions AS (
    SELECT
        fc.cmte_nm,
        fc.cmte_st,
        cbs.contributor_state,
        (fc.cmte_st = cbs.contributor_state) AS instate,
        cbs.total
    FROM contributions_by_state cbs
    JOIN fec_committee_data_2020 fc
        ON fc.cmte_id = cbs.filer_committee_id_number
)

-- Final Step: Calculate in-state vs out-of-state contribution totals and percentage
SELECT
    cmte_nm,
    SUM(CASE WHEN instate THEN total ELSE 0 END) AS instate,
    SUM(CASE WHEN NOT instate THEN total ELSE 0 END) AS outofstate,
    COALESCE(
        SUM(CASE WHEN instate = TRUE THEN total ELSE 0 END)::NUMERIC /
        NULLIF(SUM(total)::NUMERIC, 0) * 100,
        0
    ) AS instate_pct
FROM joined_contributions
WHERE cmte_nm = @committee_name
GROUP BY cmte_nm;
```

**Changes Made:**
* Added a comment explaining the purpose of the CTE
* Used proper indentation and capitalized SQL keywords to make the structure clearer
* Created a parameter for the committee name to make the query more flexible
* Changed GROUP BY 1 to the column name for clarity (both options are correct, though)
* Changed the table aliases for clarity (fc for committee data, cbs for contributions by state)
* After finishing the refactor, I added header documentation to communicate the query's overall purpose

**Questions, Clarifications or Assumptions:**
* I assumed that instate_pct meant percentage, so I fixed the percentage calculation. I added a COALESCE function to return 0 instead of NULL when there's no denominator, a NULLIF to prevent division by zero and multiplied by 100 to get the percentage value.
* I would suggest changing the name of the field 'instate_pct' to something more descriptive, like 'instate_percentage'. I decided to keep it as is since it was stated that field names do not need to be updated.
