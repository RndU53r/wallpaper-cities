import { describe, it, expect } from "vitest";

const { zonedParts, zonedTimeToUtc, civilDayNumber, dayDeltaLabel } = require("../app.js");

describe("zonedTimeToUtc / zonedParts round-trip", () => {
  it("round-trips a fixed-offset zone (Asia/Kolkata, UTC+5:30)", () => {
    const at = zonedTimeToUtc("Asia/Kolkata", 2026, 11, 10, 18, 0);
    const read = zonedParts("Asia/Kolkata", at);
    expect([read.year, read.month, read.day, read.hour, read.minute]).toEqual([2026, 11, 10, 18, 0]);
  });

  it("round-trips a DST-observing zone on both sides of the transition (America/New_York)", () => {
    // 2026-03-08 is DST "spring forward" day for America/New_York.
    const before = zonedTimeToUtc("America/New_York", 2026, 3, 1, 9, 30);
    expect(zonedParts("America/New_York", before)).toMatchObject({ month: 3, day: 1, hour: 9, minute: 30 });

    const after = zonedTimeToUtc("America/New_York", 2026, 3, 15, 9, 30);
    expect(zonedParts("America/New_York", after)).toMatchObject({ month: 3, day: 15, hour: 9, minute: 30 });
  });

  it("matches known UTC offsets for a fixed instant", () => {
    // 2026-11-10 12:30 UTC, read back in a handful of zones.
    const instant = new Date(Date.UTC(2026, 10, 10, 12, 30));
    expect(zonedParts("Asia/Kolkata", instant)).toMatchObject({ hour: 18, minute: 0 }); // UTC+5:30
    expect(zonedParts("America/New_York", instant)).toMatchObject({ hour: 7, minute: 30 }); // UTC-5 (standard time in Nov)
    expect(zonedParts("Asia/Tokyo", instant)).toMatchObject({ day: 10, hour: 21, minute: 30 }); // UTC+9, same day
  });
});

describe("dayDeltaLabel", () => {
  it("is null when both zones share the same calendar date", () => {
    const at = zonedTimeToUtc("Asia/Kolkata", 2026, 11, 10, 18, 0);
    expect(dayDeltaLabel("Europe/London", "Asia/Kolkata", at)).toBeNull();
  });

  it("is +1 for a city already into tomorrow relative to the anchor", () => {
    // Regression case found while testing the feature live: 23:00 in Delhi
    // is 02:30 the next day in Tokyo.
    const at = zonedTimeToUtc("Asia/Kolkata", 2026, 11, 10, 23, 0);
    expect(dayDeltaLabel("Asia/Tokyo", "Asia/Kolkata", at)).toBe("+1");
  });

  it("flips sign when the anchor itself is the city that's ahead", () => {
    const at = zonedTimeToUtc("Asia/Kolkata", 2026, 11, 10, 23, 0);
    expect(dayDeltaLabel("Asia/Kolkata", "Asia/Tokyo", at)).toBe("-1");
  });

  it("civilDayNumber increases by exactly 1 per calendar day", () => {
    expect(civilDayNumber(2026, 11, 11) - civilDayNumber(2026, 11, 10)).toBe(1);
    expect(civilDayNumber(2026, 12, 1) - civilDayNumber(2026, 11, 30)).toBe(1);
  });
});
