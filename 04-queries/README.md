# Query Library

Reusable SQL queries organized by category. Load relevant files when building similar queries.

## Categories

| Folder | Use for |
|---|---|
| `engagement/` | Feature engagement, product usage, activation |
| `revenue/` | MRR, churn, billing, tier distribution |
| `locations/` | Location-level metrics, status, tiers |
| `hr/` | PTO, departments, headcount |
| `operations/` | Internal tooling, operational metrics |

## File Format

Each `.sql` file uses frontmatter comments followed by the query:

```sql
-- title: Short Descriptive Name
-- description: What this query does and when to use it
-- category: engagement | revenue | locations | hr | operations
-- tags: [tag1, tag2, tag3]
-- author: name
-- notes: Caveats, required filters, assumptions

SELECT ...
```

## Adding a Query

Say **"save this query"** at any point in a Claude conversation. Claude will extract the SQL, summarize the context from the conversation, and open a draft PR on this repo for review.
