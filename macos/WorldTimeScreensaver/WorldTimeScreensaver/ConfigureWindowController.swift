import AppKit
import WebKit

/// The screensaver's "Screen Saver Options..." sheet.
///
/// Rather than re-implementing the city search/add/remove UI natively, this
/// opens the same `web/index.html` page with `?configure=1`, which (see
/// web/app.js's `isConfigureMode()`) shows just the settings panel full-size
/// with no wallpaper chrome around it. One shared UI, no second
/// implementation to keep in sync.
final class ConfigureWindowController: NSObject {

    static let shared = ConfigureWindowController()

    private var webView: WKWebView?
    private(set) lazy var window: NSWindow = makeWindow()

    private func makeWindow() -> NSWindow {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default() // shares storage with the live screensaver views

        let contentRect = NSRect(x: 0, y: 0, width: 520, height: 640)
        let view = WKWebView(frame: contentRect, configuration: configuration)
        webView = view

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "World Time — Cities"
        window.contentView = view
        window.isReleasedWhenClosed = false

        if let indexURL = Bundle(for: WorldTimeScreenSaverView.self).url(
            forResource: "index", withExtension: "html", subdirectory: "web"
        ) {
            var components = URLComponents(url: indexURL, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "configure", value: "1")]
            let configureURL = components?.url ?? indexURL
            view.loadFileURL(configureURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
        }

        return window
    }
}
