// StatusMeterLayoutTests.swift
// Pure geometry for composited menubar meter (CodexBar-style single image).

import AppKit
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

    func testShowsHeadroomIntermediateOnlyWhenHeadroomExceedsUsed() {
        XCTAssertTrue(StatusMeterLayout.showsHeadroomIntermediate(usedPercent: 20, headroomPercent: 60))
        XCTAssertFalse(StatusMeterLayout.showsHeadroomIntermediate(usedPercent: 70, headroomPercent: 0))
        XCTAssertFalse(StatusMeterLayout.showsHeadroomIntermediate(usedPercent: 50, headroomPercent: 50))
        XCTAssertFalse(StatusMeterLayout.showsHeadroomIntermediate(usedPercent: 40, headroomPercent: nil))
        XCTAssertFalse(StatusMeterLayout.showsHeadroomIntermediate(usedPercent: 10, headroomPercent: 5))
    }

    func testBarBandsIntermediateWhenHeadroomAboveUsed() {
        // used 20%, headroom 60% → fill 0.2×28, intermediate (0.6−0.2)×28
        let bands = StatusMeterLayout.barBands(usedPercent: 20, headroomPercent: 60)
        XCTAssertTrue(bands.showsIntermediate)
        XCTAssertEqual(bands.fillWidth, 28 * 0.20, accuracy: 0.0001)
        XCTAssertEqual(bands.intermediateWidth, 28 * 0.40, accuracy: 0.0001)
        // Intermediate ends at headroom mark: fill + intermediate = headroom fraction of track.
        XCTAssertEqual(bands.fillWidth + bands.intermediateWidth, 28 * 0.60, accuracy: 0.0001)
    }

    func testBarBandsOmitsIntermediateWhenHeadroomNilOrNotGreater() {
        let noHeadroom = StatusMeterLayout.barBands(usedPercent: 43, headroomPercent: nil)
        XCTAssertFalse(noHeadroom.showsIntermediate)
        XCTAssertEqual(noHeadroom.intermediateWidth, 0, accuracy: 0.0001)
        XCTAssertEqual(noHeadroom.fillWidth, 28 * 0.43, accuracy: 0.0001)

        let headroomBelow = StatusMeterLayout.barBands(usedPercent: 70, headroomPercent: 0)
        XCTAssertFalse(headroomBelow.showsIntermediate)
        XCTAssertEqual(headroomBelow.intermediateWidth, 0, accuracy: 0.0001)
        XCTAssertEqual(headroomBelow.fillWidth, 28 * 0.70, accuracy: 0.0001)

        let equal = StatusMeterLayout.barBands(usedPercent: 40, headroomPercent: 40)
        XCTAssertFalse(equal.showsIntermediate)
        XCTAssertEqual(equal.intermediateWidth, 0, accuracy: 0.0001)
    }

    func testRendererAlphasAreOrderedTrackIntermediateFill() {
        // Intermediate shade must sit between unfilled track and used fill.
        XCTAssertLessThan(StatusMeterImageRenderer.trackAlpha, StatusMeterImageRenderer.intermediateAlpha)
        XCTAssertLessThan(StatusMeterImageRenderer.intermediateAlpha, StatusMeterImageRenderer.fillAlpha)
    }

    func testRendererAcceptsHeadroomParameter() {
        let withHeadroom = StatusMeterImageRenderer.makeImage(
            percentText: "20%",
            usedPercent: 20,
            headroomPercent: 60,
            logo: nil
        )
        let without = StatusMeterImageRenderer.makeImage(
            percentText: "20%",
            usedPercent: 20,
            headroomPercent: nil,
            logo: nil
        )
        XCTAssertTrue(withHeadroom.isTemplate)
        XCTAssertTrue(without.isTemplate)
        XCTAssertEqual(withHeadroom.size.width, without.size.width, accuracy: 0.01)
        // Geometry still decides bands via shipped helper.
        let bands = StatusMeterLayout.barBands(usedPercent: 20, headroomPercent: 60)
        XCTAssertTrue(bands.showsIntermediate)
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
            logo: nil
        )
        XCTAssertEqual(image.size.height, StatusMeterLayout.canvasHeight, accuracy: 0.01)
        XCTAssertGreaterThan(image.size.width, 0)
    }

    func testStatusImageIsTemplateMonochrome() {
        let image = StatusMeterImageRenderer.makeImage(
            percentText: "43%",
            usedPercent: 43,
            logo: nil
        )
        XCTAssertTrue(image.isTemplate, "status image must be template for system black/white adaptation")
        XCTAssertEqual(StatusMeterImageRenderer.templateInk, NSColor.black)
    }

    func testStatusImageStaysTemplateWithoutBar() {
        let image = StatusMeterImageRenderer.makeImage(
            percentText: "—",
            usedPercent: nil,
            logo: nil
        )
        XCTAssertTrue(image.isTemplate)
    }
}
