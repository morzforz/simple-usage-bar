// LaunchAtLogin.swift
// Menu-bar login item via ServiceManagement (SMAppService).

import Foundation
import ServiceManagement

public enum LaunchAtLoginError: Error, LocalizedError, Equatable {
    case registrationFailed(String)
    case unregistrationFailed(String)
    case unsupported

    public var errorDescription: String? {
        switch self {
        case let .registrationFailed(message):
            return "Could not enable Launch at Login: \(message)"
        case let .unregistrationFailed(message):
            return "Could not disable Launch at Login: \(message)"
        case .unsupported:
            return "Launch at Login is not available on this system."
        }
    }
}

/// Thin wrapper around `SMAppService.mainApp` for the popover toggle.
public enum LaunchAtLogin {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "enabled"
        case .notRegistered:
            return "notRegistered"
        case .notFound:
            return "notFound"
        case .requiresApproval:
            return "requiresApproval"
        @unknown default:
            return "unknown"
        }
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            do {
                try SMAppService.mainApp.register()
            } catch {
                throw LaunchAtLoginError.registrationFailed(error.localizedDescription)
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                throw LaunchAtLoginError.unregistrationFailed(error.localizedDescription)
            }
        }
    }
}
