# =============================================================================
# MSHR — Generic Event Impact Analysis
#
# Use for any event: sporting events, natural disasters, heatwaves, policy
# changes, economic shocks, etc.
#
# Methodology:
#   1. Weekly grain for fine-grained pre/during/post resolution
#   2. Normalization: employees and hours per active qualified location
#      Businesses open: raw count (exception — no per-loc denominator)
#   3. Seasonality removal: YoY delta (current year - prior year per ISO week)
#      removes the seasonal baseline, isolating event-driven signal
#   4. Stat sig: t-test on YoY deltas in event window vs baseline window
#      Significant = growth is NOT seasonally explained -> event-driven
#   5. Incomplete week guard: last 2 weeks always excluded to avoid partial
#      data skew (timeclock data lags by up to a week in the system)
#
# Output:
#   - Tabular print of raw + normalized values per week (for manual verification)
#   - Line chart: 3 years weekly overlay with event windows annotated
#   - YoY delta chart: week-by-week deviation, seasonality removed
#   - Bar chart: baseline vs pre/during/post YoY deltas with significance flags
#   - Console: stat sig summary table
#
# Each step has a built-in self-check. If a step fails, a clear message is
# printed explaining what went wrong and what to share with your analyst.
#
# To use for a new event: edit only the CONFIG block below.
# =============================================================================

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import matplotlib.patches as mpatches
from scipy import stats

# =============================================================================
# EVENT CONFIG — edit this block only
# =============================================================================

CONFIG = {
    # Event identity
    'event_name'  : 'FIFA World Cup 2026',
    'event_type'  : 'planned',    # planned | natural_disaster | economic | policy | other
    'notes'       : 'Pre-period only — event starts next month. During/post not yet available.',

    # Geography — Step 1 auto-discovers exact city strings from the data
    'city'        : 'MIAMI',
    'state'       : 'FL',

    # Event window — set to None if period has not happened yet
    'event_start' : '2026-06-14',  # first match in this city
    'event_end'   : '2026-07-19',  # last possible match / closing ceremony
    'pre_weeks'   : 6,             # weeks before event_start to label as pre-event
    'post_weeks'  : 6,             # weeks after event_end to label as post-event

    # Comparison years for seasonality removal (YoY delta)
    'prior_years' : [2024, 2025],

    # Sample size floor — weeks below this location count are flagged
    'min_locs'    : 30,

    # Significance threshold
    'p_threshold' : 0.05,
}

# =============================================================================
# Derived dates — do not edit below this line
# =============================================================================

TODAY        = pd.Timestamp('today').normalize()
EVENT_START  = pd.Timestamp(CONFIG['event_start']) if CONFIG['event_start'] else None
EVENT_END    = pd.Timestamp(CONFIG['event_end'])   if CONFIG['event_end']   else None
PRE_START    = (EVENT_START - pd.Timedelta(weeks=CONFIG['pre_weeks'])) if EVENT_START \
               else (TODAY  - pd.Timedelta(weeks=CONFIG['pre_weeks']))
POST_END     = (EVENT_END + pd.Timedelta(weeks=CONFIG['post_weeks'])) if EVENT_END else None

# Incomplete week guard:
# Exclude the current week (always partial) and the immediately prior week
# (timeclock data for the most recent completed week is often not fully loaded).
# Result: data is always capped at 2 full weeks before today.
_current_week_start = TODAY - pd.Timedelta(days=TODAY.dayofweek)  # Monday of this week
SAFE_END     = _current_week_start - pd.Timedelta(days=8)         # Last day of 2 weeks ago
DATA_END     = str((min(POST_END, SAFE_END) if POST_END else SAFE_END).date())
DATA_START   = str((PRE_START - pd.DateOffset(years=len(CONFIG['prior_years']))).date())

has_during   = EVENT_START is not None and SAFE_END >= EVENT_START
has_post     = EVENT_END   is not None and SAFE_END >  EVENT_END

pre_end_date = (EVENT_START - pd.Timedelta(days=1) if EVENT_START else SAFE_END).date()
during_str   = 'pending' if not has_during else f"{EVENT_START.date()} -> {EVENT_END.date()}"
post_str     = 'pending' if not has_post   else f"up to {POST_END.date()}"

