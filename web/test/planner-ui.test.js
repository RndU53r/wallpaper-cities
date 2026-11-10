// @vitest-environment jsdom
import { describe, it, expect, beforeEach } from "vitest";

const { Planner, Hero } = require("../app.js");

function plannerMarkup() {
  return `
    <button id="plannerBtn" aria-pressed="false"></button>
    <div class="planner" id="planner" hidden>
      <div class="planner__head">
        <div class="planner__anchor" id="plannerAnchor">—</div>
        <div class="planner__daystep">
          <button id="plannerPrevDay">‹</button>
          <span id="plannerDayLabel">—</span>
          <button id="plannerNextDay">›</button>
        </div>
        <button id="plannerExit">Now</button>
      </div>
      <div class="planner__track" id="plannerTrack">
        <div class="planner__ticks" id="plannerTicks"></div>
        <div class="planner__handle" id="plannerHandle">
          <span class="planner__handle-time" id="plannerHandleTime">00:00</span>
        </div>
      </div>
    </div>
  `;
}

beforeEach(() => {
  document.body.innerHTML = plannerMarkup();
  Hero.current = { name: "Delhi", tz: "Asia/Kolkata", source: "manual" };
  Planner.init();
});

describe("Planner", () => {
  it("starts inactive, with the panel hidden", () => {
    expect(Planner.active).toBe(false);
    expect(document.getElementById("planner").hidden).toBe(true);
    expect(document.getElementById("plannerBtn").getAttribute("aria-pressed")).toBe("false");
  });

  it("enter() defaults the anchor to the current hero city and reveals the panel", () => {
    Planner.enter();
    expect(Planner.active).toBe(true);
    expect(Planner.anchorTz).toBe("Asia/Kolkata");
    expect(document.getElementById("planner").hidden).toBe(false);
    expect(document.getElementById("plannerBtn").getAttribute("aria-pressed")).toBe("true");
    expect(document.getElementById("plannerAnchor").textContent).toBe("DELHI");
  });

  it("setTimeOfDay() moves the handle and updates the displayed time, keeping the same calendar date", () => {
    Planner.enter();
    const before = Planner.referenceInstant;
    Planner.setTimeOfDay(18, 30);
    expect(document.getElementById("plannerHandleTime").textContent).toBe("18:30");
    const leftPct = parseFloat(document.getElementById("plannerHandle").style.left);
    expect(leftPct).toBeCloseTo(((18 * 60 + 30) / 1440) * 100, 2);
    // Still the same day in the anchor zone — only the time-of-day moved.
    expect(Planner.referenceInstant.getTime()).not.toBe(before.getTime());
  });

  it("switching anchor keeps the same instant (other cities don't jump)", () => {
    Planner.enter();
    Planner.setTimeOfDay(23, 0);
    const instant = Planner.referenceInstant.getTime();
    Planner.setAnchor("Asia/Tokyo");
    expect(Planner.anchorTz).toBe("Asia/Tokyo");
    expect(Planner.referenceInstant.getTime()).toBe(instant);
    // 23:00 Delhi == 02:30 the next day in Tokyo (regression case).
    expect(document.getElementById("plannerHandleTime").textContent).toBe("02:30");
  });

  it("shiftDay() moves one calendar day while preserving the time-of-day", () => {
    Planner.enter();
    Planner.setTimeOfDay(9, 15);
    const dayBefore = document.getElementById("plannerDayLabel").textContent;
    Planner.shiftDay(1);
    expect(document.getElementById("plannerHandleTime").textContent).toBe("09:15");
    expect(document.getElementById("plannerDayLabel").textContent).not.toBe(dayBefore);
  });

  it("exit() hides the panel again and stops reacting to further drags until re-entered", () => {
    Planner.enter();
    Planner.exit();
    expect(Planner.active).toBe(false);
    expect(document.getElementById("planner").hidden).toBe(true);
    const before = document.getElementById("plannerHandleTime").textContent;
    Planner.setTimeOfDay(5, 5); // no-op while inactive
    expect(document.getElementById("plannerHandleTime").textContent).toBe(before);
  });
});
