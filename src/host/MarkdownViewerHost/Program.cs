// MarkdownViewerHost - Minimal host for MSIX activation
// This is a Windows GUI subsystem app that handles file and protocol activation,
// then launches the bundled PowerShell engine (Open-Markdown.ps1).
//
// For MSIX packages, Windows passes activation arguments via command line:
// - File activation: The full path to the file
// - Protocol activation: The full protocol URI (mdview:file:///...)

using System.Diagnostics;
using System.Runtime.InteropServices;

namespace MarkdownViewerHost;

/// <summary>
/// Entry point for the Markdown Viewer host application.
/// Handles MSIX activation (file associations, protocol) and launches the PowerShell engine.
/// </summary>
internal static class Program
{
    // P/Invoke for MessageBox (Windows GUI without WinForms/WPF dependency)
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int MessageBoxW(IntPtr hWnd, string text, string caption, uint type);

    // MessageBox constants
    private const uint MB_OK = 0x00000000;
    private const uint MB_OKCANCEL = 0x00000001;
    private const uint MB_ICONINFORMATION = 0x00000040;
    private const int IDOK = 1;
    private const int IDCANCEL = 2;

    [STAThread]
    static void Main(string[] args)
    {
        try
        {
            // Windows passes activation arguments via command line for packaged apps
            // - File activation: args[0] is the file path
            // - Protocol activation: args[0] is the full URI (mdview:file:///...)
            if (args.Length > 0)
            {
                foreach (var arg in args)
                {
                    if (!string.IsNullOrWhiteSpace(arg))
                    {
                        LaunchEngine(arg);
                    }
                }
            }
            else
            {
                // No arguments - launched from Start Menu or shortcut
                // Show help dialog explaining how to use the app
                ShowHelpDialog();
            }
        }
        catch
        {
            // Exit silently on any error - Engine owns error presentation
            // Host must not show duplicate dialogs
        }
    }

    /// <summary>
    /// Show a help dialog when the app is launched without any file/protocol activation.
    /// This guides the user to set Markdown Viewer as the default app for .md files.
    /// </summary>
    private static void ShowHelpDialog()
    {
        const string message = 
            "Markdown Viewer renders .md and .markdown files in your browser.\n\n" +
            "To use Markdown Viewer:\n" +
            "• Right-click a .md file → Open with → Markdown Viewer\n" +
            "• Set as default: Click OK to open Default Apps settings\n\n" +
            "Once set as default, double-click any Markdown file to view it.";

        const string caption = "Markdown Viewer";

        int result = MessageBoxW(IntPtr.Zero, message, caption, MB_OKCANCEL | MB_ICONINFORMATION);

        if (result == IDOK)
        {
            // Open Windows Default Apps settings
            OpenDefaultAppsSettings();
        }
    }

    /// <summary>
    /// Open Windows Settings to the Default Apps page.
    /// </summary>
    private static void OpenDefaultAppsSettings()
    {
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = "ms-settings:defaultapps",
                UseShellExecute = true
            };
            Process.Start(startInfo);
        }
        catch
        {
            // If settings fails to open, just exit silently
        }
    }

    /// <summary>
    /// Launch the PowerShell engine with the given path or URI.
    /// </summary>
    /// <param name="pathOrUri">Absolute file path or mdview: URI</param>
    private static void LaunchEngine(string pathOrUri)
    {
        // Resolve paths relative to the host executable (package install location)
        var hostDir = AppContext.BaseDirectory;
        
        // In packaged deployment:
        // - pwsh is at: <package>/pwsh/pwsh.exe
        // - engine is at: <package>/app/Open-Markdown.ps1
        var pwshPath = Path.Combine(hostDir, "pwsh", "pwsh.exe");
        var enginePath = Path.Combine(hostDir, "app", "Open-Markdown.ps1");
        
        // Fallback for development/unpackaged scenarios
        if (!File.Exists(pwshPath))
        {
            // Try system pwsh
            pwshPath = "pwsh";
        }
        
        if (!File.Exists(enginePath))
        {
            // Try relative to host in dev layout (bin/Debug/.../win-x64 -> src/core)
            // Go up from bin\Debug\net10.0-windows10.0.19041.0\win-x64 to project root, then to src/core
            var devEnginePath = Path.GetFullPath(Path.Combine(hostDir, "..", "..", "..", "..", "..", "..", "src", "core", "Open-Markdown.ps1"));
            if (File.Exists(devEnginePath))
            {
                enginePath = devEnginePath;
            }
        }

        // Build process start info with structured arguments (no string concatenation)
        var startInfo = new ProcessStartInfo
        {
            FileName = pwshPath,
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden
        };

        // Add arguments as a structured list
        startInfo.ArgumentList.Add("-NoProfile");
        startInfo.ArgumentList.Add("-ExecutionPolicy");
        startInfo.ArgumentList.Add("Bypass");
        startInfo.ArgumentList.Add("-File");
        startInfo.ArgumentList.Add(enginePath);
        startInfo.ArgumentList.Add("-Path");
        startInfo.ArgumentList.Add(pathOrUri);

        // Start pwsh and exit immediately (stateless host policy)
        using var process = Process.Start(startInfo);
        // Do not wait for process - host exits immediately
    }
}