print(f"Event     : {CONFIG['event_name']}  [{CONFIG['event_type']}]")
print(f"Geography : {CONFIG['city'].title()}, {CONFIG['state']}")
print(f"Pre-period: {PRE_START.date()} -> {pre_end_date}")
print(f"During    : {during_str}")
print(f"Post      : {post_str}")
print(f"Data pull : {DATA_START} -> {DATA_END}  (last 2 weeks excluded — incomplete data guard)")
print()

# =============================================================================
# Step 1: City discovery check
# =============================================================================

print("=" * 70)
print("STEP 1 — City string discovery")
print("=" * 70)

try:
    DISCOVERY_SQL = f"""
    SELECT
        UPPER(city)                   AS city_upper,
        state,
        COUNT(DISTINCT location_id)   AS locations,
        COUNT(DISTINCT company_id)    AS companies
    FROM dbt.temp_timeclock_data
    WHERE state      = '{CONFIG["state"]}'
      AND city ILIKE '%{CONFIG["city"].lower()}%'
      AND event_date >= DATE_SUB(CURRENT_DATE, 90)
      AND loc_archived_at IS NULL
    GROUP BY 1, 2
    ORDER BY 3 DESC
    """
    city_check = spark.sql(DISCOVERY_SQL).toPandas()
    print(city_check.to_string(index=False))
    print()

    if len(city_check) == 0:
        raise ValueError(
            f"No city variants found for '{CONFIG['city']}' in state '{CONFIG['state']}'.\n"
            "   Fix: check spelling in CONFIG['city'] and CONFIG['state'].\n"
            "   Try a partial name, e.g. 'MIA' instead of 'MIAMI'."
        )
    print(f"OK Step 1 — {city_check['locations'].sum()} active locations found.")

except ValueError as e:
    print(f"\nFAILED Step 1: {e}")
    print("Share this message with your analyst.")
    raise
except Exception as e:
    print(f"\nFAILED Step 1 — unexpected Databricks error:")
    print(f"  {type(e).__name__}: {e}")
    print("Share this full message with your analyst.")
    raise

# =============================================================================
# Step 2: Weekly metrics pull
# =============================================================================

print()
print("=" * 70)
print("STEP 2 — Weekly metrics pull")
print("=" * 70)

try:
    SQL = f"""
    WITH events AS (
        SELECT
            location_id,
            user_id,
            event_date,
            hours_worked,
            has_clock_in,
            YEAR(event_date)               AS yr,
            DATE_TRUNC('week', event_date) AS week_start,
            WEEKOFYEAR(event_date)         AS iso_week
        FROM dbt.temp_timeclock_data
        WHERE event_date BETWEEN '{DATA_START}' AND '{DATA_END}'
          AND state       = '{CONFIG["state"]}'
          AND UPPER(city) = '{CONFIG["city"]}'
          AND loc_archived_at IS NULL
          AND employee_count IN (
              '5–9 employees',
              '10–19 employees',
              '20–49 employees',
              '50–99 employees'
          )
          AND location_age >= 84
    ),
    weekly AS (
        SELECT
            yr, week_start, iso_week,
            COUNT(DISTINCT CASE WHEN has_clock_in = 1
                                THEN location_id END)             AS businesses_open,
            COUNT(DISTINCT location_id)                           AS active_locs,
            COUNT(DISTINCT CASE WHEN has_clock_in = 1
                                THEN user_id END)                 AS employees_working,
            ROUND(SUM(COALESCE(hours_worked, 0)), 2)             AS hours_worked
        FROM events
        GROUP BY yr, week_start, iso_week
    )
    SELECT
        yr, week_start, iso_week,
        businesses_open, active_locs, employees_working, hours_worked,
        ROUND(employees_working / NULLIF(active_locs, 0), 3) AS emp_per_loc,
        ROUND(hours_worked      / NULLIF(active_locs, 0), 3) AS hrs_per_loc
    FROM weekly
    ORDER BY yr, week_start
    """

    df = spark.sql(SQL).toPandas()
    df['week_start'] = pd.to_datetime(df['week_start'])

    # Spark may return numeric columns as decimal.Decimal — force to float now
    # so all downstream steps receive clean numeric types
    for num_col in ['businesses_open', 'active_locs', 'employees_working',
                    'hours_worked', 'emp_per_loc', 'hrs_per_loc']:
        df[num_col] = pd.to_numeric(df[num_col], errors='coerce')

    if len(df) == 0:
        raise ValueError(
            f"No rows returned for {CONFIG['city']}, {CONFIG['state']} "
            f"between {DATA_START} and {DATA_END}.\n"
            "   Possible causes:\n"
            "   - City/state string mismatch (re-check Step 1 output)\n"
            "   - Date range has no data\n"
            "   - All locations filtered out by size (employee_count) or age criteria"
        )
    if df['yr'].nunique() < 2:
        raise ValueError(
            f"Only {df['yr'].nunique()} year(s) of data — need at least 2 for YoY comparison.\n"
            "   Fix: extend CONFIG['prior_years'] or check data availability for earlier years."
        )

    print(f"OK Step 2 — {len(df)} week-rows across years: {sorted(df['yr'].unique())}")

