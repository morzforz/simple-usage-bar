// AppModel.swift
// Observable app state: fetch-on-launch, timer, auth watch, manual refresh.

import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var state: AppState = .loading
    private(set) var isRefreshing = false
    private(set) var lastRefreshAttempt: Date?
    private(set) var launchAtLoginEnabled: Bool = LaunchAtLogin.isEnabled
    private(set) var launchAtLoginMessage: String?

    private let provider: any UsageProviding
    private let authStore: GrokAuthStore
    private let refreshInterval: TimeInterval
    private let minimumRefreshInterval: TimeInterval
    private var timerTask: Task<Void, Never>?
    private var inFlight: Task<Void, Never>?
    private var authWatcher: AuthFileWatcher?

    init(
        provider: any UsageProviding = GrokProvider(),
        authStore: GrokAuthStore = GrokAuthStore(),
        refreshInterval: TimeInterval = 5 * 60,
        minimumRefreshInterval: TimeInterval = 30,
        autoStart: Bool = true
    ) {
        self.provider = provider
        self.authStore = authStore
        self.refreshInterval = refreshInterval
        self.minimumRefreshInterval = minimumRefreshInterval
        if autoStart {
            start()
        }
    }

    func stop() {
        timerTask?.cancel()
        inFlight?.cancel()
        authWatcher?.stop()
        authWatcher = nil
    }

    // MARK: - Display helpers

    var statusItemTitle: String {
        switch state {
        case .loading:
            return "G …"
        case let .ready(snapshot):
            return UsageDisplayFormatter.statusItemTitle(for: snapshot)
        case let .stale(snapshot, _):
            // Keep percent visible; stale is signaled via tint + popover message.
            return UsageDisplayFormatter.statusItemTitle(for: snapshot)
        case .unauthenticated:
            return "G —"
        case .error:
            return "G !"
        case .teamUnsupported:
            return "G —"
        }
    }

    var usageBand: UsageBand {
        UsageDisplayFormatter.usageBand(for: state.snapshot)
    }

    /// Whether menubar should use band tint (ready/stale with data).
    var usesBandTint: Bool {
        state.snapshot != nil
    }

    var isStale: Bool {
        if case .stale = state { return true }
        return false
    }

    var usedPercentText: String {
        if let snapshot = state.snapshot {
            return UsageDisplayFormatter.formatUsedPercent(snapshot.usedPercent)
        }
        return "—"
    }

    var resetAbsoluteText: String {
        UsageDisplayFormatter.formatResetAbsolute(state.snapshot?.resetsAt)
    }

    var resetRelativeText: String {
        UsageDisplayFormatter.formatResetRelative(state.snapshot?.resetsAt)
    }

    var tooltipText: String {
        if case let .stale(snapshot, message) = state {
            let base = UsageDisplayFormatter.tooltip(for: snapshot)
            return "\(base) · stale: \(message)"
        }
        if let snapshot = state.snapshot {
            return UsageDisplayFormatter.tooltip(for: snapshot)
        }
        if let message = state.statusMessage {
            return "Grok · \(message)"
        }
        return "Grok · loading"
    }

    var windowLabelText: String {
        state.snapshot?.windowLabel.displayName ?? "Usage"
    }

    var displayName: String {
        state.snapshot?.displayName ?? "Grok"
    }

    var accountEmail: String? {
        state.snapshot?.accountEmail
    }

    var sourceLabel: String {
        guard let snapshot = state.snapshot else {
            return "CLI auth"
        }
        let freshness: String
        switch state {
        case .stale:
            freshness = "stale"
        case .ready:
            freshness = snapshot.source == .billingApi ? "live" : snapshot.source.rawValue
        default:
            freshness = snapshot.source.rawValue
        }
        return "CLI auth · \(freshness)"
    }

    var progressValue: Double {
        min(max(state.snapshot?.usedPercent ?? 0, 0), 100)
    }

    // MARK: - Lifecycle

    func start() {
        startAuthWatcher()
        Task { await refresh(force: true) }
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.refreshInterval ?? 300
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self?.refresh(force: false)
            }
        }
        refreshLaunchAtLoginStatus()
    }

    private func startAuthWatcher() {
        authWatcher?.stop()
        let watcher = AuthFileWatcher()
        watcher.onChange = { [weak self] in
            Task { @MainActor in
                await self?.refresh(force: true)
            }
        }
        watcher.start(authFileURL: authStore.authFileURL())
        authWatcher = watcher
    }

    func refresh(force: Bool = true) async {
        if let last = lastRefreshAttempt, !force {
            if Date().timeIntervalSince(last) < minimumRefreshInterval {
                return
            }
        }
        if let existing = inFlight {
            await existing.value
            return
        }

        let task = Task { @MainActor in
            await self.performRefresh()
        }
        inFlight = task
        await task.value
        inFlight = nil
    }

    private func performRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        lastRefreshAttempt = Date()

        if state.snapshot == nil {
            state = .loading
        }

        do {
            let snapshot = try await provider.fetchUsage(now: Date())
            state = .ready(snapshot)
        } catch let error as GrokAuthError {
            state = .unauthenticated(error.localizedDescription)
        } catch let error as GrokBillingError {
            switch error {
            case .authRejected:
                state = .unauthenticated(error.localizedDescription)
            case .teamUsageUnsupported:
                state = .teamUnsupported
            default:
                if let previous = state.snapshot {
                    state = .stale(previous, error.localizedDescription)
                } else {
                    state = .error(error.localizedDescription)
                }
            }
        } catch {
            if let previous = state.snapshot {
                state = .stale(previous, error.localizedDescription)
            } else {
                state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Launch at Login

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchAtLoginMessage = nil
        } catch {
            launchAtLoginMessage = error.localizedDescription
        }
        refreshLaunchAtLoginStatus()
    }
}
