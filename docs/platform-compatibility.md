# Platform compatibility

Current deployment floors: iOS/iPadOS 17, macOS 14, watchOS 10. SwiftData's
current SDK availability sets tvOS 17 as the matching floor for the planned TV
app.

| Capability | iOS/iPadOS | macOS | watchOS | tvOS | Penny status |
| --- | --- | --- | --- | --- | --- |
| SwiftData | 17+ | 14+ | 10+ | 17+ | Local models compile on all four targets; each platform keeps its local store. |
| Swift Charts | 16+ | 13+ | 9+ | 16+ | The TV category and history charts compile; rendered layout is pending runtime validation. |
| CloudKit private database | Supported | Supported | Supported | Supported | Opt-in CKSyncEngine private-database sync is implemented on iOS, macOS, and tvOS. Entitlements are present; container registration, signed builds, and live account/multi-device behavior remain unverified. |
| App Intents | 16+ | 13+ | 9+ | 16+ | Penny intent currently builds only for iOS and macOS. |
| App Shortcuts | Supported | Supported | Supported | Not supported | Keep shortcuts off tvOS; do not promise direct Penny Siri requests on Apple TV. |
| WatchConnectivity | iOS side | — | watch side | Not available | Snapshot and entry protocols compile; paired-device transfer still needs hardware proof. |
| Native file export | — | Markdown and CSV | — | — | Penny uses the macOS file exporter. |

CloudKit is opt-in per device. Penny keeps its local SwiftData store and syncs
versioned records to the user's private database with timestamp conflict rules
and deletion tombstones. Turning sync off stops this device and leaves existing
cloud copies intact. A valid signed build and registered iCloud container are
required; provider setup is unverified, and no local provisioning profiles were
found, so live sync has not been verified. A tvOS 27 simulator launch and
no-budget empty state are verified. Seeded dashboard data and remote focus
navigation still need runtime validation.

## Apple references

- [SwiftData model configuration](https://developer.apple.com/documentation/swiftdata/modelconfiguration)
- [Swift Charts](https://developer.apple.com/documentation/charts)
- [CloudKit private database](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase)
- [SwiftData sync requirements](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [App Shortcuts platform support](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts)
- [WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity)
