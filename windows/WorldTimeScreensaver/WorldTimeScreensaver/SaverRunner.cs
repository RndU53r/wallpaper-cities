using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Interop;
using Microsoft.Web.WebView2.Wpf;
using Screen = System.Windows.Forms.Screen;

namespace WorldTimeScreensaver;

internal static class SaverRunner
{
    /// <summary>/s — one full-screen, borderless window per display.</summary>
    public static void RunFullScreen()
    {
        foreach (Screen screen in Screen.AllScreens)
            new SaverWindow(screen).Show();
    }

    /// <summary>
    /// /p &lt;hwnd&gt; — Control Panel's screensaver list asks for a live
    /// thumbnail by passing the HWND of a small preview area; we re-parent
    /// a child window into it and fill it exactly, per the standard .scr
    /// preview contract.
    /// </summary>
    public static void RunPreview(IntPtr parentHwnd)
    {
        if (parentHwnd == IntPtr.Zero)
        {
            Application.Current.Shutdown();
            return;
        }

        var browser = new WebView2();
        var window = new Window
        {
            WindowStyle = WindowStyle.None,
            ResizeMode = ResizeMode.NoResize,
            ShowInTaskbar = false,
            Content = browser,
        };

        window.SourceInitialized += (_, _) => EmbedIntoPreview(window, parentHwnd);
        window.Show();

        _ = InitializePreviewWebViewAsync(browser);
    }

    private static void EmbedIntoPreview(Window window, IntPtr parentHwnd)
    {
        var hwndSource = (HwndSource)PresentationSource.FromVisual(window);
        IntPtr hwndSelf = hwndSource.Handle;

        IntPtr currentStyle = NativeMethods.GetWindowLongPtr(hwndSelf, NativeMethods.GWL_STYLE);
        long newStyle = (currentStyle.ToInt64() & ~NativeMethods.WS_POPUP) | NativeMethods.WS_CHILD;
        NativeMethods.SetWindowLongPtr(hwndSelf, NativeMethods.GWL_STYLE, new IntPtr(newStyle));
        NativeMethods.SetParent(hwndSelf, parentHwnd);

        NativeMethods.GetClientRect(parentHwnd, out NativeMethods.RECT rect);
        NativeMethods.MoveWindow(hwndSelf, 0, 0, rect.Width, rect.Height, true);
    }

    private static async Task InitializePreviewWebViewAsync(WebView2 browser)
    {
        var environment = await SharedWebViewEnvironment.GetAsync();
        await browser.EnsureCoreWebView2Async(environment);

        string indexPath = Path.Combine(AppContext.BaseDirectory, "web", "index.html");
        browser.CoreWebView2.Navigate(new Uri(indexPath).AbsoluteUri);
    }
}
