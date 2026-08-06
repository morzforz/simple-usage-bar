// PopoverUsageBarStyleTests.swift
// Drives shipped popover bar style + band geometry (yellow-orange headroom segment).

import XCTest
@testable import SimpleUsageBar

final class PopoverUsageBarStyleTests: XCTestCase {
    func testHeadroomStyleNameIsYellowOrange() {
        XCTAssertEqual(PopoverUsageBarStyle.headroomStyleName, "yellowOrange")
    }

    func testHeadroomColorSRGBIsYellowOrange() {
        let c = PopoverUsageBarStyle.headroomColorSRGB
        // Yellow-orange: high red, mid green, low blue — not pure yellow and not monochrome gray.
        // Dimmer than full-bright (red < 1.0) so used fill stays primary.
        XCTAssertEqual(c.red, 0.82, accuracy: 0.001)
        XCTAssertEqual(c.green, 0.48, accuracy: 0.001)
        XCTAssertEqual(c.blue, 0.12, accuracy: 0.001)
        XCTAssertLessThan(c.red, 1.0)
        XCTAssertGreaterThan(c.red, c.green)
        XCTAssertGreaterThan(c.green, c.blue)
    }

    func testHeadroomOpacityIsFaintButVisible() {
        // Fainter than solid used fill; still above track-level invisibility.
        XCTAssertEqual(PopoverUsageBarStyle.headroomOpacity, 0.58, accuracy: 0.001)
        XCTAssertGreaterThan(PopoverUsageBarStyle.headroomOpacity, 0.3)
        XCTAssertLessThan(PopoverUsageBarStyle.headroomOpacity, 1.0)
    }

    func testHeadroomColorMatchesSRGBToken() {
        // Color view token must stay in lockstep with testable sRGB components.
        let c = PopoverUsageBarStyle.headroomColorSRGB
        XCTAssertEqual(c.red, 0.82, accuracy: 0.001)
        // Used-fill band yellow (.yellow) is not our headroom token name.
        XCTAssertNotEqual(PopoverUsageBarStyle.headroomStyleName, UsageBand.elevated.styleName)
        XCTAssertNotEqual(PopoverUsageBarStyle.headroomStyleName, UsageBand.normal.styleName)
        XCTAssertNotEqual(PopoverUsageBarStyle.headroomStyleName, UsageBand.high.styleName)
    }

    func testShowsHeadroomSegmentMatchesMenubarRule() {
        XCTAssertTrue(PopoverUsageBarStyle.showsHeadroomSegment(usedPercent: 20, headroomPercent: 60))
        XCTAssertFalse(PopoverUsageBarStyle.showsHeadroomSegment(usedPercent: 70, headroomPercent: 0))
        XCTAssertFalse(PopoverUsageBarStyle.showsHeadroomSegment(usedPercent: 40, headroomPercent: nil))
        XCTAssertFalse(PopoverUsageBarStyle.showsHeadroomSegment(usedPercent: 50, headroomPercent: 50))
        // Same gate as menubar pure helper.
        XCTAssertEqual(
            PopoverUsageBarStyle.showsHeadroomSegment(usedPercent: 20, headroomPercent: 60),
            StatusMeterLayout.showsHeadroomIntermediate(usedPercent: 20, headroomPercent: 60)
        )
    }

    func testBandsReuseShippedLayoutGeometry() {
        let track: CGFloat = 200
        let bands = PopoverUsageBarStyle.bands(
            usedPercent: 20,
            headroomPercent: 60,
            trackWidth: track
        )
        let expected = StatusMeterLayout.barBands(
            usedPercent: 20,
            headroomPercent: 60,
            trackWidth: track
        )
        XCTAssertEqual(bands, expected)
        XCTAssertTrue(bands.showsIntermediate)
        XCTAssertEqual(bands.fillWidth, track * 0.20, accuracy: 0.001)
        XCTAssertEqual(bands.intermediateWidth, track * 0.40, accuracy: 0.001)
    }

    func testBandsOmitWhenHeadroomNilOrNotGreater() {
        let nilHead = PopoverUsageBarStyle.bands(usedPercent: 43, headroomPercent: nil, trackWidth: 100)
        XCTAssertFalse(nilHead.showsIntermediate)
        XCTAssertEqual(nilHead.intermediateWidth, 0, accuracy: 0.001)

        let low = PopoverUsageBarStyle.bands(usedPercent: 70, headroomPercent: 10, trackWidth: 100)
        XCTAssertFalse(low.showsIntermediate)
        XCTAssertEqual(low.intermediateWidth, 0, accuracy: 0.001)
    }

