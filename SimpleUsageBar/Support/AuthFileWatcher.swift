// AuthFileWatcher.swift
// Debounced directory watch for Grok CLI auth.json changes.

import Foundation

/// Observes the auth file's parent directory and invokes `onChange` after quiet period.
final class AuthFileWatcher: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.andrewcoleman.SimpleUsageBar.auth-watch")
    private var source: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: Int32 = -1
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval
    private let fileManager: FileManager

    /// Called on the watcher's queue after debounce; hop to MainActor in the handler if needed.
    var onChange: (() -> Void)?

    init(
        debounceInterval: TimeInterval = AuthWatchPaths.defaultDebounceInterval,
        fileManager: FileManager = .default
    ) {
        self.debounceInterval = debounceInterval
        self.fileManager = fileManager
    }

    deinit {
        stop()
    }

    func start(authFileURL: URL) {
        stop()
        let directory = AuthWatchPaths.directoryToWatch(
            authFileURL: authFileURL,
            fileManager: fileManager
        )
        let path = directory.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        directoryFileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename, .delete, .link],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scheduleDebouncedFire()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.directoryFileDescriptor >= 0 {
                close(self.directoryFileDescriptor)
                self.directoryFileDescriptor = -1
            }
        }
        self.source = source
        source.resume()
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        source?.cancel()
        source = nil
    }

    private func scheduleDebouncedFire() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
