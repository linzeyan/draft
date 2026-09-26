//! Frame-cost percentiles.
//!
//! Means hide exactly the thing we care about. A 60 fps average with a 40 ms
//! spike on every keystroke is a failure that a mean reports as a pass, so the
//! gates in docs/roadmap.md are written against p95.

/// A bounded ring of recent samples. Bounded because this runs for the life of
/// the application, not for the length of a benchmark.
pub struct Stats {
    samples: Vec<f32>,
    next: usize,
    capacity: usize,
    /// Frames to discard before recording. The first frames pay for font atlas
    /// construction and shader upload, which no user experiences as latency.
    warmup: usize,
    seen: usize,
}

impl Stats {
    pub fn new(capacity: usize, warmup: usize) -> Self {
        Self {
            samples: Vec::with_capacity(capacity),
            next: 0,
            capacity,
            warmup,
            seen: 0,
        }
    }

    pub fn push(&mut self, ms: f32) {
        self.seen += 1;
        if self.seen <= self.warmup {
            return;
        }
        if self.samples.len() < self.capacity {
            self.samples.push(ms);
        } else {
            self.samples[self.next] = ms;
            self.next = (self.next + 1) % self.capacity;
        }
    }

    pub fn len(&self) -> usize {
        self.samples.len()
    }

    pub fn percentile(&self, p: f32) -> f32 {
        if self.samples.is_empty() {
            return 0.0;
        }
        let mut sorted = self.samples.clone();
        sorted.sort_by(f32::total_cmp);
        let idx = ((sorted.len() - 1) as f32 * p).round() as usize;
        sorted[idx]
    }

    pub fn summary(&self) -> String {
        format!(
            "n={} p50={:.2}ms p95={:.2}ms p99={:.2}ms max={:.2}ms",
            self.len(),
            self.percentile(0.50),
            self.percentile(0.95),
            self.percentile(0.99),
            self.percentile(1.00),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn warmup_frames_are_not_counted() {
        let mut stats = Stats::new(64, 3);
        for _ in 0..3 {
            stats.push(999.0);
        }
        assert_eq!(stats.len(), 0);
        stats.push(1.0);
        assert_eq!(stats.percentile(1.0), 1.0, "a warmup spike leaked in");
    }

    #[test]
    fn the_window_holds_only_the_most_recent_samples() {
        let mut stats = Stats::new(4, 0);
        for ms in [50.0, 50.0, 50.0, 50.0, 1.0, 1.0, 1.0, 1.0] {
            stats.push(ms);
        }
        assert_eq!(stats.len(), 4);
        assert_eq!(
            stats.percentile(1.0),
            1.0,
            "an old spike should have aged out"
        );
    }

    #[test]
    fn percentiles_of_nothing_are_zero_rather_than_a_panic() {
        assert_eq!(Stats::new(8, 0).percentile(0.95), 0.0);
    }
}
