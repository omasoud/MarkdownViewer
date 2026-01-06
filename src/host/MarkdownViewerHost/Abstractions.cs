// Abstractions for testability
// These interfaces allow mocking external dependencies in unit tests.

using System.Text.Json;
using System.Text.Json.Serialization;

namespace MarkdownViewerHost;

/// <summary>
/// String constants for activation kinds, avoiding direct dependency on Windows.ApplicationModel.Activation.
/// </summary>
public static class ActivationKinds
{
    public const string File = "file";
    public const string Protocol = "protocol";
    public const string Launch = "launch";
    public const string Unknown = "unknown";
}

/// <summary>
/// Test signal record written to MDV_TEST_SIGNAL_PATH (or MDV_E2E_TRACE_PATH) when running in test mode.
/// This allows integration tests to verify path resolution without launching pwsh.
/// </summary>
public sealed class TestSignalRecord
{
    [JsonPropertyName("kind")]
    public string Kind { get; set; } = string.Empty;
    
    [JsonPropertyName("arg")]
    public string Arg { get; set; } = string.Empty;
    
    [JsonPropertyName("resolvedPackageRoot")]
    public string ResolvedPackageRoot { get; set; } = string.Empty;
    
    [JsonPropertyName("resolvedPwsh")]
    public string ResolvedPwsh { get; set; } = string.Empty;
    
    [JsonPropertyName("resolvedEngine")]
    public string ResolvedEngine { get; set; } = string.Empty;
    
    [JsonPropertyName("hostBaseDirectory")]
    public string HostBaseDirectory { get; set; } = string.Empty;
    
    [JsonPropertyName("pwshArguments")]
    public IReadOnlyList<string> PwshArguments { get; set; } = Array.Empty<string>();
    
    [JsonPropertyName("timestamp")]
    public string Timestamp { get; set; } = string.Empty;
    
    public string ToJson() => JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = false });
}

/// <summary>
/// Abstraction for environment variable access.
/// </summary>
public interface IEnvironment
{
    string? GetEnvironmentVariable(string variable);
}

/// <summary>
/// Default implementation using System.Environment.
/// </summary>
public sealed class DefaultEnvironment : IEnvironment
{
    public string? GetEnvironmentVariable(string variable) => Environment.GetEnvironmentVariable(variable);
}

/// <summary>
/// Abstraction for file system operations.
/// </summary>
public interface IFileSystem
{
    bool FileExists(string path);
    string GetDirectoryName(string path);
    string CombinePath(params string[] paths);
    string GetFullPath(string path);
    string GetTempPath();
    void AppendAllText(string path, string contents);
    void DeleteFile(string path);
}

/// <summary>
/// Abstraction for process launching.
/// </summary>
public interface IProcessLauncher
{
    int? LaunchProcess(string fileName, IReadOnlyList<string> arguments, bool useShellExecute, bool createNoWindow);
    void LaunchUri(string uri);
}

/// <summary>
/// Abstraction for getting the app's base directory.
/// </summary>
public interface IAppContext
{
    string BaseDirectory { get; }
}

/// <summary>
/// Abstraction for packaged app activation.
/// </summary>
public interface IAppActivation
{
    /// <summary>
    /// Try to get activation arguments from AppInstance API.
    /// </summary>
    /// <returns>The activation kind and associated data, or null if not available.</returns>
    ActivationResult? TryGetActivatedEventArgs();
}

/// <summary>
/// Result of activation query. Uses string-based Kind to avoid Windows SDK assembly dependency.
/// </summary>
public record ActivationResult(string Kind, IReadOnlyList<string>? FilePaths = null, Uri? ProtocolUri = null);

/// <summary>
/// Default implementation using System.IO.
/// </summary>
public sealed class DefaultFileSystem : IFileSystem
{
    public bool FileExists(string path) => File.Exists(path);
    public string GetDirectoryName(string path) => Path.GetDirectoryName(path) ?? string.Empty;
    public string CombinePath(params string[] paths) => Path.Combine(paths);
    public string GetFullPath(string path) => Path.GetFullPath(path);
    public string GetTempPath() => Path.GetTempPath();
    public void AppendAllText(string path, string contents) => File.AppendAllText(path, contents);
    public void DeleteFile(string path) => File.Delete(path);
}

/// <summary>
/// Default implementation using System.Diagnostics.Process.
/// </summary>
public sealed class DefaultProcessLauncher : IProcessLauncher
{
    public int? LaunchProcess(string fileName, IReadOnlyList<string> arguments, bool useShellExecute, bool createNoWindow)
    {
        var startInfo = new System.Diagnostics.ProcessStartInfo
        {
            FileName = fileName,
            UseShellExecute = useShellExecute,
            CreateNoWindow = createNoWindow,
            WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden
        };

        foreach (var arg in arguments)
        {
            startInfo.ArgumentList.Add(arg);
        }

        using var process = System.Diagnostics.Process.Start(startInfo);
        return process?.Id;
    }

    public void LaunchUri(string uri)
    {
        var startInfo = new System.Diagnostics.ProcessStartInfo
        {
            FileName = uri,
            UseShellExecute = true
        };
        System.Diagnostics.Process.Start(startInfo);
    }
}

/// <summary>
/// Default implementation using AppContext.BaseDirectory.
/// </summary>
public sealed class DefaultAppContext : IAppContext
{
    public string BaseDirectory => AppContext.BaseDirectory;
}

/// <summary>
/// Default implementation using AppInstance API (packaged apps only).
/// This class is isolated in its own method to allow lazy loading of Windows SDK types.
/// </summary>
public sealed class DefaultAppActivation : IAppActivation
{
    public ActivationResult? TryGetActivatedEventArgs()
    {
        try
        {
            return TryGetActivatedEventArgsCore();
        }
        catch
        {
            // Not running as packaged app, or Windows SDK assembly not available
            return null;
        }
    }
    
    // Separate method to isolate Windows SDK type usage and allow proper exception handling
    private static ActivationResult? TryGetActivatedEventArgsCore()
    {
        var args = Windows.ApplicationModel.AppInstance.GetActivatedEventArgs();
        if (args == null) return null;

        switch (args.Kind)
        {
            case Windows.ApplicationModel.Activation.ActivationKind.File:
                var fileArgs = (Windows.ApplicationModel.Activation.FileActivatedEventArgs)args;
                var paths = fileArgs.Files?.Select(f => f.Path).Where(p => !string.IsNullOrWhiteSpace(p)).ToList();
                return new ActivationResult(ActivationKinds.File, paths);

            case Windows.ApplicationModel.Activation.ActivationKind.Protocol:
                var protocolArgs = (Windows.ApplicationModel.Activation.ProtocolActivatedEventArgs)args;
                return new ActivationResult(ActivationKinds.Protocol, ProtocolUri: protocolArgs.Uri);

            case Windows.ApplicationModel.Activation.ActivationKind.Launch:
                return new ActivationResult(ActivationKinds.Launch);

            default:
                return new ActivationResult(ActivationKinds.Unknown);
        }
    }
}
