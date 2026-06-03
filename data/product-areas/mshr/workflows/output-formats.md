---
owner: vlad-akimenko
last_updated: 2026-05-28
review_cadence: monthly
next_review: 2026-06-28
source: internal
refs:
  - data/product-areas/mshr/report-production.md
  - data/product-areas/mshr/workflows/monthly-report.md
---

# MSHR — Output Formats

Load when producing a report or a Databricks-integrated output to determine the correct delivery format.

---

## Report (written deliverable)

**Always produce a Google Doc — never HTML.**

### Environment-Specific Workflow

1. Build the report as a `.docx` using `python-docx` (installed at `~/anaconda3/lib/python3.11/site-packages`)
2. Base64-encode and upload via `mcp__claude_ai_Google_Drive__create_file` with `contentMimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"` — Drive auto-converts DOCX to Google Doc on open
3. If the file exceeds ~250KB (charts embedded make files large), save to Desktop and instruct the user: **New → File upload → double-click → File → Save as Google Docs**

### Chart extraction from Databricks HTML exports

Databricks notebooks export as HTML files containing a `NOTEBOOK_MODEL` JavaScript variable with base64-encoded content. Charts are embedded inside as `image/png` data. To extract:

```python
import re, base64, urllib.parse, json

with open('notebook_export.html', 'r') as f:
    content = f.read()

m = re.search(r"NOTEBOOK_MODEL\s*=\s*'(.*?)'", content, re.DOTALL)
nb = json.loads(urllib.parse.unquote(base64.b64decode(m.group(1)).decode('utf-8')))

# Charts are in commands[n]['results']['data'] as type=mimeBundle items
for cmd in nb['commands']:
    for item in (cmd.get('results') or {}).get('data', []):
        if item.get('type') == 'mimeBundle' and 'image/png' in item.get('data', {}):
            img_bytes = base64.b64decode(item['data']['image/png'])
            with open('chart.png', 'wb') as f:
                f.write(img_bytes)
```

Step outputs (text, tables) are in `item['type'] == 'ansi'` items in the same `data` list.

---

## Databricks App (live data interface)

When the request is for an interactive dashboard or live data view, produce a **React app** that connects to Databricks via API — not a document.

The GitHub repo connects to Databricks via cloud API. SQL and Python code committed here is picked up by that pipeline and run directly against Databricks — no manual copy-paste required.
