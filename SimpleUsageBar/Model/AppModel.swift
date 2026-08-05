// AppModel.swift
// Observable app state: fetch-on-launch, timer, auth watch, manual refresh.

import AppKit
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
    /// Directional pace for the current billing window (or insufficient data).
    private(set) var paceOutcome: UsagePaceOutcome = .insufficientData
    /// Projected unused pool % at reset if average burn continues; nil when insufficient.
    private(set) var paceHeadroomPercent: Double?

    private let provider: any UsageProviding
    private let authStore: GrokAuthStore
    private let thresholdNotifier: any UsageThresholdNotifying
    private let paceStore: UsagePaceStore
    private let refreshInterval: TimeInterval
    private let minimumRefreshInterval: TimeInterval
    private var timerTask: Task<Void, Never>?
    private var inFlight: Task<Void, Never>?
    /// Set when a force refresh arrives while a fetch is already running (e.g. auth file change).
    private var pendingForceRefresh = false
    private var authWatcher: AuthFileWatcher?
    /// Levels already notified while usage stayed ≥ that level (in-memory session state).
    private var firedThresholdsWhileAbove: Set<Int> = []
    private var didPrepareNotifications = false

    init(
        provider: any UsageProviding = GrokProvider(),
        authStore: GrokAuthStore = GrokAuthStore(),
        thresholdNotifier: any UsageThresholdNotifying = UserNotificationsThresholdNotifier(),
        paceStore: UsagePaceStore = UsagePaceStore(),
        refreshInterval: TimeInterval = 5 * 60,
        minimumRefreshInterval: TimeInterval = 30,
        autoStart: Bool = true
    ) {
        self.provider = provider
        self.authStore = authStore
        self.thresholdNotifier = thresholdNotifier
        self.paceStore = paceStore
        self.refreshInterval = refreshInterval
        self.minimumRefreshInterval = minimumRefreshInterval
        if autoStart {
            start()
        }
    }

    /// User-facing pace summary line for the popover.
    var paceDisplayLine: String {
        paceOutcome.displayLine
    }

    /// Optional headroom line (projected unused % at reset); nil when insufficient data.
    var paceHeadroomDisplayLine: String? {
        guard let paceHeadroomPercent else { return nil }
        let rounded = Int(paceHeadroomPercent.rounded())
        return "Headroom: ~\(rounded)% unused at reset"
    }

    func stop() {
        timerTask?.cancel()
        inFlight?.cancel()
        authWatcher?.stop()
        authWatcher = nil
    }

    // MARK: - Display helpers

    /// Percent (or placeholder) shown next to the Grok logo in the menu bar.
    var statusItemTitle: String {
        switch state {
        case .loading:
            return UsageDisplayFormatter.statusPlaceholder(for: true)
        case let .ready(snapshot):
            return UsageDisplayFormatter.statusItemTitle(for: snapshot)
        case let .stale(snapshot, _):
            // Keep percent visible; stale is signaled via tint + popover message.
            return UsageDisplayFormatter.statusItemTitle(for: snapshot)
        case .error:
            return "!"
        case .unauthenticated, .teamUnsupported:
            return UsageDisplayFormatter.statusPlaceholder(for: false)
        }
    }

    /// 0…1 fill for the mini menubar usage bar (0 when no snapshot).
    var statusBarFillFraction: Double {
        guard let snapshot = state.snapshot else { return 0 }
        return UsageDisplayFormatter.barFillFraction(usedPercent: snapshot.usedPercent)
    }

    /// Whether the mini bar should be shown under the percent.
    var showsStatusUsageBar: Bool {
        state.snapshot != nil
    }

    /// Composited **template** status image for MenuBarExtra (logo + percent + optional bar).
    /// Monochrome only — system tints black/white against the menu bar (no band colors).
    var statusMeterImage: NSImage {
        let used: Double? = showsStatusUsageBar ? state.snapshot?.usedPercent : nil
        return StatusMeterImageRenderer.makeImage(
            percentText: statusItemTitle,
            usedPercent: used
        )
    }

    var usageBand: UsageBand {
        UsageDisplayFormatter.usageBand(for: state.snapshot)
    }

    /// Whether the popover should use usage-band colors (menubar is monochrome template).
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

        // Coalesce concurrent callers onto one in-flight fetch. Force callers
        // (auth-file watch, manual Refresh) must not be dropped: queue a follow-up.
        if let existing = inFlight {
            if force {
                pendingForceRefresh = true
            }
            await existing.value
            if force {
                await drainPendingForceRefresh()
            }
            return
        }

        await executeRefreshCycle()
    }

    private func executeRefreshCycle() async {
        let task = Task { @MainActor in
            await self.performRefresh()
        }
        inFlight = task
        await task.value
        inFlight = nil
        await drainPendingForceRefresh()
    }

    private func drainPendingForceRefresh() async {
        guard pendingForceRefresh else { return }
        guard inFlight == nil else { return }
        pendingForceRefresh = false
        await executeRefreshCycle()
    }

    private func performRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        lastRefreshAttempt = Date()

        if state.snapshot == nil {
            state = .loading
        }

        do {
            let now = Date()
            let snapshot = try await provider.fetchUsage(now: now)
            state = .ready(snapshot)
            recordPaceSampleAndEvaluate(snapshot: snapshot, at: now)
            await evaluateAndNotifyThresholds(usedPercent: snapshot.usedPercent)
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

    // MARK: - Pace estimate

    private func recordPaceSampleAndEvaluate(snapshot: UsageSnapshot, at date: Date) {
        paceStore.record(from: snapshot, at: date)
        let estimate = UsagePaceEvaluator.estimate(
            samples: paceStore.allSamples(),
            currentUsedPercent: snapshot.usedPercent,
            periodStart: snapshot.periodStart,
            resetsAt: snapshot.resetsAt,
            now: date
        )
        paceOutcome = estimate.outcome
        paceHeadroomPercent = estimate.headroomPercent
    }

    // MARK: - Threshold notifications

    private func evaluateAndNotifyThresholds(usedPercent: Double) async {
        let result = UsageThresholdAlert.evaluate(
            currentPercent: usedPercent,
            previouslyFiredWhileAbove: firedThresholdsWhileAbove
        )
        firedThresholdsWhileAbove = result.firedWhileAbove
        guard !result.toFire.isEmpty else { return }

        if !didPrepareNotifications {
            await thresholdNotifier.prepareAuthorization()
            didPrepareNotifications = true
        }
        for level in result.toFire {
            await thresholdNotifier.notify(level: level, usedPercent: usedPercent)
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
