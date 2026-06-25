WITH
-- ================= PARAMETERS =============================================
params AS (
  SELECT
    TRUNC(TO_DATE(:start_date, 'MM/DD/YYYY HH24:MI'))     AS start_date,
    TRUNC(TO_DATE(:end_date,   'MM/DD/YYYY HH24:MI'))  AS end_date,
    :fishery_list                            AS fishery_id,
    :pfma_list                               AS pfma_list
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
   SELECT fy.fishery_nme,lic.lic_grp_nme AS licence_area, fo.opng_desc, oc.opng_cat, pd.pd_id, fo.opng_id, oa.fa_fa_id,
         TRUNC(pd.pd_start_dtt) AS pd_start_dtt
    FROM FOS_V1_1.season sn
    JOIN FOS_V1_1.fishry_opening fo
      ON sn.fshry_fishery_id = fo.fshry_fishery_id
     AND sn.season_id = fo.season_id
    JOIN FOS_V1_1.fishery fy ON fy.fishery_id = fo.fshry_fishery_id
    JOIN FOS_V1_1.opening_area oa ON oa.opng_opng_ID = fo.opng_id
    JOIN FOS_V1_1.period pd ON fo.opng_id = pd.opng_opng_id
    JOIN FOS_V1_1.opening_lic ol ON  fo.opng_id = ol.opng_opng_id
  JOIN FOS_V1_1.licence lic ON  ol.lic_lic_id = lic.lic_id
    JOIN (
      SELECT oat.atin_id opng_id, cat.csm_opng_cat_nme opng_cat
      FROM FOS_V1_1.attr_instance oat
      JOIN FOS_V1_1.csm_opng_cat_vw cat ON cat.csm_opng_cat_id = oat.atin_val
      WHERE oat.attr_cde='CSM_OPNG_CAT' AND oat.attent_cde='OPNG'
    ) oc ON fo.opng_id = oc.opng_id
    CROSS JOIN params p
 WHERE (
        p.fishery_id IS NULL
        OR sn.fshry_fishery_id IN (SELECT fishery_id FROM fishery_list_parsed)
      )
    AND TRUNC(pd.pd_start_dtt) BETWEEN p.start_date AND p.end_date
),

-- ================= CATCH  ====================================
rc AS (
  SELECT
        fo.fshry_fishery_id,
        fo.opng_id,
        cr.crpt_id,
         cr.pd_pd_id AS pd_id,
         pd.pd_start_dtt,
         FOS_V1_1.fos_pkg.licname(cr.lic_lic_id, pd.pd_start_dtt, pd.pd_end_dtt) AS licence,
         cr.crpt_logbook_no AS logbook,
         ds.cdsrc_nme AS data_source,
         fe.fe_id,
         fe.fa_fa_id AS fa_id,
         pm.pfma as mgmt_area,
         fa.fa_nme,
         fe.fe_effort,
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
    FROM FOS_V1_1.season sn
    JOIN FOS_V1_1.fishry_opening fo
      ON sn.fshry_fishery_id = fo.fshry_fishery_id
     AND sn.season_id = fo.season_id
    JOIN FOS_V1_1.period pd ON fo.opng_id = pd.opng_opng_id
    JOIN FOS_V1_1.crpt_vw cr ON pd.pd_id = cr.pd_pd_id
    JOIN FOS_V1_1.fe_vw fe  ON cr.crpt_id = fe.crpt_crpt_id
    JOIN FOS_V1_1.catch ca  ON fe.fe_id = ca.fe_fe_id
    JOIN FOS_V1_1.observer ob ON cr.obsvr_obsvr_id = ob.obsvr_id
    JOIN FOS_V1_1.catch_data_source ds ON cr.cdsrc_cdsrc_id = ds.cdsrc_id
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

       GROUP BY  fo.fshry_fishery_id,
        fo.opng_id,
        cr.crpt_id,
         cr.pd_pd_id,
         pd.pd_start_dtt,
         FOS_V1_1.fos_pkg.licname(cr.lic_lic_id, pd.pd_start_dtt, pd.pd_end_dtt),
         cr.crpt_logbook_no,
         ds.cdsrc_nme,
         fe.fe_id,
         fe.fa_fa_id,
         pm.pfma,
         fa.fa_nme,
         fe.fe_effort
),

