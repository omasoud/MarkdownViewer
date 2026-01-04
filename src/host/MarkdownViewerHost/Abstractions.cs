// Abstractions for testability
// These interfaces allow mocking external dependencies in unit tests.

using Windows.ApplicationModel.Activation;

namespace MarkdownViewerHost;

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
/// Result of activation query.
/// </summary>
public record ActivationResult(ActivationKind Kind, IReadOnlyList<string>? FilePaths = null, Uri? ProtocolUri = null);

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
/// </summary>
public sealed class DefaultAppActivation : IAppActivation
{
    public ActivationResult? TryGetActivatedEventArgs()
    {
        try
        {
            var args = Windows.ApplicationModel.AppInstance.GetActivatedEventArgs();
            if (args == null) return null;

            switch (args.Kind)
            {
                case ActivationKind.File:
                    var fileArgs = (FileActivatedEventArgs)args;
                    var paths = fileArgs.Files?.Select(f => f.Path).Where(p => !string.IsNullOrWhiteSpace(p)).ToList();
                    return new ActivationResult(ActivationKind.File, paths);

                case ActivationKind.Protocol:
                    var protocolArgs = (ProtocolActivatedEventArgs)args;
                    return new ActivationResult(ActivationKind.Protocol, ProtocolUri: protocolArgs.Uri);

                case ActivationKind.Launch:
                    return new ActivationResult(ActivationKind.Launch);

                default:
                    return new ActivationResult(args.Kind);
            }
        }
        catch
        {
            // Not running as packaged app, or API not available
            return null;
        }
    }
}
