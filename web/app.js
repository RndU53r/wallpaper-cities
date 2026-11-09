"use strict";

/*
 * World Time — shared Motion UI.
 * Pure HTML/CSS/JS, no build step. The only network-ish capability used is
 * the browser Geolocation API (a coarse lat/lon fix, requested from the OS,
 * never sent anywhere) — reverse geocoding that fix to a city is done
 * entirely on-device against web/cities-db.js, no network call involved.
 */

// ---------------------------------------------------------------------------
// Tunables
// ---------------------------------------------------------------------------

const CITY_STORAGE_KEY = "worldtime.cities.v2";
const HERO_OVERRIDE_KEY = "worldtime.heroOverride.v1";
const MONUMENT_STORAGE_KEY = "worldtime.monuments.v1";
const THEME_STORAGE_KEY = "worldtime.theme.v1";
const THEME_MODES = ["auto", "system", "day", "night"];
const MONUMENT_MAX_DIM = 1600;
const MONUMENT_JPEG_QUALITY = 0.82;
const MIN_CITIES = 4;
const MAX_CITIES = 6;
const FOLD_HALF_MS = 175; // ~350ms total fold, within the requested 300-500ms
const GEO_TIMEOUT_MS = 8000;
const GEO_MAX_USEFUL_KM = 300; // beyond this, the nearest curated city is too far to trust
const GEO_RECHECK_MS = 5 * 60 * 1000; // re-evaluate for travel every 5 minutes

const LOCAL_TZ = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";

// ---------------------------------------------------------------------------
// Small utilities
// ---------------------------------------------------------------------------

function clamp01(v) { return Math.max(0, Math.min(1, v)); }
function lerp(a, b, t) { return a + (b - a) * t; }

function hashString(str) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Last-resort label for a timezone with no curated dataset entry. */
function friendlyNameFromTz(tz) {
  const last = tz.includes("/") ? tz.split("/").pop() : tz;
  return last.replace(/_/g, " ");
}

/** The display name to use for a timezone: curated dataset first (this is
 *  what makes India show "Delhi" rather than the raw zone id "Kolkata"),
 *  falling back to a derived name only for zones outside the curated set. */
function cityNameForTz(tz) {
  const entry = cityForTimeZone(tz);
  return entry ? entry.name : friendlyNameFromTz(tz);
}

function prefersReducedMotion() {
  return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

function localHourFraction(tz) {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, hour: "numeric", minute: "numeric", second: "numeric", hour12: false,
  });
  const parts = fmt.formatToParts(new Date());
  const get = (type) => Number(parts.find((p) => p.type === type).value);
  const h = get("hour") % 24;
  const m = get("minute");
  const s = get("second");
  return h + m / 60 + s / 3600;
}

function hhmmss(tz) {
  const fmt = new Intl.DateTimeFormat("en-GB", {
    timeZone: tz, hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false,
  });
  const parts = fmt.formatToParts(new Date());
  const get = (type) => parts.find((p) => p.type === type).value;
  return { h: get("hour"), m: get("minute"), s: get("second") };
}

function hhmm(tz) {
  const fmt = new Intl.DateTimeFormat("en-GB", {
    timeZone: tz, hour: "2-digit", minute: "2-digit", hour12: false,
  });
  const parts = fmt.formatToParts(new Date());
  const get = (type) => parts.find((p) => p.type === type).value;
  return `${get("hour")}:${get("minute")}`;
}

/** Fires a clock-aligned tick at (as close as possible to) every second
 *  boundary, re-reading Date.now() each time rather than accumulating a
 *  fixed 1000ms interval — avoids the drift setInterval is prone to under
 *  tab throttling / event-loop jitter. */
function scheduleClockAligned(fn) {
  function run() { fn(); schedule(); }
  function schedule() { setTimeout(run, 1000 - (Date.now() % 1000)); }
  schedule();
}

// ---------------------------------------------------------------------------
// Hero city: geolocation -> on-device reverse geocode -> device timezone ->
// manual override. Never blocks the UI — renders a best-guess immediately.
// ---------------------------------------------------------------------------

const Hero = {
  current: null, // { name, tz, source: 'manual'|'geo'|'devicetz' }

  init() {
    const override = this._loadOverride();
    if (override) {
      this.current = { ...override, source: "manual" };
    } else {
      this.current = this._deviceTzGuess();
    }

    if (!override) this._tryGeolocate();

    setInterval(() => {
      if (this._loadOverride()) return; // manual always wins until cleared
      this._tryGeolocate();
      this._checkDeviceTzChanged();
    }, GEO_RECHECK_MS);
  },

  _deviceTzGuess() {
    const entry = cityForTimeZone(LOCAL_TZ);
    return entry
      ? { name: entry.name, tz: entry.tz, source: "devicetz" }
      : { name: friendlyNameFromTz(LOCAL_TZ), tz: LOCAL_TZ, source: "devicetz" };
  },

  _checkDeviceTzChanged() {
    if (this.current.source !== "devicetz") return;
    const fresh = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (fresh && fresh !== this.current.tz) this._set(this._deviceTzGuess());
  },

  _tryGeolocate() {
    if (!("geolocation" in navigator)) return;
    try {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const match = nearestCity(pos.coords.latitude, pos.coords.longitude);
          if (match && match.distanceKm <= GEO_MAX_USEFUL_KM) {
            this._set({ name: match.name, tz: match.tz, source: "geo" });
          }
          // else: too far from anything curated to trust — keep the
          // current (devicetz) guess rather than show a wrong city.
        },
        () => { /* denied/unavailable — the devicetz guess already rendered */ },
        { enableHighAccuracy: false, timeout: GEO_TIMEOUT_MS, maximumAge: 10 * 60 * 1000 }
      );
    } catch (_) { /* geolocation unsupported in this host — ignore */ }
  },

  setManualOverride(city) {
    if (!city) {
      try { localStorage.removeItem(HERO_OVERRIDE_KEY); } catch (_) {}
      this._set(this._deviceTzGuess());
      this._tryGeolocate();
      return;
    }
    const entry = { name: city.name, tz: city.tz };
    try { localStorage.setItem(HERO_OVERRIDE_KEY, JSON.stringify(entry)); } catch (_) {}
    this._set({ ...entry, source: "manual" });
  },

  _loadOverride() {
    try {
      const raw = localStorage.getItem(HERO_OVERRIDE_KEY);
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      return parsed && parsed.tz ? parsed : null;
    } catch (_) { return null; }
  },

  _set(next) {
    if (this.current && this.current.tz === next.tz && this.current.source === next.source) return;
    this.current = next;
    this._notify();
  },

  onChange(fn) { (this._listeners = this._listeners || []).push(fn); },
  _notify() { (this._listeners || []).forEach((fn) => fn(this.current)); },
};

