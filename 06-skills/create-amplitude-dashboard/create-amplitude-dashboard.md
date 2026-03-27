---
name: create-amplitude-dashboard
description: Create an Amplitude dashboard from a Confluence eventing mastersheet
--- 

argument-hint: <confluence-page-url>
allowed-tools:
  - mcp__claude_ai_Atlassian_MCP__getConfluencePage
  - mcp__claude_ai_Atlassian_MCP__searchConfluenceUsingCql
  - mcp__claude_ai_Amplitude__get_context
  - mcp__claude_ai_Amplitude__get_project_context
  - mcp__claude_ai_Amplitude__query_dataset
  - mcp__claude_ai_Amplitude__save_chart_edits
  - mcp__claude_ai_Amplitude__create_dashboard
  - mcp__claude_ai_Amplitude__search
  - mcp__claude_ai_Amplitude__get_event_properties
---

# Create Amplitude Dashboard from Confluence Eventing Spec

You are helping a PM create an Amplitude dashboard from a Confluence eventing mastersheet. The Confluence page URL is: $ARGUMENTS

Follow these steps in order. Do NOT skip ahead — complete each step before moving to the next.

---

## Step 1: Fetch & Parse the Confluence Eventing Spec

1. Extract the Confluence page ID from the URL. It is typically the last numeric segment or found in `/pages/{id}/`.
2. Call `getConfluencePage` with that page ID to fetch the full page content.
3. Parse the HTML tables in the response to extract these columns (names may vary slightly):
   - **Screen** (or Page/View)
   - **Event Name** (e.g., `Page Viewed`, `Button Clicked`, `Toggle Clicked`)
   - **Common Properties** (properties shared across events)
   - **Specific Event Properties** (properties unique to this event, e.g., `button_text`, `selection`, `dropdown_selection`)
4. Group events by screen/flow.
5. Present a summary to the PM:
   ```
   Found X events across Y screens:
   - Screen A: [list of event names]
   - Screen B: [list of event names]
   ...
   ```
   Also note any key properties you found (e.g., `product_area`, `button_text`, `selection`).

If the page has multiple tables, parse all of them — some specs split events by feature area.

---

## Step 2: Select the Amplitude Project

1. Call `get_context` to list the PM's available Amplitude projects.
2. Ask the PM which project to target (e.g., "Web Production 340652" or "Mobile Production 341024").
3. Store the selected `projectId` (appId) for all subsequent Amplitude calls.

---

## Step 3: Choose a Dashboard Tier

Ask the PM which dashboard tier they want:

**Basic** — Core funnel + top-level adoption (3 charts):
- 1 funnel chart (key conversion flow, e.g., Page Viewed -> primary action)
- 1 segmented event chart (primary action broken down by a key dimension like `product_area`)
- 1 line chart (daily unique users hitting the entry Page Viewed event)

**Full Suite** — Comprehensive per-screen tracking (Basic charts plus):
- 1 funnel per screen group (e.g., Settings funnel, Scheduler funnel, Team Roster funnel)
- Breakdown charts for key interactions (toggles, dropdowns, filters grouped by selection values)
- Warning/error tracking charts (compliance warnings, violation summaries)

**Custom** — PM picks which events/funnels to include from a proposed list you generate.

---

## Step 4: Propose Charts for Confirmation

Based on the selected tier and the parsed events, generate a numbered chart proposal. Use this mapping to decide chart types:

| Spec Pattern | Chart Type | Config |
|---|---|---|
| Multiple sequential Page Viewed / Button Clicked events | **Funnel** | Steps in order of user flow |
| Toggle Clicked / Dropdown Clicked | **Stacked Bar** | Group by `selection` or `dropdown_selection` |
| Single Page Viewed event | **Line** | Uniques over time |
| Compliance Warning / Error events | **Bar** | Count over time, segment by violation/warning type |
| Button Clicked with Approve/Decline actions | **Stacked Bar** | Group by `button_text` |

Present the proposal like this:

```
Proposed Charts:

Chart 1: [Funnel] Settings → Team Roster Adoption Flow
  Steps: Page Viewed (child_labor_settings) → Toggle Clicked → Link Clicked (team_roster)

Chart 2: [Line] Daily Active Users — Child Labor Settings
  Event: Page Viewed where product_area = child_labor

Chart 3: [Stacked Bar] Toggle Interactions by Selection
  Event: Toggle Clicked, grouped by selection

...
```

Ask the PM to **confirm**, **remove**, or **add/modify** charts before proceeding. Iterate until the PM approves.

---

## Step 5: Create Charts in Amplitude

For each confirmed chart, create it in Amplitude using this two-step process:

1. **Define the chart**: Call `query_dataset` with the chart definition:
   - Set the appropriate event(s), filters, group-bys
   - Use date range: **Last 30 Days**
   - Use the correct chart type (funnel, line, stacked bar, bar)
   - This returns an `editId`

2. **Save the chart**: Call `save_chart_edits` with:
   - The `editId` from step 1
   - A descriptive `title` for the chart
   - This returns a permanent `chartId`

3. Collect all `chartId` values as you go. Report progress to the PM (e.g., "Created chart 3/7: Daily Active Users").

If a chart creation fails, report the error and continue with the remaining charts. At the end, note any charts that failed so the PM can create them manually.

---

## Step 6: Assemble the Dashboard

Once all charts are created, assemble them into a dashboard:

1. Call `create_dashboard` with:
   - **title**: "[Feature Name] — Eventing Dashboard"
   - **description**: "Auto-generated from Confluence spec: [page title]. Created [today's date].  Eventing doc: [confluence-page-url]"
   - **items**: Array of chart references laid out using these rules:

### Layout Rules
- Total width per row = **12 columns**
- Max **4 items per row**
- Heights: **375** (compact metrics), **500** (standard funnels), **625** (detailed/tall charts)

### Layout Strategy
- **Row 1**: Overview/main funnel — width 12, height 500
- **Row 2**: 2-3 metric/line charts side by side — width 4 or 6 each, height 375
- **Row 3+**: Screen-specific funnels or breakdown charts — width 6, height 375

Each item in the `items` array should reference a `chartId` and specify `x`, `y`, `width`, `height` for positioning.

2. After creation, present the dashboard URL to the PM:
   ```
   Dashboard created successfully!
   Title: [Feature Name] — Eventing Dashboard
   Charts: X charts across Y rows
   URL: [dashboard URL]
   ```

---

## Error Handling

- If the Confluence page cannot be fetched, ask the PM to verify the URL and their permissions.
- If no events are found in the tables, show the raw page content summary and ask the PM to point out where the events are.
- If an Amplitude chart fails to create, log the error, skip it, and continue. Summarize failures at the end.
- If `get_context` returns no projects, ask the PM to verify their Amplitude access.
