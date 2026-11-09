using System;
using System.IO;
using System.Windows;

namespace WorldTimeScreensaver;

/// <summary>
/// The screensaver's "Settings..." dialog, opened from Control Panel. Rather
/// than re-implementing the city search/add/remove UI natively, this loads
/// the same web/index.html page with ?configure=1, which (see
/// web/app.js's isConfigureMode()) shows just the settings panel full-size
/// with no wallpaper chrome — one shared UI, nothing to keep in sync.
/// </summary>
public partial class ConfigureWindow : Window
{
    public ConfigureWindow()
    {
        InitializeComponent();
        Loaded += async (_, _) => await InitializeWebViewAsync();
    }

    private async System.Threading.Tasks.Task InitializeWebViewAsync()
    {
        var environment = await SharedWebViewEnvironment.GetAsync();
        await Browser.EnsureCoreWebView2Async(environment);

        string indexPath = Path.Combine(AppContext.BaseDirectory, "web", "index.html");
        var uriBuilder = new UriBuilder(new Uri(indexPath)) { Query = "configure=1" };
        Browser.CoreWebView2.Navigate(uriBuilder.Uri.AbsoluteUri);
    }
}
