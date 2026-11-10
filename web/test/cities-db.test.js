import { describe, it, expect } from "vitest";

const { CITIES_DB, cityForTimeZone, nearestCity } = require("../cities-db.js");

describe("cityForTimeZone", () => {
  it("resolves known legacy IANA aliases to the curated canonical entry", () => {
    // Regression: a device reporting Intl.DateTimeFormat().resolvedOptions()
    // .timeZone === "Asia/Calcutta" (observed on a real device in Delhi) used
    // to miss the curated dataset entirely and fall back to a raw-string
    // label ("Calcutta") instead of the intended "Delhi" override.
    expect(cityForTimeZone("Asia/Calcutta")?.name).toBe("Delhi");
    expect(cityForTimeZone("Asia/Calcutta")?.tz).toBe("Asia/Kolkata");

    // Same bug class for Kyiv, which is in the default city strip.
    expect(cityForTimeZone("Europe/Kiev")?.name).toBe("Kyiv");
    expect(cityForTimeZone("Europe/Kiev")?.tz).toBe("Europe/Kyiv");
  });

  it("still resolves canonical (non-aliased) zones directly", () => {
    expect(cityForTimeZone("Asia/Kolkata")?.name).toBe("Delhi");
    expect(cityForTimeZone("Europe/Kyiv")?.name).toBe("Kyiv");
    expect(cityForTimeZone("Asia/Tokyo")?.name).toBe("Tokyo");
  });

  it("returns null for a zone with no curated entry or alias", () => {
    expect(cityForTimeZone("Pacific/Not_A_Real_Zone")).toBeNull();
  });
});

describe("CITIES_DB", () => {
  it("every curated city has a non-empty name and a plausible lat/lon", () => {
    for (const city of CITIES_DB) {
      expect(city.name.trim().length, `city with tz ${city.tz} has no name`).toBeGreaterThan(0);
      expect(city.tz, `${city.name}'s tz "${city.tz}" doesn't look like an IANA zone`).toContain("/");
      expect(city.lat, `${city.name}'s lat is out of range`).toBeGreaterThanOrEqual(-90);
      expect(city.lat, `${city.name}'s lat is out of range`).toBeLessThanOrEqual(90);
      expect(city.lon, `${city.name}'s lon is out of range`).toBeGreaterThanOrEqual(-180);
      expect(city.lon, `${city.name}'s lon is out of range`).toBeLessThanOrEqual(180);
    }
  });
});

describe("nearestCity", () => {
  it("finds Delhi for a coordinate near central Delhi", () => {
    expect(nearestCity(28.6, 77.2)?.name).toBe("Delhi");
  });
});
