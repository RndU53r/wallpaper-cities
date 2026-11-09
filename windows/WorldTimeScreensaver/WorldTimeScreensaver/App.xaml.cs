using System;
using System.Linq;
using System.Windows;

namespace WorldTimeScreensaver;

public enum ScreensaverMode
{
    FullScreen,
    Configure,
    Preview,
}

public readonly record struct ParsedArgs(ScreensaverMode Mode, IntPtr PreviewParentHwnd);

/// <summary>
/// Entry point implementing the standard Windows .scr command-line contract:
/// `/s` run full-screen, `/c` (optionally `/c:&lt;hwnd&gt;`) show settings,
/// `/p &lt;hwnd&gt;` render into Control Panel's small preview thumbnail, and
/// no arguments falls back to `/c`.
/// </summary>
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        var parsed = ParseArgs(e.Args);
        switch (parsed.Mode)
        {
            case ScreensaverMode.FullScreen:
                SaverRunner.RunFullScreen();
                break;

            case ScreensaverMode.Preview:
                SaverRunner.RunPreview(parsed.PreviewParentHwnd);
                break;

            case ScreensaverMode.Configure:
            default:
                var configureWindow = new ConfigureWindow();
                configureWindow.Closed += (_, _) => Shutdown();
                configureWindow.Show();
                break;
        }
    }

    internal static ParsedArgs ParseArgs(string[] args)
    {
        if (args.Length == 0)
            return new ParsedArgs(ScreensaverMode.Configure, IntPtr.Zero);

        string first = args[0].Trim();

        if (StartsWithFlag(first, 's'))
            return new ParsedArgs(ScreensaverMode.FullScreen, IntPtr.Zero);

        if (StartsWithFlag(first, 'p'))
        {
            string? hwndText = ExtractAttachedValue(first) ?? (args.Length > 1 ? args[1] : null);
            return new ParsedArgs(
                ScreensaverMode.Preview,
                long.TryParse(hwndText, out long hwndValue) ? new IntPtr(hwndValue) : IntPtr.Zero);
        }

        // "/c", "/c:<hwnd>", anything else, or nothing at all -> configure.
        return new ParsedArgs(ScreensaverMode.Configure, IntPtr.Zero);
    }

    private static bool StartsWithFlag(string arg, char flag) =>
        arg.Length >= 2 && (arg[0] == '/' || arg[0] == '-') && char.ToLowerInvariant(arg[1]) == flag;

    private static string? ExtractAttachedValue(string arg)
    {
        int colon = arg.IndexOf(':');
        if (colon >= 0 && colon + 1 < arg.Length) return arg[(colon + 1)..];

        string digits = new(arg.SkipWhile(c => !char.IsDigit(c)).ToArray());
        return digits.Length > 0 ? digits : null;
    }
}
