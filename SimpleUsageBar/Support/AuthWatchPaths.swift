// AuthWatchPaths.swift
// Pure helpers for resolving which directory to watch for CLI auth changes.

import Foundation

public enum AuthWatchPaths {
    public static let authFileName = "auth.json"
    public static let defaultDebounceInterval: TimeInterval = 0.5

    /// Directory that should be observed for create/update/delete of the auth file.
    /// Prefers the auth file's parent (e.g. `~/.grok`); if missing, watches the grandparent
    /// (e.g. home) so a later `mkdir .grok` + login can still be noticed.
    public static func directoryToWatch(
        authFileURL: URL,
        fileManager: FileManager = .default
    ) -> URL {
        let parent = authFileURL.deletingLastPathComponent()
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: parent.path, isDirectory: &isDir), isDir.boolValue {
            return parent
        }
        return parent.deletingLastPathComponent()
    }

    /// Whether a filesystem event name is relevant to the CLI auth store.
    public static func isRelevantEventName(
        _ name: String?,
        authFileName: String = authFileName
    ) -> Bool {
        guard let name, !name.isEmpty else {
            // Directory-level events often omit a filename; treat as relevant.
            return true
        }
        if name == authFileName { return true }
        // Atomic writes may use temp names like auth.json.tmp / auth.json.lock
        if name.hasPrefix(authFileName) { return true }
        if name == ".grok" { return true }
        return false
    }
}

/// Simple debounce gate: accepts at most one fire per interval (throttle-style),
/// suitable for coalescing rapid FSEvents without timers in unit tests.
public struct DebounceGate: Sendable {
    public let interval: TimeInterval
    private var lastAccepted: Date?

    public init(interval: TimeInterval = AuthWatchPaths.defaultDebounceInterval) {
        self.interval = interval
    }

    /// Returns true if an event at `now` should pass the gate.
    public mutating func accept(now: Date = Date()) -> Bool {
        if let last = lastAccepted, now.timeIntervalSince(last) < interval {
            return false
        }
        lastAccepted = now
        return true
    }

    public mutating func reset() {
        lastAccepted = nil
    }
}