except ValueError as e:
    print(f"\nFAILED Step 2: {e}")
    print("Share this message with your analyst.")
    raise
except Exception as e:
    print(f"\nFAILED Step 2 — unexpected error:")
    print(f"  {type(e).__name__}: {e}")
    print("Share this full message with your analyst.")
    raise

# =============================================================================
# Step 3: Sample size check + tabular data print
# =============================================================================

print()
print("=" * 70)
print("STEP 3 — Sample size check + data table")
print("=" * 70)

thin = df[df['active_locs'] < CONFIG['min_locs']]
if not thin.empty:
    print(f"WARNING: {len(thin)} week(s) have fewer than {CONFIG['min_locs']} qualified "
          f"locations — treat those weeks with caution:")
    print(thin[['yr', 'week_start', 'active_locs']].to_string(index=False))
    print()

print("Weekly data — raw and normalized (use to verify values manually):")
print()
display_cols = ['yr', 'week_start', 'businesses_open', 'active_locs',
                'employees_working', 'hours_worked', 'emp_per_loc', 'hrs_per_loc']
pd.set_option('display.float_format', '{:.2f}'.format)
pd.set_option('display.max_rows', 200)
print(df[display_cols].to_string(index=False))
print()
print("OK Step 3 — table printed above. Check values look reasonable before continuing.")

# =============================================================================
# Step 4: Assign period labels + build YoY delta series
# =============================================================================

print()
print("=" * 70)
print("STEP 4 — Period labels + YoY delta calculation")
print("=" * 70)

try:
    def assign_period(dt):
        if EVENT_START and EVENT_END:
            if PRE_START <= dt < EVENT_START:         return 'pre-event'
            if EVENT_START <= dt <= EVENT_END:        return 'during'
            if EVENT_END < dt <= (POST_END or dt):    return 'post-event'
        elif EVENT_START:
            if PRE_START <= dt <= SAFE_END:           return 'pre-event'
        return 'baseline'

    df['period'] = df['week_start'].apply(assign_period)

    current_yr  = df['yr'].max()
    prior_yr    = current_yr - 1
    baseline_yr = current_yr - 2

    METRICS = [
        ('businesses_open', 'Businesses Open',        'raw count'),
        ('emp_per_loc',     'Employees per Location',  'normalized'),
        ('hrs_per_loc',     'Hours per Location',      'normalized'),
    ]
    metric_cols = [col for col, _, _ in METRICS]

    df_curr_slim  = df[df['yr'] == current_yr][['iso_week', 'week_start', 'period'] + metric_cols].copy()
    df_prior_slim = df[df['yr'] == prior_yr  ][['iso_week'] + metric_cols].copy()

    df_delta = df_curr_slim.merge(df_prior_slim, on='iso_week', suffixes=('_curr', '_prior'))

    # Cast to float — Spark Decimal types survive into merged columns
    for col in metric_cols:
        df_delta[f'{col}_curr']  = pd.to_numeric(df_delta[f'{col}_curr'],  errors='coerce')
        df_delta[f'{col}_prior'] = pd.to_numeric(df_delta[f'{col}_prior'], errors='coerce')

    for col in metric_cols:
        df_delta[f'{col}_yoy_delta'] = df_delta[f'{col}_curr'] - df_delta[f'{col}_prior']
        df_delta[f'{col}_yoy_pct']   = (
            (df_delta[f'{col}_curr'] - df_delta[f'{col}_prior'])
            / df_delta[f'{col}_prior'].replace(0, np.nan).abs()
            * 100
        )

    df_delta = df_delta.sort_values('week_start').reset_index(drop=True)

    if len(df_delta) == 0:
        raise ValueError(
            "No overlapping ISO weeks between current and prior year after merge.\n"
            "   Fix: check both years have data covering the same calendar weeks."
        )

    period_counts = df_delta['period'].value_counts().to_dict()
    print(f"OK Step 4 — period breakdown: {period_counts}")

