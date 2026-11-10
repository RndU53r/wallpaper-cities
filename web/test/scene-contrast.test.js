// @vitest-environment jsdom
import { describe, it, expect, beforeEach } from "vitest";

const { Scene } = require("../app.js");

let fakeImageData;

function solidPixels(r, g, b, count = 24 * 8) {
  const data = new Uint8ClampedArray(count * 4);
  for (let i = 0; i < data.length; i += 4) {
    data[i] = r;
    data[i + 1] = g;
    data[i + 2] = b;
    data[i + 3] = 255;
  }
  return data;
}

beforeEach(() => {
  document.body.innerHTML = `<footer id="ticker"></footer>`;
  Scene.tickerEl = document.getElementById("ticker");
  Scene.canvas = { width: 400, height: 300 };
  Scene._sampleCtx = undefined;

  // jsdom doesn't implement canvas rendering — stub just enough of the 2D
  // context surface for _sampleTickerContrast's offscreen-canvas readback
  // (a real browser's actual pixels are what app.js's own "set a bright/
  // dark monument photo" live test exercises; this covers the threshold
  // and class-toggling logic in isolation).
  HTMLCanvasElement.prototype.getContext = function () {
    return {
      drawImage: () => {},
      getImageData: () => ({ data: fakeImageData }),
    };
  };

  Scene.tickerEl.getBoundingClientRect = () => ({ left: 0, top: 0, width: 300, height: 60, right: 300, bottom: 60 });
});

describe("Scene._sampleTickerContrast", () => {
  it("switches the ticker to on-dark when the sampled background is dark", () => {
    // Regression: the ticker used to always use the Day/Night chrome
    // theme's own ink color, which could land near-black text over a dark
    // user-supplied monument photo regardless of this sample.
    fakeImageData = solidPixels(10, 10, 10);
    Scene._sampleTickerContrast(400, 300);
    expect(Scene.tickerEl.classList.contains("ticker--on-dark")).toBe(true);
    expect(Scene.tickerEl.classList.contains("ticker--on-light")).toBe(false);
  });

  it("switches the ticker to on-light when the sampled background is bright", () => {
    fakeImageData = solidPixels(240, 235, 225);
    Scene._sampleTickerContrast(400, 300);
    expect(Scene.tickerEl.classList.contains("ticker--on-light")).toBe(true);
    expect(Scene.tickerEl.classList.contains("ticker--on-dark")).toBe(false);
  });

  it("flips classes correctly when sampled background switches from dark to light", () => {
    fakeImageData = solidPixels(5, 5, 5);
    Scene._sampleTickerContrast(400, 300);
    expect(Scene.tickerEl.classList.contains("ticker--on-dark")).toBe(true);

    fakeImageData = solidPixels(250, 248, 245);
    Scene._sampleTickerContrast(400, 300);
    expect(Scene.tickerEl.classList.contains("ticker--on-dark")).toBe(false);
    expect(Scene.tickerEl.classList.contains("ticker--on-light")).toBe(true);
  });

  it("does nothing (and doesn't throw) if the ticker has zero size", () => {
    Scene.tickerEl.getBoundingClientRect = () => ({ left: 0, top: 0, width: 0, height: 0, right: 0, bottom: 0 });
    fakeImageData = solidPixels(10, 10, 10);
    expect(() => Scene._sampleTickerContrast(400, 300)).not.toThrow();
    expect(Scene.tickerEl.classList.contains("ticker--on-dark")).toBe(false);
    expect(Scene.tickerEl.classList.contains("ticker--on-light")).toBe(false);
  });
});
