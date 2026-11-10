// @vitest-environment jsdom
import { describe, it, expect, beforeEach } from "vitest";

const { Ticker, Cities } = require("../app.js");

// jsdom has no real layout engine (scrollWidth/clientWidth are always 0)
// and no ResizeObserver — stub both so the ticker's own static-vs-scrolling
// decision is deterministic and driven only by what each test sets.
let containerWidthPx = 0;
const TILE_WIDTH = 150;

beforeEach(() => {
  if (!("ResizeObserver" in globalThis)) {
    globalThis.ResizeObserver = class {
      observe() {}
      disconnect() {}
    };
  }
  // Re-defining these each test is harmless (configurable: true) and keeps
  // the getters simple — no need to guard against "already defined".
  Object.defineProperty(HTMLElement.prototype, "clientWidth", {
    configurable: true,
    get() {
      return this.id === "ticker" ? containerWidthPx : 0;
    },
  });
  Object.defineProperty(HTMLElement.prototype, "scrollWidth", {
    configurable: true,
    get() {
      return this.id === "tickerTrack" ? this.children.length * TILE_WIDTH : 0;
    },
  });

  document.body.innerHTML = `<footer id="ticker"><div id="tickerTrack"></div></footer>`;
});

const TEST_CITIES = [
  { name: "New York", tz: "America/New_York" },
  { name: "London", tz: "Europe/London" },
  { name: "Paris", tz: "Europe/Paris" },
  { name: "Kyiv", tz: "Europe/Kyiv" },
  { name: "Tokyo", tz: "Asia/Tokyo" },
];

describe("Ticker", () => {
  it("scrolling case: every tile has its time filled in immediately on rebuild, not just the first pass", () => {
    // Regression: the ticker used to duplicate its tile set (for the
    // seamless scroll loop) a frame *after* main()'s one synchronous
    // tickClocks() call had already run, so the duplicate pass's tiles
    // rendered with blank time text until the next clock-aligned tick (up
    // to a second later) — "other global cities time is not showing up".
    containerWidthPx = 100; // narrow: forces the scrolling/duplicate path
    Cities.list = TEST_CITIES;
    Ticker.init();

    const timeEls = Array.from(document.querySelectorAll(".city-tile__time"));
    expect(timeEls.length).toBeGreaterThan(TEST_CITIES.length);
    for (const el of timeEls) {
      expect(el.textContent).toMatch(/^\d{2}:\d{2}$/);
    }
  });

  it("static case: the centered layout is applied synchronously, with no one-frame flash of the unclassified layout", () => {
    // Regression: deciding static-vs-scrolling inside requestAnimationFrame
    // meant the browser could paint one frame of the ticker left-aligned
    // (its layout before classification) before it snapped to centered a
    // moment later — a visible "jitter" on every load/resize.
    containerWidthPx = 10000; // wide: everything fits in one pass
    Cities.list = TEST_CITIES;
    Ticker.init();

    const container = document.getElementById("ticker");
    expect(container.classList.contains("ticker--static")).toBe(true);

    const timeEls = Array.from(document.querySelectorAll(".city-tile__time"));
    expect(timeEls.length).toBe(TEST_CITIES.length);
    for (const el of timeEls) {
      expect(el.textContent).toMatch(/^\d{2}:\d{2}$/);
    }
  });

  it("empty city list: clears itself without throwing", () => {
    containerWidthPx = 500;
    Cities.list = [];
    expect(() => Ticker.init()).not.toThrow();
    expect(document.querySelectorAll(".city-tile").length).toBe(0);
  });
});
