WITH most_recent_filing_id AS
  (SELECT filer_committee_id_number,
          coverage_from_date,
          coverage_through_date ,
          max(fec_report_id) AS report_id
   FROM f3x_fecfile
   WHERE filer_committee_id_number='C00401224'
     AND coverage_from_date BETWEEN '2020-01-01' AND '2020-03-31'
   GROUP BY 1,
            2,
            3)
SELECT sa.fec_report_id,
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
       sa.contribution_amount::text,
       sa.contribution_aggregate::text ,
       sa.contribution_purpose_descrip,
       sa.contributor_employer,
       sa.contributor_occupation,
       sa.memo_text_description
FROM sa_fecfile sa
JOIN lr ON sa.fec_report_id=lr.report_id
WHERE upper(sa.form_type)='SA11AI'
ORDER BY random()
LIMIT 1600000), FEC_Committee_Data_2020 AS
  (SELECT *
   FROM fec_committees
   WHERE bg_cycle=2020)
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