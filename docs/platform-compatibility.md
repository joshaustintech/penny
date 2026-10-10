# Platform compatibility

Current deployment floors: iOS/iPadOS 17, macOS 14, watchOS 10. SwiftData's
current SDK availability sets tvOS 17 as the matching floor for the planned TV
app.

| Capability | iOS/iPadOS | macOS | watchOS | tvOS | Penny status |
| --- | --- | --- | --- | --- | --- |
| SwiftData | 17+ | 14+ | 10+ | 17+ | Local models compile on all four targets; TV currently uses local storage only. |
| Swift Charts | 16+ | 13+ | 9+ | 16+ | The TV category and history charts compile; rendered layout is pending runtime validation. |
| CloudKit private database | Supported | Supported | Supported | Supported | Requires the CloudKit capability and an iCloud account. Not configured or used. |
| App Intents | 16+ | 13+ | 9+ | 16+ | Penny intent currently builds only for iOS and macOS. |
| App Shortcuts | Supported | Supported | Supported | Not supported | Keep shortcuts off tvOS; do not promise direct Penny Siri requests on Apple TV. |
| WatchConnectivity | iOS side | — | watch side | Not available | Snapshot and entry protocols compile; paired-device transfer still needs hardware proof. |
| Native file export | — | Markdown and CSV | — | — | Penny uses the macOS file exporter. |

CloudKit stays off until a safe local-to-private migration, conflict policy,
disable path, and status/recovery UI are implemented. A tvOS 27 simulator is
installed here; its native launch and no-budget empty state are verified. A
seeded dashboard and remote focus navigation still need runtime validation.

## Apple references

- [SwiftData model configuration](https://developer.apple.com/documentation/swiftdata/modelconfiguration)
- [Swift Charts](https://developer.apple.com/documentation/charts)
- [CloudKit private database](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase)
- [App Shortcuts platform support](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts)
- [WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity)