// Cross-instance sync (multi-display hosts + the configure window share one
// WebView storage/profile — see the `storage` listener further down).
window.addEventListener("storage", (e) => {
  if (e.key !== HERO_OVERRIDE_KEY) return;
  try {
    const parsed = e.newValue ? JSON.parse(e.newValue) : null;
    Hero._set(parsed ? { ...parsed, source: "manual" } : Hero._deviceTzGuess());
  } catch (_) { /* ignore malformed external write */ }
});

// ---------------------------------------------------------------------------
// Theme — the UI chrome's light/dark appearance (distinct from each city's
// own generated day/night sky, which always varies regardless of this).
// ---------------------------------------------------------------------------

const Theme = {
  mode: "auto", // 'auto' (daylight at the hero city) | 'system' | 'day' | 'night'

  init() {
    this.mode = this._load();
    this._apply();

    const media = window.matchMedia && window.matchMedia("(prefers-color-scheme: light)");
    if (media && media.addEventListener) {
      media.addEventListener("change", () => { if (this.mode === "system") this._apply(); });
    }

    Hero.onChange(() => { if (this.mode === "auto") this._apply(); });
    // Daylight shifts continuously even without a hero change (e.g. dawn
    // breaking) — recheck periodically rather than only on hero switches.
    setInterval(() => { if (this.mode === "auto") this._apply(); }, 60 * 1000);
  },

  _load() {
    try {
      const raw = localStorage.getItem(THEME_STORAGE_KEY);
      return THEME_MODES.includes(raw) ? raw : "auto";
    } catch (_) { return "auto"; }
  },

  setMode(mode) {
    if (!THEME_MODES.includes(mode)) return;
    this.mode = mode;
    try { localStorage.setItem(THEME_STORAGE_KEY, mode); } catch (_) {}
    this._apply();
    this._notify();
  },

  _isLight() {
    switch (this.mode) {
      case "day": return true;
      case "night": return false;
      case "system": {
        const media = window.matchMedia && window.matchMedia("(prefers-color-scheme: light)");
        return media ? media.matches : true;
      }
      case "auto":
      default: {
        const tz = (Hero.current && Hero.current.tz) || LOCAL_TZ;
        return skyPalette(localHourFraction(tz)).daylight >= 0.5;
      }
    }
  },

  _apply() {
    document.body.dataset.theme = this._isLight() ? "light" : "dark";
  },

  onChange(fn) { (this._listeners = this._listeners || []).push(fn); },
  _notify() { (this._listeners || []).forEach((fn) => fn(this.mode)); },
};

window.addEventListener("storage", (e) => {
  if (e.key !== THEME_STORAGE_KEY) return;
  Theme.mode = THEME_MODES.includes(e.newValue) ? e.newValue : "auto";
  Theme._apply();
  Theme._notify();
});

// ---------------------------------------------------------------------------
// City strip persistence (4-6 cities, never including the hero city)
// ---------------------------------------------------------------------------

const Cities = {
  list: [],

  init() {
    this.list = this._loadFromStorage() || this._defaultStrip();
    this._save();
  },

  _defaultStrip() {
    const heroTz = Hero.current ? Hero.current.tz : LOCAL_TZ;
    return DEFAULT_STRIP_TZS
      .map((tz) => cityForTimeZone(tz))
      .filter((c) => c && c.tz !== heroTz);
  },

  _loadFromStorage() {
    try {
      const raw = localStorage.getItem(CITY_STORAGE_KEY);
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) && parsed.length ? parsed : null;
    } catch (_) { return null; }
  },

  _save() {
    try { localStorage.setItem(CITY_STORAGE_KEY, JSON.stringify(this.list)); } catch (_) {}
  },

  /** What should actually be displayed: the stored list minus whichever
   *  city the hero is currently showing, so the hero is never duplicated
   *  in the strip even if it's still present in the saved preference. */
  visibleList() {
    const heroTz = Hero.current ? Hero.current.tz : null;
    return this.list.filter((c) => c.tz !== heroTz);
  },

  /** @returns {true|'max'} true on success, 'max' if already at the cap. */
  add(city) {
    if (this.list.some((c) => c.tz === city.tz)) return true;
    if (this.list.length >= MAX_CITIES) return "max";
    this.list.push(city);
    this._save();
    this._notify();
    return true;
  },

  /** @returns {true|'min'} true on success, 'min' if already at the floor. */
  remove(tz) {
    if (this.list.length <= MIN_CITIES) return "min";
    this.list = this.list.filter((c) => c.tz !== tz);
    this._save();
    this._notify();
    return true;
  },

  reorder(fromIndex, toIndex) {
    if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return;
    if (fromIndex >= this.list.length || toIndex >= this.list.length) return;
    const [moved] = this.list.splice(fromIndex, 1);
    this.list.splice(toIndex, 0, moved);
    this._save();
    this._notify();
  },

  onChange(fn) { (this._listeners = this._listeners || []).push(fn); },
  _notify() { (this._listeners || []).forEach((fn) => fn(this.list)); },
};

