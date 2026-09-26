//! Frame-time percentiles.
//!
//! Means hide exactly the thing we care about. A 60fps average with a 40ms
//! spike on every keystroke is a failure that a mean reports as a pass, so the
//! gates in docs/roadmap.md are written against p95.

pub struct Stats {
    samples: Vec<f32>,
    /// Frames to discard before recording. The first frames pay for font atlas
    /// construction and shader upload, which no user ever experiences as
    /// interaction latency.
    warmup: usize,
    seen: usize,
}

impl Stats {
    pub fn new(warmup: usize) -> Self {
        Self { samples: Vec::with_capacity(4096), warmup, seen: 0 }
    }

    pub fn push(&mut self, ms: f32) {
        self.seen += 1;
        if self.seen > self.warmup {
            self.samples.push(ms);
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
        sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
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
