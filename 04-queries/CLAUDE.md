# Query Library

Reusable SQL queries. Scan `INDEX.md` first to find relevant queries, then load the matching `.sql` files as reference when building similar queries.

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
