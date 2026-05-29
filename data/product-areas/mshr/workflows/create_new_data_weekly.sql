-- =====================================================================
-- WEEKLY METRICS CREATION WITH METRIC-SPECIFIC FILTERING
-- Applies different inclusion criteria based on metric type
-- Reporting period: Sunday to Saturday
-- =====================================================================

CREATE OR REPLACE TABLE dbt.new_data_weekly AS
(
    /*=====================================================================
    PARAMETERS & BUSINESS QUALIFICATION
    =====================================================================*/
    WITH params AS (SELECT 260 AS periods_back),           -- ~5 years of weeks
    
    -- First calculate weekly metrics
    weekly_metrics AS (
        SELECT 
            location_id,
            DATE_TRUNC('week', event_date)::DATE AS week_start,  -- Sunday
            COUNT(DISTINCT user_id) AS weekly_employees,
            SUM(hours_worked) AS weekly_hours,
            
            -- Wage coverage
            SUM(CASE WHEN hourly_wage_rate IS NOT NULL THEN hours_worked END) / 
                NULLIF(SUM(hours_worked), 0) AS wage_coverage_ratio,
            
            -- Check if location was archived this week
            MAX(CASE 
                WHEN DATE_TRUNC('week', loc_archived_at) = DATE_TRUNC('week', event_date) 
                THEN 1 ELSE 0 
            END) AS archived_this_week
            
        FROM dbt.temp_timeclock_data
        GROUP BY location_id, DATE_TRUNC('week', event_date)
    ),
    
    -- Calculate rolling averages and week counts
    business_qualifications AS (
        SELECT 
            m.*,
            
            -- Calculate 12-week (3-month) average employees
            AVG(weekly_employees) OVER (
                PARTITION BY location_id 
                ORDER BY week_start
                ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
            ) AS employees_12w_avg,
            
            -- Count active weeks in past 52 weeks (1 year)
            COUNT(*) OVER (
                PARTITION BY location_id
                ORDER BY week_start
                ROWS BETWEEN 51 PRECEDING AND CURRENT ROW
            ) AS weeks_active_52w
            
        FROM weekly_metrics m
    ),
    
    qualified_businesses AS (
        SELECT 
            location_id,
            week_start,
            
            -- JOBS METRICS QUALIFICATION (5-100 employees, 12+ weeks active)
            CASE 
                WHEN employees_12w_avg BETWEEN 5 AND 100
                    AND weeks_active_52w >= 12  -- ~3 months
                    AND archived_this_week = 0
                THEN 1 ELSE 0 
            END AS qualified_for_jobs,
            
            -- TURNOVER METRICS QUALIFICATION (10-100 employees, 12+ weeks active)
            CASE 
                WHEN employees_12w_avg BETWEEN 10 AND 100
                    AND weeks_active_52w >= 12
                    AND archived_this_week = 0
                THEN 1 ELSE 0 
            END AS qualified_for_turnover,
            
            -- HOURS METRICS QUALIFICATION (5-100 employees, 12+ weeks active)
            CASE 
                WHEN employees_12w_avg BETWEEN 5 AND 100
                    AND weeks_active_52w >= 12
                    AND archived_this_week = 0
                THEN 1 ELSE 0 
            END AS qualified_for_hours,
            
            -- WAGE METRICS QUALIFICATION (5-100 employees, 12+ weeks, wage coverage)
            CASE 
                WHEN employees_12w_avg BETWEEN 5 AND 100
                    AND weeks_active_52w >= 12
                    AND wage_coverage_ratio > 0.5
                    AND archived_this_week = 0
                THEN 1 ELSE 0 
            END AS qualified_for_wages,
            
            -- OUTLOOK METRICS QUALIFICATION (5-100 employees, 26+ weeks active)
            CASE 
                WHEN employees_12w_avg BETWEEN 5 AND 100
                    AND weeks_active_52w >= 26  -- ~6 months
                    AND archived_this_week = 0
                THEN 1 ELSE 0 
            END AS qualified_for_outlook,
            
            -- Store base metrics for later use
            employees_12w_avg,
            weeks_active_52w
            
        FROM business_qualifications
    ),

    /*=====================================================================
    1 | Reporting periods (Sunday to Saturday)
    =====================================================================*/
    report_periods AS (
        SELECT
            week_start AS period_start,                    -- Sunday
            DATE_ADD(week_start, 6) AS period_end,         -- Saturday
            DATE_ADD(week_start, 7) AS future_start,       -- Following Sunday
            DATE_ADD(week_start, 34) AS future_end         -- 4 weeks ahead (Saturday)
        FROM (
            SELECT EXPLODE(
                SEQUENCE(
                    DATE_TRUNC('week', DATE_ADD(CURRENT_DATE, -1 * (SELECT periods_back FROM params) * 7)),
                    DATE_TRUNC('week', CURRENT_DATE),
                    INTERVAL 1 WEEK
                )
            ) AS week_start
        ) w
        WHERE DATE_ADD(week_start, 6) <= CURRENT_DATE  -- Only complete weeks
    ),

    /*=====================================================================
    2 | Active locations & users with proper filtering
    =====================================================================*/
    active_locations AS (
        SELECT
            rp.period_end,
            t.location_id,
            qb.qualified_for_jobs,
            qb.qualified_for_turnover,
            qb.qualified_for_hours,
            qb.qualified_for_wages,
            qb.qualified_for_outlook
        FROM report_periods rp
        JOIN dbt.temp_timeclock_data t
            ON t.location_id IS NOT NULL
            AND t.event_date BETWEEN rp.period_start AND rp.period_end
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = rp.period_start
        GROUP BY rp.period_end, t.location_id, 
                 qb.qualified_for_jobs, qb.qualified_for_turnover, 
                 qb.qualified_for_hours, qb.qualified_for_wages, qb.qualified_for_outlook
    ),
    
    active_locations_cnt AS (
        SELECT 
            period_end, 
            COUNT(DISTINCT CASE WHEN qualified_for_hours = 1 THEN location_id END) AS active_location_count
        FROM active_locations
        GROUP BY period_end
    ),
    
    active_users_cnt AS (
        SELECT 
            rp.period_end, 
            COUNT(DISTINCT CASE 
                WHEN qb.qualified_for_turnover = 1 THEN t.user_id 
            END) AS active_users
        FROM report_periods rp
        JOIN dbt.temp_timeclock_data t
            ON t.user_id IS NOT NULL
            AND t.shift_id IS NOT NULL
            AND t.event_date BETWEEN rp.period_start AND rp.period_end
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = rp.period_start
        GROUP BY rp.period_end
    ),
    
    avg_active_users AS (
        SELECT
            period_end,
            (
                COALESCE(active_users, 0) +
                COALESCE(LAG(active_users, 1) OVER (ORDER BY period_end), 0) +
                COALESCE(LAG(active_users, 2) OVER (ORDER BY period_end), 0) +
                COALESCE(LAG(active_users, 3) OVER (ORDER BY period_end), 0) +
                COALESCE(LAG(active_users, 4) OVER (ORDER BY period_end), 0) +
                COALESCE(LAG(active_users, 5) OVER (ORDER BY period_end), 0) +
                COALESCE(LAG(active_users, 6) OVER (ORDER BY period_end), 0) +
                COALESCE(LAG(active_users, 7) OVER (ORDER BY period_end), 0) +
                COALESCE(LAG(active_users, 8) OVER (ORDER BY period_end), 0) +
                COALESCE(LAG(active_users, 9) OVER (ORDER BY period_end), 0) +
                COALESCE(LAG(active_users, 10) OVER (ORDER BY period_end), 0) +
                COALESCE(LAG(active_users, 11) OVER (ORDER BY period_end), 0)
            ) / 12.0 AS avg_active_users_12w  -- 12-week (3-month) average
        FROM active_users_cnt
    ),

    /*=====================================================================
    3 | Jobs added & archived (JOBS METRICS FILTERING)
    =====================================================================*/
    user_period_users AS (
        SELECT 
            rp.period_start, 
            rp.period_end, 
            t.user_id,
            t.location_id
        FROM report_periods rp
        JOIN dbt.temp_timeclock_data t
            ON t.user_id IS NOT NULL
            AND t.shift_id IS NOT NULL
            AND t.event_date BETWEEN rp.period_start AND rp.period_end
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = rp.period_start
        WHERE qb.qualified_for_jobs = 1
        GROUP BY rp.period_start, rp.period_end, t.user_id, t.location_id
    ),
    
    /* Jobs ADDED - first appearance at location */
    jobs_added AS (
        SELECT
            curr.period_end,
            COUNT(DISTINCT u_curr.user_id) AS jobs_added_users
        FROM report_periods curr
        LEFT JOIN user_period_users u_curr
            ON u_curr.period_start = curr.period_start
        LEFT JOIN report_periods prev
            ON prev.period_end = DATE_ADD(curr.period_end, -7)  -- Previous week
        LEFT ANTI JOIN user_period_users u_prev
            ON u_prev.user_id = u_curr.user_id
            AND u_prev.location_id = u_curr.location_id
            AND u_prev.period_start = prev.period_start
        WHERE u_curr.user_id IS NOT NULL
        GROUP BY curr.period_end
    ),
    
    /* Jobs ARCHIVED - worked last week but not this week */
    jobs_archived AS (
        SELECT
            curr.period_end,
            COUNT(DISTINCT u_prev.user_id) AS jobs_archived_users
        FROM report_periods curr
        LEFT JOIN report_periods prev
            ON prev.period_end = DATE_ADD(curr.period_end, -7)
        LEFT JOIN user_period_users u_prev
            ON u_prev.period_start = prev.period_start
        LEFT ANTI JOIN user_period_users u_curr
            ON u_curr.user_id = u_prev.user_id
            AND u_curr.location_id = u_prev.location_id
            AND u_curr.period_start = curr.period_start
        WHERE u_prev.user_id IS NOT NULL
        GROUP BY curr.period_end
    ),

    /*=====================================================================
    4 | New users & archived users (TURNOVER METRICS FILTERING)
    =====================================================================*/
    user_first_seen AS (
        SELECT 
            t.user_id, 
            MIN(t.event_date) AS first_shift_date
        FROM dbt.temp_timeclock_data t
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = DATE_TRUNC('week', t.event_date)
        WHERE t.user_id IS NOT NULL
            AND qb.qualified_for_turnover = 1
        GROUP BY t.user_id
    ),
    
    new_users AS (
        SELECT 
            rp.period_end, 
            COUNT(DISTINCT ufs.user_id) AS new_users
        FROM report_periods rp
        JOIN user_first_seen ufs
            ON ufs.first_shift_date BETWEEN rp.period_start AND rp.period_end
        GROUP BY rp.period_end
    ),
    
    archived_users AS (
        SELECT 
            rp.period_end, 
            COUNT(DISTINCT t.user_id) AS archived_users
        FROM report_periods rp
        JOIN dbt.temp_timeclock_data t
            ON t.user_id IS NOT NULL
            AND t.archived_at IS NOT NULL
            AND DATE_TRUNC('week', t.archived_at) = rp.period_start
            AND t.archived_at < CURRENT_DATE()
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = rp.period_start
        WHERE qb.qualified_for_turnover = 1
        GROUP BY rp.period_end
    ),

    /*=====================================================================
    5 | Hours worked (HOURS METRICS FILTERING)
    =====================================================================*/
    hours_worked AS (
        SELECT 
            rp.period_end, 
            SUM(t.hours_worked) AS hours_worked
        FROM report_periods rp
        JOIN dbt.temp_timeclock_data t
            ON t.hours_worked IS NOT NULL
            AND t.event_date BETWEEN rp.period_start AND rp.period_end
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = rp.period_start
        WHERE qb.qualified_for_hours = 1
        GROUP BY rp.period_end
    ),
    
    hours_worked_wage AS (
        SELECT 
            rp.period_end, 
            SUM(t.hours_worked) AS hours_worked_wage
        FROM report_periods rp
        JOIN dbt.temp_timeclock_data t
            ON t.hours_worked IS NOT NULL
            AND t.hourly_wage_rate IS NOT NULL
            AND t.event_date BETWEEN rp.period_start AND rp.period_end
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = rp.period_start
        WHERE qb.qualified_for_wages = 1
        GROUP BY rp.period_end
    ),

    /*=====================================================================
    6 | Nominal wages (WAGE METRICS FILTERING)
    =====================================================================*/
    nominal_wages AS (
        SELECT 
            rp.period_end,
            ROUND(SUM(t.total_wages_earned) / SUM(t.hours_worked), 2) AS avg_nominal_wage
        FROM report_periods rp
        JOIN dbt.temp_timeclock_data t
            ON t.total_wages_earned IS NOT NULL
            AND t.hours_worked IS NOT NULL
            AND t.hourly_wage_rate BETWEEN 7.25 AND 100
            AND t.event_date BETWEEN rp.period_start AND rp.period_end
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = rp.period_start
        WHERE qb.qualified_for_wages = 1
        GROUP BY rp.period_end
    ),

    /*=====================================================================
    7 | Weekly pay (WAGE METRICS FILTERING)
    =====================================================================*/
    weekly_pay AS (
        SELECT 
            rp.period_end,
            ROUND(
                SUM(t.total_wages_earned) / COUNT(DISTINCT t.user_id), 
                2
            ) AS avg_weekly_pay
        FROM report_periods rp
        JOIN dbt.temp_timeclock_data t
            ON t.total_wages_earned IS NOT NULL
            AND t.hours_worked IS NOT NULL
            AND t.hourly_wage_rate BETWEEN 7.25 AND 100
            AND t.event_date BETWEEN rp.period_start AND rp.period_end
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = rp.period_start
        WHERE qb.qualified_for_wages = 1
        GROUP BY rp.period_end
    ),

    /*=====================================================================
    8 | Shift counts for growth (OUTLOOK METRICS FILTERING)
    =====================================================================*/
    current_shift_stats AS (
        SELECT 
            rp.period_end,
            COUNT(*) AS shifts_curr,
            COUNT(DISTINCT t.location_id) AS locs_curr
        FROM report_periods rp
        JOIN dbt.temp_timeclock_data t
            ON t.shift_id IS NOT NULL
            AND t.event_date BETWEEN rp.period_start AND rp.period_end
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = rp.period_start
        WHERE qb.qualified_for_outlook = 1
        GROUP BY rp.period_end
    ),
    
    future_shift_stats AS (
        SELECT 
            rp.period_end,
            COUNT(*) AS shifts_future,
            COUNT(DISTINCT t.location_id) AS locs_future
        FROM report_periods rp
        JOIN dbt.temp_timeclock_data t
            ON t.shift_id IS NOT NULL
            AND t.event_date BETWEEN rp.future_start AND rp.future_end
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = rp.period_start
        WHERE qb.qualified_for_outlook = 1
        GROUP BY rp.period_end
    ),

    /*=====================================================================
    9 | Hours on new job-location pairs (JOBS METRICS FILTERING)
    =====================================================================*/
    this_period_shifts AS (
        SELECT 
            rp.period_start, 
            rp.period_end,
            t.user_id, 
            t.location_id, 
            t.hours_worked
        FROM report_periods rp
        JOIN dbt.temp_timeclock_data t
            ON t.user_id IS NOT NULL
            AND t.location_id IS NOT NULL
            AND t.shift_id IS NOT NULL
            AND t.event_date BETWEEN rp.period_start AND rp.period_end
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = rp.period_start
        WHERE qb.qualified_for_jobs = 1
    ),
    
    prev_period_shifts AS (
        SELECT 
            prev.period_start, 
            prev.period_end,
            t.user_id, 
            t.location_id
        FROM report_periods prev
        JOIN dbt.temp_timeclock_data t
            ON t.user_id IS NOT NULL
            AND t.location_id IS NOT NULL
            AND t.shift_id IS NOT NULL
            AND t.event_date BETWEEN prev.period_start AND prev.period_end
        LEFT JOIN qualified_businesses qb
            ON qb.location_id = t.location_id
            AND qb.week_start = prev.period_start
        WHERE qb.qualified_for_jobs = 1
    ),
    
    new_job_assignments AS (
        SELECT 
            curr.period_end, 
            curr.hours_worked
        FROM this_period_shifts curr
        LEFT JOIN prev_period_shifts prev
            ON prev.user_id = curr.user_id
            AND prev.location_id = curr.location_id
            AND prev.period_start = DATE_ADD(curr.period_start, -7)
        WHERE prev.user_id IS NULL
    ),
    
    hours_new_jobs AS (
        SELECT 
            period_end, 
            SUM(hours_worked) AS hours_new_jobs
        FROM new_job_assignments
        GROUP BY period_end
    ),

    /*=====================================================================
    10 | 52-week Business Survival (OUTLOOK METRICS FILTERING)
    =====================================================================*/
    survival_52w AS (
        SELECT
            DATE_ADD(al52.period_end, 364) AS period_end,  -- 52 weeks = 364 days
            COUNT(DISTINCT al52.location_id) AS businesses_52w_ago,
            COUNT(DISTINCT CASE 
                WHEN alcurr.location_id IS NOT NULL
                THEN al52.location_id 
            END) AS survivors
        FROM active_locations al52
        LEFT JOIN active_locations alcurr
            ON alcurr.location_id = al52.location_id
            AND alcurr.period_end = DATE_ADD(al52.period_end, 364)
        WHERE al52.qualified_for_outlook = 1
            AND alcurr.qualified_for_outlook = 1
        GROUP BY DATE_ADD(al52.period_end, 364)
    )

/*=====================================================================
 11 | FINAL SELECT
=====================================================================*/

    SELECT
    DATE(rp.period_start)  AS period_start,
    DATE(rp.period_end)    AS period_end,

    /* Denominators (using appropriate filters) */
    act.active_location_count,
    au.active_users,
    CAST(ROUND(aau.avg_active_users_12w, 2) AS DOUBLE) AS avg_active_users_12w,
    COALESCE(cs.shifts_curr, 0) AS total_shifts,

    /* Job flows (JOBS METRICS) */
    COALESCE(ja.jobs_added_users, 0) AS jobs_added,
    COALESCE(jr.jobs_archived_users, 0) AS jobs_archived,
    COALESCE(nu.new_users, 0) AS users_added,
    COALESCE(ar.archived_users, 0) AS users_archived,

    /* Hours & wages totals (HOURS/WAGE METRICS) */
    ROUND(COALESCE(hw.hours_worked, 0), 2) AS hours_worked,
    ROUND(COALESCE(hww.hours_worked_wage, 0), 2) AS hours_worked_with_wage,
    ROUND(COALESCE(hnj.hours_new_jobs, 0), 2) AS hours_new_jobs,

    /* Future shifts (OUTLOOK METRICS) */
    COALESCE(fs.shifts_future, 0) AS future_shifts,
    COALESCE(fs.locs_future, 0) AS future_locs,

    /* Wages (WAGE METRICS) */
    nw.avg_nominal_wage,
    wp.avg_weekly_pay,

    /* 52-week survival (OUTLOOK METRICS) */
    COALESCE(bs.survivors, 0) AS surviving_businesses_this_week,
    COALESCE(bs.businesses_52w_ago, 0) AS surviving_businesses_last_52w,

    /* Averages per location */
    CAST(ROUND(COALESCE(hw.hours_worked, 0) / NULLIF(act.active_location_count, 0), 2) AS DOUBLE)
        AS avg_hours_worked_per_loc,
    CAST(ROUND(COALESCE(hww.hours_worked_wage, 0) / NULLIF(act.active_location_count, 0), 2) AS DOUBLE)
        AS avg_hours_wage_per_loc,
    CAST(ROUND(COALESCE(ja.jobs_added_users, 0) / NULLIF(act.active_location_count, 0), 2) AS DOUBLE)
        AS avg_jobs_added_per_loc,
    CAST(ROUND(COALESCE(jr.jobs_archived_users, 0) / NULLIF(act.active_location_count, 0), 2) AS DOUBLE)
        AS avg_jobs_archived_per_loc,
    CAST(ROUND((COALESCE(ja.jobs_added_users, 0) - COALESCE(jr.jobs_archived_users, 0)) / 
               NULLIF(act.active_location_count, 0), 2) AS DOUBLE) 
        AS avg_net_jobs_added_per_loc,

    /* Shift & employee averages */
    CAST(ROUND(COALESCE(cs.shifts_curr, 0) / NULLIF(act.active_location_count, 0), 2) AS DOUBLE)
        AS shifts_per_loc,
    CAST(ROUND(COALESCE(hw.hours_worked, 0) / NULLIF(au.active_users, 0), 2) AS DOUBLE)
        AS hours_worked_per_user,
    CAST(ROUND(COALESCE(hw.hours_worked, 0) / NULLIF(cs.shifts_curr, 0), 2) AS DOUBLE)
        AS hours_worked_per_shift,
    CAST(ROUND(COALESCE(au.active_users, 0) / NULLIF(act.active_location_count, 0), 2) AS DOUBLE)
        AS employees_per_loc,

    /* Future scheduling (OUTLOOK METRICS) */
    CAST(ROUND(COALESCE(fs.shifts_future, 0) / NULLIF(cs.shifts_curr, 0), 2) AS DOUBLE)
        AS future_shift_growth,
    CAST(ROUND(COALESCE(fs.locs_future, 0) / NULLIF(cs.locs_curr, 0), 2) AS DOUBLE)
        AS future_loc_growth,

    /* Workforce dynamics (TURNOVER METRICS) */
    CAST(ROUND(COALESCE(ar.archived_users, 0) / NULLIF(aau.avg_active_users_12w, 0), 2) AS DOUBLE)
        AS turnover_rate,
    CAST(ROUND(COALESCE(nu.new_users, 0) / NULLIF(aau.avg_active_users_12w, 0), 2) AS DOUBLE)
        AS hire_rate,
    CAST(ROUND((COALESCE(nu.new_users, 0) + COALESCE(ar.archived_users, 0))
                / NULLIF(aau.avg_active_users_12w, 0), 2) AS DOUBLE)
        AS turnover_volatility_idx

    FROM        report_periods rp
    LEFT JOIN   active_locations_cnt  act ON act.period_end = rp.period_end
    LEFT JOIN   active_users_cnt      au  ON au.period_end  = rp.period_end
    LEFT JOIN   avg_active_users      aau ON aau.period_end = rp.period_end
    LEFT JOIN   jobs_added            ja  ON ja.period_end  = rp.period_end
    LEFT JOIN   jobs_archived         jr  ON jr.period_end  = rp.period_end
    LEFT JOIN   new_users             nu  ON nu.period_end  = rp.period_end
    LEFT JOIN   archived_users        ar  ON ar.period_end  = rp.period_end
    LEFT JOIN   hours_worked          hw  ON hw.period_end  = rp.period_end
    LEFT JOIN   hours_worked_wage     hww ON hww.period_end = rp.period_end
    LEFT JOIN   hours_new_jobs        hnj ON hnj.period_end = rp.period_end
    LEFT JOIN   nominal_wages         nw  ON nw.period_end  = rp.period_end
    LEFT JOIN   weekly_pay            wp  ON wp.period_end  = rp.period_end
    LEFT JOIN   current_shift_stats   cs  ON cs.period_end  = rp.period_end
    LEFT JOIN   future_shift_stats    fs  ON fs.period_end  = rp.period_end
    LEFT JOIN   survival_52w          bs  ON bs.period_end  = rp.period_end

    WHERE       period_start >= DATE_ADD(CURRENT_DATE, -1820)  -- ~5 years (52 weeks * 5 * 7 days)

    ORDER BY rp.period_end
);
