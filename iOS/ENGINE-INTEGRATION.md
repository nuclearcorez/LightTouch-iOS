# iOS engine integration notes

## Existing upstream support discovered

The pinned QEMU source already contains an iOS embedding interface:

- `contrib/ios-app/qemu-ios-entry.c` exposes `qemu_ios_main(argc, argv)`. It is designed to run on a background pthread because the UIKit app owns the main thread and run loop.
- `contrib/ios-app/qemu-ios-ui.h` exposes machine metadata, frame callbacks and frame access, normalized touch input, emulated Home/Power/volume buttons, pause/resume, guest shutdown state, and diagnostics.
- `contrib/ios-app/qemu-ios-ui.c` has an Apple/iOS-specific frame publication path.
- The QEMU Meson configuration has an iOS graphics path using OpenGLES, Foundation, IOSurface, and CoreFoundation. It distinguishes iOS SDKs from macOS OpenGL builds.
- The shared LightTouch portable ABI is already separated from the desktop UI in `Portable/include/lighttouch.h`; Rust wrappers live in `crates/lighttouch-core` and raw C bindings in `crates/lighttouch-sys`.

This means a native iOS frontend is a real supported integration direction in the engine source; it is not necessary to emulate the desktop windowing layer.

## Integration architecture

1. Keep UIKit/SwiftUI on the main thread. Run the QEMU entry point on one dedicated background thread for the life of the app process (the engine documents one VM per process).
2. Add an Objective-C/C bridge around the exported QEMU iOS API. The bridge owns the argument vector, engine thread, callback lifetime, and shutdown sequencing.
3. Publish guest frames to a Metal/Core Animation presentation view without blocking the QEMU callback. Map guest touch coordinates into the guest's normalized portrait coordinate system and forward stable touch IDs.
4. Route Home, Sleep/Wake, volume, rotation, and pause/resume through the engine's hardware-input API.
5. Build the portable storage/runtime and firmware-preparation components for iOS separately. Do not try to link the desktop eframe/winit windowing frontend into the iOS app.
6. Keep guest boot disabled until the engine, storage library, frame path, input path, and shutdown confirmation have all been exercised on a physical device.

## iOS-specific blockers to prove

- Cross-build every non-Apple dependency for the iOS device SDK; Homebrew macOS libraries cannot be linked into an iOS binary.
- Decide whether the engine should be a static library or an embedded signed dynamic framework/dylib, and ensure all transitive dependencies are packaged correctly.
- Verify TCG executable-memory behavior under iOS code-signing/JIT policy. Do not assume Android's executable-memory behavior carries over.
- Replace or conditionally compile host-only Rust/C++ dependencies (desktop audio, Unix process supervision, host file descriptors, and OpenSSL networking) where iOS requires a different implementation.
- Test cold boot, guest power-off, interrupted shutdown, storage-dirty recovery, screen lock/background transitions, audio routing, and thermal behavior on actual iPhone hardware.

A successful SwiftUI/IPA build is only a host-app build check. It does not prove any of these engine/runtime requirements.
