# penny
Simple local-first money budgeting app across the Apple ecosystem.

## Export format

CSV uses stable columns in this order: `id`, `date`, `amount`, `currency`, `type`, `category`, `subcategory`, `description`. Dates use `YYYY-MM-DD`; amounts are exact decimal strings in the currency's minor-unit precision. Text fields use standard CSV quoting and formula-safe prefixes.
