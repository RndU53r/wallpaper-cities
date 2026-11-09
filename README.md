# World Time

A live "Global Time" clock — a giant split-flap digit clock for your current
city, a scrolling strip of world-city times, and a generative, per-city,
day/night-aware background (or a landmark photo you supply yourself) —
shipped four ways from one shared design:

- **macOS** and **Windows**: an OS-native screensaver (not a third-party
  wallpaper engine), both hosting one shared `web/` HTML/CSS/JS UI.
- **iOS, iPadOS, Android**: a real native Flutter app (not a web wrapper)
  from a single Dart codebase, reimplementing the same UI natively.

Your current city ("the hero city") is resolved automatically — on-device
geolocation reverse-geocoded against a bundled ~150-city dataset, falling
back to your device's timezone, then to a manual picker — and never blocks
the UI. A strip of 4–6 other cities (bounded, reorderable) runs underneath,
always excluding whichever city is currently the hero.

All installers in this repo are **unsigned/debug** — there's no Apple
Developer, Google Play, or code-signing account configured for this project
yet. See each platform's section below for what that means in practice.

## Repo layout

```
web/                           Shared Motion UI for the two screensavers
  index.html / style.css / app.js / cities-db.js
macos/WorldTimeScreensaver/     Xcode project -> WorldTimeScreensaver.saver
macos/installer/                 -> unsigned .pkg (pkgbuild)
windows/WorldTimeScreensaver/   .NET/WPF solution -> WorldTimeScreensaver.scr
windows/installer/               -> Inno Setup script, compiled by CI
mobile/world_time/              Flutter app (iOS, iPadOS, Android)
.github/workflows/              CI: builds + uploads every environment's artifact
```

## How the screensavers are built

Both platform shells are thin: they open a native WebView pointed at
`web/index.html` and handle their OS's screensaver plugin contract (install,
preview thumbnail, settings dialog). All the actual UI — the clock, the
ticker, the generative/photo backgrounds, the city editor — lives once in
`web/`. Because it's a *screensaver*, it shows after your configured idle
timeout (or on lock), not continuously while you're working.

City/theme/hero-override changes made through the gear icon are saved to the
WebView's local storage and picked up immediately by every open instance —
every display, plus the native settings window — via the standard web
`storage` event. No native bridge code, no restart.

### macOS

**Build & install:**

```bash
cd macos/WorldTimeScreensaver
xcodebuild -project WorldTimeScreensaver.xcodeproj -configuration Release build CODE_SIGNING_ALLOWED=NO
```

Then double-click the resulting `WorldTimeScreensaver.saver` — macOS installs
it into `~/Library/Screen Savers` and opens System Settings → Screen Saver
with it selected. Unsigned, so the first launch needs a one-time Gatekeeper
override (Privacy & Security → the blocked-item notice → **Open Anyway**).

**Or use the installer:** `macos/installer/build.sh` builds the `.saver` and
wraps it in an unsigned `.pkg` (via `pkgbuild`) that copies it into your
`~/Library/Screen Savers` for you — same Gatekeeper override applies.

Requires macOS 13 (Ventura) or later.

### Windows

