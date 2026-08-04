// AppModel.swift
// Observable app state: fetch-on-launch, timer, manual refresh.

import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var state: AppState = .loading
    private(set) var isRefreshing = false
    private(set) var lastRefreshAttempt: Date?

    private let provider: any UsageProviding
    private let refreshInterval: TimeInterval
    private let minimumRefreshInterval: TimeInterval
    private var refreshTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var inFlight: Task<Void, Never>?

    init(
        provider: any UsageProviding = GrokProvider(),
        refreshInterval: TimeInterval = 5 * 60,
        minimumRefreshInterval: TimeInterval = 30,
        autoStart: Bool = true
    ) {
        self.provider = provider
        self.refreshInterval = refreshInterval
        self.minimumRefreshInterval = minimumRefreshInterval
        if autoStart {
            start()
        }
    }

    func stop() {
        refreshTask?.cancel()
        timerTask?.cancel()
        inFlight?.cancel()
    }

    // MARK: - Display helpers

    var statusItemTitle: String {
        switch state {
        case .loading:
            return "G …"
        case let .ready(snapshot), let .stale(snapshot, _):
            return UsageDisplayFormatter.statusItemTitle(for: snapshot)
        case .unauthenticated:
            return "G —"
        case .error:
            return "G !"
        case .teamUnsupported:
            return "G —"
        }
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
        switch snapshot.source {
        case .billingApi:
            return "CLI auth · live"
        case .mock:
            return "mock"
        case .agentRpc:
            return "CLI auth · RPC"
        }
    }

    var progressValue: Double {
        min(max(state.snapshot?.usedPercent ?? 0, 0), 100)
    }

    // MARK: - Lifecycle

    func start() {
        Task { await refresh(force: true) }
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.refreshInterval ?? 300) * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self?.refresh(force: false)
            }
        }
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

        // Keep prior snapshot visible while reloading when we already have data.
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
}
