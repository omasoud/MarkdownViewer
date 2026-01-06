// Abstractions for testability
// These interfaces allow mocking external dependencies in unit tests.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using Windows.ApplicationModel.Activation;

namespace MarkdownViewerHost
{
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
    /// Result of activation query. Uses string-based Kind to avoid Windows SDK assembly dependency.
    /// </summary>
    public sealed class ActivationResult
    {
        public string Kind { get; private set; }
        public IReadOnlyList<string> FilePaths { get; private set; }
        public Uri ProtocolUri { get; private set; }

        public ActivationResult(string kind, IReadOnlyList<string> filePaths = null, Uri protocolUri = null)
        {
            Kind = kind ?? ActivationKinds.Unknown;
            FilePaths = filePaths;
            ProtocolUri = protocolUri;
        }
    }

    /// <summary>
    /// Abstraction for environment variable access.
    /// </summary>
    public interface IEnvironment
    {
        string GetEnvironmentVariable(string variable);
    }

    /// <summary>
    /// Default implementation using System.Environment.
    /// </summary>
    public sealed class DefaultEnvironment : IEnvironment
    {
        public string GetEnvironmentVariable(string variable)
        {
            return Environment.GetEnvironmentVariable(variable);
        }
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
        ActivationResult TryGetActivatedEventArgs();
    }

    /// <summary>
    /// Default implementation using System.IO.
    /// </summary>
    public sealed class DefaultFileSystem : IFileSystem
    {
        public bool FileExists(string path) { return File.Exists(path); }
        public string GetDirectoryName(string path) { return Path.GetDirectoryName(path) ?? string.Empty; }
        public string CombinePath(params string[] paths) { return Path.Combine(paths); }
        public string GetFullPath(string path) { return Path.GetFullPath(path); }
        public string GetTempPath() { return Path.GetTempPath(); }
        public void AppendAllText(string path, string contents) { File.AppendAllText(path, contents); }
        public void DeleteFile(string path) { File.Delete(path); }
    }

    /// <summary>
    /// Default implementation using System.Diagnostics.Process.
    /// </summary>
    public sealed class DefaultProcessLauncher : IProcessLauncher
    {
        public int? LaunchProcess(string fileName, IReadOnlyList<string> arguments, bool useShellExecute, bool createNoWindow)
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = fileName,
                UseShellExecute = useShellExecute,
                CreateNoWindow = createNoWindow,
                WindowStyle = ProcessWindowStyle.Hidden
            };

            // On .NET Framework, ArgumentList isn't available; build a properly quoted Arguments string
            startInfo.Arguments = string.Join(" ", arguments.Select(a => ProcessArgumentQuoter.QuoteArgument(a)));

            using (var process = Process.Start(startInfo))
            {
                return process != null ? (int?)process.Id : null;
            }
        }

        public void LaunchUri(string uri)
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = uri,
                UseShellExecute = true
            };
            Process.Start(startInfo);
        }
    }

    /// <summary>
    /// Default implementation using AppContext.BaseDirectory.
    /// </summary>
    public sealed class DefaultAppContext : IAppContext
    {
        public string BaseDirectory
        {
            get { return AppContext.BaseDirectory; }
        }
    }

    /// <summary>
    /// Default implementation using AppInstance API (packaged apps only).
    /// This class is isolated in its own method to allow lazy loading of Windows SDK types.
    /// </summary>
    public sealed class DefaultAppActivation : IAppActivation
    {
        public ActivationResult TryGetActivatedEventArgs()
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
        private static ActivationResult TryGetActivatedEventArgsCore()
        {
            var args = Windows.ApplicationModel.AppInstance.GetActivatedEventArgs();
            if (args == null) return null;

            switch (args.Kind)
            {
                case ActivationKind.File:
                    var fileArgs = (FileActivatedEventArgs)args;
                    var paths = fileArgs.Files != null
                        ? fileArgs.Files.Select(f => f.Path).Where(p => !string.IsNullOrWhiteSpace(p)).ToList()
                        : null;
                    return new ActivationResult(ActivationKinds.File, paths);

                case ActivationKind.Protocol:
                    var protocolArgs = (ProtocolActivatedEventArgs)args;
                    return new ActivationResult(ActivationKinds.Protocol, protocolUri: protocolArgs.Uri);

                case ActivationKind.Launch:
                    return new ActivationResult(ActivationKinds.Launch);

                default:
                    return new ActivationResult(ActivationKinds.Unknown);
            }
        }
    }
}
