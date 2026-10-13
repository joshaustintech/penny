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

## Native navigation: ade8232

Budget, Activity and Reports are separate native pages. iOS/iPadOS use modern
typed tabs with an iOS 17 fallback; Mac uses a native section control. Each iOS
tab owns its navigation stack. Reports retain planned-versus-actual and spending
trends; the duplicated allocation donut was removed. Budget style is one compact
row with a full touch target. The visible month is abbreviated consistently,
with its full date available as an accessibility hint.

The final complete iPhone suite passed: 15 executed, 13 passed, two iPad-specific
tests skipped, zero failures. Actual journeys cover entry/edit/delete, negative
adjustments, mode changes, preserved history/relaunch, settings and accessibility.
CSV/Markdown formats were verified separately by the 33 baseline core tests;
native Mac save-panel interaction remains unverified in this run.

Audit-driven repairs moved the month inset onto each page, corrected the style
button's hit shape, and removed excess financial-header padding. Intermediate
scroll-edge treatments did not fix the issue and were removed. The final full
audit passes without exclusions. Mac Debug build passed; native dark window and
iPhone dark dashboard were inspected. Source increment added/modified 199
production lines, within the 200-line limit.

Watch baseline now has a genuine watchOS 11/42mm capture. It reveals separated
balance/label list rows and an overlapping bottom spending button. This is a
failed companion candidate, not approval. Watch source is unchanged from the
original baseline; its current executable was built by the iOS scheme.

Next work, in priority order:

1. Compose Mac header across the workspace, replace section control with proper
   sidebar navigation, and verify narrow layouts. Add gated initial screenshot
   routes so Mac Activity/Reports can be captured despite automation blockage.
2. Fix Watch balance grouping and move the spending action into scroll content.
3. Add missing category detail navigation with accurate matching transactions.
4. Capture current iPad/second-iPhone/TV states and required light/dark, entry,
   history, settings, overspending and larger-text journeys.
5. Finish the skeptical audit and functional gaps; live iCloud/Siri/HomePod and
   physical Watch receipts remain external verification limitations.

Goal remains active. Pre-existing staged TV assets and untracked `.swiftpm/`
are preserved. No final release or design excellence is claimed.

## Desktop composition: 65c3fc9

Mac has Budget/Activity/Reports sidebar navigation and a larger, text-scaled
remaining amount. Header orientation uses measured content width, not device
class: wide workspace aligns secondary metrics horizontally; narrow Mac and
portrait iPad use a vertical summary. Initial iPad capture exposed wrapped
metric labels, which prompted this correction. The native transaction table
no longer collapses to 120 points; it uses a usable flexible height and aligned
currency amounts. Empty alternating stripes are native table background, not
fabricated transaction rows.

Mac light/dark, 800-point narrow, Activity and Reports windows were captured
from the real active executable using an isolated fixture. Gated initial section
arguments allow capture despite blocked Mac UI automation. These demonstrate
rendering, not successful pointer/keyboard interaction. Mac build passed. Three
iPad tests passed: balance hierarchy, reveal sidebar after setup, and real
Command-N entry opening. Corrected iPad portrait screenshot inspected. iPhone
full accessibility audit and largest-text category scaling passed after the
measured-width header change.

Remaining criticisms: Reports retain dense chart captions; some iPad portrait
category descriptions wrap awkwardly; Mac settings/entry/export interactions
still need current runtime evidence or a documented automation limitation.
No final visual approval yet.

## Watch overlap correction: ee6c426

Balance and its label share one native list row. Add spending now belongs to
scroll content; it no longer overlays the balance or category heading. Smaller
caption2 labels were replaced with footnotes and primary contrast. Decorative
empty-state image is hidden from VoiceOver.

Real 42mm/watchOS 11 dashboard capture inspected. The spending form opens,
scrolls to its send control, and prevents empty submission. Initial test failed
because it assumed the below-viewport send button already existed; adding a
real swipe journey fixed that assumption. Final runtime test passed and its
form screenshot was inspected. The scroll capture intentionally shows the
lower form; amount input was verified before scrolling. Paired save receipt
and hardware remain unverified. New screenshots are in the manifest.

Next: category detail navigation; current iPad landscape/second-phone/TV
coverage; explicit transaction type labels on iPhone; Reports typography;
remaining functional/spec audit and final skeptical visual assessment.

### Activity labels — e856efed636912de3c17318c0489c7ea8e64ec93

Phone history now identifies transaction type even when notes exist. Savings contributions and debt payments use explicit names; income avoids duplicated category text. Real edit/delete journey passed (1 test, 0 failures), `/private/tmp/penny-activity-label-final.xcresult`; iOS and macOS builds passed. Fresh `ios-activity-types-light.png` inspected: correct fixture amounts, no overlap or clipped controls. Remaining criticisms: contribution heading wraps; repeated notes waste space; permanent edit/delete controls compete with amounts. Category detail navigation remains outstanding.

### Category details — 0f98a52d476b9d28c61f7827e9005e2442076c97

