// AppKitToolTipBridge.swift
// Transparent NSView that hosts AppKit `toolTip` — more reliable than SwiftUI `.help`
// in some contexts. Still may not show inside MenuBarExtra windows; PopoverUsageBar
// also presents an in-popover hover callout using the same string.

import AppKit
import SwiftUI

/// Clear AppKit view overlay that sets `NSView.toolTip` for native macOS tooltips.
struct AppKitToolTipBridge: NSViewRepresentable {
    var text: String

    func makeNSView(context: Context) -> TooltipTrackingView {
        let view = TooltipTrackingView()
        view.toolTip = text.isEmpty ? nil : text
        return view
    }

    func updateNSView(_ nsView: TooltipTrackingView, context: Context) {
        nsView.toolTip = text.isEmpty ? nil : text
    }
}

/// Tracking view that accepts mouse hits so AppKit can display tooltips.
final class TooltipTrackingView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Transparent; exists only for hit-testing + toolTip.
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Participate in hit testing so tooltips can attach to this rect.
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    override var acceptsFirstResponder: Bool { false }
}
