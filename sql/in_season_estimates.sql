SELECT
    fishery,
    estimate_type,
    licence_area,
    TO_NUMBER(TO_CHAR(tmprl_stratum,
        DECODE('YEAR', 'YEAR', 'YYYY', 'MON', 'MON/YYYY', 'DD/MON/YYYY')
    )) AS CALENDAR_YEAR,
    /*TO_CHAR(tmprl_stratum,
        DECODE('MON', 'YEAR', 'YYYY', 'MON', 'MON', 'DD/MON/YYYY')
    ) AS MONTH,*/
	mgmt_area,
    vessel_count,
    boat_days,
    -- Privacy flag centralised: nullify all catch columns in one place
    CASE WHEN suppress = 1 THEN NULL ELSE sockeye_kept    END AS sockeye_kept,
    CASE WHEN suppress = 1 THEN NULL ELSE sockeye_reld    END AS sockeye_reld,
    CASE WHEN suppress = 1 THEN NULL ELSE coho_kept       END AS coho_kept,
    CASE WHEN suppress = 1 THEN NULL ELSE coho_reld       END AS coho_reld,
    CASE WHEN suppress = 1 THEN NULL ELSE pink_kept       END AS pink_kept,
    CASE WHEN suppress = 1 THEN NULL ELSE pink_reld       END AS pink_reld,
    CASE WHEN suppress = 1 THEN NULL ELSE chum_kept       END AS chum_kept,
    CASE WHEN suppress = 1 THEN NULL ELSE chum_reld       END AS chum_reld,
    CASE WHEN suppress = 1 THEN NULL ELSE chinook_kept    END AS chinook_kept,
    CASE WHEN suppress = 1 THEN NULL ELSE chinook_reld    END AS chinook_reld,
    CASE WHEN suppress = 1 THEN NULL ELSE steelhead_kept  END AS steelhead_kept,
    CASE WHEN suppress = 1 THEN NULL ELSE steelhead_reld  END AS steelhead_reld,
    TRIM(
        CASE WHEN missing_ef = 1 OR missing_tc = 1
            THEN 'Some estimates are incomplete.  '
        END
        ||
        CASE WHEN suppress = 1
            THEN 'Catch figures omitted due to privacy restrictions.'
        END
    ) AS notes