// Multi-display screensaver hosts (and the native configure sheet) each run
// their own WKWebView/WebView2 instance sharing one storage/profile — the
// standard cross-document `storage` event keeps every instance's city list
// in sync live, with no native bridge code required.
window.addEventListener("storage", (e) => {
  if (e.key !== CITY_STORAGE_KEY || e.newValue == null) return;
  try {
    const parsed = JSON.parse(e.newValue);
    if (Array.isArray(parsed)) {
      Cities.list = parsed;
      Cities._notify();
    }
  } catch (_) { /* ignore malformed external write */ }
});

// ---------------------------------------------------------------------------
// Monument images — a city's background can be a real photo the user
// supplies (their own landmark shot) instead of the generated skyline.
// Stored locally only (as a compressed data URL), never uploaded anywhere.
// ---------------------------------------------------------------------------

/** Downscale + re-encode a user-picked image file client-side, so a handful
 *  of city photos stay comfortably within localStorage's quota. */
function compressImageFile(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(reader.error || new Error("Could not read file"));
    reader.onload = () => {
      const img = new Image();
      img.onerror = () => reject(new Error("Could not decode image"));
      img.onload = () => {
        const scale = Math.min(1, MONUMENT_MAX_DIM / Math.max(img.width, img.height));
        const width = Math.round(img.width * scale);
        const height = Math.round(img.height * scale);
        const canvas = document.createElement("canvas");
        canvas.width = width;
        canvas.height = height;
        canvas.getContext("2d").drawImage(img, 0, 0, width, height);
        resolve(canvas.toDataURL("image/jpeg", MONUMENT_JPEG_QUALITY));
      };
      img.src = reader.result;
    };
    reader.readAsDataURL(file);
  });
}

const Monuments = {
  map: {}, // tz -> data URL

  init() { this.map = this._load(); },

  _load() {
    try {
      const raw = localStorage.getItem(MONUMENT_STORAGE_KEY);
      const parsed = raw ? JSON.parse(raw) : {};
      return parsed && typeof parsed === "object" ? parsed : {};
    } catch (_) { return {}; }
  },

  _save() {
    try {
      localStorage.setItem(MONUMENT_STORAGE_KEY, JSON.stringify(this.map));
    } catch (_) {
      // Likely quota exceeded for the current set of photos — the in-memory
      // copy still works for this session, just won't persist across restarts.
    }
  },

  get(tz) { return this.map[tz] || null; },

  async set(tz, file) {
    const dataUrl = await compressImageFile(file);
    this.map[tz] = dataUrl;
    this._save();
    this._notify(tz);
  },

  remove(tz) {
    delete this.map[tz];
    this._save();
    this._notify(tz);
  },

  onChange(fn) { (this._listeners = this._listeners || []).push(fn); },
  _notify(tz) { (this._listeners || []).forEach((fn) => fn(tz)); },
};

window.addEventListener("storage", (e) => {
  if (e.key !== MONUMENT_STORAGE_KEY) return;
  try {
    Monuments.map = e.newValue ? JSON.parse(e.newValue) : {};
    Monuments._notify(null);
  } catch (_) { /* ignore malformed external write */ }
});

// Decoded-image cache for the canvas scene, keyed by tz. getMonumentImage()
// returns null until decode finishes; the scene's own render loop just
// naturally picks the image up a frame or two later once it's ready.
const _monumentImageCache = new Map();

function getMonumentImage(tz) {
  const dataUrl = Monuments.get(tz);
  if (!dataUrl) return null;
  const cached = _monumentImageCache.get(tz);
  if (cached && cached.src === dataUrl) return cached.complete ? cached : null;
  const img = new Image();
  img.src = dataUrl;
  _monumentImageCache.set(tz, img);
  return img.complete ? img : null;
}

// ---------------------------------------------------------------------------
// Flip digit — real split-flap: two static backdrop halves (always the new
// value) plus two animated flaps (outgoing top folds away, incoming bottom
// folds in), each clipped to its own half-height box.
// ---------------------------------------------------------------------------

class FlipDigit {
  constructor(el) {
    this.el = el;
    this.topStatic = el.querySelector(".flip__half--top .flip__char");
    this.bottomStatic = el.querySelector(".flip__half--bottom .flip__char");
    this.topFlap = el.querySelector(".flip__flap--top");
    this.bottomFlap = el.querySelector(".flip__flap--bottom");
    this.topFlapChar = this.topFlap.querySelector(".flip__char");
    this.bottomFlapChar = this.bottomFlap.querySelector(".flip__char");
    this.value = null; // null = not painted yet
    this._timer = null;
  }