Category rows now navigate to remaining balance, used/planned summary, and matching monthly transactions. Balanced Needs includes historical Housing entries, matching reporting semantics. Existing edit/delete actions are available. Real phone test proved correct filtering and balance, opened editing, saved 1000 USD spending, and observed remaining update from 1600 to 1500. Final navigation and setup/settings/dashboard accessibility tests passed (2 tests); additional edit-refresh test passed. Mac build passed. Fresh light screenshot inspected: correct money and unclipped controls. Remaining criticisms: date contrast is weak; transaction actions still compete with money; detail has no month context or category-specific add shortcut. Other platform detail captures and larger-text inspection remain outstanding. Results: `/private/tmp/penny-category-detail-final.xcresult`, `/private/tmp/penny-category-detail-edit.xcresult`.

### TV currency and focus — 2c34f18b8df6ae1fcd26a1f9b63a61c8bac3794e

Real tvOS 27 capture exposed raw minor-unit axes (100000 for 1000 USD), unlabeled actual-only chart, truncated planned amounts, and missing visual focus feedback. Charts now plot major currency units, format monetary axes, and compare used bars with planned squares and legend. Category used/planned amounts occupy separate lines. Focus modifier order corrected; fresh screenshot visibly enlarges focused Wants. Full available TV UI suite passed (3 tests, 0 failures): dashboard amounts, remote focus, storage recovery, settings sync recovery. Result `/private/tmp/penny-tv-focus-final.xcresult`. No live iCloud receipt implied. Screenshots inspected at 3840x2160; visible cards contain complete amounts; Savings is intentionally beyond horizontal viewport and reachable by remote. Remaining criticisms: chart axis/legend text too subdued for distance; month label lacks polish; category carousel still dominates composition. Light appearance and further TV states remain to capture.

### Stable entry presentation and responsive evidence — 75e1cd8cb198110ee4245f5add8c7c8e37435e47

New landscape iPad test exposed editing failure from category detail: hidden dashboard page owned the sheet. One root presenter now owns entry sheets. Corrected iPad category/edit journey passed; second iPhone 17e dashboard and category edit-refresh journeys passed (2 tests). Mac build passed. Full-screen iPad captures avoid the cropped rotated app-window screenshot issue; actual PNG dimensions and landscape orientation recorded. Inspected fresh iPad landscape dashboard/detail and second phone dashboard/detail: correct amounts and reachable controls. Remaining observed defects: category dividers turn vertical inside navigation-link HStacks; compact activity title wraps before category; detail lacks month context. These remain revision work, not approved design. Results: `/private/tmp/penny-ipad-screen-capture.xcresult`, `/private/tmp/penny-second-phone-category.xcresult`.

### Category rules — 8b83a62471c01b8bc0effff0a54cc3435914086a

Native Divider inherited horizontal-stack orientation when category rows became navigation links, drawing vertical lines through amounts. Explicit one-point decorative horizontal rule restores consistent separation. Fresh second-phone screenshot inspected: rules below category summaries, no vertical lines crossing values. Balance hierarchy test passed; iOS and Mac builds passed. Result `/private/tmp/penny-divider-check.xcresult`. Remaining compact activity-title wrapping and other platform state evidence remain outstanding.

### Compact activity — 4ea8a3954fadc510d6b80644bd73d486666f70e2

Compact activity uses a full-width title/note/date followed by amount and controls. Fresh second-phone category screenshot confirms Spending · Needs remains on one line and date contrast is stronger. Category detail names the month. Real category edit-refresh and Activity edit/delete tests passed (2 tests), `/private/tmp/penny-compact-activity.xcresult`; iOS and Mac builds passed. Full accessibility audit was not repeated for this increment. Remaining criticisms: detail summary is vertically loose; repeated row actions remain prominent; reports and remaining platform states still require current evidence.

### Zero-income months — 42b15c127cbbe073609e900626246a0ab00dfda1

Setup and storage rejected explicit zero income. Budget setup now accepts zero; storage accepts zero only for income. General transaction conversion still rejects zero, spending remains positive, adjustments remain nonzero. Core persistence test verifies reload, zero allocations, reconciliation, and rejection of zero spending. All 34 core tests passed. Initial UI test exposed the general money-conversion guard; corrected setup-specific path then passed actual creation/relaunch. Final result `/private/tmp/penny-zero-income-final.xcresult`; core log `/private/tmp/penny-zero-core.log`. iOS, Mac, Watch, and TV builds passed. Fresh screenshot inspected: all amounts zero, no progress division artifact. Remaining design criticism: zero budget has no explanatory income prompt; repeated zero category summaries are verbose; lower rows need scrolling past native tabs. Goal remains active.

### Watch queue verification — 992218623578ea6da6dcb8eb39b19e12255beda7

Full available Watch UI suite passed (2 tests, 0 failures), `/private/tmp/penny-watch-queue-current.xcresult`. Actual form opens, empty send remains disabled, valid 1.23 USD request invokes activated WCSession.transferUserInfo and shows Queued for iPhone. Test flag prefills amount only; queue path is real. This does not prove receiver delivery, persisted iPhone entry, or acknowledgement. Fresh scrolled form screenshot inspected: native toolbar scroll-under behavior, visible Note and disabled send, no overlapping fixed footer. watchOS 11 is available runtime; current watchOS 26/27 unavailable. Existing dashboard remains intermediate.
