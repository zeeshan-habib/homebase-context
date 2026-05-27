<!-- Load when: looking up metric definitions, table schemas, SQL patterns, or suppression rules for any MSHR dimension -->

# MSHR Data Layer

| Folder / File | When to load |
|---|---|
| `product-areas/mshr/` | Any MSHR data work — load `product-areas/mshr/CLAUDE.md` first to pick the right file |
| `product-areas/mshr/mshr.md` | SQL definitions, table schemas, suppression rules, index methodology, example queries |
| `product-areas/mshr/data-model.md` | Key entities, data sources, pipeline architecture, disambiguation |
| `product-areas/mshr/workflows/` | Report production (monthly, ad hoc), data sourcing, benchmark recreation, event impact analysis |

**Critical rule:** This folder (`data/`) is the single source of truth for all metric definitions. Domain files in `domains/` reference metrics but never define them — always resolve metric definitions here, not in domain files.
