# Platform compatibility

Minimum targets: iOS/iPadOS 17, macOS 14, watchOS 10, tvOS 17. SwiftData sets these floors; Swift Charts and App Intents are available on all four target families at these versions.

| Capability | Targets | Notes |
| --- | --- | --- |
| SwiftData | All | Local persistence; use CloudKit-compatible optional relationships and no uniqueness constraints. |
| CloudKit sync | iOS, iPadOS, macOS, watchOS, tvOS | Explicit opt-in needs iCloud/CloudKit and Background Modes remote-notification capabilities; Apple Developer account with admin access required. Compatibility and user-controlled container switching remain unverified. |
| Swift Charts | All | Shared chart data, platform-adapted views. |
| App Intents | All | Structured intents; supported Siri exposure varies by OS. |
| App Shortcuts | iOS, iPadOS, watchOS | Not supported on macOS or tvOS; macOS can expose App Intents to Shortcuts. |
| Export | macOS | Use native save panels and UTF-8 files. |

Verified locally with Xcode 27.0 and 27.0 SDKs. iOS 27 simulators are installed; watchOS 27 and tvOS 27 simulator runtimes are unavailable. A valid Apple Development certificate exists, but no Penny app target, provisioning profile, or CloudKit container is configured yet. These environment facts are not device or sync validation.

The iOS and macOS builds extract eight App Intents and eight App Shortcuts each. Every intent requires authentication on the device running it. Metadata extraction is build evidence only; Siri voice execution and the HomePod Personal Requests pathway have not been exercised. Without Watch or Apple TV targets and a configured sync container, those platforms cannot yet show the user's iPhone budget.

Apple references: [SwiftData sync](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices), [App Shortcuts HIG](https://developer.apple.com/design/human-interface-guidelines/app-shortcuts), [App Intents](https://developer.apple.com/documentation/AppIntents).
