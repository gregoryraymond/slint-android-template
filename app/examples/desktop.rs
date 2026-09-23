//! Run the app in a desktop window for local UI development:
//!
//! ```sh
//! just desktop
//! ```
//!
//! On device the entry point is `android_main` in the library instead. This
//! exists so the UI can be iterated without waiting on an emulator.
//!
//! Rendering here goes through winit + FemtoVG, while the device uses Skia
//! (see app/Cargo.toml). Layout and behaviour match; treat the device as the
//! source of truth for pixel-level detail.

#[cfg(not(target_os = "android"))]
fn main() {
    slint_android_app::run_ui();
}

// `cargo check --all-targets --target aarch64-linux-android` still compiles
// examples, so this needs an android-side main to exist.
#[cfg(target_os = "android")]
fn main() {}