    func testTooltipUsageOnlyWhenHeadroomNil() {
        let text = PopoverUsageBarStyle.tooltipText(usedPercent: 43, headroomPercent: nil)
        XCTAssertTrue(text.lowercased().contains("used"))
        XCTAssertTrue(text.contains("43%"))
        XCTAssertFalse(text.lowercased().contains("headroom"))
        XCTAssertFalse(text.lowercased().contains("yellow-orange"))
    }

    func testTooltipUsageOnlyWhenUsedExceedsOrEqualsHeadroom() {
        let exceeds = PopoverUsageBarStyle.tooltipText(usedPercent: 70, headroomPercent: 0)
        XCTAssertTrue(exceeds.contains("70%"))
        XCTAssertFalse(exceeds.lowercased().contains("headroom"))
        XCTAssertFalse(exceeds.lowercased().contains("yellow-orange"))

        let equal = PopoverUsageBarStyle.tooltipText(usedPercent: 50, headroomPercent: 50)
        XCTAssertTrue(equal.contains("50%"))
        XCTAssertFalse(equal.lowercased().contains("headroom"))
    }

    func testTooltipIncludesHeadroomWhenSegmentShown() {
        let text = PopoverUsageBarStyle.tooltipText(usedPercent: 20, headroomPercent: 60)
        // Used + headroom colors and percents.
        XCTAssertTrue(text.lowercased().contains("used"))
        XCTAssertTrue(text.contains("20%"))
        XCTAssertTrue(text.lowercased().contains("headroom"))
        XCTAssertTrue(text.lowercased().contains("yellow-orange"))
        XCTAssertTrue(text.contains("60%"))
        // Multi-line when both segments apply.
        XCTAssertTrue(text.contains("\n"))
        // Same gate as visible intermediate band.
        XCTAssertTrue(PopoverUsageBarStyle.showsHeadroomSegment(usedPercent: 20, headroomPercent: 60))
    }

    func testHoverCalloutPresentationIsEnabledForMenuBarExtra() {
        // Documented fix: `.help` is unreliable in MenuBarExtra windows; ship hover callout.
        XCTAssertTrue(PopoverUsageBarStyle.presentsTooltipAsHoverCallout)
        XCTAssertEqual(
            PopoverUsageBarStyle.hoverCalloutAccessibilityID,
            "usageProgressTooltip"
        )
        // Callout content is still the pure tooltip builder (not a separate wording path).
        let text = PopoverUsageBarStyle.tooltipText(usedPercent: 15, headroomPercent: 55)
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("15%"))
        XCTAssertTrue(text.contains("55%"))
    }

    func testNestedPopoverIsDeferredWithReason() {
        // Nested tip popover over MenuBarExtra is intentionally not wired (focus/dismiss races).
        XCTAssertFalse(PopoverUsageBarStyle.usesNestedPopover)
        XCTAssertFalse(PopoverUsageBarStyle.nestedPopoverDeferralReason.isEmpty)
        XCTAssertTrue(
            PopoverUsageBarStyle.nestedPopoverDeferralReason.lowercased().contains("menubarextra")
                || PopoverUsageBarStyle.nestedPopoverDeferralReason.lowercased().contains("nested")
        )
    }

    func testHoverDebounceDelaysStabilizeShowAndHide() {
        // Hide delay must be longer than show so bar→tip motion does not flicker.
        XCTAssertGreaterThan(
            PopoverUsageBarStyle.hoverHideDelayNanoseconds,
            PopoverUsageBarStyle.hoverShowDelayNanoseconds
        )
        XCTAssertGreaterThan(PopoverUsageBarStyle.hoverShowDelayNanoseconds, 0)
        XCTAssertGreaterThan(PopoverUsageBarStyle.barVisualHeight, 0)
        XCTAssertGreaterThan(PopoverUsageBarStyle.barHoverVerticalPadding, 0)
        // Contiguous hover region policy: tip is in-window callout, not a nested popover.
        XCTAssertTrue(PopoverUsageBarStyle.presentsTooltipAsHoverCallout)
        XCTAssertFalse(PopoverUsageBarStyle.usesNestedPopover)
    }
}
