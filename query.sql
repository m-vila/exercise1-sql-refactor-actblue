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
-- Step 3: Load FEC committee data for 2020 election cycle
fec_committee_data_2020 AS (
   SELECT *
   FROM fec_committees
   WHERE bg_cycle = 2020
),
SELECT cmte_nm ,
       sum(CASE
               WHEN instate=TRUE THEN total
           END) AS instate ,
       sum(CASE
               WHEN instate=FALSE THEN total
           END) AS outofstate ,
       sum(CASE
               WHEN instate=TRUE THEN total
           END)::numeric / sum(total)::numeric AS instate_pct
FROM
  (SELECT c.cmte_nm ,
          c.cmte_st ,
          b.contributor_state ,
          c.cmte_st = b.contributor_state AS instate ,
          b.total
   FROM
     (SELECT a.filer_committee_id_number ,
             a.contributor_state ,
             sum(a.contribution_aggregate) total
      FROM DS_technical_112221 a
      GROUP BY 1,
               2) b ,
        FEC_Committee_Data_2020 AS c)
GROUP BY 1
HAVING cmte_nm = 'ACTBLUE';