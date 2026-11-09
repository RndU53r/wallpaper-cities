using System;
using System.IO;
using System.Windows;
using System.Windows.Input;
using Screen = System.Windows.Forms.Screen;

namespace WorldTimeScreensaver;

/// <summary>
/// One of these is created per display in full-screen mode. Per screensaver
/// convention, any key press or meaningful mouse movement exits the app.
/// </summary>
public partial class SaverWindow : Window
{
    private const double MouseMoveExitThreshold = 8.0;
    private Point? _initialMousePosition;

    public SaverWindow(Screen screen)
    {
        InitializeComponent();

        WindowStartupLocation = WindowStartupLocation.Manual;
        Left = screen.Bounds.Left;
        Top = screen.Bounds.Top;
        Width = screen.Bounds.Width;
        Height = screen.Bounds.Height;

        // Setting WindowState=Maximized after Show (rather than computing
        // DPI-scaled Width/Height up front) reliably snaps the window to
        // fill exactly this monitor's work area, sidestepping per-monitor
        // DPI math that's easy to get subtly wrong across mixed-DPI setups.
        Loaded += async (_, _) =>
        {
            WindowState = WindowState.Maximized;
            await InitializeWebViewAsync();
        };

        PreviewKeyDown += (_, _) => RequestExit();
        PreviewMouseDown += (_, _) => RequestExit();
        PreviewMouseWheel += (_, _) => RequestExit();
        PreviewMouseMove += OnPreviewMouseMove;
    }

    private void OnPreviewMouseMove(object sender, MouseEventArgs e)
    {
        Point current = e.GetPosition(this);
        if (_initialMousePosition is null)
        {
            _initialMousePosition = current;
            return;
        }

        double dx = current.X - _initialMousePosition.Value.X;
        double dy = current.Y - _initialMousePosition.Value.Y;
        if (Math.Sqrt(dx * dx + dy * dy) > MouseMoveExitThreshold)
            RequestExit();
    }

    private static void RequestExit() => Application.Current.Shutdown();

    private async System.Threading.Tasks.Task InitializeWebViewAsync()
    {
        var environment = await SharedWebViewEnvironment.GetAsync();
        await Browser.EnsureCoreWebView2Async(environment);

        string indexPath = Path.Combine(AppContext.BaseDirectory, "web", "index.html");
        Browser.CoreWebView2.Navigate(new Uri(indexPath).AbsoluteUri);
    }
}
