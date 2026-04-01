---
name: amplitude-eventing
description: >
  Creates a Confluence page with Amplitude event tracking requirements for a new feature.
  Use this skill whenever a user wants to document Amplitude events, create an eventing spec,
  write event tracking requirements, or produce an analytics instrumentation plan for a feature.
  Trigger when the user provides a Jira epic link and/or Figma design link and asks to create
  event requirements, an eventing doc, or an analytics spec. Also trigger when users say things
  like "write up the events for this feature", "create the eventing Confluence page", "document
  the Amplitude events", or "make an eventing spec".
compatibility: "Requires Atlassian MCP (getConfluencePage, createConfluencePage, editJiraIssue), Figma MCP (get_design_context), and Figma REST API access for screenshot export"
---

# Amplitude Eventing Skill

Creates a Confluence page with Amplitude event tracking requirements for a new feature, following Homebase's eventing standards.

## Hardcoded Resources

- **Events Charter (Google Doc)**: https://docs.google.com/document/d/1yU151NEOxFJ4aA8Rys4QZfPwRK26zoxKIf-Jicnzon8/edit?tab=t.p794is70chy — consolidated naming conventions, approved event names, required properties, and audit standards. Use the "Building an LLM Friendly Charter" tab.
- **Output Confluence Space**: `BizOps` space, parent folder ID `4233756705`
- **Cloud ID**: `joinhomebase.atlassian.net`
- **Example page** (use as format reference): page ID `4817780866`

## Eventing Philosophy

Comprehensive coverage is the baseline. But comprehensive alone isn't enough. A spec that doesn't help us understand meaningful user behavior - or can't answer "is this feature or flow working?" - is missing the point.

**After generating the full event list, pressure-test it against these questions:**
1. **Is the success outcome captured?** What's the thing this feature/flow is trying to drive - and is there an event (or sequence of events) that tells us it happened?
2. **Are failure states visible?** If a critical action fails, would we know? Or does the spec only capture the happy path?
3. **Can we build funnels?** Are the entry points, decision points, and exit points all instrumented so analysts can see where users drop off or diverge?
4. **Can we answer the PM's question?** If someone asks "is this feature/flow working?" in a month, do these events give us enough signal?

If the answer to any of these is no, add what's missing. This is about layering outcome-awareness on top of thorough UI coverage - not replacing it.

## Inputs Required from User

1. **Jira epic URL** (e.g. `https://joinhomebase.atlassian.net/browse/PAY-XXXXX`)
2. **Figma design URL** (e.g. `https://www.figma.com/design/...`)

If either is missing, ask the user to provide them before proceeding.

---

## Step-by-Step Workflow

### Step 1: Read the Example Page for Format Reference

Fetch the example Confluence page (ID: `4817780866`) using `getConfluencePage` to understand the exact output format. Pay attention to:
- How the page opens (epic link + Figma link at the top)
- The note/callout block pattern for any critical business event warnings
- Table column structure: **Screen | Common Properties | Event Name | Event Specific Properties | QA / Notes**
- How sections are divided by platform/surface (e.g. "EE Mobile — In-App Flow", "EE iOS Live Activity", "EE Android Notifications")
- Use of `---` horizontal rules between sections

### Step 2: Fetch the Events Charter

Fetch the Events Charter Google Doc (see Hardcoded Resources) to load event naming conventions and property standards. Key things to extract:
- Approved event names per platform (web vs. mobile)
- Standard property naming conventions (snake_case)
- Which properties are required on all events vs. event-specific
- How `product_area` and `event_category` should be set
- Critical business events that should stay granular (not consolidated)

### Step 3: Fetch the Jira Epic

Use `getJiraIssue` with the issue key from the URL (e.g. `PAY-17939`). Extract:
- Feature name / epic title → becomes the page title
- Description / acceptance criteria → understand what the feature does
- Any linked pages, designs, or sub-tasks that clarify scope
- Platforms mentioned (web, iOS, Android, or all)

### Step 4: Fetch the Figma Design and Export Screenshots

**4a. Get design context via Figma MCP**

