using System.Threading.Tasks;
using Microsoft.Web.WebView2.Core;

namespace WorldTimeScreensaver;

/// <summary>
/// One CoreWebView2Environment (and therefore one user-data/localStorage
/// profile) shared by every WebView2 instance this process creates — one
/// per monitor in full-screen mode, plus the configure window. That shared
/// profile is what lets a city added on one screen appear on every other
/// screen live via the `storage` DOM event (see web/app.js), with no native
/// bridge needed.
/// </summary>
internal static class SharedWebViewEnvironment
{
    private static Task<CoreWebView2Environment>? _environmentTask;

    public static Task<CoreWebView2Environment> GetAsync()
    {
        _environmentTask ??= CoreWebView2Environment.CreateAsync();
        return _environmentTask;
    }
}
