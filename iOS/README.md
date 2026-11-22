# LightTouch for iOS

This directory contains the native SwiftUI host app and the GitHub Actions IPA packaging workflow.

## Current status

The first milestone is the native app shell and repeatable iOS device-build pipeline. The app currently provides the Library, Prepare, and Settings UI, but it does **not** yet boot a guest. The QEMU engine, frame/input bridge, audio, and firmware preparation pipeline still need to be cross-built for iOS and connected to these screens.

Do not describe this initial IPA as a working emulator. It is an unsigned UI-development build.

## Build

GitHub Actions workflow: **iOS IPA** (`.github/workflows/ios-ipa.yml`).

The workflow uses a macOS Xcode runner, generates an Xcode project with XcodeGen, builds for generic iOS devices, and packages an unsigned IPA artifact. The artifact must be signed with a valid provisioning profile before normal installation on a physical iPhone.

## Deployment target

The project keeps an iOS 17.0 minimum deployment target for broad device compatibility and builds with the current iOS SDK on the runner. This is suitable for the requested iOS 27 host device without making the app needlessly unavailable to earlier iOS releases.

## Next integration milestones

1. Build the QEMU iOS embedding target (`contrib/ios-app`) for arm64 iOS and package its engine library.
2. Build the portable C++ runtime and Rust firmware/core crates for `aarch64-apple-ios`, resolving iOS-specific dependencies and filesystem/socket constraints.
3. Add a Swift/Objective-C bridge for engine lifecycle, display frames, multitouch, hardware buttons, audio, and shutdown confirmation.
4. Connect firmware download/import/preparation, persistent per-device storage, and the guest library to the Prepare and Library screens.
5. Add signed IPA export when signing credentials are configured; keep unsigned CI builds available for development.

The emulator uses QEMU TCG; it does not depend on hardware virtualization. iOS JIT policy and executable-memory restrictions must be evaluated against the exact engine build rather than assumed to work like Android.
