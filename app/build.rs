fn main() {
    slint_build::compile("ui/main.slint").expect("Slint build failed");

    // Kotlin/Java is GENERATED here, not hand-written. A glue crate bundles its
    // .kt with include_str! and exposes a helper that writes it into app/kotlin/
    // at build time; cargo-apk2 then compiles whatever it finds there into
    // classes.dex. Add the crate to [build-dependencies], uncomment
    // kotlin_sources in Cargo.toml, and add a line like:
    //
    //   slint_android_gestures::build::copy_kotlin_to("kotlin")
    //       .expect("write kotlin sources");
    //
    // app/kotlin/ is gitignored precisely because it is regenerated every build.
}