FROM (
    SELECT
        fy.fishery_nme                                          AS fishery,
        DECODE(op.tctype_cde, 1, 'In-season', 2, 'Post-season') AS estimate_type,
        op.lic_grp_nme                                          AS licence_area,
        op.tmprl_stratum,
        TO_NUMBER(REPLACE(fa.fa_nme, 'management area '))       AS mgmt_area,
        NVL(vc.vessel_count, 0)                                 AS vessel_count,
        NVL(op.ec, 0)                                           AS boat_days,
        -- Centralise the suppression flag so outer query stays clean
		-- Can toggle privacy suppression, enter Y (on) or N (off)
        CASE
    WHEN :ATIP_SAFE = 'Y'
     AND (
          (NVL(vc.vessel_count, 0) > 0 AND NVL(vc.vessel_count, 0) < 3)
       OR (NVL(op.ec, 0)           > 0 AND NVL(op.ec, 0)           < 3)
         )
    THEN 1 ELSE 0
END AS suppress,
        sa.sockeye_kept,
        sa.sockeye_reld,
        sa.coho_kept,
        sa.coho_reld,
        sa.pink_kept,
        sa.pink_reld,
        sa.chum_kept,
        sa.chum_reld,
        sa.chinook_kept,
        sa.chinook_reld,
        sa.steelhead_kept,
        sa.steelhead_reld,
        missing_ef,
        missing_tc
    FROM (
        -- ── Effort / opening summary (op) ──────────────────────────────
        SELECT
            fshry_fishery_id,
            tmprl_stratum,
            msfa_id,
            tctype_cde,
            lic_id,
            lic_grp_nme,
            SUM(ef.efrt_cnt)  AS ec,
            MAX(no_ef)        AS missing_ef,
            MAX(no_tc)        AS missing_tc
        FROM (
            SELECT
                fo.fshry_fishery_id,
                TRUNC(pd.pd_start_dtt, 'YEAR')                                    AS tmprl_stratum,
                CASE WHEN fa.fa_fa_id IS NULL THEN fa.fa_id ELSE fa.fa_fa_id END  AS msfa_id,
                pd.pd_id,
                oa.fa_fa_id,
                og.gear_gear_cde,
                lic.lic_id,
                lic.lic_grp_nme,
                tct.tctype_cde,
                CASE WHEN NOT EXISTS (
                    SELECT ef.efrt_id FROM FOS_V1_1.effort ef
                    WHERE ef.pd_pd_id          = pd.pd_id
                      AND ef.fa_fa_id          = oa.fa_fa_id
                      AND ef.gear_gear_cde     = og.gear_gear_cde
                      AND ef.lic_lic_id        = lic.lic_id
                      AND ef.tctype_tctype_cde = tct.tctype_cde
                ) THEN 1 ELSE 0 END AS no_ef,
                CASE WHEN NOT EXISTS (
                    SELECT tc.totctch_id
                    FROM FOS_V1_1.total_catch tc
                    JOIN FOS_V1_1.effort ef ON ef.efrt_id = tc.efrt_id
                    WHERE ef.pd_pd_id          = pd.pd_id
                      AND ef.fa_fa_id          = oa.fa_fa_id
                      AND ef.gear_gear_cde     = og.gear_gear_cde
                      AND ef.lic_lic_id        = lic.lic_id
                      AND ef.tctype_tctype_cde = tct.tctype_cde
                ) THEN 1 ELSE 0 END AS no_tc
            FROM       FOS_V1_1.season            sn
            JOIN       FOS_V1_1.fishry_opening    fo  ON  sn.season_id           = fo.season_id
            JOIN       FOS_V1_1.period            pd  ON  fo.opng_id             = pd.opng_opng_id
                                                      AND fo.pdtype_pdtype_id    = pd.pdtype_pdtype_id
            JOIN       FOS_V1_1.opening_area_aggr oaa ON  fo.opng_id             = oaa.opng_opng_id
            JOIN       FOS_V1_1.opening_area      oa  ON  oaa.opng_opng_id       = oa.opng_opng_id
                                                      AND oaa.oaa_id             = oa.oaa_oaa_id
            JOIN       FOS_V1_1.opening_lic       ol  ON  fo.opng_id             = ol.opng_opng_id
            JOIN       FOS_V1_1.opening_gear      og  ON  fo.opng_id             = og.opng_opng_id
            JOIN       FOS_V1_1.fishry_area       fa  ON  oa.fa_fa_id            = fa.fa_id
            JOIN       FOS_V1_1.total_catch_type  tct ON  1=1   -- cross-conditions handled in WHERE
            JOIN       FOS_V1_1.licence           lic ON  ol.lic_lic_id          = lic.lic_id
            WHERE INSTR(',' || :fishery_list || ',', ',' || sn.fshry_fishery_id || ',') > 0
              AND tct.tctype_cde      = 1
              AND oaa.oaa_est_ind     = 1
              AND ol.opnlic_tot_catch_ind = 1
              AND (CASE WHEN fa.fa_fa_id IS NULL THEN fa.fa_id ELSE fa.fa_fa_id END) IN (
    SELECT fa_id FROM (
        SELECT 2588 fa_id,   1 pfma FROM DUAL UNION ALL
        SELECT 2589,         2      FROM DUAL UNION ALL
        SELECT 2590,         3      FROM DUAL UNION ALL
        SELECT 2631,         4      FROM DUAL UNION ALL
        SELECT 2591,         5      FROM DUAL UNION ALL
        SELECT 2632,         6      FROM DUAL UNION ALL
        SELECT 2633,         7      FROM DUAL UNION ALL
        SELECT 2634,         8      FROM DUAL UNION ALL
        SELECT 2592,         9      FROM DUAL UNION ALL
        SELECT 2593,        10      FROM DUAL UNION ALL
        SELECT 2594,        11      FROM DUAL UNION ALL
        SELECT 2595,        12      FROM DUAL UNION ALL
        SELECT 2596,        13      FROM DUAL UNION ALL
        SELECT 2597,        14      FROM DUAL UNION ALL
        SELECT 2598,        15      FROM DUAL UNION ALL
        SELECT 2599,        16      FROM DUAL UNION ALL
        SELECT 2600,        17      FROM DUAL UNION ALL
        SELECT 2601,        18      FROM DUAL UNION ALL
        SELECT 2602,        19      FROM DUAL UNION ALL
        SELECT 2603,        20      FROM DUAL UNION ALL
        SELECT 2604,        21      FROM DUAL UNION ALL
        SELECT 2605,        22      FROM DUAL UNION ALL
        SELECT 2606,        23      FROM DUAL UNION ALL
        SELECT 2607,        24      FROM DUAL UNION ALL
        SELECT 2608,        25      FROM DUAL UNION ALL
        SELECT 2609,        26      FROM DUAL UNION ALL
        SELECT 2610,        27      FROM DUAL UNION ALL
        SELECT 2611,        28      FROM DUAL UNION ALL
        SELECT 2635,        29      FROM DUAL UNION ALL
        SELECT 2612,       101      FROM DUAL UNION ALL
        SELECT 2613,       102      FROM DUAL UNION ALL
        SELECT 2614,       103      FROM DUAL UNION ALL
        SELECT 2615,       104      FROM DUAL UNION ALL
        SELECT 2616,       105      FROM DUAL UNION ALL
        SELECT 2617,       106      FROM DUAL UNION ALL
        SELECT 2618,       107      FROM DUAL UNION ALL
        SELECT 2619,       108      FROM DUAL UNION ALL
        SELECT 2620,       109      FROM DUAL UNION ALL
        SELECT 2621,       110      FROM DUAL UNION ALL
        SELECT 2622,       111      FROM DUAL UNION ALL
        SELECT 2623,       121      FROM DUAL UNION ALL
        SELECT 2624,       123      FROM DUAL UNION ALL
        SELECT 2625,       124      FROM DUAL UNION ALL
        SELECT 2626,       125      FROM DUAL UNION ALL
        SELECT 2627,       126      FROM DUAL UNION ALL
        SELECT 2628,       127      FROM DUAL UNION ALL
        SELECT 2629,       130      FROM DUAL UNION ALL
        SELECT 2630,       142      FROM DUAL
    )
    WHERE INSTR(',' || :pfma_list || ',', ',' || pfma || ',') > 0
)
			  -- ── Shared date filter (extracted once) ──────────────────
              AND sn.season_end_dtt   >= TRUNC(TO_DATE(:start_date, 'MM/DD/YYYY HH24:MI'))
              AND TRUNC(sn.season_start_dtt) <= TRUNC(TO_DATE(:end_date, 'MM/DD/YYYY HH24:MI:SS'))
              AND fo.opng_end_dtt     >= TRUNC(TO_DATE(:start_date, 'MM/DD/YYYY HH24:MI'))
              AND TRUNC(fo.opng_start_dtt) <= TRUNC(TO_DATE(:end_date, 'MM/DD/YYYY HH24:MI:SS'))
              AND TRUNC(pd.pd_start_dtt) BETWEEN TRUNC(TO_DATE(:start_date, 'MM/DD/YYYY HH24:MI'))
                                             AND TRUNC(TO_DATE(:end_date,   'MM/DD/YYYY HH24:MI:SS'))
        ) opst
        LEFT JOIN FOS_V1_1.effort ef
               ON  opst.pd_id          = ef.pd_pd_id
              AND  opst.fa_fa_id       = ef.fa_fa_id
              AND  opst.gear_gear_cde  = ef.gear_gear_cde
              AND  opst.lic_id         = ef.lic_lic_id
              AND  opst.tctype_cde     = ef.tctype_tctype_cde
        GROUP BY fshry_fishery_id, tmprl_stratum, msfa_id, tctype_cde, lic_id, lic_grp_nme
    ) op

    -- ── Vessel count (vc) ───────────────────────────────────────────────
    LEFT JOIN (
        SELECT
            fo.fshry_fishery_id,
            TRUNC(pd.pd_start_dtt, 'YEAR')                                   AS tmprl_stratum,
            CASE WHEN fa.fa_fa_id IS NULL THEN fa.fa_id ELSE fa.fa_fa_id END AS msfa_id,
            licg.lic_id,
            COUNT(DISTINCT FOS_V1_1.fos_pkg.getVesselForLic(cr.lic_lic_id, pd.pd_start_dtt)) AS vessel_count
        FROM       FOS_V1_1.season          sn
        JOIN       FOS_V1_1.fishry_opening  fo   ON  sn.fshry_fishery_id = fo.fshry_fishery_id
                                                 AND sn.season_id        = fo.season_id
        JOIN       FOS_V1_1.period          pd   ON  fo.opng_id          = pd.opng_opng_id
        JOIN       FOS_V1_1.crpt_vw         cr   ON  pd.pd_id            = cr.pd_pd_id
        JOIN       FOS_V1_1.fe_vw           fe   ON  cr.crpt_id          = fe.crpt_crpt_id
        JOIN       FOS_V1_1.fishry_area     fa   ON  fa.fa_id            = fe.fa_fa_id
        JOIN       FOS_V1_1.licence         lici ON  cr.lic_lic_id       = lici.lic_id
        JOIN       FOS_V1_1.licence         licg ON  licg.figr_cde       = lici.figr_cde
                                                 AND licg.grag_id        = lici.grag_id
                                                 AND licg.lfaa_id        = lici.lfaa_id
                                                 AND licg.spag_id        = lici.spag_id
        WHERE INSTR(',' || :fishery_list || ',', ',' || sn.fshry_fishery_id || ',') > 0
          AND licg.lictype_lictype_cde = 1
          AND cr.crpt_flag  = 0
          AND cr.cdsrc_cdsrc_id IN (1, 3, 9, 14)
          AND (CASE WHEN fa.fa_fa_id IS NULL THEN fa.fa_id ELSE fa.fa_fa_id END) IN (
    SELECT fa_id FROM (
        SELECT 2588 fa_id,   1 pfma FROM DUAL UNION ALL
        SELECT 2589,         2      FROM DUAL UNION ALL
        SELECT 2590,         3      FROM DUAL UNION ALL
        SELECT 2631,         4      FROM DUAL UNION ALL
        SELECT 2591,         5      FROM DUAL UNION ALL
        SELECT 2632,         6      FROM DUAL UNION ALL
        SELECT 2633,         7      FROM DUAL UNION ALL
        SELECT 2634,         8      FROM DUAL UNION ALL
        SELECT 2592,         9      FROM DUAL UNION ALL
        SELECT 2593,        10      FROM DUAL UNION ALL
        SELECT 2594,        11      FROM DUAL UNION ALL
        SELECT 2595,        12      FROM DUAL UNION ALL
        SELECT 2596,        13      FROM DUAL UNION ALL
        SELECT 2597,        14      FROM DUAL UNION ALL
        SELECT 2598,        15      FROM DUAL UNION ALL
        SELECT 2599,        16      FROM DUAL UNION ALL
        SELECT 2600,        17      FROM DUAL UNION ALL
        SELECT 2601,        18      FROM DUAL UNION ALL
        SELECT 2602,        19      FROM DUAL UNION ALL
        SELECT 2603,        20      FROM DUAL UNION ALL
        SELECT 2604,        21      FROM DUAL UNION ALL
        SELECT 2605,        22      FROM DUAL UNION ALL
        SELECT 2606,        23      FROM DUAL UNION ALL
        SELECT 2607,        24      FROM DUAL UNION ALL
        SELECT 2608,        25      FROM DUAL UNION ALL
        SELECT 2609,        26      FROM DUAL UNION ALL
        SELECT 2610,        27      FROM DUAL UNION ALL
        SELECT 2611,        28      FROM DUAL UNION ALL
        SELECT 2635,        29      FROM DUAL UNION ALL
        SELECT 2612,       101      FROM DUAL UNION ALL
        SELECT 2613,       102      FROM DUAL UNION ALL
        SELECT 2614,       103      FROM DUAL UNION ALL
        SELECT 2615,       104      FROM DUAL UNION ALL
        SELECT 2616,       105      FROM DUAL UNION ALL
        SELECT 2617,       106      FROM DUAL UNION ALL
        SELECT 2618,       107      FROM DUAL UNION ALL
        SELECT 2619,       108      FROM DUAL UNION ALL
        SELECT 2620,       109      FROM DUAL UNION ALL
        SELECT 2621,       110      FROM DUAL UNION ALL
        SELECT 2622,       111      FROM DUAL UNION ALL
        SELECT 2623,       121      FROM DUAL UNION ALL
        SELECT 2624,       123      FROM DUAL UNION ALL
        SELECT 2625,       124      FROM DUAL UNION ALL
        SELECT 2626,       125      FROM DUAL UNION ALL
        SELECT 2627,       126      FROM DUAL UNION ALL
        SELECT 2628,       127      FROM DUAL UNION ALL
        SELECT 2629,       130      FROM DUAL UNION ALL
        SELECT 2630,       142      FROM DUAL
    )
    WHERE INSTR(',' || :pfma_list || ',', ',' || pfma || ',') > 0
)
          AND sn.season_end_dtt   >= TRUNC(TO_DATE(:start_date, 'MM/DD/YYYY HH24:MI'))
          AND TRUNC(sn.season_start_dtt) <= TRUNC(TO_DATE(:end_date, 'MM/DD/YYYY HH24:MI:SS'))
          AND fo.opng_end_dtt     >= TRUNC(TO_DATE(:start_date, 'MM/DD/YYYY HH24:MI'))
          AND TRUNC(fo.opng_start_dtt) <= TRUNC(TO_DATE(:end_date, 'MM/DD/YYYY HH24:MI:SS'))
          AND TRUNC(pd.pd_start_dtt) BETWEEN TRUNC(TO_DATE(:start_date, 'MM/DD/YYYY HH24:MI'))
                                         AND TRUNC(TO_DATE(:end_date,   'MM/DD/YYYY HH24:MI:SS'))
        GROUP BY fo.fshry_fishery_id,
                 TRUNC(pd.pd_start_dtt, 'YEAR'),
                 CASE WHEN fa.fa_fa_id IS NULL THEN fa.fa_id ELSE fa.fa_fa_id END,
                 licg.lic_id
    ) vc
           ON  op.fshry_fishery_id = vc.fshry_fishery_id
          AND  op.tmprl_stratum    = vc.tmprl_stratum
          AND  op.msfa_id          = vc.msfa_id
          AND  op.lic_id           = vc.lic_id

    -- ── Species catch aggregates (sa) ──────────────────────────────────
    LEFT JOIN (
        SELECT
            fo.fshry_fishery_id,
            TRUNC(pd.pd_start_dtt, 'YEAR')                                   AS tmprl_stratum,
            CASE WHEN fa.fa_fa_id IS NULL THEN fa.fa_id ELSE fa.fa_fa_id END AS msfa_id,
            ef.tctype_tctype_cde                                              AS tctype_cde,
            ef.lic_lic_id,
            SUM(DECODE(tc.species_species_cde,'118',DECODE(tc.catch_disposition_id,0,tc.totctch_cnt,0),0)) AS sockeye_kept,
            SUM(DECODE(tc.species_species_cde,'118',DECODE(tc.catch_disposition_id,1,tc.totctch_cnt,0),0)) AS sockeye_reld,
            SUM(DECODE(tc.species_species_cde,'115',DECODE(tc.catch_disposition_id,0,tc.totctch_cnt,0),0)) AS coho_kept,
            SUM(DECODE(tc.species_species_cde,'115',DECODE(tc.catch_disposition_id,1,tc.totctch_cnt,0),0)) AS coho_reld,
            SUM(DECODE(tc.species_species_cde,'108',DECODE(tc.catch_disposition_id,0,tc.totctch_cnt,0),0)) AS pink_kept,
            SUM(DECODE(tc.species_species_cde,'108',DECODE(tc.catch_disposition_id,1,tc.totctch_cnt,0),0)) AS pink_reld,
            SUM(DECODE(tc.species_species_cde,'112',DECODE(tc.catch_disposition_id,0,tc.totctch_cnt,0),0)) AS chum_kept,
            SUM(DECODE(tc.species_species_cde,'112',DECODE(tc.catch_disposition_id,1,tc.totctch_cnt,0),0)) AS chum_reld,
            SUM(DECODE(tc.species_species_cde,'124',DECODE(tc.catch_disposition_id,0,tc.totctch_cnt,0),0)) AS chinook_kept,
            SUM(DECODE(tc.species_species_cde,'124',DECODE(tc.catch_disposition_id,1,tc.totctch_cnt,0),0)) AS chinook_reld,
            SUM(DECODE(tc.species_species_cde,'128',DECODE(tc.catch_disposition_id,0,tc.totctch_cnt,0),0)) AS steelhead_kept,
            SUM(DECODE(tc.species_species_cde,'128',DECODE(tc.catch_disposition_id,1,tc.totctch_cnt,0),0)) AS steelhead_reld
        FROM       FOS_V1_1.season            sn
        JOIN       FOS_V1_1.fishry_opening    fo  ON  sn.season_id              = fo.season_id
        JOIN       FOS_V1_1.period            pd  ON  fo.opng_id                = pd.opng_opng_id
                                                  AND fo.pdtype_pdtype_id       = pd.pdtype_pdtype_id
        JOIN       FOS_V1_1.opening_area_aggr oaa ON  fo.opng_id                = oaa.opng_opng_id
        JOIN       FOS_V1_1.opening_area      oa  ON  oaa.opng_opng_id          = oa.opng_opng_id
                                                  AND oaa.oaa_id                = oa.oaa_oaa_id
        JOIN       FOS_V1_1.opening_lic       ol  ON  fo.opng_id                = ol.opng_opng_id
        JOIN       FOS_V1_1.opening_gear      og  ON  fo.opng_id                = og.opng_opng_id
        JOIN       FOS_V1_1.fishry_area       fa  ON  oa.fa_fa_id               = fa.fa_id
        JOIN       FOS_V1_1.effort            ef  ON  pd.pd_id                  = ef.pd_pd_id
                                                  AND ol.lic_lic_id             = ef.lic_lic_id
                                                  AND oa.fa_fa_id               = ef.fa_fa_id
                                                  AND og.gear_gear_cde          = ef.gear_gear_cde
        JOIN       FOS_V1_1.total_catch       tc  ON  ef.efrt_id                = tc.efrt_id
        JOIN       FOS_V1_1.total_catch_status ts  ON  tc.tcstat_tcstat_cde     = ts.tcstat_cde
        WHERE INSTR(',' || :fishery_list || ',', ',' || sn.fshry_fishery_id || ',') > 0
          AND ef.tctype_tctype_cde  = 1
          AND oaa.oaa_est_ind       = 1
          AND ol.opnlic_tot_catch_ind = 1
          AND tc.species_species_cde IN ('118','115','108','112','124','128')
          AND tc.mat_mat_cde         IN (1, 2, 3)
          AND (CASE WHEN fa.fa_fa_id IS NULL THEN fa.fa_id ELSE fa.fa_fa_id END) IN (
    SELECT fa_id FROM (
        SELECT 2588 fa_id,   1 pfma FROM DUAL UNION ALL
        SELECT 2589,         2      FROM DUAL UNION ALL
        SELECT 2590,         3      FROM DUAL UNION ALL
        SELECT 2631,         4      FROM DUAL UNION ALL
        SELECT 2591,         5      FROM DUAL UNION ALL
        SELECT 2632,         6      FROM DUAL UNION ALL
        SELECT 2633,         7      FROM DUAL UNION ALL
        SELECT 2634,         8      FROM DUAL UNION ALL
        SELECT 2592,         9      FROM DUAL UNION ALL
        SELECT 2593,        10      FROM DUAL UNION ALL
        SELECT 2594,        11      FROM DUAL UNION ALL
        SELECT 2595,        12      FROM DUAL UNION ALL
        SELECT 2596,        13      FROM DUAL UNION ALL
        SELECT 2597,        14      FROM DUAL UNION ALL
        SELECT 2598,        15      FROM DUAL UNION ALL
        SELECT 2599,        16      FROM DUAL UNION ALL
        SELECT 2600,        17      FROM DUAL UNION ALL
        SELECT 2601,        18      FROM DUAL UNION ALL
        SELECT 2602,        19      FROM DUAL UNION ALL
        SELECT 2603,        20      FROM DUAL UNION ALL
        SELECT 2604,        21      FROM DUAL UNION ALL
        SELECT 2605,        22      FROM DUAL UNION ALL
        SELECT 2606,        23      FROM DUAL UNION ALL
        SELECT 2607,        24      FROM DUAL UNION ALL
        SELECT 2608,        25      FROM DUAL UNION ALL
        SELECT 2609,        26      FROM DUAL UNION ALL
        SELECT 2610,        27      FROM DUAL UNION ALL
        SELECT 2611,        28      FROM DUAL UNION ALL
        SELECT 2635,        29      FROM DUAL UNION ALL
        SELECT 2612,       101      FROM DUAL UNION ALL
        SELECT 2613,       102      FROM DUAL UNION ALL
        SELECT 2614,       103      FROM DUAL UNION ALL
        SELECT 2615,       104      FROM DUAL UNION ALL
        SELECT 2616,       105      FROM DUAL UNION ALL
        SELECT 2617,       106      FROM DUAL UNION ALL
        SELECT 2618,       107      FROM DUAL UNION ALL
        SELECT 2619,       108      FROM DUAL UNION ALL
        SELECT 2620,       109      FROM DUAL UNION ALL
        SELECT 2621,       110      FROM DUAL UNION ALL
        SELECT 2622,       111      FROM DUAL UNION ALL
        SELECT 2623,       121      FROM DUAL UNION ALL
        SELECT 2624,       123      FROM DUAL UNION ALL
        SELECT 2625,       124      FROM DUAL UNION ALL
        SELECT 2626,       125      FROM DUAL UNION ALL
        SELECT 2627,       126      FROM DUAL UNION ALL
        SELECT 2628,       127      FROM DUAL UNION ALL
        SELECT 2629,       130      FROM DUAL UNION ALL
        SELECT 2630,       142      FROM DUAL
    )
    WHERE INSTR(',' || :pfma_list || ',', ',' || pfma || ',') > 0
)
          AND sn.season_end_dtt   >= TRUNC(TO_DATE(:start_date, 'MM/DD/YYYY HH24:MI'))
          AND TRUNC(sn.season_start_dtt) <= TRUNC(TO_DATE(:end_date, 'MM/DD/YYYY HH24:MI:SS'))
          AND TRUNC(fo.opng_end_dtt) >= TRUNC(TO_DATE(:start_date, 'MM/DD/YYYY HH24:MI'))
          AND TRUNC(fo.opng_start_dtt) <= TRUNC(TO_DATE(:end_date, 'MM/DD/YYYY HH24:MI:SS'))
          AND TRUNC(pd.pd_start_dtt) BETWEEN TRUNC(TO_DATE(:start_date, 'MM/DD/YYYY HH24:MI'))
                                         AND TRUNC(TO_DATE(:end_date,   'MM/DD/YYYY HH24:MI:SS'))
        GROUP BY fo.fshry_fishery_id,
                 TRUNC(pd.pd_start_dtt, 'YEAR'),
                 CASE WHEN fa.fa_fa_id IS NULL THEN fa.fa_id ELSE fa.fa_fa_id END,
                 ef.tctype_tctype_cde,
                 ef.lic_lic_id
    ) sa
           ON  op.fshry_fishery_id = sa.fshry_fishery_id
          AND  op.tmprl_stratum    = sa.tmprl_stratum
          AND  op.msfa_id          = sa.msfa_id
          AND  op.tctype_cde       = sa.tctype_cde
          AND  op.lic_id           = sa.lic_lic_id

    JOIN FOS_V1_1.fishry_area fa ON fa.fa_id = op.msfa_id
    JOIN FOS_V1_1.fishery     fy ON fy.fishery_id = op.fshry_fishery_id
)
WHERE NOT (
    vessel_count    = 0 AND
    boat_days       = 0 AND
    sockeye_kept    = 0 AND
    sockeye_reld    = 0 AND
    coho_kept       = 0 AND
    coho_reld       = 0 AND
    chum_kept       = 0 AND
    chum_reld       = 0 AND
    pink_kept       = 0 AND
    pink_reld       = 0 AND
    chinook_kept    = 0 AND
    chinook_reld    = 0 AND
    steelhead_kept  = 0 AND
    steelhead_reld  = 0
)
ORDER BY
tmprl_stratum DESC,
licence_area,
mgmt_area