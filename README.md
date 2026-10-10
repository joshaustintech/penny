# penny
Native local-first budgeting app for iPhone, iPad, and Mac.
Watch, Apple TV, and iCloud sync are not configured yet.

## Export format

CSV uses stable columns in this order: `id`, `date`, `amount`, `currency`, `type`, `category`, `subcategory`, `description`. Dates use `YYYY-MM-DD`; amounts are exact decimal strings in the currency's minor-unit precision. Text fields use standard CSV quoting and formula-safe prefixes.
