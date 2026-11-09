# World Time — a live screensaver for Windows and Mac

A "live wallpaper" styled after Bogdan Nikitin's
[Global Time Dashboard — Motion UI](https://dribbble.com/shots/27028668-Global-Time-Dashboard-Motion-UI):
a giant flip-digit clock for your local time, a scrolling strip of world-city
clocks, and a generative, per-city, day/night-aware background — installed as
a proper OS-native screensaver on both macOS and Windows, not a third-party
wallpaper engine.

Because it's a screensaver, it shows after your configured idle timeout (or
on lock), not continuously while you're actively working.

## How it's built

```
web/                         The shared UI — the one thing both platforms run.
  index.html / style.css / app.js / cities.json
macos/WorldTimeScreensaver/   Xcode project → WorldTimeScreensaver.saver
windows/WorldTimeScreensaver/ .NET/WPF solution → WorldTimeScreensaver.scr
```

Both platform shells are thin: they just open a native WebView pointed at
`web/index.html` and handle their OS's screensaver plugin contract (install,
preview thumbnail, settings dialog). All the actual UI — the clock, the
ticker, the generative backgrounds, the city editor — lives once in `web/`.

City list changes (add/remove, via the gear icon) are saved to the WebView's
local storage and picked up immediately by every open instance — every
display, plus the settings window — via the standard web `storage` event.
No native bridge code, no restart.

## macOS

**Build:**

```bash
cd macos/WorldTimeScreensaver
xcodebuild -project WorldTimeScreensaver.xcodeproj -configuration Release build CODE_SIGNING_ALLOWED=NO
```

Or just open `WorldTimeScreensaver.xcodeproj` in Xcode and hit Build —
useful if you want to sign it with your own Apple Developer ID instead of
building unsigned.

This produces `WorldTimeScreensaver.saver` (a universal arm64 + x86_64
bundle) under `build/Release/`.

**Install:** double-click the `.saver` file. macOS installs it into
`~/Library/Screen Savers` and opens System Settings → Screen Saver with it
selected automatically.

Since an unsigned local build isn't notarized, the first launch may need a
one-time Gatekeeper override: System Settings → Privacy & Security → scroll
down to the blocked-item notice → **Open Anyway**.

**Settings:** the gear/"Screen Saver Options..." button in System Settings
opens the same city editor you'd see via the in-wallpaper gear icon.

Requires macOS 13 (Ventura) or later — set by `LSMinimumSystemVersion` in
`Info.plist` / `MACOSX_DEPLOYMENT_TARGET` in the Xcode project; lower it if
you need to support older systems (and double check `SMAppService`-adjacent
APIs aren't relied on elsewhere, though this project doesn't use any).

## Windows

**Build** (needs the .NET 8 SDK with the Windows desktop workload, on
Windows — WPF can't be compiled on macOS/Linux, so this part has to be built
and tested on an actual Windows machine):

```powershell
cd windows\WorldTimeScreensaver
dotnet build WorldTimeScreensaver.sln -c Release
```

This produces both `WorldTimeScreensaver.exe` and `WorldTimeScreensaver.scr`
(a post-build step just copies the exe to `.scr`, which is the extension
Windows actually requires to list something as a screensaver) under
`WorldTimeScreensaver\bin\Release\net8.0-windows\`.

For something you can copy to another machine without it needing the .NET
runtime pre-installed:

```powershell
dotnet publish WorldTimeScreensaver\WorldTimeScreensaver.csproj -c Release -r win-x64 --self-contained -p:PublishSingleFile=true
```

The `web` folder is copied into the publish output automatically (it's
wired up in the `.csproj`) — copy the published `.exe` (renamed to `.scr`)
*and* its sibling `web` folder together; `PublishSingleFile` bundles the
.NET runtime into one exe, but not loose content files alongside it.

**Install:** right-click `WorldTimeScreensaver.scr` → **Install**, or copy it
into `C:\Windows\System32` and it'll appear in Settings → Personalization →
Lock screen → Screen saver settings.

**Needs the WebView2 Runtime.** It's preinstalled on current Windows 11 and
most up-to-date Windows 10 systems. If it's missing, Windows will prompt to
install Microsoft's own Evergreen WebView2 Runtime the first time the
screensaver runs — this is a Microsoft component, not a third-party
dependency.

**The `Microsoft.Web.WebView2` NuGet package version pinned in the `.csproj`
may have been superseded by the time you build** — if `dotnet restore`
can't find it, bump it:

```powershell
dotnet add windows\WorldTimeScreensaver\WorldTimeScreensaver\WorldTimeScreensaver.csproj package Microsoft.Web.WebView2
```

**Worth double-checking first**, since none of this could be compiled or run
on the Mac this was built on:
- The `/s` `/c` `/p` command-line handling in `App.xaml.cs` — this is the
  standard, documented `.scr` contract, but exercise all three once on a
  real machine (Control Panel calls all three at different times).
- `SaverRunner.RunPreview` (the small live thumbnail in the screensaver
  picker) — the `SetParent`/`WS_CHILD` re-parenting is the normal technique
  for this, but it's the one piece of Win32 interop here, and it's
  the most fiddly part of any `.scr` to get pixel-perfect.
- Per-monitor DPI behavior in `SaverWindow` on a mixed-DPI, multi-monitor
  setup.

## Changing the city list without touching code

Click the grid icon (top right) any time the wallpaper/screensaver is
showing, or open the screensaver's settings from System Settings / Control
Panel — search any city or IANA timezone name and add or remove freely.
Changes apply immediately, persist, and sync across every open instance (all
displays plus the settings window).

To change the *default* list a fresh install starts with, edit
`web/cities.json` (keep `web/app.js`'s inlined `DEFAULT_CITIES` constant in
sync — it's the offline fallback used if `cities.json` can't be fetched for
some reason).

## What's deliberately not here

- **No photographic backgrounds.** Each city's background is procedurally
  generated (seeded from its timezone string) rather than pulled from a
  bundled photo set or a live image API — no licensing to manage, no API
  keys, no network dependency, and it scales to any city you add with zero
  extra assets. See the seeding logic (`buildCityScene`) and the day/night
  palette interpolation (`skyPalette`) in `web/app.js`.
- **No always-on, behind-the-icons wallpaper mode.** This is a screensaver —
  idle-timeout or lock-triggered, using each OS's official screensaver
  plugin format. An always-visible wallpaper would need a different,
  unofficial approach (the Windows "WorkerW" trick / macOS's desktop window
  level) and would be a separate shell reusing the same `web/` layer.