---=================Filter duplicates======================================
joined AS (
  SELECT TO_CHAR(op.pd_start_dtt,'YYYY') AS cal_year,
         op.fishery_nme as fishery,
         op.pd_id,
         rc.crpt_id,
         rc.fe_id,
         op.fishery_nme,
         op.opng_cat,
         op.opng_desc,
         op.opng_id,
         op.pd_start_dtt,
         TO_CHAR(op.pd_start_dtt,'YYYY-MM-DD') AS pd_start_date,
         rc.mgmt_area,
         rc.fa_nme AS area_name,
         rc.licence,
         rc.logbook,
         rc.data_source,
         UPPER(REGEXP_REPLACE(rc.data_source,'[^A-Z]')) AS ds_code,
         rc.fe_effort,
         rc.sockeye_kept, rc.sockeye_reld,
         rc.coho_kept, rc.coho_reld,
         rc.pink_kept, rc.pink_reld,
         rc.chum_kept, rc.chum_reld,
         rc.chinook_kept, rc.chinook_reld,
         rc.steelhead_kept, rc.steelhead_reld
    FROM op JOIN rc ON op.pd_id = rc.pd_id
    AND op.pd_start_dtt = rc.pd_start_dtt
    AND op.fa_fa_id = rc.fa_id
),
grp AS (
  SELECT fishery, opng_cat, opng_desc, opng_id, pd_start_dtt, area_name, licence,
         MAX(CASE WHEN fe_effort = 1 THEN 1 ELSE 0 END) AS has_effort_one,
         MAX(CASE WHEN fe_effort < 1 THEN 1 ELSE 0 END) AS has_effort_lt1,
         MAX(CASE WHEN ds_code = 'LOGBOOK' THEN 1 ELSE 0 END) AS has_logbook,
         MAX(CASE WHEN ds_code = 'PHONEIN' THEN 1 ELSE 0 END) AS has_phonein
    FROM joined
   GROUP BY fishery, opng_cat, opng_desc, opng_id, pd_start_dtt, area_name, licence
),
filtered AS (
  SELECT j.*,
         CASE
           WHEN g.has_effort_one = 1 AND (
                (g.has_logbook = 1 AND j.ds_code='LOGBOOK' AND j.fe_effort = 1) OR
                (g.has_logbook = 0 AND j.fe_effort = 1)
           ) THEN 'One'
           WHEN g.has_effort_one = 0 AND g.has_effort_lt1 = 1 AND (
                (g.has_logbook = 1 AND j.ds_code='LOGBOOK') OR
                (g.has_logbook = 0 AND j.ds_code='PHONEIN')
           ) THEN 'LT1'
           ELSE 'Other'
         END AS selection_flag
    FROM joined j
    JOIN grp g
      ON j.fishery   = g.fishery
     AND j.opng_cat  = g.opng_cat
     AND j.opng_desc = g.opng_desc
     AND j.opng_id = g.opng_id
     AND j.pd_start_dtt   = g.pd_start_dtt
     AND j.area_name = g.area_name
     AND j.licence   = g.licence
    CROSS JOIN params p
   WHERE ((
         ( g.has_effort_one = 1 AND (
              (g.has_logbook = 1 AND j.ds_code='LOGBOOK' AND j.fe_effort = 1)
           OR (g.has_logbook = 0 AND j.fe_effort = 1)
           ) )
      OR ( g.has_effort_one = 0 AND g.has_effort_lt1 = 1 AND (
              (g.has_logbook = 1 AND j.ds_code='LOGBOOK')
           OR (g.has_logbook = 0 AND j.ds_code='PHONEIN')
           ) )
      OR ( g.has_effort_one = 0 AND g.has_effort_lt1 = 0 )
      )
    )
),
-- ================= Aggregated ============================================
agg AS (
  SELECT
    op.fishery_nme AS fishery,
    'Fisher-reported' AS estimate_type,
    op.licence_area,
    EXTRACT(YEAR FROM op.pd_start_dtt) AS calendar_year,
    rc.mgmt_area AS mgmt_area,
    count(distinct rc.licence) AS vessel_count,
    sum(rc.fe_effort) as boat_days,
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
    CAST(NULL AS VARCHAR2(200)) AS notes --not used in fisher reported but keep for join

  FROM op
  JOIN rc
    ON op.opng_id = rc.opng_id
      AND op.pd_start_dtt = rc.pd_start_dtt
      AND op.fa_fa_id = rc.fa_id
      GROUP BY
  op.fishery_nme,
  op.licence_area,
  EXTRACT(YEAR FROM op.pd_start_dtt),
  rc.mgmt_area
)

SELECT *
FROM agg
ORDER BY
  calendar_year DESC,
  licence_area,
  mgmt_area