WPF can't be compiled on macOS/Linux, so this has to be built and tested on
an actual Windows machine (or via this repo's CI, see below).

```powershell
dotnet publish windows\WorldTimeScreensaver\WorldTimeScreensaver\WorldTimeScreensaver.csproj ^
  -c Release -r win-x64 --self-contained -o windows\installer\publish
```

This produces `WorldTimeScreensaver.exe`, a `WorldTimeScreensaver.scr` copy
of it, supporting DLLs, and the `web\` assets it loads at runtime, all in one
folder. **Install:** right-click `WorldTimeScreensaver.scr` → **Install**, or
copy the whole folder's contents into `C:\Windows\System32`.

**Or use the installer:** compile `windows\installer\WorldTimeScreensaver.iss`
with Inno Setup (`ISCC.exe`) after the publish step above — it copies
everything into System32 for you. Unsigned, so Windows SmartScreen will warn
on first run.

Needs the WebView2 Runtime (preinstalled on current Windows 11/10; Windows
prompts to install Microsoft's own Evergreen runtime if it's missing).

## Mobile (iOS, iPadOS, Android) — `mobile/world_time/`

A real Flutter app, not an embedded WebView — the split-flap clock, the
generative background, the ticker, and the settings sheet are all native
widgets/`CustomPainter`s reimplementing the same design. One Dart codebase
targets iOS, iPadOS, and Android.

```bash
cd mobile/world_time
flutter pub get
flutter run            # or: flutter build ios --simulator / flutter build apk --debug
```

Verified running on the iOS Simulator during development. Android builds
from the same codebase via CI (no Android SDK was available on the machine
this was built on).

**Signing:** builds here are unsigned/debug.
- iOS: `flutter build ios --simulator` works unsigned for Simulator-only use.
  A real device-installable build needs an Apple Developer signing identity
  this project doesn't have yet.
- Android: `flutter build apk --debug` produces a sideloadable APK, no
  developer account needed.

**Adaptive layout:** a width breakpoint (700px) switches to a larger,
centered layout on tablets/landscape instead of stretching the phone UI.

**Not yet in the mobile app** (present in the web/screensaver version,
flagged as follow-up rather than silently skipped):
- User-supplied landmark photos per city (the generative background always
  renders; `image_picker` is already a dependency, just not wired up yet).
- Home-screen widgets (would need `home_widget` + a native widget extension
  on each platform regardless of app framework — a real follow-on project).

## CI — `.github/workflows/`

Three workflows build and upload every environment's artifact on every push
to `main` (and on demand via `workflow_dispatch`):

| Workflow | Runner | Produces |
|---|---|---|
| `macos.yml` | `macos-latest` | `WorldTimeScreensaver.saver`, `.pkg` installer |
| `windows.yml` | `windows-latest` | `WorldTimeScreensaver.scr` (+ publish folder), `.exe` installer |
| `mobile.yml` | `macos-latest` + `ubuntu-latest` | iOS Simulator `.app`, Android debug `.apk` |

This is also how Windows and Android get verified at all from a Mac-only dev
machine — by reading the Actions run's logs/artifacts rather than eyes-on.

## Customizing

Click the gear icon (web/screensaver) or the settings icon (mobile app) any
time:
- **Hero city**: auto-detected (location, falling back to device timezone),
  or pin any city manually (★ on a city row, or **Use automatic** to clear
  an override).
- **Cities strip**: search and add, remove, or reorder — bounded to 4–6.
- **Theme**: Auto (follows the hero city's current daylight), System
  (matches the OS appearance setting), or a direct Day/Night override — this
  is the UI chrome's light/dark look, independent of each city's own
  generated sky, which always reflects that city's real local time
  regardless of this setting.
- **Landmark photo** (web/screensaver only, for now): pick your own photo of
  a city's landmark to replace that city's generated skyline background.

To change the *default* city list and dataset a fresh install starts with,
edit `web/cities-db.js` (`DEFAULT_STRIP_TZS` and `CITIES_DB`) and the
matching `citiesDb`/`defaultStripTzs` in
`mobile/world_time/lib/data/cities_db.dart` — kept in sync by hand, not
shared code, since the mobile app is a separate native codebase.

## What's deliberately not here

- **No live photo/video API for backgrounds.** Each city's background is
  either procedurally generated (seeded from its timezone string — no
  licensing to manage, no API keys, scales to any city with zero extra
  assets) or a photo *you* provide yourself through the settings panel —
  never a bundled or fetched third-party photo.
- **No always-on, behind-the-icons desktop wallpaper mode.** The desktop
  builds are screensavers — idle-timeout or lock-triggered. An
  always-visible wallpaper would need a different, unofficial approach (the
  Windows "WorkerW" trick / macOS's desktop window level) and would be a
  separate shell reusing the same `web/` layer.
- **No IP-based geolocation fallback.** The hero-city fallback chain is
  geolocation → device timezone → manual picker, skipping a third-party
  IP-lookup stage to avoid an extra network dependency and data transmission
  for something device-timezone already approximates well.
- **No signed/store releases yet.** Every installer here is unsigned/debug;
  wiring up real Apple/Google/code-signing accounts is a later step.