  set(value) {
    value = String(value);
    if (value === this.value) return;
    const previous = this.value;
    this.value = value;

    // First paint, or reduced motion: show it directly, no animation.
    if (previous === null || prefersReducedMotion()) {
      this._paintAll(value);
      if (previous !== null) this._crossfade();
      return;
    }

    if (this._timer) { clearTimeout(this._timer); this._timer = null; }

    // Static backdrops settle to the new value immediately; the flaps carry
    // the outgoing (old, top) / incoming (new, bottom) transition on top.
    this.topStatic.textContent = value;
    this.bottomStatic.textContent = value;
    this.topFlapChar.textContent = previous;
    this.bottomFlapChar.textContent = value;

    this._setFlap(this.topFlap, 0, false);
    this._setFlap(this.bottomFlap, 90, false);
    void this.topFlap.offsetHeight; // force reflow before animating in

    this._setFlap(this.topFlap, -90, true);
    this._timer = setTimeout(() => {
      this._setFlap(this.bottomFlap, 0, true);
      this._timer = null;
    }, FOLD_HALF_MS);
  }

  _paintAll(value) {
    this.topStatic.textContent = value;
    this.bottomStatic.textContent = value;
    this.topFlapChar.textContent = value;
    this.bottomFlapChar.textContent = value;
    this._setFlap(this.topFlap, 0, false);
    this._setFlap(this.bottomFlap, 0, false);
  }

  _crossfade() {
    this.el.style.transition = "none";
    this.el.style.opacity = "0.25";
    void this.el.offsetHeight;
    this.el.style.transition = "opacity 150ms linear";
    this.el.style.opacity = "1";
  }

  _setFlap(flap, deg, animated) {
    flap.style.transition = animated
      ? `transform ${FOLD_HALF_MS}ms cubic-bezier(.37,.01,.6,1)`
      : "none";
    flap.style.transform = `rotateX(${deg}deg)`;
  }
}

function buildFlipLayer(outerClass) {
  const outer = document.createElement("span");
  outer.className = outerClass;
  const char = document.createElement("span");
  char.className = "flip__char";
  char.textContent = "0";
  outer.appendChild(char);
  return outer;
}

function buildFlipGroup(container, digitCount, sepAfter) {
  container.innerHTML = "";
  const digits = [];
  for (let i = 0; i < digitCount; i++) {
    const flip = document.createElement("span");
    flip.className = "flip";
    flip.appendChild(buildFlipLayer("flip__half flip__half--top"));
    flip.appendChild(buildFlipLayer("flip__half flip__half--bottom"));
    flip.appendChild(buildFlipLayer("flip__flap flip__flap--top"));
    flip.appendChild(buildFlipLayer("flip__flap flip__flap--bottom"));
    container.appendChild(flip);
    digits.push(new FlipDigit(flip));

    if (sepAfter.has(i)) {
      const gap1 = document.createElement("span");
      gap1.className = "flip-seg-gap";
      container.appendChild(gap1);
      const sep = document.createElement("span");
      sep.className = "flip-sep";
      sep.textContent = ":";
      container.appendChild(sep);
      const gap2 = document.createElement("span");
      gap2.className = "flip-seg-gap";
      container.appendChild(gap2);
    }
  }
  return digits;
}

// ---------------------------------------------------------------------------
// Hero clock
// ---------------------------------------------------------------------------

const HeroClock = {
  init() {
    const container = document.getElementById("heroClock");
    this.digits = buildFlipGroup(container, 6, new Set([1, 3]));
    this._renderLabel();
    Hero.onChange(() => this._renderLabel());
  },
  _renderLabel() {
    document.getElementById("heroLabel").textContent =
      Hero.current.name.toUpperCase() + " · LOCAL";
  },
  tick() {
    const { h, m, s } = hhmmss(Hero.current.tz);
    const str = h + m + s;
    for (let i = 0; i < 6; i++) this.digits[i].set(str[i]);
  },
};

// ---------------------------------------------------------------------------
// Ticker — the 4-6 city strip, excluding whichever city is currently hero
// ---------------------------------------------------------------------------

const Ticker = {
  speedPxPerSec: 26,
  offset: 0,
  lastTs: null,

  init() {
    this.track = document.getElementById("tickerTrack");
    Cities.onChange(() => this.rebuild());
    Hero.onChange(() => this.rebuild());
    this.rebuild();
    requestAnimationFrame((ts) => this._raf(ts));
  },

  rebuild() {
    this.track.innerHTML = "";
    this.tiles = [];
    const cities = Cities.visibleList();
    if (!cities.length) return;
    // Render the list twice back-to-back for a seamless scrolling loop.
    for (let copy = 0; copy < 2; copy++) {
      cities.forEach((city) => {
        const tile = document.createElement("div");
        tile.className = "city-tile";
        const name = document.createElement("div");
        name.className = "city-tile__name";
        name.textContent = city.name;
        const time = document.createElement("div");
        time.className = "city-tile__time";
        tile.appendChild(name);
        tile.appendChild(time);
        this.track.appendChild(tile);
        this.tiles.push({ tz: city.tz, timeEl: time });
      });
    }
    this.offset = 0;
    this.track.style.transform = "translateX(0px)";
    this._measure();
  },

  _measure() {
    requestAnimationFrame(() => {
      this.halfWidth = this.track.scrollWidth / 2 || 1;
    });
  },

  tickClocks() {
    (this.tiles || []).forEach((t) => { t.timeEl.textContent = hhmm(t.tz); });
  },

  _raf(ts) {
    if (this.lastTs == null) this.lastTs = ts;
    const dt = (ts - this.lastTs) / 1000;
    this.lastTs = ts;

    if (this.halfWidth) {
      this.offset -= this.speedPxPerSec * dt;
      if (-this.offset >= this.halfWidth) this.offset += this.halfWidth;
      this.track.style.transform = `translateX(${this.offset}px)`;
    }
    requestAnimationFrame((t) => this._raf(t));
  },
};

