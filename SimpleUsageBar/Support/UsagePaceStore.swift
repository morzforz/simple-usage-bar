// UsagePaceStore.swift
// Retains billing % samples for pace (in-memory + lightweight disk).

import Foundation

/// Appends samples on successful billing refresh; prunes to current period and a cap.
public final class UsagePaceStore: @unchecked Sendable {
    public private(set) var samples: [UsagePaceSample] = []

    private let maxSamples: Int
    private let fileURL: URL?
    private let lock = NSLock()

    public init(
        maxSamples: Int = 500,
        fileURL: URL? = UsagePaceStore.defaultFileURL()
    ) {
        self.maxSamples = max(2, maxSamples)
        self.fileURL = fileURL
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([UsagePaceSample].self, from: data) {
            samples = decoded
        }
    }

    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("SimpleUsageBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pace_samples.json")
    }

    /// Record a successful billing snapshot. Drops samples from other periods.
    public func record(from snapshot: UsageSnapshot, at date: Date = Date()) {
        let sample = UsagePaceSample(
            usedPercent: snapshot.usedPercent,
            recordedAt: date,
            periodStart: snapshot.periodStart,
            resetsAt: snapshot.resetsAt
        )
        lock.lock()
        defer { lock.unlock() }

        if let start = sample.periodStart, let end = sample.resetsAt {
            samples.removeAll {
                $0.periodStart != start || $0.resetsAt != end
            }
        }

        // Avoid near-duplicate spam if percent unchanged within 30s.
        if let last = samples.last,
           abs(last.usedPercent - sample.usedPercent) < 0.05,
           sample.recordedAt.timeIntervalSince(last.recordedAt) < 30 {
            samples[samples.count - 1] = sample
        } else {
            samples.append(sample)
        }

        if samples.count > maxSamples {
            samples = Array(samples.suffix(maxSamples))
        }
        persistLocked()
    }

    public func allSamples() -> [UsagePaceSample] {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    private func persistLocked() {
        guard let fileURL else { return }
        guard let data = try? JSONEncoder().encode(samples) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
