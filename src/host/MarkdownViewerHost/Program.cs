// MarkdownViewerHost - Minimal host for MSIX activation
// This is a Windows GUI subsystem app that handles file and protocol activation,
// then launches the bundled PowerShell engine (Open-Markdown.ps1).
//
// Activation handling:
// - Packaged (MSIX): Uses AppInstance.GetActivatedEventArgs() for proper activation data
// - Unpackaged (dev): Falls back to command-line args
// - No activation: Shows help dialog

using System.Diagnostics;
using System.Reflection;
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
        catch (Exception /*ex*/)
        {
            // Exit silently on any error - Engine owns error presentation
            // Host must not show duplicate dialogs
            // copy exception to clipboard for debugging
            // Clipboard.SetText(ex.ToString());
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
    /// Uses Windows Forms for a modern, visually appealing UI.
    /// </summary>
    private static void ShowHelpDialog()
{
    using var form = new Form();
    form.Text = "Markdown Viewer";
    form.Size = new Size(600, 400);
    form.BackColor = Color.AliceBlue;
    form.FormBorderStyle = FormBorderStyle.FixedDialog;
    form.MaximizeBox = false;
    form.MinimizeBox = false;
    form.StartPosition = FormStartPosition.CenterScreen;

    // --- ICON LOGIC START ---
    var assembly = Assembly.GetExecutingAssembly();
    using var stream = assembly.GetManifestResourceStream("AppIconResource"); // Ensure name matches .csproj

    if (stream != null)
    {
        // 1. Set the Window Icon (Taskbar/Titlebar)
        // The standard Icon constructor is fine for small sizes
        form.Icon = new Icon(stream);
        form.ShowIcon = true;

        // 2. Get the High-Quality Image for the UI
        // We ask for 64, but your helper will likely find the 256px version 
        // and downscale it nicely, or return the 256px one directly.
        using var bestBitmap = IconHelper.GetIconBySize(stream, 64);

        if (bestBitmap != null)
        {
            var iconBox = new PictureBox();
            
            // If the bitmap is huge (256px), we scale it down to 64px for the UI
            if (bestBitmap.Width > 64)
            {
                var scaled = new Bitmap(64, 64);
                using (var g = Graphics.FromImage(scaled))
                {
                    g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                    g.DrawImage(bestBitmap, 0, 0, 64, 64);
                }
                iconBox.Image = scaled;
            }
            else
            {
                iconBox.Image = (Image)bestBitmap.Clone();
            }

            iconBox.Size = new Size(64, 64);
            iconBox.SizeMode = PictureBoxSizeMode.CenterImage;
            iconBox.Location = new Point(30, 25);
            iconBox.BackColor = Color.Transparent; // Clean transparency
            iconBox.BorderStyle = BorderStyle.None;
            form.Controls.Add(iconBox);
        }
    }
    // --- ICON LOGIC END ---

    // The rest of your UI setup...
    var headerFont = new Font("Segoe UI", 18, FontStyle.Regular);
    var bodyFont = new Font("Segoe UI", 11, FontStyle.Regular);
    var buttonFont = new Font("Segoe UI", 10, FontStyle.Regular);

    var lblHeading = new Label();
    lblHeading.Text = "Welcome to Markdown Viewer";
    lblHeading.Font = headerFont;
    lblHeading.ForeColor = Color.FromArgb(0, 51, 153);
    lblHeading.Location = new Point(110, 30);
    lblHeading.AutoSize = true;
    form.Controls.Add(lblHeading);

    var lblBody = new Label();
    lblBody.Text = "This app renders Markdown files (.md) in your browser.\n\n" +
                   "To view a Markdown file:\n" +
                   "• Right-click a .md file → Open with → Markdown Viewer\n" +
                   "• Or double-click a .md file after you have set Markdown\n" +
                   "   Viewer as the default app below.";
    lblBody.Font = bodyFont;
    lblBody.ForeColor = Color.FromArgb(64, 64, 64);
    lblBody.Location = new Point(110, 80);
    lblBody.Size = new Size(500, 150);
    form.Controls.Add(lblBody);

    var btnSettings = new Button();
    btnSettings.Text = "Open Default Apps Settings";
    btnSettings.Font = buttonFont;
    btnSettings.Size = new Size(250, 45);
    btnSettings.Location = new Point(110, 240);
    btnSettings.FlatStyle = FlatStyle.Flat;
    btnSettings.BackColor = Color.FromArgb(0, 120, 215);
    btnSettings.ForeColor = Color.White;
    btnSettings.Cursor = Cursors.Hand;
    btnSettings.FlatAppearance.BorderSize = 0;
    btnSettings.Click += (s, e) => 
    {
        OpenDefaultAppsSettings();
        form.Close();
    };
    form.Controls.Add(btnSettings);

    var btnClose = new Button();
    btnClose.Text = "Close";
    btnClose.Font = buttonFont;
    btnClose.Size = new Size(100, 45);
    btnClose.Location = new Point(370, 240);
    btnClose.FlatStyle = FlatStyle.Flat;
    btnClose.BackColor = Color.FromArgb(240, 240, 240);
    btnClose.ForeColor = Color.Black;
    btnClose.FlatAppearance.BorderSize = 0;
    btnClose.Click += (s, e) => form.Close();
    form.Controls.Add(btnClose);

    form.ShowDialog();
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