except ValueError as e:
    print(f"\nFAILED Step 4: {e}")
    print("Share this message with your analyst.")
    raise
except Exception as e:
    print(f"\nFAILED Step 4 — unexpected error:")
    print(f"  {type(e).__name__}: {e}")
    print("Share this full message with your analyst.")
    raise

# =============================================================================
# Step 5: Statistical significance — YoY delta: event window vs baseline
# =============================================================================

print()
print("=" * 70)
print("STEP 5 — Statistical significance")
print("=" * 70)

try:
    P   = CONFIG['p_threshold']
    SIG = lambda p: f'* p={p:.3f}' if p < P else f'ns p={p:.3f}'

    print(f"Comparing {current_yr} vs {prior_yr} YoY deltas: event periods vs baseline")
    print(f"{'Metric':<28} {'Period':<12} {'Weeks':>6} {'Avg YoY delta':>14} {'vs Baseline':>13}  Result")
    print('-' * 85)

    sig_results = {}
    for col, label, _ in METRICS:
        delta_col = f'{col}_yoy_delta'
        baseline_deltas = (df_delta[df_delta['period'] == 'baseline'][delta_col]
                           .dropna().astype(float).values)

        for period in ['pre-event', 'during', 'post-event']:
            period_deltas = (df_delta[df_delta['period'] == period][delta_col]
                             .dropna().astype(float).values)

            if len(period_deltas) < 2:
                continue
            if len(baseline_deltas) < 2:
                print(f"  {label:<26} {period:<12} — not enough baseline weeks for significance test")
                continue

            avg_delta = period_deltas.mean()
            t, p      = stats.ttest_ind(period_deltas, baseline_deltas, equal_var=False)
            diff      = avg_delta - baseline_deltas.mean()
            direction = 'up' if diff > 0 else 'down'

            sig_results[(col, period)] = {'p': p, 'avg_delta': avg_delta, 'diff': diff}

            print(f"  {label:<26} {period:<12} {len(period_deltas):>6} {avg_delta:>+14.2f} "
                  f"{direction} {diff:>+10.2f}  {SIG(p)}")

    print(f"\nOK Step 5 — significance table printed above.")
    print("  * = statistically significant at p < {:.2f}  |  ns = not significant".format(P))
    print("  A significant pre-event result means activity is higher/lower than seasonal baseline alone.")

except Exception as e:
    print(f"\nFAILED Step 5 — unexpected error:")
    print(f"  {type(e).__name__}: {e}")
    print("Share this full message with your analyst.")
    raise

# =============================================================================
# Step 6: Visualisation
# =============================================================================

print()
print("=" * 70)
print("STEP 6 — Charts")
print("=" * 70)