// ---------------------------------------------------------------------------
// Generative scene — anchored on the hero city, crossfading when it changes
// ---------------------------------------------------------------------------

const SKY_KEYFRAMES = [
  { hour: 0, top: [11, 16, 38], bottom: [27, 37, 80], silhouette: [5, 6, 13], stars: 1, warmth: 0 },
  { hour: 6, top: [43, 47, 99], bottom: [255, 138, 101], silhouette: [17, 19, 31], stars: 0.15, warmth: 0.8 },
  { hour: 12, top: [79, 168, 232], bottom: [191, 227, 247], silhouette: [16, 21, 28], stars: 0, warmth: 0.15 },
  { hour: 18, top: [42, 31, 77], bottom: [255, 107, 74], silhouette: [12, 13, 22], stars: 0.1, warmth: 0.9 },
  { hour: 24, top: [11, 16, 38], bottom: [27, 37, 80], silhouette: [5, 6, 13], stars: 1, warmth: 0 },
];

function skyPalette(hourFraction) {
  let lo = SKY_KEYFRAMES[0], hi = SKY_KEYFRAMES[SKY_KEYFRAMES.length - 1];
  for (let i = 0; i < SKY_KEYFRAMES.length - 1; i++) {
    if (hourFraction >= SKY_KEYFRAMES[i].hour && hourFraction <= SKY_KEYFRAMES[i + 1].hour) {
      lo = SKY_KEYFRAMES[i]; hi = SKY_KEYFRAMES[i + 1];
      break;
    }
  }
  const span = hi.hour - lo.hour || 1;
  const t = clamp01((hourFraction - lo.hour) / span);
  const mixC = (a, b) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
  return {
    top: mixC(lo.top, hi.top),
    bottom: mixC(lo.bottom, hi.bottom),
    silhouette: mixC(lo.silhouette, hi.silhouette),
    stars: lerp(lo.stars, hi.stars, t),
    warmth: lerp(lo.warmth, hi.warmth, t),
    daylight: 1 - Math.min(lerp(lo.stars, hi.stars, t) + 0.0, 1),
  };
}

function rgb(c) { return `rgb(${c[0] | 0}, ${c[1] | 0}, ${c[2] | 0})`; }
function rgba(c, a) { return `rgba(${c[0] | 0}, ${c[1] | 0}, ${c[2] | 0}, ${a})`; }

function buildCityScene(tz) {
  const rng = mulberry32(hashString(tz));
  const buildingCount = 12 + Math.floor(rng() * 6);
  const buildings = [];
  let x = 0;
  for (let i = 0; i < buildingCount; i++) {
    const widthFrac = 0.04 + rng() * 0.05;
    const heightFrac = 0.1 + rng() * 0.38;
    buildings.push({
      xFrac: x,
      widthFrac,
      heightFrac,
      lit: rng() > 0.45,
      litRows: 2 + Math.floor(rng() * 4),
    });
    x += widthFrac * (0.55 + rng() * 0.4);
    if (x > 1) break;
  }
  const blobs = Array.from({ length: 3 }, () => ({
    xFrac: rng(),
    yFrac: 0.1 + rng() * 0.35,
    rFrac: 0.18 + rng() * 0.22,
    speed: 0.004 + rng() * 0.006,
    phase: rng() * Math.PI * 2,
    dir: rng() > 0.5 ? 1 : -1,
  }));
  const stars = Array.from({ length: 70 }, () => ({
    x: rng(), y: rng() * 0.65, r: 0.5 + rng() * 1.1, tw: rng() * Math.PI * 2,
  }));
  const hueShift = (rng() - 0.5) * 24;
  return { tz, buildings, blobs, stars, hueShift };
}

