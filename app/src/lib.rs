use std::rc::Rc;

use app_core::Counter;

slint::include_modules!();

#[cfg(target_os = "android")]
#[no_mangle]
fn android_main(app: slint::android::AndroidApp) {
    slint::android::init(app).expect("Slint Android init failed");
    run_ui();
}

#[cfg_attr(not(target_os = "android"), allow(dead_code))]
fn run_ui() {
    let ui = MainWindow::new().expect("failed to construct MainWindow");
    let counter = Rc::new(Counter::new());

    ui.set_count(counter.value() as i32);

    let counter_for_bump = counter.clone();
    let ui_weak = ui.as_weak();
    ui.on_bump(move || {
        let new_value = counter_for_bump.increment();
        if let Some(ui) = ui_weak.upgrade() {
            ui.set_count(new_value as i32);
        }
    });

    ui.run().expect("event loop failed");
}
