// ActivationHandler - Testable core logic for handling app activation
// This class contains the business logic extracted from Program for testability.

using Windows.ApplicationModel.Activation;

namespace MarkdownViewerHost;

/// <summary>
/// Handles app activation and launches the PowerShell engine.
/// This class is designed for testability with injectable dependencies.
/// </summary>
public sealed class ActivationHandler
{
    private readonly IFileSystem _fileSystem;
    private readonly IProcessLauncher _processLauncher;
    private readonly IAppContext _appContext;
    private readonly IAppActivation _appActivation;
    private readonly Action<string>? _log;

    public ActivationHandler(
        IFileSystem fileSystem,
        IProcessLauncher processLauncher,
        IAppContext appContext,
        IAppActivation appActivation,
        Action<string>? log = null)
    {
        _fileSystem = fileSystem ?? throw new ArgumentNullException(nameof(fileSystem));
        _processLauncher = processLauncher ?? throw new ArgumentNullException(nameof(processLauncher));
        _appContext = appContext ?? throw new ArgumentNullException(nameof(appContext));
        _appActivation = appActivation ?? throw new ArgumentNullException(nameof(appActivation));
        _log = log;
    }

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
            case ActivationKind.File:
                _log?.Invoke("  Handling File activation");
                return HandleFileActivation(activationResult.FilePaths);

            case ActivationKind.Protocol:
                _log?.Invoke("  Handling Protocol activation");
                return HandleProtocolActivation(activationResult.ProtocolUri);

            case ActivationKind.Launch:
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
                LaunchEngine(path);
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
        LaunchEngine(uri.AbsoluteUri);
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
    /// </summary>
    /// <param name="pathOrUri">Absolute file path or mdview: URI</param>
    public void LaunchEngine(string pathOrUri)
    {
        _log?.Invoke($"  LaunchEngine: {pathOrUri}");

        var packageRoot = ResolvePackageRoot();
        var pwshPath = ResolvePwshPath(packageRoot);
        var enginePath = ResolveEnginePath(packageRoot);
        var arguments = BuildEngineArguments(enginePath, pathOrUri);

        _log?.Invoke($"    Starting: {pwshPath} {string.Join(" ", arguments)}");

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
}
