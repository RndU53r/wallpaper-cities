import ScreenSaver
import WebKit

/// Hosts the shared `web/` Motion UI inside a WKWebView and acts as the
/// screensaver's principal class (see Info.plist's NSPrincipalClass).
///
/// macOS instantiates one of these per display when the screensaver is
/// actually running, and one more (with `isPreview == true`) for the small
/// thumbnail in System Settings' screensaver picker.
@objc(WorldTimeScreenSaverView)
public final class WorldTimeScreenSaverView: ScreenSaverView {

    private var webView: WKWebView?

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // The WKWebView drives its own render loop (CSS transitions, canvas
        // rAF) independent of animateOneFrame, so a slow tick is enough —
        // it only exists to satisfy the ScreenSaverView animation contract.
        animationTimeInterval = 1.0 / 10.0

        let configuration = WKWebViewConfiguration()
        // Deliberately the default, persistent WKWebsiteDataStore (not
        // `.nonPersistent()`): every WorldTimeScreenSaverView instance in
        // this process — one per display, plus the configure sheet — loads
        // the same bundled origin and so shares one localStorage, which is
        // how a city added on one screen (or in the configure sheet) shows
        // up on every other screen live (see web/app.js's `storage` event
        // listener).
        configuration.websiteDataStore = .default()

        let view = WKWebView(frame: bounds, configuration: configuration)
        view.autoresizingMask = [.width, .height]
        view.setValue(false, forKey: "drawsBackground")
        addSubview(view)
        webView = view

        loadWallpaper()
    }

    private func loadWallpaper() {
        guard let indexURL = Bundle(for: Self.self).url(
            forResource: "index", withExtension: "html", subdirectory: "web"
        ) else {
            assertionFailure("web/index.html missing from the screensaver bundle's Resources")
            return
        }
        let readAccessRoot = indexURL.deletingLastPathComponent()
        webView?.loadFileURL(indexURL, allowingReadAccessTo: readAccessRoot)
    }

    public override func startAnimation() {
        super.startAnimation()
    }

    public override func stopAnimation() {
        super.stopAnimation()
    }

    public override func animateOneFrame() {
        // No-op: see commonInit().
    }

    public override var hasConfigureSheet: Bool { true }

    public override var configureSheet: NSWindow? {
        ConfigureWindowController.shared.window
    }
}
