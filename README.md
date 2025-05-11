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
-- Step 1: Find the most recent FEC filing IDs for ActBlue in Q1 2020
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
* A quick Google search revealed that 'C00401224' represents and added a comment for clarification
* Changed GROUP BY 1,2,3 to column names for clarity but both options are correct
* Added a comma after the CTE for consistency with multiple CTEs
* I assumed the original data rance is correct based on my understanding of how FEC filings work (monthly reports typically cover activity from the previous month).
