# slint-android-template

A **GitHub template** for building Android apps with [Slint](https://slint.dev)
and Rust. Click **Use this template**, run one script, and you have a building,
installable APK project.

All application logic is Rust. No Kotlin or Java in the tree by default.

## Quick start

```sh
# 1. Click "Use this template" on GitHub, then:
git clone https://github.com/<you>/my-app && cd my-app

# 2. Rename the scaffold into your project
./init.sh --name my-app --package com.example.myapp --label "My App"

# 3. Build and run on a device or emulator
just setup-emulator     # once, ~700MB system image
just run
```

`init.sh` rewrites the crate names, Android application id and launcher label,
installs the project README, then **deletes itself**.

## Why a script instead of placeholders

GitHub's "Use this template" copies files **literally** — it cannot run
`cargo generate` hooks. A template carrying `{{crate_name}}` placeholders
therefore produces a repo that does not compile and a workspace rust-analyzer
cannot load, until the user hand-edits it.

So this template ships a **real, building project** and renames it in place.
The trade-off is that the template repo has a concrete name in it
(`slint-android-app`) — which is also what lets CI here prove the scaffold
actually builds, rather than proving a placeholder-substituted copy of it does.

> Prefer `cargo generate`? Use
> [`slint-mobile`](https://github.com/gregoryraymond/slint-mobile) instead —
> same scaffold, placeholder-based, driven by `cargo generate --git`.
> This repo is the GitHub-template equivalent.

## What you get

| | |
|---|---|
| **Workspace split** | `core/` pure logic (host-testable, no Slint/Android) + `app/` UI and Android entry point |
| **Stable import alias** | `core` is aliased to `app_core`, so renaming the project touches no `use` statement |
| **Multi-arch APK** | aarch64 + x86_64, so one artifact runs on a phone *and* the default emulator |
| **Dev container** | Rust, cargo-apk2, JDK 17, Kotlin, Android SDK 34, NDK r27 — all pinned |
| **justfile** | `just build` / `release` / `run` / `setup-emulator` / `ci` |
| **CI** | Host lint+test + a verified **debug** APK on every push; **signed** release APK on `v*` tags |
| **APK gating** | Every build is checked for a truncated native lib, a missing launcher activity, and debug-signed releases |

## Layout

```
├── init.sh             # one-shot renamer; deletes itself
├── Cargo.toml          # workspace + shared deps
├── rust-toolchain.toml # pinned channel + android targets
├── core/               # pure-logic rlib
├── app/                # cdylib: Slint UI + android_main
├── docs/
│   └── PROJECT_README.md   # becomes your README.md after init.sh
├── .devcontainer/
└── .github/workflows/  # ci.yml (host + debug APK) + release.yml (signed)
```

## Related

- [`slint-mobile`](https://github.com/gregoryraymond/slint-mobile) — the same
  scaffold as a `cargo generate` template
- [`slint-mobile-components`](https://github.com/gregoryraymond/slint-mobile-components)
  — widgets and theme, usable as git dependencies
- [`slint-mapping`](https://github.com/gregoryraymond/slint-mapping) — map
  rendering, and `slint-android-gestures` for multi-touch

## Licence

MIT OR Apache-2.0.
