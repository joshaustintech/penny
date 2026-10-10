# Platform compatibility

See the current [platform compatibility report](docs/platform-compatibility.md).

The macOS export UI test target builds, but
`testExportOpensNativeSavePanel` has not executed on this host. On Xcode 27 and
macOS 27.0.1, `xcodebuild` reports that the test runner hangs before connecting
to XCTest. `vmmap` shows it remains launch-suspended. This reproduced with the
default build settings and with ad-hoc and Apple Development signatures; no
export assertion ran. The specific host permission causing startup failure is
unconfirmed.
