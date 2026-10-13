# Penny continuation audit

Baseline: `5040a8a4930f324fe368d4f24300eeb3d6c2a117`, main synchronized
with origin at inspection. Seven TV asset catalog files were already staged;
they are preserved separately from continuation changes. `.swiftpm/` also
pre-existed untracked.

## Verified baseline

- Core: 33 tests passed, including exact allocations, refunds, rounding,
  persistent edits/deletion, historical mode changes, CSV/Markdown escaping,
  and cloud record encoding/conflict rules.
- iOS simulator Debug build passed with Xcode's installed SDK.
- Source implements manual budgets/entries, historical months, charts,
  local SwiftData, opt-in CloudKit, Watch sharing, App Intents and Mac export.
  Presence in source does not prove live provider/device behavior.
- Four Xcode schemes cover iOS/iPadOS, macOS, watchOS and tvOS.
- Available runtimes: iOS 27, tvOS 27, watchOS 11. Host access resolves
  the sandbox-only CoreSimulator connection failure.
- No existing `design-review` screenshots or capture scripts were found.
- Category detail navigation is absent. Dashboard categories are static cards.
- Live iCloud, Siri voice execution, HomePod and physical Watch transfer
  require separate evidence; existing documentation marks them unverified.

## Rejected baseline visual audit

Fresh iPhone 18 Pro captures use an isolated test store, not personal records.
Dashboard fixture: USD 5,000 income, no expenses. See `manifest.json`.

1. Slogan occupies two large lines before the financial answer; income competes
   with remaining funds. Hierarchy: 2/5.
2. Large navigation-title region is empty. Month controls plus that region
   waste substantial vertical space. Composition: 2/5.
3. Oversized allocation donut pushes every category balance below the first
   viewport. Duplicate chart legend and cards prolong scanning. Charts: 2/5.
4. Repeated rounded cards obscure comparative category structure. Craft: 2/5.
5. Setup income placeholder has weak visual contrast and ambiguous input
   affordance. Controls: 3/5.

Other dimensions and platforms remain unscored until current runtime inspection.
These ratings are internal design heuristics, not certified quality scores.

## Redesign direction

Lead with remaining monthly funds; retain income/spending as secondary context.
Use compact native navigation. Replace category-card repetition with a readable
ledger of remaining amounts and progress, and move detailed charts behind the
everyday financial summary. Keep standard controls and platform behavior.

Apple's [adoption guidance](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
recommends standard navigation/controls, reduced custom navigation backgrounds,
and testing accessibility appearances. No decorative glass layer is needed.

## Completion status

In progress. No platform has final visual approval. Financial tests do not
establish live CloudKit/Siri behavior or design excellence.

## Intermediate increment: 8d7113d

Remaining funds now precede income/spending, category balances precede charts,
and categories have progress bars and ruled rows. Mac has a 1,100 × 800 default
window and a minimum usable window size. An explicitly gated isolated fixture
supplies realistic test data without touching personal records.

iOS hierarchy regression and setup/settings/budget accessibility audit passed
after fixing two low-contrast labels. Native Mac Debug build passed and its
actual window was captured. Unsigned Mac UI runner was killed; a fresh ad-hoc
signed runner started but timed out enabling automation. Developer mode is
disabled on this host. Mac UI automation remains unverified; window capture
does not substitute for that test.

Xcode post-test simulator diagnostics stalled after successful iOS tests.
Stopping only the task-owned diagnostic collector allowed the result to finalize
successfully. Subsequent runs use `-collect-test-diagnostics never` and finalize
normally. A fixture regression initially expected spending to include debt and
savings; it was corrected to USD 1,370 expenses, distinct from USD 700
contributions. Final fixture hierarchy test and accessibility audit passed.

Owner rejected both Mac and iOS design during this increment. It is an
independently verified intermediate change, not design approval. Remaining
problems: single long scrolling surface; sparse Mac composition; excessive
category row height. Next: Budget/Activity/Reports navigation and compact,
adaptive category composition. Screenshots are labeled intermediate in manifest.

## Compact categories: 8126015

Categories now use compact icon/amount/progress rows and an eager two-column
grid on spacious layouts. Five/six finite categories do not need virtualization.
Lazy grid rendering caused Dynamic Type audit failures as rows left the visible
region during scaling; eager rows preserve accessible elements. All three final
iOS tests passed: balance hierarchy and funded-savings status, actual category
height growth at largest accessibility text, and full setup/settings/budget
accessibility audit. No issues were excluded from the audit.

The existing light/dark Penny accent asset is now configured in build settings;
previous builds fell back to system blue. Full savings/debt contributions show
“Plan complete”; contributions exceeding the allocation show “Above planned
contribution” instead of expense-limit language. Mac and TV Debug builds passed.
Native Mac light/dark windows and iPhone light/dark/large-text captures were
inspected and recorded in the manifest. Mac UI automation remains blocked as
described above.

Remaining design criticisms, in priority order:

1. Activity and reports still extend the budget into one long scrolling surface.
2. Mac header metrics cluster at the left while much of the upper workspace is
   unused; the category grid improves the lower composition but not the header.
3. At maximum accessibility text, the persistent full month/year heading takes
   excessive vertical space. Use a shorter visible date while retaining the full
   accessible date, and keep all controls reachable.

No final visual approval. Continue the navigation and platform composition work.
