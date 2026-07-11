// ActivationHandler - Testable core logic for handling app activation
// This class contains the business logic extracted from Program for testability.

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace MarkdownViewerHost
{
    /// <summary>
    /// Handles app activation and launches the PowerShell engine.
    /// This class is designed for testability with injectable dependencies.
    /// </summary>
    public sealed class ActivationHandler
    {
        /// <summary>
        /// Environment variable name for test signal path.
        /// When set, host writes JSON trace and exits without launching pwsh.
        /// </summary>
        public const string TestSignalPathEnvVar = "MDV_TEST_SIGNAL_PATH";

        /// <summary>
        /// Environment variable name for E2E trace path (alias for test signal).
        /// When set, host writes JSON trace and exits without launching pwsh.
        /// Used for MSIX E2E activation tests.
        /// </summary>
        public const string E2ETracePathEnvVar = "MDV_E2E_TRACE_PATH";

        private readonly IFileSystem _fileSystem;
        private readonly IProcessLauncher _processLauncher;
        private readonly IAppContext _appContext;
        private readonly IAppActivation _appActivation;
        private readonly IEnvironment _environment;
        private readonly Action<string> _log;

        public ActivationHandler(
            IFileSystem fileSystem,
            IProcessLauncher processLauncher,
            IAppContext appContext,
            IAppActivation appActivation,
            Action<string> log = null)
            : this(fileSystem, processLauncher, appContext, appActivation, new DefaultEnvironment(), log)
        {
        }

        public ActivationHandler(
            IFileSystem fileSystem,
            IProcessLauncher processLauncher,
            IAppContext appContext,
            IAppActivation appActivation,
            IEnvironment environment,
            Action<string> log = null)
        {
            _fileSystem = fileSystem ?? throw new ArgumentNullException("fileSystem");
            _processLauncher = processLauncher ?? throw new ArgumentNullException("processLauncher");
            _appContext = appContext ?? throw new ArgumentNullException("appContext");
            _appActivation = appActivation ?? throw new ArgumentNullException("appActivation");
            _environment = environment ?? throw new ArgumentNullException("environment");
            _log = log;
        }

        /// <summary>
        /// Gets the test signal path from environment variable, or null if not in test mode.
        /// Checks MDV_TEST_SIGNAL_PATH first, then MDV_E2E_TRACE_PATH as fallback.
        /// </summary>
        public string GetTestSignalPath()
        {
            var path = _environment.GetEnvironmentVariable(TestSignalPathEnvVar);
            if (!string.IsNullOrEmpty(path)) return path;
            return _environment.GetEnvironmentVariable(E2ETracePathEnvVar);
        }

        /// <summary>
        /// Returns true if running in test mode (MDV_TEST_SIGNAL_PATH is set).
        /// </summary>
        public bool IsTestMode
        {
            get { return !string.IsNullOrEmpty(GetTestSignalPath()); }
        }

        /// <summary>
        /// Try to handle activation using the AppInstance API (for packaged apps).
        /// </summary>
        /// <returns>True if activation was handled, false to fall back to args</returns>
        public bool TryHandlePackagedActivation()
        {
            var activationResult = _appActivation.TryGetActivatedEventArgs();
            if (_log != null) 
            {
                _log(string.Format("  AppActivation result: {0}", activationResult != null ? activationResult.Kind.ToString() : "(null)"));
                if (activationResult != null)
                {
                    _log(string.Format("  ActivationKind: {0}", activationResult.Kind));
                }
            }

            if (activationResult == null)
            {
                return false;
            }

            if (activationResult.Kind == ActivationKinds.File)
            {
                if (_log != null) _log("  Handling File activation via AppInstance");
                return HandleFileActivation(activationResult.FilePaths);
            }
            else if (activationResult.Kind == ActivationKinds.Protocol)
            {
                if (_log != null) 
                {
                    _log("  Handling Protocol activation via AppInstance");
                    _log(string.Format("  ProtocolUri from ActivatedEventArgs: {0}", activationResult.ProtocolUri?.AbsoluteUri ?? "(null)"));
                }
                return HandleProtocolActivation(activationResult.ProtocolUri);
            }
            else if (activationResult.Kind == ActivationKinds.Launch)
            {
                // Launched without specific activation (e.g., from Start Menu)
                // Return false to show help dialog via the args.Length == 0 path
                if (_log != null) _log("  Launch activation (no file/protocol) - will show help");
                return false;
            }
            else
            {
                if (_log != null) _log(string.Format("  Unhandled activation kind: {0}", activationResult.Kind));
                return false;
            }
        }

        /// <summary>
        /// Handle file activation (double-click .md file or Open With).
        /// </summary>
        public bool HandleFileActivation(IReadOnlyList<string> filePaths)
        {
            if (filePaths == null || filePaths.Count == 0)
            {
                if (_log != null) _log("  FileActivation: No files");
                return false;
            }

            // AppInstance file payloads can contain the same Windows path more than once.
            // Launch each distinct source exactly once while preserving selection order.
            var seenPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var distinctPaths = new List<string>();
            foreach (var path in filePaths)
            {
                if (!string.IsNullOrWhiteSpace(path) && seenPaths.Add(path))
                {
                    distinctPaths.Add(path);
                }
            }

            if (distinctPaths.Count == 0)
            {
                if (_log != null) _log("  FileActivation: No valid files");
                return false;
            }

            if (_log != null)
            {
                _log(string.Format("  FileActivation: {0} file(s), {1} distinct", filePaths.Count, distinctPaths.Count));
            }

            foreach (var path in distinctPaths)
            {
                if (_log != null) _log(string.Format("    File: {0}", path));
                LaunchEngine(path, "file");
            }

            return true;
        }

        /// <summary>
        /// Handle protocol activation (mdview: links).
        /// </summary>
        public bool HandleProtocolActivation(Uri uri)
        {
            if (uri == null)
            {
                return false;
            }

            // Pass the full URI (including fragment) to the engine
            LaunchEngine(uri.AbsoluteUri, "protocol");
            return true;
        }

        /// <summary>
        /// Handle command-line arguments (fallback for unpackaged/dev scenario).
        /// </summary>
        public void HandleCommandLineArgs(string[] args)
        {
            foreach (var arg in args)
            {
                if (!string.IsNullOrWhiteSpace(arg))
                {
                    LaunchEngine(arg);
                }
            }
        }

        /// <summary>
        /// Open Windows Settings to the Default Apps page.
        /// </summary>
        public void OpenDefaultAppsSettings()
        {
            try
            {
                _processLauncher.LaunchUri("ms-settings:defaultapps");
            }
            catch
            {
                // If settings fails to open, just exit silently
            }
        }

        /// <summary>
        /// Resolves the package root directory, accounting for WAP subfolder layout.
        /// </summary>
        public string ResolvePackageRoot()
        {
            var hostDir = _appContext.BaseDirectory;
            var packageRoot = hostDir;

            // Check if we're in a subfolder by looking for pwsh\ in parent directory
            var parentDir = _fileSystem.GetDirectoryName(hostDir.TrimEnd(Path.DirectorySeparatorChar));
            if (!string.IsNullOrEmpty(parentDir))
            {
                var parentPwshPath = _fileSystem.CombinePath(parentDir, "pwsh", "pwsh.exe");
                var parentAppPath = _fileSystem.CombinePath(parentDir, "app", "Open-Markdown.ps1");
                if (_fileSystem.FileExists(parentPwshPath) || _fileSystem.FileExists(parentAppPath))
                {
                    if (_log != null) _log("    Detected host is in WAP subfolder, using parent as package root");
                    packageRoot = parentDir + Path.DirectorySeparatorChar;
                }
            }

            return packageRoot;
        }

        /// <summary>
        /// Resolves the path to the PowerShell executable.
        /// </summary>
        public string ResolvePwshPath(string packageRoot)
        {
            var pwshPath = _fileSystem.CombinePath(packageRoot, "pwsh", "pwsh.exe");
            if (_log != null) _log(string.Format("    Looking for pwsh at: {0}", pwshPath));

            if (!_fileSystem.FileExists(pwshPath))
            {
                if (_log != null) _log("    pwsh not found in package, using system pwsh");
                pwshPath = "pwsh";
            }

            return pwshPath;
        }

        /// <summary>
        /// Resolves the path to the engine script (Open-Markdown.ps1).
        /// </summary>
        public string ResolveEnginePath(string packageRoot)
        {
            var enginePath = _fileSystem.CombinePath(packageRoot, "app", "Open-Markdown.ps1");
            if (_log != null) _log(string.Format("    Looking for engine at: {0}", enginePath));

            if (!_fileSystem.FileExists(enginePath))
            {
                // Try relative to host in dev layout
                var devEnginePath = _fileSystem.GetFullPath(
                    _fileSystem.CombinePath(packageRoot, "..", "..", "..", "..", "..", "..", "src", "core", "Open-Markdown.ps1"));
                if (_log != null) _log(string.Format("    Engine not found, trying dev path: {0}", devEnginePath));
                if (_fileSystem.FileExists(devEnginePath))
                {
                    enginePath = devEnginePath;
                }
                else
                {
                    if (_log != null) _log("    ERROR: Engine not found at either location!");
                }
            }

            return enginePath;
        }

        /// <summary>
        /// Builds the argument list for launching the PowerShell engine.
        /// </summary>
        public IReadOnlyList<string> BuildEngineArguments(string enginePath, string pathOrUri)
        {
            return new[]
            {
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                enginePath,
                "-Path",
                pathOrUri
            };
        }

        /// <summary>
        /// Launch the PowerShell engine with the given path or URI.
        /// In test mode (MDV_TEST_SIGNAL_PATH or MDV_E2E_TRACE_PATH set), writes a JSON trace and exits without launching pwsh.
        /// </summary>
        /// <param name="pathOrUri">Absolute file path or mdview: URI</param>
        /// <param name="activationKind">The kind of activation that triggered this launch</param>
        public void LaunchEngine(string pathOrUri, string activationKind = "commandline")
        {
            if (_log != null) _log(string.Format("  LaunchEngine: {0}", pathOrUri));

            var packageRoot = ResolvePackageRoot();
            var pwshPath = ResolvePwshPath(packageRoot);
            var enginePath = ResolveEnginePath(packageRoot);
            var arguments = BuildEngineArguments(enginePath, pathOrUri);

            if (_log != null) _log(string.Format("    Starting: {0} {1}", pwshPath, string.Join(" ", arguments)));

            // Check for test mode
            var testSignalPath = GetTestSignalPath();
            if (!string.IsNullOrEmpty(testSignalPath))
            {
                if (_log != null) _log(string.Format("    TEST MODE: Writing signal to {0}", testSignalPath));
                WriteTestSignal(testSignalPath, activationKind, pathOrUri, packageRoot, pwshPath, enginePath, arguments);
                return; // Exit without launching pwsh
            }

            try
            {
                var processId = _processLauncher.LaunchProcess(pwshPath, arguments, useShellExecute: false, createNoWindow: true);
                if (_log != null) _log(string.Format("    Process started: PID={0}", processId));
            }
            catch (Exception ex)
            {
                if (_log != null) _log(string.Format("    LaunchEngine exception: {0}", ex.Message));
            }
        }

        /// <summary>
        /// Writes a test signal JSON record to the specified path.
        /// </summary>
        private void WriteTestSignal(string signalPath, string kind, string arg, string packageRoot, string pwshPath, string enginePath, IReadOnlyList<string> arguments)
        {
            try
            {
                var json = SerializeTestSignal(kind, arg, packageRoot, pwshPath, enginePath, arguments);
                _fileSystem.AppendAllText(signalPath, json + Environment.NewLine);
            }
            catch (Exception ex)
            {
                if (_log != null) _log(string.Format("    Failed to write test signal: {0}", ex.Message));
            }
        }

        /// <summary>
        /// Serializes test signal data to JSON without using System.Text.Json.
        /// </summary>
        private string SerializeTestSignal(string kind, string arg, string packageRoot, string pwshPath, string enginePath, IReadOnlyList<string> arguments)
        {
            var sb = new StringBuilder();
            sb.Append('{');
            sb.Append("\"kind\":\""); sb.Append(EscapeJsonString(kind)); sb.Append("\",");
            sb.Append("\"arg\":\""); sb.Append(EscapeJsonString(arg)); sb.Append("\",");
            sb.Append("\"resolvedPackageRoot\":\""); sb.Append(EscapeJsonString(packageRoot)); sb.Append("\",");
            sb.Append("\"resolvedPwsh\":\""); sb.Append(EscapeJsonString(pwshPath)); sb.Append("\",");
            sb.Append("\"resolvedEngine\":\""); sb.Append(EscapeJsonString(enginePath)); sb.Append("\",");
            sb.Append("\"hostBaseDirectory\":\""); sb.Append(EscapeJsonString(_appContext.BaseDirectory)); sb.Append("\",");
            sb.Append("\"pwshArguments\":[");
            for (int i = 0; i < arguments.Count; i++)
            {
                if (i > 0) sb.Append(',');
                sb.Append('"'); sb.Append(EscapeJsonString(arguments[i])); sb.Append('"');
            }
            sb.Append("],");
            sb.Append("\"timestamp\":\""); sb.Append(EscapeJsonString(DateTime.UtcNow.ToString("o"))); sb.Append('"');
            sb.Append('}');
            return sb.ToString();
        }

        private static string EscapeJsonString(string s)
        {
            if (s == null) return string.Empty;
            var sb = new StringBuilder();
            foreach (char c in s)
            {
                switch (c)
                {
                    case '\\': sb.Append("\\\\"); break;
                    case '"': sb.Append("\\\""); break;
                    case '\b': sb.Append("\\b"); break;
                    case '\f': sb.Append("\\f"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < 32) sb.AppendFormat("\\u{0:X4}", (int)c);
                        else sb.Append(c);
                        break;
                }
            }
            return sb.ToString();
        }
    }
}