try:
    COLORS = {baseline_yr: '#c8d8e8', prior_yr: '#5a9fd4', current_yr: '#e85d26'}
    PERIOD_COLORS = {
        'baseline':   '#e0e0e0',
        'pre-event':  '#ffe0a0',
        'during':     '#ffb3a0',
        'post-event': '#b3e6c8',
    }

    fig = plt.figure(figsize=(20, 6 * len(METRICS)))
    fig.suptitle(
        f"{CONFIG['event_name']}  |  {CONFIG['city'].title()}, {CONFIG['state']}\n"
        f"Seasonality-Adjusted Event Impact  |  {CONFIG['notes']}\n"
        f"Data through {DATA_END} (last 2 weeks excluded)",
        fontsize=12, fontweight='bold', y=1.01
    )

    for idx, (col, label, note) in enumerate(METRICS):
        gs = gridspec.GridSpec(len(METRICS), 3, figure=fig, hspace=0.5, wspace=0.35)
        ax_line  = fig.add_subplot(gs[idx, 0])
        ax_delta = fig.add_subplot(gs[idx, 1])
        ax_bar   = fig.add_subplot(gs[idx, 2])

        # Panel 1: 3-year weekly line chart
        for yr in [baseline_yr, prior_yr, current_yr]:
            yr_df = df[df['yr'] == yr].sort_values('week_start')
            ax_line.plot(yr_df['week_start'], yr_df[col],
                         color=COLORS[yr], linewidth=1.8, label=str(yr), alpha=0.9)

        if EVENT_START:
            ax_line.axvspan(PRE_START, EVENT_START,
                            alpha=0.12, color='orange', label='Pre-event')
        if EVENT_START and has_during:
            ax_line.axvspan(EVENT_START, EVENT_END or SAFE_END,
                            alpha=0.18, color='red', label='During')
        if has_post and POST_END:
            ax_line.axvspan(EVENT_END, POST_END,
                            alpha=0.12, color='green', label='Post-event')
        if EVENT_START and not has_during:
            ax_line.axvline(EVENT_START, color='red', linestyle='--',
                            linewidth=1.2, label='Event start')

        ax_line.set_title(f'{label}  ({note})\n3-year weekly', fontsize=9)
        ax_line.set_xlabel('Week')
        ax_line.legend(fontsize=7)
        ax_line.grid(axis='y', alpha=0.3)
        ax_line.tick_params(axis='x', rotation=45, labelsize=7)

        # Panel 2: YoY delta bars
        delta_col  = f'{col}_yoy_delta'
        colors_bar = [PERIOD_COLORS.get(p, '#e0e0e0') for p in df_delta['period']]
        ax_delta.bar(df_delta['week_start'], df_delta[delta_col].astype(float),
                     width=5, color=colors_bar, edgecolor='white', linewidth=0.5)
        ax_delta.axhline(0, color='black', linewidth=0.8)
        ax_delta.set_title(f'YoY Delta ({current_yr} - {prior_yr})\nseasonality removed', fontsize=9)
        ax_delta.set_xlabel('Week')
        ax_delta.grid(axis='y', alpha=0.3)
        ax_delta.tick_params(axis='x', rotation=45, labelsize=7)
        legend_patches = [mpatches.Patch(color=v, label=k) for k, v in PERIOD_COLORS.items()]
        ax_delta.legend(handles=legend_patches, fontsize=7)

        # Panel 3: Period comparison bars with significance annotations
        periods_to_show = ['baseline', 'pre-event']
        if has_during: periods_to_show.append('during')
        if has_post:   periods_to_show.append('post-event')

        means = [df_delta[df_delta['period'] == p][delta_col].astype(float).mean()
                 for p in periods_to_show]
        sems  = [df_delta[df_delta['period'] == p][delta_col].astype(float).sem()
                 for p in periods_to_show]
        bar_colors = [PERIOD_COLORS[p] for p in periods_to_show]

        x = np.arange(len(periods_to_show))
        ax_bar.bar(x, means, yerr=sems, capsize=5,
                   color=bar_colors, edgecolor='grey', linewidth=0.7)
        ax_bar.axhline(0, color='black', linewidth=0.8)

        max_mean = max((abs(m) for m in means if not np.isnan(m)), default=1)
        for i, period in enumerate(periods_to_show):
            if period == 'baseline':
                continue
            res = sig_results.get((col, period))
            if res:
                y_pos  = means[i] + (sems[i] if not np.isnan(sems[i]) else 0) + max_mean * 0.05
                marker = f"*\n{res['avg_delta']:+.2f}" if res['p'] < P \
                         else f"ns\n{res['avg_delta']:+.2f}"
                color  = ('darkgreen' if (res['p'] < P and res['avg_delta'] > 0) else
                          'darkred'   if (res['p'] < P and res['avg_delta'] < 0) else 'grey')
                ax_bar.text(x[i], y_pos, marker,
                            ha='center', va='bottom', fontsize=8,
                            color=color, fontweight='bold')

        ax_bar.set_xticks(x)
        ax_bar.set_xticklabels([p.replace('-', '\n') for p in periods_to_show], fontsize=8)
        ax_bar.set_title(f'YoY Delta by Period\n(* = sig p<{P}, ns = not sig)', fontsize=9)
        ax_bar.grid(axis='y', alpha=0.3)

    fname = f"mshr_event_{CONFIG['city'].lower()}_{CONFIG['event_name'].replace(' ', '_')}.png"
    plt.savefig(fname, dpi=150, bbox_inches='tight')
    plt.show()
    print(f"OK Step 6 — chart saved as: {fname}")

except Exception as e:
    print(f"\nFAILED Step 6 — chart generation error:")
    print(f"  {type(e).__name__}: {e}")
    print("The data tables in Steps 3 and 5 are still valid.")
    print("Share this error with your analyst to fix the chart.")
    raise