Use the Figma MCP `get_design_context` (or `get_metadata`) tool with the Figma URL. Extract:
- All distinct screens, modals, overlays, and notifications visible in the design
- Interactive elements: buttons, links, toggles, form inputs, CTAs
- Screen names or frame names (these map to the "Screen" column in the table)
- The **node IDs** for each top-level screen/frame (you'll need these for image export)
- Any platform-specific frames (iOS vs Android vs Web)

If Figma MCP is unavailable, ask the user to describe the key screens and interactions, and skip 4b.

**4b. Export screen screenshots via Figma REST API**

Extract the `FILE_KEY` from the Figma URL (the segment between `/design/` and the next `/`, e.g. `https://www.figma.com/design/FILE_KEY/...`).

For each screen/frame identified in 4a, call the Figma Images API:
```
GET https://api.figma.com/v1/images/{FILE_KEY}?ids={NODE_IDS}&format=png&scale=1.5
```
- `NODE_IDS`: comma-separated node IDs (use `:` instead of `-` in node IDs as required by the API)
- The response returns a JSON map of `node_id → CDN URL` (temporary S3 URL, valid ~14 days)

Download each image to `/tmp/figma-screens/` for visual inspection (to verify you have the right screen for each event section). Build a mapping of `screen_name → CDN URL` to use in the Confluence table.

### Step 5: Generate the Event Requirements

Using all gathered context, reason through which Amplitude events to fire:

**For each screen/surface identified in Figma:**
1. Does it represent a new view the user sees? → `Screen Viewed` (mobile) or `Page Viewed` (web)
2. Are there buttons/CTAs? → `Button Clicked` for each meaningful button, `Link Clicked` for each meaningful link
3. Are there modals or dialogs? → `Modal Viewed` when shown, `Button Clicked` for modal actions
4. Are there push notifications or live activities? → `Push Notification Clicked`
5. Are there forms? → Use the appropriate approved event for the submit action (e.g. `Button Clicked` on the submit button)

**For each event, determine:**
- **Screen**: The UI surface where it occurs (match Figma frame names)
- **Common Properties**: Shared across all events in this section (e.g. `product_area`, `event_category`, `shift_id`)
- **Event Name**: Standard name from charter (always use existing standards, never invent new event names)
- **Event Specific Properties**: Properties unique to this event instance (snake_case, descriptive values)
- **QA / Notes**: Trigger condition, edge cases, or implementation notes

**Property naming rules (from charter):**
- All property keys: `snake_case`
- Enum values: `snake_case` strings (e.g. `break_status: active`)
- Numeric values: typed as `<int>` or `<float>` in the spec
- Boolean values: `true` / `false`
- Always include `product_area` and `event_category` as common properties per section

**Critical Business Events:**
- If any events represent critical business actions (e.g. transactions, key lifecycle moments), add a callout note (blockquote) at the top flagging them as candidates for server-side events, advising alignment with Analytics.

**Pressure-test the event list:** After completing the list above, apply the questions from the Eventing Philosophy section. Check that the success outcome is captured, failure states are visible, funnels can be built, and the spec can answer "is this feature or flow working?" Fill any gaps before proceeding.

### Step 6: Organize by Platform / Surface

Group events into logical sections mirroring the example page:
- **Web** surfaces if applicable (separate H3 sections per page/flow)
- **EE Mobile — In-App Flow** for core mobile screens
- **EE iOS Live Activity** if iOS-specific UI exists
- **EE Android Notifications** if Android-specific UI exists
- **Manager / EM flows** if the feature has manager-facing surfaces

Use `---` horizontal rules between sections.

### Step 7: Create the Confluence Page (ADF format with screenshots)

Because Confluence's standard markdown does not support images inside table cells, the page **must** be created using Atlassian Document Format (ADF) — a JSON-based rich content format. Use `createConfluencePage` with `contentFormat: adf`.

**ADF page structure:**

The `body` field must be a valid ADF JSON document (a `doc` node with `content` array). Build it as follows:

1. **Header block**: Two paragraphs — epic link and Figma link (as inline text with marks).
2. **Intro paragraph**: "Below table shows the full Amplitude details we will be triggering from HB for this feature."
3. **Critical business events callout** (if applicable): A `blockquote` node.
4. **For each platform section**:
   - A `rule` node (horizontal divider)
   - A `heading` node (level 3) with the section name
   - A `table` node (see schema below)

**Table schema — each row uses this pattern:**

The first column of the *first row* in each group of events for a given screen must contain an ADF `mediaSingle` node embedding the Figma screenshot. Subsequent rows for the same screen leave that cell empty (or use a text cell with the screen name only).

```json
{
  "type": "tableRow",
  "content": [
    {
      "type": "tableCell",
      "attrs": {},
      "content": [
        {
          "type": "mediaSingle",
          "attrs": { "layout": "center", "width": 220 },
          "content": [
            {
              "type": "media",
              "attrs": {
                "type": "external",
                "url": "<FIGMA_CDN_URL_FOR_THIS_SCREEN>"
              }
            }
          ]
        },
        {
          "type": "paragraph",
          "content": [
            { "type": "text", "text": "<Screen Name>" }
          ]
        }
      ]
    },
    {
      "type": "tableCell",
      "attrs": {},
      "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "<Common Properties>" }] }]
    },
    {
      "type": "tableCell",
      "attrs": {},
      "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "<Event Name>" }] }]
    },
    {
      "type": "tableCell",
      "attrs": {},
      "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "<Event Specific Properties>" }] }]
    },
    {
      "type": "tableCell",
      "attrs": {},
      "content": [{ "type": "paragraph", "content": [{ "type": "text", "text": "<QA / Notes>" }] }]
    }
  ]
}
```

- Use `"type": "external"` for the media node — this tells Confluence to fetch the image directly from the CDN URL without uploading it to Confluence's media server.
- The table must include a header row with column labels: **Screen | Common Properties | Event Name | Event Specific Properties | QA / Notes**. Use `tableHeader` nodes (instead of `tableCell`) for the header row.
- If screenshot CDN URL is unavailable for a screen, fall back to a plain text cell with the screen name.

**`createConfluencePage` call parameters:**
- `cloudId`: `joinhomebase.atlassian.net`
- `spaceId`: `1808367648` (BizOps space)
- `parentId`: `4233756705` (Analytics Eventing folder)
- `title`: `<Feature Name> Eventing`
- `contentFormat`: `adf`
- `body`: the full ADF JSON document as a string

### Step 8: Add Confluence Link to Jira Ticket Description

After the Confluence page is successfully created, append a link to the new Confluence page at the bottom of the Jira ticket's description so engineers can easily find the event requirements.

Use `editJiraIssue` with:
- `cloudId`: `joinhomebase.atlassian.net`
- `issueIdOrKey`: the Jira issue key (e.g. `PAY-17939`)
- `fields`: update the `description` field by taking the existing description ADF body (fetched in Step 3) and appending a new paragraph at the end of its `content` array:

```json
{
  "type": "paragraph",
  "content": [
    {
      "type": "text",
      "text": "📊 Amplitude Eventing Spec: "
    },
    {
      "type": "text",
      "text": "<Page Title> Eventing",
      "marks": [
        {
          "type": "link",
          "attrs": {
            "href": "<CONFLUENCE_PAGE_URL>"
          }
        }
      ]
    }
  ]
}
```

Replace `<Page Title>` with the feature name and `<CONFLUENCE_PAGE_URL>` with the URL returned from `createConfluencePage`.

**Important**: Preserve the full existing description content — only append to it, never replace it.

### Step 9: Confirm with User

After creating the page and posting the Jira comment, share the Confluence page URL with the user and confirm the Jira ticket has been updated. Then ask:
- Does the event coverage look complete?
- Are there any screens or interactions from the Figma that were missed?
- Any events that should be flagged as server-side candidates?

---

## Quality Checklist

Before creating the page, verify:
- [ ] Page title follows pattern: `<Feature Name> Eventing`
- [ ] Epic link and Figma link appear at the top
- [ ] All event names follow charter conventions (no invented names)
- [ ] All property keys are `snake_case`
- [ ] Each meaningful button/CTA has a `Button Clicked` or `Link Clicked` event
- [ ] Each new screen has a `Screen Viewed` or `Page Viewed` event
- [ ] Common properties are factored out per section (not repeated per row)
- [ ] Critical business events are flagged in a callout note
- [ ] Sections are separated by horizontal rules
- [ ] Page is created with `contentFormat: adf` (not markdown)
- [ ] First column of each screen group contains a `mediaSingle` ADF node with the Figma screenshot CDN URL
- [ ] Fallback to plain screen name text if screenshot URL is unavailable
- [ ] Confluence page URL has been appended to the bottom of the Jira ticket description
- [ ] Success outcome for the feature/flow is captured by at least one event or event sequence
- [ ] Failure states for critical actions are instrumented (not just the happy path)
- [ ] Entry points, decision points, and exit points are covered for funnel analysis

---

## Notes & Edge Cases

- **Web-only features**: Skip mobile sections entirely; use `Page Viewed` instead of `Screen Viewed`
- **Mobile-only features**: Skip web sections
- **If Figma URL has a specific node-id**: Pass it directly to Figma MCP for focused context
- **Rows with no Amplitude event**: Include them in the table with "Display only — no Amplitude event" in the Event Name column (see example: Android Status Bar Chip)
- **Figma node IDs in API calls**: The Figma Images API requires node IDs with `-` replaced by `:` (e.g. `123:456`, not `123-456`). The MCP `get_design_context` response typically returns IDs in the `123:456` format already.
- **Screenshot CDN URL expiry**: Figma CDN URLs expire after ~14 days. The Confluence page will show broken images after expiry, but this is acceptable for a spec document used near the time of feature development.
- **Multiple screens per section**: Only the first row for each distinct screen needs the `mediaSingle` image node. Additional event rows for the same screen can use a plain text cell (or empty cell) in the Screen column to keep the table readable.
- **ADF construction**: Build the ADF document in Python or as a Python dict/JSON string before passing to `createConfluencePage`. Do not attempt to inline a markdown table — it will not render images in cells.
