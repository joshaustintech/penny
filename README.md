# Penny

Native, local-first budgeting for iOS/iPadOS, macOS, watchOS, and tvOS.
Optional private iCloud sync is implemented for iOS/iPadOS, macOS, and tvOS; it
needs a registered CloudKit container and signed provisioning before live sync
can be verified. Watch shares a user-enabled budget snapshot through the paired
iPhone.

Siri budget shortcuts are implemented on iOS/iPadOS and watchOS. macOS exposes
Penny App Intents for custom shortcuts, but does not support App Shortcuts.
Voice execution, paired Watch transfer, and HomePod Personal Requests have not
been verified on hardware. Apple TV does not support App Shortcuts.

See [platform compatibility](docs/platform-compatibility.md) for build evidence
and known limits.

## Export format

CSV uses stable columns in this order: `id`, `date`, `amount`, `currency`, `type`, `category`, `subcategory`, `description`. Dates use `YYYY-MM-DD`; amounts are exact decimal strings in the currency's minor-unit precision. Text fields use standard CSV quoting and formula-safe prefixes.
