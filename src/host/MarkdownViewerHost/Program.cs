// MarkdownViewerHost - Minimal host for MSIX activation
// This is a Windows GUI subsystem app that handles file and protocol activation,
// then launches the bundled PowerShell engine (Open-Markdown.ps1).
//
// For MSIX packages, Windows passes activation arguments via command line:
// - File activation: The full path to the file
// - Protocol activation: The full protocol URI (mdview:file:///...)

using System.Diagnostics;

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
            // No arguments - nothing to do, exit silently
        }
        catch
        {
            // Exit silently on any error - Engine owns error presentation
            // Host must not show duplicate dialogs
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