const Scene = {
  TRANSITION_MS: 1800,
  // A missing/unmatched city (nothing curated nearby) falls back to this
  // neutral tz for its scene rather than ever borrowing another city's
  // imagery — in practice every tz still gets a coherent generated scene
  // (see buildCityScene), this is just the documented fallback identity.
  NEUTRAL_TZ: "Etc/UTC",

  init() {
    this.canvas = document.getElementById("scene");
    this.ctx = this.canvas.getContext("2d");
    this.caption = document.getElementById("sceneCaption");
    this.sceneCache = new Map();
    this.currentTz = (Hero.current && Hero.current.tz) || this.NEUTRAL_TZ;
    this.nextTz = null;
    this.phase = "hold";
    this.phaseStart = performance.now();
    this.startTime = performance.now();

    Hero.onChange((hero) => this._onHeroChange(hero.tz));

    window.addEventListener("resize", () => this._resize());
    this._resize();

    requestAnimationFrame((ts) => this._raf(ts));
  },

  _onHeroChange(tz) {
    if (tz === this.currentTz) return;
    if (this.phase === "transition" && tz === this.nextTz) return;
    this.nextTz = tz;
    this.phase = "transition";
    this.phaseStart = performance.now();
  },

  _sceneFor(tz) {
    if (!this.sceneCache.has(tz)) this.sceneCache.set(tz, buildCityScene(tz));
    return this.sceneCache.get(tz);
  },

  _resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.canvas.width = Math.round(window.innerWidth * dpr);
    this.canvas.height = Math.round(window.innerHeight * dpr);
    this.canvas.style.width = window.innerWidth + "px";
    this.canvas.style.height = window.innerHeight + "px";
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  },

  _drawCity(ctx, w, h, tz, now, alpha) {
    const scene = this._sceneFor(tz);
    const hourFraction = localHourFraction(tz);
    const palette = skyPalette(hourFraction);
    const t = (now - this.startTime) / 1000;

    ctx.save();
    ctx.globalAlpha = alpha;

    const zoom = 1.04 + Math.sin(t * 0.03) * 0.025;
    const panX = Math.sin(t * 0.015) * w * 0.015;
    const panY = Math.cos(t * 0.012) * h * 0.01;
    ctx.translate(w / 2 + panX, h / 2 + panY);
    ctx.scale(zoom, zoom);
    ctx.translate(-w / 2, -h / 2);

    const monumentImg = getMonumentImage(tz);

    if (monumentImg) {
      // A user-supplied landmark photo stands in for the generated skyline
      // entirely; a day/night color wash keeps it feeling "live" and visually
      // consistent with the generated cities rather than a flat static photo.
      this._drawCoverImage(ctx, monumentImg, w, h);
      const wash = ctx.createLinearGradient(0, 0, 0, h);
      wash.addColorStop(0, rgba(palette.top, 0.3));
      wash.addColorStop(1, rgba(palette.bottom, 0.22));
      ctx.fillStyle = wash;
      ctx.fillRect(0, 0, w, h);
    } else {
      ctx.filter = `hue-rotate(${scene.hueShift}deg)`;
      const grad = ctx.createLinearGradient(0, 0, 0, h);
      grad.addColorStop(0, rgb(palette.top));
      grad.addColorStop(1, rgb(palette.bottom));
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, w, h);
      ctx.filter = "none";
    }

    if (!monumentImg && palette.stars > 0.02) {
      ctx.save();
      ctx.globalAlpha = alpha * palette.stars;
      scene.stars.forEach((s) => {
        const tw = 0.55 + 0.45 * Math.sin(t * 1.3 + s.tw);
        ctx.fillStyle = `rgba(255,255,255,${0.5 * tw})`;
        ctx.beginPath();
        ctx.arc(s.x * w, s.y * h, s.r, 0, Math.PI * 2);
        ctx.fill();
      });
      ctx.restore();
    }

    scene.blobs.forEach((b) => {
      const bx = ((b.xFrac + Math.sin(t * b.speed + b.phase) * 0.06 * b.dir) % 1 + 1) % 1 * w;
      const by = b.yFrac * h;
      const r = b.rFrac * Math.max(w, h);
      const rg = ctx.createRadialGradient(bx, by, 0, bx, by, r);
      const warm = palette.warmth;
      const blobColor = warm > 0.5 ? [255, 180, 130] : [255, 255, 255];
      rg.addColorStop(0, rgba(blobColor, (monumentImg ? 0.1 : 0.16) * (0.4 + warm)));
      rg.addColorStop(1, rgba(blobColor, 0));
      ctx.fillStyle = rg;
      ctx.beginPath();
      ctx.arc(bx, by, r, 0, Math.PI * 2);
      ctx.fill();
    });

    if (!monumentImg) {
      const baseY = h;
      const skylineH = h * 0.4;
      ctx.fillStyle = rgb(palette.silhouette);
      scene.buildings.forEach((b) => {
        const bx = b.xFrac * w;
        const bw = b.widthFrac * w;
        const bh = b.heightFrac * skylineH + skylineH * 0.3;
        ctx.fillRect(bx, baseY - bh, bw, bh);
        if (b.lit && palette.daylight < 0.55) {
          const winAlpha = alpha * (0.55 - palette.daylight) * 1.3;
          ctx.fillStyle = `rgba(255, 201, 120, ${Math.max(0, winAlpha)})`;
          const rows = b.litRows;
          for (let r = 0; r < rows; r++) {
            const wy = baseY - bh + 6 + r * ((bh - 12) / rows);
            for (let c = 2; c < bw - 2; c += 7) {
              if ((r + c) % 3 === 0) ctx.fillRect(bx + c, wy, 2.2, 2.6);
            }
          }
          ctx.fillStyle = rgb(palette.silhouette);
        }
      });
    }

    ctx.restore();
  },

  /** Draws `img` into the w×h box with "cover" fit (fills completely, center-cropped). */
  _drawCoverImage(ctx, img, w, h) {
    const imageRatio = img.width / img.height;
    const boxRatio = w / h;
    let sx, sy, sw, sh;
    if (imageRatio > boxRatio) {
      sh = img.height; sw = sh * boxRatio; sx = (img.width - sw) / 2; sy = 0;
    } else {
      sw = img.width; sh = sw / boxRatio; sx = 0; sy = (img.height - sh) / 2;
    }
    ctx.drawImage(img, sx, sy, sw, sh, 0, 0, w, h);
  },

  _raf(ts) {
    const now = ts;
    const w = window.innerWidth, h = window.innerHeight;

    if (this.phase === "hold") {
      this._drawCity(this.ctx, w, h, this.currentTz, now, 1);
      this._updateCaption(this.currentTz);
    } else {
      const p = clamp01((now - this.phaseStart) / this.TRANSITION_MS);
      this.ctx.clearRect(0, 0, w, h);
      this._drawCity(this.ctx, w, h, this.currentTz, now, 1 - p);
      this._drawCity(this.ctx, w, h, this.nextTz, now, p);
      this._updateCaption(this.nextTz);
      if (p >= 1) {
        this.currentTz = this.nextTz;
        this.nextTz = null;
        this.phase = "hold";
      }
    }

    requestAnimationFrame((t) => this._raf(t));
  },

  _updateCaption(tz) {
    this.caption.textContent = `${cityNameForTz(tz).toUpperCase()} · ${hhmm(tz)}`;
  },
};

