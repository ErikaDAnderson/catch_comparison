-- =========================fisher_reported_estimates_before_R.sql =======================================
-- original sql taken from Fisher Reported Catch_GN_2013-2023_V2,sql on SAS-SAFE
-- Modified in 2026-03 with AI to
-- 1) parameterize query
-- 2) remove duplicates selecting LOGBOOKs over phone-ins, if present
-- 3) include all records for the day when fe_effort <1
------------------------------------------------------------------------------

WITH
-- ================= PARAMETERS =============================================
params AS (
  SELECT
    TRUNC(TO_DATE(:start_date, 'MM/DD/YYYY HH24:MI'))     AS start_date,
    TRUNC(TO_DATE(:end_date,   'MM/DD/YYYY HH24:MI'))  AS end_date,
    :fishery_list                            AS fishery_id,
    :prma_list                               AS pfma_list
  FROM dual
),

-- ================= PFMA MAP ===============================================
pfma_map AS (
    SELECT 2588 fa_id,1 pfma FROM dual UNION ALL
    SELECT 2589,2 FROM dual UNION ALL
    SELECT 2590,3 FROM dual UNION ALL
    SELECT 2631,4 FROM dual UNION ALL
    SELECT 2591,5 FROM dual UNION ALL
    SELECT 2632,6 FROM dual UNION ALL
    SELECT 2633,7 FROM dual UNION ALL
    SELECT 2634,8 FROM dual UNION ALL
    SELECT 2592,9 FROM dual UNION ALL
    SELECT 2593,10 FROM dual UNION ALL
    SELECT 2594,11 FROM dual UNION ALL
    SELECT 2595,12 FROM dual UNION ALL
    SELECT 2596,13 FROM dual UNION ALL
    SELECT 2597,14 FROM dual UNION ALL
    SELECT 2598,15 FROM dual UNION ALL
    SELECT 2599,16 FROM dual UNION ALL
    SELECT 2600,17 FROM dual UNION ALL
    SELECT 2601,18 FROM dual UNION ALL
    SELECT 2602,19 FROM dual UNION ALL
    SELECT 2603,20 FROM dual UNION ALL
    SELECT 2604,21 FROM dual UNION ALL
    SELECT 2605,22 FROM dual UNION ALL
    SELECT 2606,23 FROM dual UNION ALL
    SELECT 2607,24 FROM dual UNION ALL
    SELECT 2608,25 FROM dual UNION ALL
    SELECT 2609,26 FROM dual UNION ALL
    SELECT 2610,27 FROM dual UNION ALL
    SELECT 2611,28 FROM dual UNION ALL
    SELECT 2635,29 FROM dual UNION ALL
    SELECT 2612,101 FROM dual UNION ALL
    SELECT 2613,102 FROM dual UNION ALL
    SELECT 2614,103 FROM dual UNION ALL
    SELECT 2615,104 FROM dual UNION ALL
    SELECT 2616,105 FROM dual UNION ALL
    SELECT 2617,106 FROM dual UNION ALL
    SELECT 2618,107 FROM dual UNION ALL
    SELECT 2619,108 FROM dual UNION ALL
    SELECT 2620,109 FROM dual UNION ALL
    SELECT 2621,110 FROM dual UNION ALL
    SELECT 2622,111 FROM dual UNION ALL
    SELECT 2623,121 FROM dual UNION ALL
    SELECT 2624,123 FROM dual UNION ALL
    SELECT 2625,124 FROM dual UNION ALL
    SELECT 2626,125 FROM dual UNION ALL
    SELECT 2627,126 FROM dual UNION ALL
    SELECT 2628,127 FROM dual UNION ALL
    SELECT 2629,130 FROM dual UNION ALL
    SELECT 2630,142 FROM dual
),

-- ================= LIST PARSER ===================================
pfma_list_parsed AS (
  SELECT TO_NUMBER(token) AS pfma
  FROM (
    SELECT TRIM(REGEXP_SUBSTR(p.pfma_list, '[^,]+', 1, LEVEL)) AS token
    FROM params p
    CONNECT BY REGEXP_SUBSTR(p.pfma_list, '[^,]+', 1, LEVEL) IS NOT NULL
  )
  WHERE REGEXP_LIKE(token, '^\d+$') 
),

fishery_list_parsed AS (
  SELECT TO_NUMBER(token) AS fishery_id
  FROM (
    SELECT TRIM(REGEXP_SUBSTR(p.fishery_id, '[^,]+', 1, LEVEL)) AS token
    FROM params p
    CONNECT BY REGEXP_SUBSTR(p.fishery_id, '[^,]+', 1, LEVEL) IS NOT NULL
  )
  WHERE REGEXP_LIKE(token, '^\d+$')
),
-- ================= OPENINGS ===============================================
op AS (
  SELECT fy.fishery_nme,
         lic.lic_grp_nme AS licence_area,
         lic.lic_lic_id,
         pd.pd_id,
         TRUNC(pd.pd_start_dtt) as pd_start_dtt,
         FOS_V1_1.fos_pkg.getVesselForLic(lic.lic_id, pd.pd_start_dtt) AS vessel_id
  FROM FOS_V1_1.season sn
  JOIN FOS_V1_1.fishry_opening fo
    ON sn.fshry_fishery_id = fo.fshry_fishery_id
   AND sn.season_id = fo.season_id
  JOIN FOS_V1_1.fishery fy 
    ON fy.fishery_id = fo.fshry_fishery_id
  JOIN FOS_V1_1.period pd 
    ON fo.opng_id = pd.opng_opng_id
  JOIN FOS_V1_1.opening_lic ol
    ON  fo.opng_id = ol.opng_opng_id
  JOIN FOS_V1_1.licence lic 
    ON  ol.lic_lic_id = lic.lic_id  
    CROSS JOIN params p 
 WHERE (
        p.fishery_id IS NULL
        OR sn.fshry_fishery_id IN (SELECT fishery_id FROM fishery_list_parsed)
      )
    AND TRUNC(pd.pd_start_dtt) BETWEEN p.start_date AND p.end_date
),

