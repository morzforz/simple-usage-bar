// StatusMeterImageRenderer.swift
// Composites logo + percent + horizontal meter into one NSImage for the status item.
//
// Monochrome template image (black + clear only): macOS tints it black or white
// against the menu-bar wallpaper. Do not bake usage-band green/yellow/red here.
//
// Approach (aligned with CodexBar / typical NSStatusItem practice):
// - Draw into a fixed ~18pt-tall bitmap
// - isTemplate = true for system adaptive monochrome
// - Do NOT rely on multi-line SwiftUI MenuBarExtra labels (system clips them)

import AppKit
import Foundation

enum StatusMeterImageRenderer {
    /// Solid black used for template-image silhouettes (system recolors).
    static let templateInk = NSColor.black

    /// Build a status-item **template** image for the current usage presentation.
    /// - Parameters:
    ///   - percentText: e.g. "43%", "…", "—", "!"
    ///   - usedPercent: when non-nil, draws the bar under the percent (fill from helpers)
    ///   - logo: optional Grok logo (re-tinted to black for the template)
    static func makeImage(
        percentText: String,
        usedPercent: Double?,
        logo: NSImage? = NSImage(named: "GrokLogo")
    ) -> NSImage {
        let showsBar = usedPercent != nil
        let width = StatusMeterLayout.canvasWidth(percentText: percentText, showsBar: showsBar)
        let height = StatusMeterLayout.canvasHeight
        let size = NSSize(width: width, height: height)
        let ink = templateInk

        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.saveGState()
            defer { ctx.restoreGState() }

            let logoSide = StatusMeterLayout.logoSide
            let pad = StatusMeterLayout.horizontalPadding
            let logoX = pad
            let logoY = (height - logoSide) / 2

            if let logo {
                let logoRect = NSRect(x: logoX, y: logoY, width: logoSide, height: logoSide)
                if let tinted = Self.tintedImage(logo, color: ink, size: NSSize(width: logoSide, height: logoSide)) {
                    tinted.draw(in: logoRect)
                } else {
                    logo.draw(in: logoRect)
                }
            }

            let columnX = logoX + logoSide + StatusMeterLayout.logoTextSpacing
            let textW = StatusMeterLayout.estimatedPercentTextWidth(percentText)
            let columnW = showsBar ? max(textW, StatusMeterLayout.barWidth) : textW

            let font = NSFont.monospacedDigitSystemFont(
                ofSize: StatusMeterLayout.percentFontSize,
                weight: .semibold
            )
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: ink,
            ]
            let nsText = percentText as NSString
            let textSize = nsText.size(withAttributes: attrs)

            let barH = StatusMeterLayout.barHeight
            let barW = StatusMeterLayout.barWidth
            let spacing = StatusMeterLayout.percentToBarSpacing

            if showsBar, let used = usedPercent {
                let stackH = textSize.height + spacing + barH
                let stackOriginY = (height - stackH) / 2
                let textY = stackOriginY + barH + spacing
                let textX = columnX + max(0, (columnW - textSize.width) / 2)
                nsText.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

                let barX = columnX + max(0, (columnW - barW) / 2)
                let barY = stackOriginY
                let track = NSRect(x: barX, y: barY, width: barW, height: barH)
                let radius = barH / 2

                // Track (lighter black via alpha — template-safe monochrome).
                let trackPath = NSBezierPath(roundedRect: track, xRadius: radius, yRadius: radius)
                ink.withAlphaComponent(0.28).setFill()
                trackPath.fill()

                // Fill left → right, clipped to capsule.
                let fillW = StatusMeterLayout.barFillWidth(usedPercent: used)
                if fillW > 0.5 {
                    ctx.saveGState()
                    trackPath.addClip()
                    ink.withAlphaComponent(0.95).setFill()
                    NSBezierPath(rect: NSRect(x: barX, y: barY, width: fillW, height: barH)).fill()
                    ctx.restoreGState()
                }
            } else {
                let textY = (height - textSize.height) / 2
                let textX = columnX
                nsText.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)
            }

            return true
        }

        // System adapts black template → black or white against the menu bar.
        image.isTemplate = true
        image.size = size
        return image
    }

    private static func tintedImage(_ image: NSImage, color: NSColor, size: NSSize) -> NSImage? {
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            image.draw(in: rect)
            ctx.setBlendMode(.sourceIn)
            color.setFill()
            ctx.fill(rect)
            return true
        }
        return img
    }
}