// ---------------------------------------------------------------------------
// Settings panel
// ---------------------------------------------------------------------------

const Panel = {
  init() {
    this.panel = document.getElementById("panel");
    this.list = document.getElementById("cityList");
    this.search = document.getElementById("citySearch");
    this.results = document.getElementById("searchResults");
    this.limitMsg = document.getElementById("limitMsg");
    this.heroValue = document.getElementById("heroSourceValue");
    this.heroReset = document.getElementById("heroResetBtn");
    this.monumentInput = document.getElementById("monumentFileInput");
    this.monumentInput.addEventListener("change", () => this._onMonumentFileChosen());
    this.themeOptions = document.getElementById("themeOptions");

    document.getElementById("settingsBtn").addEventListener("click", () => this.open());
    document.getElementById("closePanelBtn").addEventListener("click", () => this.close());
    this.panel.addEventListener("click", (e) => { if (e.target === this.panel) this.close(); });
    document.addEventListener("keydown", (e) => { if (e.key === "Escape") this.close(); });

    this.search.addEventListener("input", () => this._onSearch());
    this.search.addEventListener("focus", () => this._onSearch());

    this.heroReset.addEventListener("click", () => Hero.setManualOverride(null));

    // Quick direct Day/Night buttons live in the top bar, always visible,
    // not tucked inside the settings panel.
    document.getElementById("themeDayBtn").addEventListener("click", () => Theme.setMode("day"));
    document.getElementById("themeNightBtn").addEventListener("click", () => Theme.setMode("night"));

    this.themeOptions.querySelectorAll("button").forEach((btn) => {
      btn.addEventListener("click", () => Theme.setMode(btn.dataset.mode));
    });
    Theme.onChange(() => this._renderTheme());
    this._renderTheme();

    Cities.onChange(() => this._renderList());
    Hero.onChange(() => { this._renderList(); this._renderHeroRow(); });
    Monuments.onChange(() => this._renderList());
    this._renderList();
    this._renderHeroRow();

    this._allZones = (typeof Intl.supportedValuesOf === "function")
      ? Intl.supportedValuesOf("timeZone")
      : CITIES_DB.map((c) => c.tz);
  },

  open() { this.panel.hidden = false; this.search.value = ""; this.results.hidden = true; this.search.focus(); },
  close() { this.panel.hidden = true; },

  _renderHeroRow() {
    const h = Hero.current;
    const sourceLabel = { manual: "manual", geo: "auto — location", devicetz: "auto — device timezone" }[h.source];
    this.heroValue.textContent = `${h.name} (${sourceLabel})`;
    this.heroReset.hidden = h.source !== "manual";
  },

  _renderTheme() {
    this.themeOptions.querySelectorAll("button").forEach((btn) => {
      btn.setAttribute("aria-pressed", String(btn.dataset.mode === Theme.mode));
    });
  },

  _showLimitMsg(text) {
    this.limitMsg.textContent = text;
    this.limitMsg.hidden = false;
    clearTimeout(this._limitMsgTimer);
    this._limitMsgTimer = setTimeout(() => { this.limitMsg.hidden = true; }, 3000);
  },

  _renderList() {
    this.list.innerHTML = "";
    const cities = Cities.list;
    const atMin = cities.length <= MIN_CITIES;

    cities.forEach((city, index) => {
      const li = document.createElement("li");
      li.className = "panel__item";

      const handle = document.createElement("span");
      handle.className = "panel__item-handle";
      handle.textContent = "⠷";
      handle.draggable = true;
      handle.addEventListener("dragstart", (e) => {
        e.dataTransfer.setData("text/plain", String(index));
      });
      li.addEventListener("dragover", (e) => e.preventDefault());
      li.addEventListener("drop", (e) => {
        e.preventDefault();
        const from = Number(e.dataTransfer.getData("text/plain"));
        Cities.reorder(from, index);
      });

      const reorder = document.createElement("div");
      reorder.className = "panel__item-reorder";
      const upBtn = document.createElement("button");
      upBtn.textContent = "▲";
      upBtn.disabled = index === 0;
      upBtn.setAttribute("aria-label", `Move ${city.name} up`);
      upBtn.addEventListener("click", () => Cities.reorder(index, index - 1));
      const downBtn = document.createElement("button");
      downBtn.textContent = "▼";
      downBtn.disabled = index === cities.length - 1;
      downBtn.setAttribute("aria-label", `Move ${city.name} down`);
      downBtn.addEventListener("click", () => Cities.reorder(index, index + 1));
      reorder.appendChild(upBtn);
      reorder.appendChild(downBtn);

      const label = document.createElement("div");
      label.className = "panel__item-label";
      const nameSpan = document.createElement("span");
      nameSpan.className = "panel__item-name";
      nameSpan.textContent = city.name;
      const tzSpan = document.createElement("span");
      tzSpan.className = "panel__item-tz";
      tzSpan.textContent = city.tz;
      label.appendChild(nameSpan);
      label.appendChild(tzSpan);

      const monumentUrl = Monuments.get(city.tz);
      const monumentBtn = document.createElement("button");
      monumentBtn.className = "panel__item-monument";
      monumentBtn.title = monumentUrl ? "Change landmark photo" : "Add a landmark photo";
      monumentBtn.setAttribute("aria-label", `${monumentUrl ? "Change" : "Add"} a landmark photo for ${city.name}`);
      if (monumentUrl) {
        monumentBtn.style.backgroundImage = `url(${monumentUrl})`;
        monumentBtn.classList.add("panel__item-monument--set");
      } else {
        monumentBtn.textContent = "\u{1F3DB}"; // classical building glyph
      }
      monumentBtn.addEventListener("click", () => this._pickMonumentImage(city));

      let monumentRemoveBtn = null;
      if (monumentUrl) {
        monumentRemoveBtn = document.createElement("button");
        monumentRemoveBtn.className = "panel__item-remove panel__item-monument-remove";
        monumentRemoveBtn.textContent = "−"; // minus sign, distinct from the "remove city" ✕
        monumentRemoveBtn.title = "Remove landmark photo";
        monumentRemoveBtn.setAttribute("aria-label", `Remove landmark photo for ${city.name}`);
        monumentRemoveBtn.addEventListener("click", () => Monuments.remove(city.tz));
      }

      const heroBtn = document.createElement("button");
      heroBtn.className = "panel__item-remove";
      heroBtn.textContent = "★";
      heroBtn.title = "Set as hero city";
      heroBtn.setAttribute("aria-label", `Set ${city.name} as hero city`);
      heroBtn.addEventListener("click", () => Hero.setManualOverride(city));

      const removeBtn = document.createElement("button");
      removeBtn.className = "panel__item-remove";
      removeBtn.textContent = "✕";
      removeBtn.disabled = atMin;
      removeBtn.title = atMin ? `Minimum of ${MIN_CITIES} cities` : "Remove";
      removeBtn.setAttribute("aria-label", `Remove ${city.name}`);
      removeBtn.addEventListener("click", () => {
        if (Cities.remove(city.tz) === "min") {
          this._showLimitMsg(`Minimum of ${MIN_CITIES} cities — add another before removing.`);
        }
      });

      li.appendChild(handle);
      li.appendChild(reorder);
      li.appendChild(label);
      li.appendChild(monumentBtn);
      if (monumentRemoveBtn) li.appendChild(monumentRemoveBtn);
      li.appendChild(heroBtn);
      li.appendChild(removeBtn);
      this.list.appendChild(li);
    });
  },

  _pickMonumentImage(city) {
    this._pendingMonumentTz = city.tz;
    this.monumentInput.value = "";
    this.monumentInput.click();
  },

  async _onMonumentFileChosen() {
    const file = this.monumentInput.files && this.monumentInput.files[0];
    const tz = this._pendingMonumentTz;
    this._pendingMonumentTz = null;
    if (!file || !tz) return;
    try {
      await Monuments.set(tz, file);
      this._renderList();
    } catch (_) {
      this._showLimitMsg("Couldn't read that image — try a different file.");
    }
  },

  _onSearch() {
    const q = this.search.value.trim().toLowerCase();
    if (!q) { this.results.hidden = true; this.results.innerHTML = ""; return; }

    const matches = this._allZones
      .filter((tz) => tz.toLowerCase().includes(q) || cityNameForTz(tz).toLowerCase().includes(q))
      .slice(0, 8);

    this.results.innerHTML = "";
    if (!matches.length) { this.results.hidden = true; return; }

    matches.forEach((tz) => {
      const row = document.createElement("div");
      row.className = "panel__result";
      row.appendChild(document.createTextNode(cityNameForTz(tz)));
      const tzSpan = document.createElement("span");
      tzSpan.className = "tz";
      tzSpan.textContent = tz;
      row.appendChild(tzSpan);
      row.addEventListener("click", () => {
        const result = Cities.add({ name: cityNameForTz(tz), tz });
        if (result === "max") {
          this._showLimitMsg(`Maximum of ${MAX_CITIES} cities — remove one first.`);
        } else {
          this.search.value = "";
          this.results.hidden = true;
        }
      });
      this.results.appendChild(row);
    });
    this.results.hidden = false;
  },
};

// ---------------------------------------------------------------------------
// Date label + main loop
// ---------------------------------------------------------------------------

function tickDateLabel() {
  const fmt = new Intl.DateTimeFormat(undefined, { weekday: "long", month: "long", day: "numeric" });
  document.getElementById("dateLabel").textContent = fmt.format(new Date());
}

function isConfigureMode() {
  return location.hash === "#configure" || new URLSearchParams(location.search).has("configure");
}

function main() {
  Hero.init();
  Cities.init();
  Monuments.init();
  Theme.init();

  HeroClock.init();
  Ticker.init();
  Scene.init();
  Panel.init();

  tickDateLabel();
  HeroClock.tick();
  Ticker.tickClocks();

  scheduleClockAligned(() => {
    HeroClock.tick();
    Ticker.tickClocks();
  });

  setInterval(tickDateLabel, 60 * 1000);

  // The native shells' "configure" window loads this same page with
  // ?configure=1 so it shows just the settings panel over the live scene,
  // instead of rebuilding the city editor as a second, separate native UI.
  if (isConfigureMode()) {
    document.body.classList.add("configure-mode");
    Panel.open();
  }
}

main();
