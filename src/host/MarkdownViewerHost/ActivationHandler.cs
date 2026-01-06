// ActivationHandler - Testable core logic for handling app activation
// This class contains the business logic extracted from Program for testability.

namespace MarkdownViewerHost;

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
    private readonly Action<string>? _log;

    public ActivationHandler(
        IFileSystem fileSystem,
        IProcessLauncher processLauncher,
        IAppContext appContext,
        IAppActivation appActivation,
        Action<string>? log = null)
        : this(fileSystem, processLauncher, appContext, appActivation, new DefaultEnvironment(), log)
    {
    }

    public ActivationHandler(
        IFileSystem fileSystem,
        IProcessLauncher processLauncher,
        IAppContext appContext,
        IAppActivation appActivation,
        IEnvironment environment,
        Action<string>? log = null)
    {
        _fileSystem = fileSystem ?? throw new ArgumentNullException(nameof(fileSystem));
        _processLauncher = processLauncher ?? throw new ArgumentNullException(nameof(processLauncher));
        _appContext = appContext ?? throw new ArgumentNullException(nameof(appContext));
        _appActivation = appActivation ?? throw new ArgumentNullException(nameof(appActivation));
        _environment = environment ?? throw new ArgumentNullException(nameof(environment));
        _log = log;
    }

    /// <summary>
    /// Gets the test signal path from environment variable, or null if not in test mode.
    /// Checks MDV_TEST_SIGNAL_PATH first, then MDV_E2E_TRACE_PATH as fallback.
    /// </summary>
    public string? GetTestSignalPath()
    {
        var path = _environment.GetEnvironmentVariable(TestSignalPathEnvVar);
        if (!string.IsNullOrEmpty(path)) return path;
        return _environment.GetEnvironmentVariable(E2ETracePathEnvVar);
    }

    /// <summary>
    /// Returns true if running in test mode (MDV_TEST_SIGNAL_PATH is set).
    /// </summary>
    public bool IsTestMode => !string.IsNullOrEmpty(GetTestSignalPath());

    /// <summary>
    /// Try to handle activation using the AppInstance API (for packaged apps).
    /// </summary>
    /// <returns>True if activation was handled, false to fall back to args</returns>
    public bool TryHandlePackagedActivation()
    {
        var activationResult = _appActivation.TryGetActivatedEventArgs();
        _log?.Invoke($"  AppActivation result: {activationResult?.Kind}");

        if (activationResult == null)
        {
            return false;
        }

        switch (activationResult.Kind)
        {
            case ActivationKinds.File:
                _log?.Invoke("  Handling File activation");
                return HandleFileActivation(activationResult.FilePaths);

            case ActivationKinds.Protocol:
                _log?.Invoke("  Handling Protocol activation");
                return HandleProtocolActivation(activationResult.ProtocolUri);

            case ActivationKinds.Launch:
                // Launched without specific activation (e.g., from Start Menu)
                // Return false to show help dialog via the args.Length == 0 path
                _log?.Invoke("  Launch activation (no file/protocol) - will show help");
                return false;

            default:
                _log?.Invoke($"  Unhandled activation kind: {activationResult.Kind}");
                return false;
        }
    }

    /// <summary>
    /// Handle file activation (double-click .md file or Open With).
    /// </summary>
    public bool HandleFileActivation(IReadOnlyList<string>? filePaths)
    {
        if (filePaths == null || filePaths.Count == 0)
        {
            _log?.Invoke("  FileActivation: No files");
            return false;
        }

        _log?.Invoke($"  FileActivation: {filePaths.Count} file(s)");
        foreach (var path in filePaths)
        {
            _log?.Invoke($"    File: {path}");
            if (!string.IsNullOrWhiteSpace(path))
            {
                LaunchEngine(path, "file");
            }
        }

        return true;
    }

    /// <summary>
    /// Handle protocol activation (mdview: links).
    /// </summary>
    public bool HandleProtocolActivation(Uri? uri)
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
                _log?.Invoke($"    Detected host is in WAP subfolder, using parent as package root");
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
        _log?.Invoke($"    Looking for pwsh at: {pwshPath}");

        if (!_fileSystem.FileExists(pwshPath))
        {
            _log?.Invoke("    pwsh not found in package, using system pwsh");
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
        _log?.Invoke($"    Looking for engine at: {enginePath}");

        if (!_fileSystem.FileExists(enginePath))
        {
            // Try relative to host in dev layout
            var devEnginePath = _fileSystem.GetFullPath(
                _fileSystem.CombinePath(packageRoot, "..", "..", "..", "..", "..", "..", "src", "core", "Open-Markdown.ps1"));
            _log?.Invoke($"    Engine not found, trying dev path: {devEnginePath}");
            if (_fileSystem.FileExists(devEnginePath))
            {
                enginePath = devEnginePath;
            }
            else
            {
                _log?.Invoke($"    ERROR: Engine not found at either location!");
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
        _log?.Invoke($"  LaunchEngine: {pathOrUri}");

        var packageRoot = ResolvePackageRoot();
        var pwshPath = ResolvePwshPath(packageRoot);
        var enginePath = ResolveEnginePath(packageRoot);
        var arguments = BuildEngineArguments(enginePath, pathOrUri);

        _log?.Invoke($"    Starting: {pwshPath} {string.Join(" ", arguments)}");

        // Check for test mode
        var testSignalPath = GetTestSignalPath();
        if (!string.IsNullOrEmpty(testSignalPath))
        {
            _log?.Invoke($"    TEST MODE: Writing signal to {testSignalPath}");
            WriteTestSignal(testSignalPath, activationKind, pathOrUri, packageRoot, pwshPath, enginePath, arguments);
            return; // Exit without launching pwsh
        }

        try
        {
            var processId = _processLauncher.LaunchProcess(pwshPath, arguments, useShellExecute: false, createNoWindow: true);
            _log?.Invoke($"    Process started: PID={processId}");
        }
        catch (Exception ex)
        {
            _log?.Invoke($"    LaunchEngine exception: {ex.Message}");
        }
    }

    /// <summary>
    /// Writes a test signal JSON record to the specified path.
    /// </summary>
    private void WriteTestSignal(string signalPath, string kind, string arg, string packageRoot, string pwshPath, string enginePath, IReadOnlyList<string> arguments)
    {
        var signal = new TestSignalRecord
        {
            Kind = kind,
            Arg = arg,
            ResolvedPackageRoot = packageRoot,
            ResolvedPwsh = pwshPath,
            ResolvedEngine = enginePath,
            HostBaseDirectory = _appContext.BaseDirectory,
            PwshArguments = arguments,
            Timestamp = DateTime.UtcNow.ToString("o")
        };

        try
        {
            _fileSystem.AppendAllText(signalPath, signal.ToJson() + Environment.NewLine);
        }
        catch (Exception ex)
        {
            _log?.Invoke($"    Failed to write test signal: {ex.Message}");
        }
    }
}