-- ================= CATCH (FULL SPECIES) ====================================
rc AS (
  SELECT
    cr.crpt_id,
    cr.pd_pd_id pd_id,
    pd.pd_start_dtt,
    fe.fe_id,
    pm.pfma AS mgmt_area,
    fe.fe_effort,
    fe.fe_hrs_fished,
         SUM(DECODE(ca.species_species_cde,'118',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,0,ca.catch_qty)))) AS sockeye_kept,
         SUM(DECODE(ca.species_species_cde,'118',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,1,ca.catch_qty)))) AS sockeye_reld,
         SUM(DECODE(ca.species_species_cde,'115',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,0,ca.catch_qty)))) AS coho_kept,
         SUM(DECODE(ca.species_species_cde,'115',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,1,ca.catch_qty)))) AS coho_reld,
         SUM(DECODE(ca.species_species_cde,'108',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,0,ca.catch_qty)))) AS pink_kept,
         SUM(DECODE(ca.species_species_cde,'108',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,1,ca.catch_qty)))) AS pink_reld,
         SUM(DECODE(ca.species_species_cde,'112',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,0,ca.catch_qty)))) AS chum_kept,
         SUM(DECODE(ca.species_species_cde,'112',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,1,ca.catch_qty)))) AS chum_reld,
         SUM(DECODE(ca.species_species_cde,'124',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,0,ca.catch_qty)))) AS chinook_kept,
         SUM(DECODE(ca.species_species_cde,'124',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,1,ca.catch_qty)))) AS chinook_reld,
         SUM(DECODE(ca.species_species_cde,'128',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,0,ca.catch_qty)))) AS steelhead_kept,
         SUM(DECODE(ca.species_species_cde,'128',DECODE(ca.mat_mat_cde,1,DECODE(ca.catch_released,1,ca.catch_qty)))) AS steelhead_reld
         
  FROM FOS_V1_1.period pd
  JOIN FOS_V1_1.crpt_vw cr ON pd.pd_id = cr.pd_pd_id
  JOIN FOS_V1_1.fe_vw fe  ON cr.crpt_id = fe.crpt_crpt_id
  JOIN FOS_V1_1.catch ca  ON fe.fe_id = ca.fe_fe_id
  JOIN FOS_V1_1.fishry_area fa ON fa.fa_id = fe.fa_fa_id

  LEFT JOIN pfma_map pm
    ON (CASE WHEN fa.fa_fa_id IS NULL THEN fa.fa_id ELSE fa.fa_fa_id END) = pm.fa_id

  CROSS JOIN params p

  WHERE TRUNC(pd.pd_start_dtt) BETWEEN p.start_date AND p.end_date
    AND cr.crpt_flag = 0
    AND cr.cdsrc_cdsrc_id IN (3,9)

    AND pm.pfma IS NOT NULL
AND (
      p.pfma_list IS NULL
      OR pm.pfma IN (SELECT pfma FROM pfma_list_parsed)
    )

  GROUP BY cr.crpt_id, cr.pd_pd_id, pd.pd_start_dtt, fe.fe_id, pm.pfma,
           fe.fe_effort, fe.fe_hrs_fished
),

-- ================= FINAL AGG ==============================================
agg AS (
  SELECT
    op.fishery_nme AS fishery,
    op.licence_area,
    'Fisher-reported' AS estimate_type,
    EXTRACT(YEAR FROM op.pd_start_dtt) AS calendar_year, 
    rc.mgmt_area AS mgmt_area,
    COUNT(DISTINCT op.vessel_id) AS vessel_count,
    SUM(rc.fe_effort) AS boat_days,
    SUM(rc.sockeye_kept) sockeye_kept,
    SUM(rc.sockeye_reld) sockeye_reld,
    SUM(rc.coho_kept) coho_kept,
    SUM(rc.coho_reld) coho_reld,
    SUM(rc.pink_kept) pink_kept,
    SUM(rc.pink_reld) pink_reld,
    SUM(rc.chum_kept) chum_kept,
    SUM(rc.chum_reld) chum_reld,
    SUM(rc.chinook_kept) chinook_kept,
    SUM(rc.chinook_reld) chinook_reld,
    SUM(rc.steelhead_kept) steelhead_kept,
    SUM(rc.steelhead_reld) steelhead_reld,
    CAST(NULL AS VARCHAR2(200)) AS notes --do we need this?

  FROM op
  JOIN rc ON op.pd_id = rc.pd_id

GROUP BY
  op.fishery_nme,
  op.licence_area,
  EXTRACT(YEAR FROM op.pd_start_dtt),
  rc.mgmt_area
)

SELECT
  fishery,
  estimate_type,
  licence_area,
  calendar_year,
  mgmt_area,
  vessel_count,
  boat_days,
  sockeye_kept,
  sockeye_reld,
  coho_kept,
  coho_reld,
  pink_kept,
  pink_reld,
  chum_kept,
  chum_reld,
  chinook_kept,
  chinook_reld,
  steelhead_kept,
  steelhead_reld,
  notes
FROM agg
ORDER BY
  calendar_year DESC,
  licence_area,
  mgmt_area;
