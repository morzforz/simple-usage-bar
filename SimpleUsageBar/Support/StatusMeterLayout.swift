// StatusMeterLayout.swift
// Pure geometry for the menubar status meter image (CodexBar-style single bitmap).
// Menu bar working height is ~18–22 pt; multi-line SwiftUI labels are unreliable.

import Foundation

/// Horizontal band widths for the usage meter (fill + optional headroom intermediate).
public struct StatusMeterBarBands: Sendable, Equatable {
    /// Used-portion width from the left of the track (points).
    public var fillWidth: CGFloat
    /// Intermediate (headroom) width immediately after fill; 0 when not shown.
    public var intermediateWidth: CGFloat
    /// Whether the intermediate headroom band should be drawn.
    public var showsIntermediate: Bool

    public init(fillWidth: CGFloat, intermediateWidth: CGFloat, showsIntermediate: Bool) {
        self.fillWidth = fillWidth
        self.intermediateWidth = intermediateWidth
        self.showsIntermediate = showsIntermediate
    }
}

/// Layout constants and pure measurements for the composited status image.
public enum StatusMeterLayout {
    /// Menu bar icon/content height in points (matches system status item).
    public static let canvasHeight: CGFloat = 18
    public static let logoSide: CGFloat = 13
    public static let logoTextSpacing: CGFloat = 4
    public static let percentFontSize: CGFloat = 10
    public static let barWidth: CGFloat = 28
    public static let barHeight: CGFloat = 3
    /// Vertical gap between percent baseline area and the bar.
    public static let percentToBarSpacing: CGFloat = 1
    public static let horizontalPadding: CGFloat = 1

    /// Width of monospaced percent text at the menubar font size (approximation used for layout tests).
    public static func estimatedPercentTextWidth(_ text: String) -> CGFloat {
        // 10pt monospaced ≈ 6.1pt per character on macOS system mono metrics.
        CGFloat(text.count) * 6.1
    }

    /// Total canvas width for logo + percent column (+ optional bar under percent).
    public static func canvasWidth(percentText: String, showsBar: Bool) -> CGFloat {
        let textW = estimatedPercentTextWidth(percentText)
        let columnW = showsBar ? max(textW, barWidth) : textW
        return horizontalPadding + logoSide + logoTextSpacing + columnW + horizontalPadding
    }

    /// Fill width in points for the meter track (uses shipped fill helper).
    public static func barFillWidth(usedPercent: Double) -> CGFloat {
        CGFloat(UsageDisplayFormatter.barFillWidth(usedPercent: usedPercent, totalWidth: Double(barWidth)))
    }

    /// Whether the intermediate headroom band is visible: headroom present and strictly greater than used.
    public static func showsHeadroomIntermediate(
        usedPercent: Double,
        headroomPercent: Double?
    ) -> Bool {
        guard let headroomPercent else { return false }
        return headroomPercent > usedPercent
    }

    /// Band geometry for used fill + optional intermediate (ends at headroom % on the track).
    ///
    /// Layout left → right: fill [0…used%], intermediate (used%…headroom%] when shown, then track.
    public static func barBands(
        usedPercent: Double,
        headroomPercent: Double?,
        trackWidth: CGFloat = barWidth
    ) -> StatusMeterBarBands {
        let fillW = CGFloat(
            UsageDisplayFormatter.barFillWidth(usedPercent: usedPercent, totalWidth: Double(trackWidth))
        )
        guard showsHeadroomIntermediate(usedPercent: usedPercent, headroomPercent: headroomPercent),
              let headroomPercent else {
            return StatusMeterBarBands(fillWidth: fillW, intermediateWidth: 0, showsIntermediate: false)
        }
        let headroomEnd = CGFloat(
            UsageDisplayFormatter.barFillWidth(usedPercent: headroomPercent, totalWidth: Double(trackWidth))
        )
        let intermediateW = max(0, headroomEnd - fillW)
        return StatusMeterBarBands(
            fillWidth: fillW,
            intermediateWidth: intermediateW,
            showsIntermediate: intermediateW > 0.5
        )
    }
}
