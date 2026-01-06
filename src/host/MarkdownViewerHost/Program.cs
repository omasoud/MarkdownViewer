// MarkdownViewerHost - Minimal host for MSIX activation
// This is a Windows GUI subsystem app that handles file and protocol activation,
// then launches the bundled PowerShell engine (Open-Markdown.ps1).
//
// Activation handling:
// - Packaged (MSIX): Uses AppInstance.GetActivatedEventArgs() for proper activation data
// - Unpackaged (dev): Falls back to command-line args
// - No activation: Shows help dialog

using System;
using System.IO;
using System.Linq;
using System.Windows.Forms;

namespace MarkdownViewerHost
{
    /// <summary>
    /// Simple file logger for debugging WinExe apps where Console.WriteLine doesn't work.
    /// Logs are written to %TEMP%\MarkdownViewerHost.log
    /// </summary>
    internal static class Logger
    {
        private static readonly string LogPath = Path.Combine(Path.GetTempPath(), "MarkdownViewerHost.log");
        private static readonly bool EnableLogging = true; // Set to false in release if desired

        public static void Log(string message)
        {
            if (!EnableLogging) return;
            try
            {
                var timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
                File.AppendAllText(LogPath, string.Format("[{0}] {1}{2}", timestamp, message, Environment.NewLine));
            }
            catch
            {
                // Ignore logging failures
            }
        }

        public static void LogException(Exception ex, string context = "")
        {
            Log(string.Format("EXCEPTION {0}: {1}: {2}", context, ex.GetType().Name, ex.Message));
            Log(string.Format("  StackTrace: {0}", ex.StackTrace));
        }

        public static void Clear()
        {
            try { File.Delete(LogPath); } catch { }
        }
    }

    /// <summary>
    /// Entry point for the Markdown Viewer host application. 
    /// Handles MSIX activation (file associations, protocol) and launches the PowerShell engine.
    /// </summary>
    internal static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            Logger.Log("=== MarkdownViewerHost started ===");
            Logger.Log(string.Format("  Args: [{0}]", string.Join(", ", args.Select(a => string.Format("\"{0}\"", a)))));
            Logger.Log(string.Format("  BaseDirectory: {0}", AppContext.BaseDirectory));

            // Enable visual styles for TaskDialog
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Create the activation handler with default (real) implementations
            var handler = new ActivationHandler(
                new DefaultFileSystem(),
                new DefaultProcessLauncher(),
                new DefaultAppContext(),
                new DefaultAppActivation(),
                Logger.Log);

            try
            {
                // Try to get activation data from AppInstance API (packaged apps)
                var activationHandled = handler.TryHandlePackagedActivation();
                Logger.Log(string.Format("  PackagedActivation handled: {0}", activationHandled));

                if (!activationHandled)
                {
                    // Fallback to command-line args (unpackaged/dev scenario)
                    if (args.Length > 0)
                    {
                        handler.HandleCommandLineArgs(args);
                    }
                    else
                    {
                        // No arguments - launched from Start Menu or shortcut
                        Logger.Log("  Showing help dialog (no args)");
                        HelpDialogManager.ShowHelpDialog();
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.LogException(ex, "Main");
                // Exit silently on any error - Engine owns error presentation
                // Host must not show duplicate dialogs
            }

            Logger.Log("=== MarkdownViewerHost exiting ===");
        }
    }
}
