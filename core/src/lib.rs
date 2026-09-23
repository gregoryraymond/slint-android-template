//! Pure-logic crate for slint_mobile.
//!
//! No Slint or Android dependencies live here — only domain types and logic.
//! The UI layer (`app/`) consumes this through a normal Rust dependency, so
//! everything in this crate is testable with plain `cargo test` on the host.

use std::sync::atomic::{AtomicI64, Ordering};

#[derive(Debug, Default)]
pub struct Counter {
    value: AtomicI64,
}

impl Counter {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn value(&self) -> i64 {
        self.value.load(Ordering::Relaxed)
    }

    pub fn increment(&self) -> i64 {
        self.value.fetch_add(1, Ordering::Relaxed) + 1
    }

    pub fn reset(&self) {
        self.value.store(0, Ordering::Relaxed);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn counter_increments() {
        let c = Counter::new();
        assert_eq!(c.value(), 0);
        assert_eq!(c.increment(), 1);
        assert_eq!(c.increment(), 2);
        c.reset();
        assert_eq!(c.value(), 0);
    }
}
