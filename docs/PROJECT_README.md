# slint-android-app

A [Slint](https://slint.dev) UI compiled to an Android APK. All application
logic is in Rust; there is no Kotlin or Java in the tree by default — the only
thing in `classes.dex` is the bundled `NativeActivity` that Slint needs.

## Layout

```
slint-android-app/
├── Cargo.toml          # Workspace + shared dependencies + default-members
├── rust-toolchain.toml # Pins stable + the Android targets
├── core/               # Pure-logic crate (rlib). No Slint, no Android.
│   └── src/lib.rs
└── app/                # UI + Android entry point (cdylib).
    ├── build.rs        # Invokes slint-build on ui/main.slint
    ├── ui/main.slint   # Declarative UI
    ├── android-res/    # Android resources
    ├── android-assets/ # Android assets
    └── src/lib.rs      # android_main entry point
```

The split is deliberate: `core/` builds and tests on the host with plain
`cargo test`, so most logic can be developed without an emulator. `app/` is the
only crate that pulls in Slint and Android. The core crate is aliased to
`app_core` in `[workspace.dependencies]`, so Rust sources never carry the
project name in their imports — rename the project and no `use` statement
changes.

## One-time setup

Fastest path is the provided dev container — it ships Rust, cargo-apk2, JDK 17,
Kotlin, Android SDK 34 and NDK r27 pinned. See
[`.devcontainer/Dockerfile`](.devcontainer/Dockerfile). Manually instead:

```sh
rustup target add aarch64-linux-android x86_64-linux-android
cargo install cargo-apk2 --locked
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_NDK_ROOT="$ANDROID_HOME/ndk/<version>"
```

`cargo-apk2` is the maintained fork of `cargo-apk`; it adds Kotlin/Java source
compilation and declarative activity/service blocks. It needs a JDK on `PATH`.
`KOTLIN_HOME` is only required once a dependency actually ships Kotlin source —
a pure-Rust app builds without it.

## Build & run

```sh
just                 # list recipes
just build           # debug APK (aarch64 + x86_64)
just release         # release APK
just setup-emulator  # create the "slint" AVD (once, ~700MB image)
just run             # build, install, launch
just ci              # fmt-check + clippy + test, same as CI
```

The APK is multi-arch, so one artifact installs on both a real device
(aarch64) and the default emulator image (x86_64 on Intel/AMD hosts).

`just run` needs no `-p` or `--target` because the workspace sets
`default-members = ["app"]`.

## CI

- **`.github/workflows/ci.yml`** — fmt, clippy and tests on the host. No NDK, so
  it is fast and runs on every push. It lints `core` only: `app` is an
  Android-only cdylib whose entry point does not compile for the host.
- **`.github/workflows/android.yml`** — installs the NDK and cargo-apk2, lints
  `app` against the real Android target, and builds the APK. On a `v*` tag it
  attaches the APK to a GitHub Release; on ordinary pushes it uploads a
  7-day artifact.

Release assets are used rather than artifacts for tags on purpose: artifact
storage has a quota that a few ~90MB APKs exhaust, while release assets count
against repository storage.

```sh
git tag v0.1.0 && git push origin v0.1.0    # -> APK attached to the release
```

## Adding JVM-side glue

cargo-apk2 makes this incremental:

- **From a crate** — add the dep, set `kotlin_sources = "kotlin"` under
  `[package.metadata.android]`, and its classes land in `classes.dex` on a
  normal build. [`slint-android-gestures`](https://github.com/gregoryraymond/slint-mapping/tree/main/crates/slint-android-gestures)
  is a complete worked example (multi-touch pinch).
- **Hand-written** — drop `.kt` files in `app/kotlin/<package>/`, same config.
- **Services** — wrap the JVM subclass in a crate and declare it with
  `[[package.metadata.android.service]]`.

## Optional: the component library

[`slint-mobile-components`](https://github.com/gregoryraymond/slint-mobile-components)
provides widgets and a theme. Both are `publish = false`, so use git deps:

```toml
slint-mobile-theme = { git = "https://github.com/gregoryraymond/slint-mobile-components" }
slint-mobile-components-widgets = { git = "https://github.com/gregoryraymond/slint-mobile-components" }
```

## Notes

- `backend-android-activity-06` tracks `android-activity` 0.6.x. When Slint
  moves to a newer major, update the feature name in the workspace `Cargo.toml`.
- `min_sdk_version = 24` is the floor for Skia + modern `android-activity`.
  Below it the build succeeds but the renderer fails on real devices.
- Android application id is set in `app/Cargo.toml` under
  `[package.metadata.android] package`.
