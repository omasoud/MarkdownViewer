// MarkdownViewerHost - Minimal host for MSIX activation
// This is a Windows GUI subsystem app that handles file and protocol activation,
// then launches the bundled PowerShell engine (Open-Markdown.ps1).
//
// Activation handling:
// - Packaged (MSIX): Uses AppInstance.GetActivatedEventArgs() for proper activation data
// - Unpackaged (dev): Falls back to command-line args
// - No activation: Shows help dialog

using System.Diagnostics;
using System.Windows.Forms;
using Windows.ApplicationModel;
using Windows.ApplicationModel.Activation;

namespace MarkdownViewerHost;

/// <summary>
/// Entry point for the Markdown Viewer host application.
/// Handles MSIX activation (file associations, protocol) and launches the PowerShell engine.
/// </summary>
internal static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        // Enable visual styles for TaskDialog
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        
        try
        {
            // Try to get activation data from AppInstance API (packaged apps)
            var activationHandled = TryHandlePackagedActivation();
            
            if (!activationHandled)
            {
                // Fallback to command-line args (unpackaged/dev scenario)
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
                    ShowHelpDialog();
                }
            }
        }
        catch
        {
            // Exit silently on any error - Engine owns error presentation
            // Host must not show duplicate dialogs
        }
    }

    /// <summary>
    /// Try to handle activation using the AppInstance API (for packaged apps).
    /// </summary>
    /// <returns>True if activation was handled, false to fall back to args</returns>
    private static bool TryHandlePackagedActivation()
    {
        try
        {
            // This will throw if not running as a packaged app
            var activatedArgs = AppInstance.GetActivatedEventArgs();
            if (activatedArgs == null)
            {
                return false;
            }

            switch (activatedArgs.Kind)
            {
                case ActivationKind.File:
                    return HandleFileActivation((FileActivatedEventArgs)activatedArgs);
                    
                case ActivationKind.Protocol:
                    return HandleProtocolActivation((ProtocolActivatedEventArgs)activatedArgs);
                    
                case ActivationKind.Launch:
                    // Launched without specific activation (e.g., from Start Menu)
                    // Return false to show help dialog via the args.Length == 0 path
                    return false;
                    
                default:
                    return false;
            }
        }
        catch
        {
            // Not running as packaged app, or API not available
            return false;
        }
    }

    /// <summary>
    /// Handle file activation (double-click .md file or Open With).
    /// </summary>
    private static bool HandleFileActivation(FileActivatedEventArgs args)
    {
        if (args.Files == null || args.Files.Count == 0)
        {
            return false;
        }

        foreach (var file in args.Files)
        {
            // Get the path from the storage item
            var path = file.Path;
            if (!string.IsNullOrWhiteSpace(path))
            {
                LaunchEngine(path);
            }
        }

        return true;
    }

    /// <summary>
    /// Handle protocol activation (mdview: links).
    /// </summary>
    private static bool HandleProtocolActivation(ProtocolActivatedEventArgs args)
    {
        var uri = args.Uri;
        if (uri == null)
        {
            return false;
        }

        // Pass the full URI (including fragment) to the engine
        LaunchEngine(uri.AbsoluteUri);
        return true;
    }

    /// <summary>
    /// Show a help dialog when the app is launched without any file/protocol activation.
    /// This guides the user to set Markdown Viewer as the default app for .md files.
    /// Uses TaskDialog for a modern, visually appealing UI.
    /// </summary>
    private static void ShowHelpDialog()
    {
        // Create owner form for proper dialog positioning
        using var owner = new Form { TopMost = true };

        var page = new TaskDialogPage
        {
            Caption = "Markdown Viewer",
            Heading = "Welcome to Markdown Viewer",
            Text = "This app renders Markdown files (.md, .markdown) in your browser.\n\n" +
                   "To view a Markdown file:\n" +
                   "• Right-click a .md file → Open with → Markdown Viewer\n" +
                   "• Or set Markdown Viewer as the default app for .md files",
            Icon = TaskDialogIcon.Information,
            AllowCancel = true  // Allow closing with X button
        };

        // Add button to open Default Apps settings
        var btnDefaultApps = new TaskDialogCommandLinkButton("Open Default Apps Settings")
        {
            DescriptionText = "Set Markdown Viewer as the default app for .md and .markdown files"
        };
        btnDefaultApps.Click += (s, e) =>
        {
            OpenDefaultAppsSettings();
        };
        page.Buttons.Add(btnDefaultApps);

        // Add Close button
        page.Buttons.Add(TaskDialogButton.Close);

        // Show the dialog
        TaskDialog.ShowDialog(owner.Handle, page);
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
