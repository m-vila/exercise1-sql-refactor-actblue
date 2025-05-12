/*
Purpose: This query analyzes ActBlue's campaign contributions for Q1 2020,
calculating the in-state versus out-of-state contribution totals and percentage.
*/

-- Step 1: Find the most recent FEC report ID for ActBlue in Q1 2020
WITH most_recent_filing_id AS (
   SELECT 
      filer_committee_id_number,
      coverage_from_date,
      coverage_through_date,
      MAX(fec_report_id) AS report_id
   FROM f3x_fecfile
   WHERE filer_committee_id_number='C00401224' -- ActBlue's FEC Committee ID
     AND coverage_from_date BETWEEN '2020-01-01' AND '2020-03-31' -- Q1 2020 
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
   WHERE UPPER(sa.form_type)='SA11AI' -- Individual contribution records to political committees
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
    ROUND(
        SUM(CASE WHEN instate = TRUE THEN total ELSE 0 END)::NUMERIC / -- Calculate percentage with safeguard against division by zero
        NULLIF(SUM(total)::NUMERIC, 0) * 100, 
        2
    ) AS instate_pct
FROM joined_contributions
WHERE cmte_nm = 'ACTBLUE'
GROUP BY cmte_nm;