# Platform compatibility

Current deployment floors: iOS/iPadOS 17, macOS 14, watchOS 10, and tvOS 17.

| Capability | iOS/iPadOS | macOS | watchOS | tvOS | Penny status |
| --- | --- | --- | --- | --- | --- |
| SwiftData | 17+ | 14+ | 10+ | 17+ | Local models compile on all four targets; each platform keeps its local store. |
| Swift Charts | 16+ | 13+ | 9+ | 16+ | tvOS category and history charts render with seeded data in the tvOS 27 simulator. |
| CloudKit private database | Supported | Supported | Supported | Supported | Opt-in CKSyncEngine private-database sync is implemented on iOS, macOS, and tvOS. Entitlements are present; container registration, signed builds, and live account/multi-device behavior remain unverified. |
| App Intents | 16+ | 13+ | 9+ | 16+ | Penny intents build on iOS, iPadOS, macOS, and watchOS. |
| App Shortcuts | Supported | Not supported | Supported | Not supported | Penny shortcuts build on iOS, iPadOS, and watchOS; macOS App Intents remain available to custom Shortcuts. Voice execution is unverified. |
| WatchConnectivity | iOS side | — | watch side | Not available | Snapshot display and Watch request queueing passed on paired simulators; save receipt and hardware remain unverified. |
| Native file export | — | Markdown and CSV | — | — | Penny uses the macOS file exporter. |

CloudKit is opt-in per device. Penny keeps its local SwiftData store and syncs
versioned records to the user's private database with timestamp conflict rules
and deletion tombstones. Turning sync off stops this device and leaves existing
cloud copies intact. A valid signed build and registered iCloud container are
required; provider setup is unverified, and no local provisioning profiles were
found. An automatic-signing build also failed because Xcode rejected the
configured developer-account credentials, so live sync has not been verified.
A tvOS 27 simulator UI test verifies
the seeded $2,930 remaining total, both charts, and remote focus movement. On a
paired iPhone 16 Pro (iOS 18.4) and Apple Watch Series 10 (watchOS 11)
simulator, Penny delivered and rendered the shared $1,000 budget and categories.
Physical-device transfer and Watch-to-iPhone spending receipts remain unverified.
The watchOS UI test also verifies the shared balance and request queueing; the
paired simulator did not return a saved receipt.

Watch Siri shortcuts read only the explicitly shared budget snapshot and require
local device authentication. Watch intent code builds, but Siri invocation and
paired-device snapshot transfer have not been exercised on hardware. HomePod
Personal Requests remain unverified; supported behavior depends on the user's
Personal Requests settings and the associated iPhone or iPad.

Apple documents App Shortcuts as available on iOS, iPadOS, and watchOS, but not
macOS or tvOS. The HomePod pathway is the user's Shortcuts collection with
Personal Requests enabled; Penny's authenticated HomePod behavior remains
unverified. Apple says locked-device shortcuts that open an app ask the user to
unlock that device.

The built metadata contains eight App Intents and eight App Shortcuts for iOS,
eight App Intents and no App Shortcuts for macOS, and four App Intents and four
App Shortcuts for watchOS. This verifies build metadata, not Siri execution.

See [Siri support](siri-support.md) for registered phrases and platform limits.

## Apple references

- [SwiftData model configuration](https://developer.apple.com/documentation/swiftdata/modelconfiguration)
- [Swift Charts](https://developer.apple.com/documentation/charts)
- [CloudKit private database](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase)
- [SwiftData sync requirements](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [App Shortcuts platform support](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts)
- [Run shortcuts with Siri](https://support.apple.com/guide/shortcuts/run-shortcuts-with-siri/apd07c25bb38/ios)
- [Set up HomePod Personal Requests](https://support.apple.com/en-gb/108397)
- [WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity)
