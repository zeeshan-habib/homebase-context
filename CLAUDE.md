# Homebase Context Repository

This repo contains business context files for Homebase analytics, not code.
Load files selectively based on the task — do not load everything at once.

## File Index

See README.md for the full file index and "when to load" guidance.

## Folder Structure

- `01-instructions/` — Behavioral rules and environment setup. Load for any analytics request.
- `02-business/` — Business overview and product timeline. Load when domain context is needed.
- `03-data/` — Metric definitions, schema references, and SQL patterns. Load based on the specific data domain.
- `03-data/product-domains/` — Product-area-specific schemas and logic (timetracking, payroll, etc.).

## Rules

- If a question involves a metric, table, or term not covered in these files, say so — do not guess.
- See context-file-style-guide.md for authoring guidelines when adding new files.
