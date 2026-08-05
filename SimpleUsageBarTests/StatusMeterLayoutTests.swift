// StatusMeterLayoutTests.swift
// Pure geometry for composited menubar meter (CodexBar-style single image).

import XCTest
@testable import SimpleUsageBar

final class StatusMeterLayoutTests: XCTestCase {
    func testCanvasHeightFitsMenuBar() {
        // System status item working height is ~18–22pt; we target 18.
        XCTAssertEqual(StatusMeterLayout.canvasHeight, 18)
        XCTAssertLessThanOrEqual(
            StatusMeterLayout.percentFontSize + StatusMeterLayout.percentToBarSpacing + StatusMeterLayout.barHeight,
            StatusMeterLayout.canvasHeight
        )
    }

    func testBarFillWidthMatchesShippedHelper() {
        XCTAssertEqual(StatusMeterLayout.barFillWidth(usedPercent: 43), 28 * 0.43, accuracy: 0.0001)
        XCTAssertEqual(StatusMeterLayout.barFillWidth(usedPercent: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(StatusMeterLayout.barFillWidth(usedPercent: 100), 28, accuracy: 0.0001)
        XCTAssertEqual(StatusMeterLayout.barFillWidth(usedPercent: 150), 28, accuracy: 0.0001)
        XCTAssertEqual(StatusMeterLayout.barFillWidth(usedPercent: -10), 0, accuracy: 0.0001)
    }

    func testCanvasWidthGrowsWithPercentText() {
        // Without the bar, width tracks text length.
        let narrow = StatusMeterLayout.canvasWidth(percentText: "9%", showsBar: false)
        let wide = StatusMeterLayout.canvasWidth(percentText: "100%", showsBar: false)
        XCTAssertGreaterThan(wide, narrow)
        XCTAssertGreaterThan(narrow, StatusMeterLayout.logoSide)
        // With the bar, short labels are floored to bar width so 9% and 43% match.
        let withBarShort = StatusMeterLayout.canvasWidth(percentText: "9%", showsBar: true)
        let withBarMid = StatusMeterLayout.canvasWidth(percentText: "43%", showsBar: true)
        XCTAssertEqual(withBarShort, withBarMid, accuracy: 0.01)
    }

    func testCanvasWidthWithBarAtLeastBarWidth() {
        // Even for short "1%", column must fit the bar track.
        let w = StatusMeterLayout.canvasWidth(percentText: "1%", showsBar: true)
        let minExpected =
            StatusMeterLayout.horizontalPadding
            + StatusMeterLayout.logoSide
            + StatusMeterLayout.logoTextSpacing
            + StatusMeterLayout.barWidth
            + StatusMeterLayout.horizontalPadding
        XCTAssertGreaterThanOrEqual(w, minExpected - 0.01)
    }

    func testRendererProducesNonEmptyImageWithBar() {
        let image = StatusMeterImageRenderer.makeImage(
            percentText: "43%",
            usedPercent: 43,
            tint: .labelColor,
            logo: nil
        )
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertEqual(image.size.height, StatusMeterLayout.canvasHeight, accuracy: 0.01)
        // Image must be wide enough for logo column + bar.
        XCTAssertGreaterThanOrEqual(image.size.width, StatusMeterLayout.barWidth)
    }

    func testRendererProducesImageWithoutBar() {
        let image = StatusMeterImageRenderer.makeImage(
            percentText: "…",
            usedPercent: nil,
            tint: .labelColor,
            logo: nil
        )
        XCTAssertEqual(image.size.height, StatusMeterLayout.canvasHeight, accuracy: 0.01)
        XCTAssertGreaterThan(image.size.width, 0)
    }
}
