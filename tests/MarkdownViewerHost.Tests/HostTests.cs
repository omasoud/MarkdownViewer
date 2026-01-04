// MarkdownViewerHost.Tests - Unit tests for the Host application
// Tests the ActivationHandler logic including path resolution, activation handling, and engine launching.

using System.Diagnostics;
using MarkdownViewerHost;
using NSubstitute;
using Windows.ApplicationModel.Activation;
using Xunit;

namespace MarkdownViewerHost.Tests;

/// <summary>
/// Tests for the ActivationHandler class which handles the core activation and launching logic.
/// </summary>
public class ActivationHandlerTests
{
    private readonly IFileSystem _fileSystem;
    private readonly IProcessLauncher _processLauncher;
    private readonly IAppContext _appContext;
    private readonly IAppActivation _appActivation;
    private readonly List<string> _logMessages;
    private readonly ActivationHandler _handler;

    public ActivationHandlerTests()
    {
        _fileSystem = Substitute.For<IFileSystem>();
        _processLauncher = Substitute.For<IProcessLauncher>();
        _appContext = Substitute.For<IAppContext>();
        _appActivation = Substitute.For<IAppActivation>();
        _logMessages = new List<string>();

        // Default setup - base directory without WAP subfolder
        _appContext.BaseDirectory.Returns(@"C:\PackageRoot\");
        
        // Default file system behavior - forward path operations
        _fileSystem.CombinePath(Arg.Any<string[]>()).Returns(x => Path.Combine((string[])x[0]));
        _fileSystem.GetDirectoryName(Arg.Any<string>()).Returns(x => Path.GetDirectoryName((string)x[0]) ?? string.Empty);
        _fileSystem.GetFullPath(Arg.Any<string>()).Returns(x => Path.GetFullPath((string)x[0]));

        _handler = new ActivationHandler(
            _fileSystem,
            _processLauncher,
            _appContext,
            _appActivation,
            msg => _logMessages.Add(msg));
    }

    #region TryHandlePackagedActivation Tests

    [Fact]
    public void TryHandlePackagedActivation_Returns_False_When_NoActivationData()
    {
        // Arrange
        _appActivation.TryGetActivatedEventArgs().Returns((ActivationResult?)null);

        // Act
        var result = _handler.TryHandlePackagedActivation();

        // Assert
        Assert.False(result);
    }

    [Fact]
    public void TryHandlePackagedActivation_Returns_False_For_LaunchActivation()
    {
        // Arrange - Launch activation (Start Menu) should return false to show help
        _appActivation.TryGetActivatedEventArgs().Returns(new ActivationResult(ActivationKind.Launch));

        // Act
        var result = _handler.TryHandlePackagedActivation();

        // Assert
        Assert.False(result);
        Assert.Contains(_logMessages, m => m.Contains("Launch activation"));
    }

    [Fact]
    public void TryHandlePackagedActivation_Handles_FileActivation()
    {
        // Arrange
        var filePaths = new List<string> { @"C:\docs\README.md" };
        _appActivation.TryGetActivatedEventArgs().Returns(new ActivationResult(ActivationKind.File, filePaths));
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        var result = _handler.TryHandlePackagedActivation();

        // Assert
        Assert.True(result);
        _processLauncher.Received(1).LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), false, true);
    }

    [Fact]
    public void TryHandlePackagedActivation_Handles_ProtocolActivation()
    {
        // Arrange
        var uri = new Uri("mdview:file:///C:/docs/readme.md#section");
        _appActivation.TryGetActivatedEventArgs().Returns(new ActivationResult(ActivationKind.Protocol, ProtocolUri: uri));
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        var result = _handler.TryHandlePackagedActivation();

        // Assert
        Assert.True(result);
        _processLauncher.Received(1).LaunchProcess(
            Arg.Any<string>(),
            Arg.Is<IReadOnlyList<string>>(args => args.Contains("mdview:file:///C:/docs/readme.md#section")),
            false, true);
    }

    [Fact]
    public void TryHandlePackagedActivation_Returns_False_For_UnhandledActivationKind()
    {
        // Arrange - Use an activation kind that's not handled
        _appActivation.TryGetActivatedEventArgs().Returns(new ActivationResult(ActivationKind.Search));

        // Act
        var result = _handler.TryHandlePackagedActivation();

        // Assert
        Assert.False(result);
        Assert.Contains(_logMessages, m => m.Contains("Unhandled activation kind"));
    }

    #endregion

    #region HandleFileActivation Tests

    [Fact]
    public void HandleFileActivation_Returns_False_When_FilePaths_Is_Null()
    {
        // Act
        var result = _handler.HandleFileActivation(null);

        // Assert
        Assert.False(result);
        Assert.Contains(_logMessages, m => m.Contains("No files"));
    }

    [Fact]
    public void HandleFileActivation_Returns_False_When_FilePaths_Is_Empty()
    {
        // Act
        var result = _handler.HandleFileActivation(new List<string>());

        // Assert
        Assert.False(result);
        Assert.Contains(_logMessages, m => m.Contains("No files"));
    }

    [Fact]
    public void HandleFileActivation_Launches_Engine_For_Each_File()
    {
        // Arrange
        var filePaths = new List<string>
        {
            @"C:\docs\file1.md",
            @"C:\docs\file2.md",
            @"C:\docs\file3.md"
        };
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        var result = _handler.HandleFileActivation(filePaths);

        // Assert
        Assert.True(result);
        _processLauncher.Received(3).LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), false, true);
    }

    [Fact]
    public void HandleFileActivation_Skips_WhitespaceOnly_Paths()
    {
        // Arrange
        var filePaths = new List<string>
        {
            @"C:\docs\valid.md",
            "   ",
            "",
            @"C:\docs\another.md"
        };
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        var result = _handler.HandleFileActivation(filePaths);

        // Assert
        Assert.True(result);
        // Only 2 valid files should be processed
        _processLauncher.Received(2).LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), false, true);
    }

    #endregion

    #region HandleProtocolActivation Tests

    [Fact]
    public void HandleProtocolActivation_Returns_False_When_Uri_Is_Null()
    {
        // Act
        var result = _handler.HandleProtocolActivation(null);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public void HandleProtocolActivation_Passes_FullUri_Including_Fragment()
    {
        // Arrange
        var uri = new Uri("mdview:file:///C:/docs/readme.md#installation");
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        var result = _handler.HandleProtocolActivation(uri);

        // Assert
        Assert.True(result);
        _processLauncher.Received(1).LaunchProcess(
            Arg.Any<string>(),
            Arg.Is<IReadOnlyList<string>>(args => args.Contains("mdview:file:///C:/docs/readme.md#installation")),
            false, true);
    }

    [Theory]
    [InlineData("mdview:file:///C:/docs/other.md")]
    [InlineData("mdview:file:///C:/docs/other.md#section")]
    [InlineData("mdview:file:///C:/docs/other.md#part-6-authentication-methods")]
    public void HandleProtocolActivation_Preserves_Various_Uris(string uriString)
    {
        // Arrange
        var uri = new Uri(uriString);
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        var result = _handler.HandleProtocolActivation(uri);

        // Assert
        Assert.True(result);
        _processLauncher.Received(1).LaunchProcess(
            Arg.Any<string>(),
            Arg.Is<IReadOnlyList<string>>(args => args.Contains(uriString)),
            false, true);
    }

    #endregion

    #region OpenDefaultAppsSettings Tests

    [Fact]
    public void OpenDefaultAppsSettings_Launches_MsSettings_Uri()
    {
        // Act
        _handler.OpenDefaultAppsSettings();

        // Assert
        _processLauncher.Received(1).LaunchUri("ms-settings:defaultapps");
    }

    [Fact]
    public void OpenDefaultAppsSettings_Handles_Exception_Silently()
    {
        // Arrange
        _processLauncher.When(x => x.LaunchUri(Arg.Any<string>())).Throw(new InvalidOperationException("Test error"));

        // Act - Should not throw
        var exception = Record.Exception(() => _handler.OpenDefaultAppsSettings());

        // Assert
        Assert.Null(exception);
    }

    #endregion

    #region LaunchEngine Tests

    [Fact]
    public void LaunchEngine_Uses_Package_PwshPath_When_Available()
    {
        // Arrange
        _appContext.BaseDirectory.Returns(@"C:\PackageRoot\");
        _fileSystem.FileExists(@"C:\PackageRoot\pwsh\pwsh.exe").Returns(true);
        _fileSystem.FileExists(@"C:\PackageRoot\app\Open-Markdown.ps1").Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        _handler.LaunchEngine(@"C:\docs\README.md");

        // Assert
        _processLauncher.Received(1).LaunchProcess(
            @"C:\PackageRoot\pwsh\pwsh.exe",
            Arg.Any<IReadOnlyList<string>>(),
            false, true);
    }

    [Fact]
    public void LaunchEngine_Falls_Back_To_System_Pwsh_When_Not_In_Package()
    {
        // Arrange
        _appContext.BaseDirectory.Returns(@"C:\DevPath\");
        _fileSystem.FileExists(@"C:\DevPath\pwsh\pwsh.exe").Returns(false);
        _fileSystem.FileExists(@"C:\DevPath\app\Open-Markdown.ps1").Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        _handler.LaunchEngine(@"C:\docs\README.md");

        // Assert
        _processLauncher.Received(1).LaunchProcess(
            "pwsh",
            Arg.Any<IReadOnlyList<string>>(),
            false, true);
        Assert.Contains(_logMessages, m => m.Contains("using system pwsh"));
    }

    [Fact]
    public void LaunchEngine_Builds_Correct_Arguments()
    {
        // Arrange
        _appContext.BaseDirectory.Returns(@"C:\PackageRoot\");
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        _handler.LaunchEngine(@"C:\docs\README.md");

        // Assert
        _processLauncher.Received(1).LaunchProcess(
            Arg.Any<string>(),
            Arg.Is<IReadOnlyList<string>>(args =>
                args.Count == 7 &&
                args[0] == "-NoProfile" &&
                args[1] == "-ExecutionPolicy" &&
                args[2] == "Bypass" &&
                args[3] == "-File" &&
                args[4].EndsWith("Open-Markdown.ps1") &&
                args[5] == "-Path" &&
                args[6] == @"C:\docs\README.md"),
            false, true);
    }

    [Fact]
    public void LaunchEngine_Handles_ProcessLaunch_Exception_Gracefully()
    {
        // Arrange
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(x => { throw new InvalidOperationException("Process failed"); });

        // Act - Should not throw
        var exception = Record.Exception(() => _handler.LaunchEngine(@"C:\docs\README.md"));

        // Assert
        Assert.Null(exception);
        Assert.Contains(_logMessages, m => m.Contains("exception"));
    }

    [Theory]
    [InlineData(@"C:\Users\test\file.md")]
    [InlineData(@"D:\folder\subfolder\document.markdown")]
    [InlineData(@"\\server\share\notes.md")]
    public void LaunchEngine_Passes_FilePath_Unchanged(string path)
    {
        // Arrange
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        _handler.LaunchEngine(path);

        // Assert
        _processLauncher.Received(1).LaunchProcess(
            Arg.Any<string>(),
            Arg.Is<IReadOnlyList<string>>(args => args[6] == path),
            false, true);
    }

    [Theory]
    [InlineData("mdview:file:///C:/docs/other.md")]
    [InlineData("mdview:file:///C:/docs/other.md#section")]
    public void LaunchEngine_Passes_ProtocolUri_Unchanged(string uri)
    {
        // Arrange
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        _handler.LaunchEngine(uri);

        // Assert
        _processLauncher.Received(1).LaunchProcess(
            Arg.Any<string>(),
            Arg.Is<IReadOnlyList<string>>(args => args[6] == uri),
            false, true);
    }

    #endregion

    #region ResolvePackageRoot Tests

    [Fact]
    public void ResolvePackageRoot_Returns_BaseDirectory_When_Not_In_WapSubfolder()
    {
        // Arrange
        _appContext.BaseDirectory.Returns(@"C:\PackageRoot\");
        _fileSystem.FileExists(Arg.Any<string>()).Returns(false);

        // Act
        var result = _handler.ResolvePackageRoot();

        // Assert
        Assert.Equal(@"C:\PackageRoot\", result);
    }

    [Fact]
    public void ResolvePackageRoot_Returns_ParentDirectory_When_In_WapSubfolder()
    {
        // Arrange - Host is in MarkdownViewerHost subfolder
        _appContext.BaseDirectory.Returns(@"C:\PackageRoot\MarkdownViewerHost\");
        _fileSystem.FileExists(@"C:\PackageRoot\pwsh\pwsh.exe").Returns(true);

        // Act
        var result = _handler.ResolvePackageRoot();

        // Assert
        Assert.Equal(@"C:\PackageRoot\", result);
    }

    [Fact]
    public void ResolvePackageRoot_Detects_WapSubfolder_Via_AppPath()
    {
        // Arrange - Detect via app folder instead of pwsh
        _appContext.BaseDirectory.Returns(@"C:\PackageRoot\MarkdownViewerHost\");
        _fileSystem.FileExists(@"C:\PackageRoot\pwsh\pwsh.exe").Returns(false);
        _fileSystem.FileExists(@"C:\PackageRoot\app\Open-Markdown.ps1").Returns(true);

        // Act
        var result = _handler.ResolvePackageRoot();

        // Assert
        Assert.Equal(@"C:\PackageRoot\", result);
        Assert.Contains(_logMessages, m => m.Contains("WAP subfolder"));
    }

    #endregion

    #region HandleCommandLineArgs Tests

    [Fact]
    public void HandleCommandLineArgs_Launches_Engine_For_Each_Arg()
    {
        // Arrange
        var args = new[] { @"C:\file1.md", @"C:\file2.md" };
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        _handler.HandleCommandLineArgs(args);

        // Assert
        _processLauncher.Received(2).LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), false, true);
    }

    [Fact]
    public void HandleCommandLineArgs_Skips_WhitespaceOnly_Args()
    {
        // Arrange
        var args = new[] { @"C:\file1.md", "  ", "", @"C:\file2.md" };
        _fileSystem.FileExists(Arg.Any<string>()).Returns(true);
        _processLauncher.LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), Arg.Any<bool>(), Arg.Any<bool>())
            .Returns(12345);

        // Act
        _handler.HandleCommandLineArgs(args);

        // Assert
        _processLauncher.Received(2).LaunchProcess(Arg.Any<string>(), Arg.Any<IReadOnlyList<string>>(), false, true);
    }

    #endregion

    #region BuildEngineArguments Tests

    [Fact]
    public void BuildEngineArguments_Returns_Correct_Structure()
    {
        // Act
        var args = _handler.BuildEngineArguments(@"C:\engine\Open-Markdown.ps1", @"C:\docs\test.md");

        // Assert
        Assert.Equal(7, args.Count);
        Assert.Equal("-NoProfile", args[0]);
        Assert.Equal("-ExecutionPolicy", args[1]);
        Assert.Equal("Bypass", args[2]);
        Assert.Equal("-File", args[3]);
        Assert.Equal(@"C:\engine\Open-Markdown.ps1", args[4]);
        Assert.Equal("-Path", args[5]);
        Assert.Equal(@"C:\docs\test.md", args[6]);
    }

    #endregion
}

/// <summary>
/// Original tests preserved for behavioral documentation and framework validation.
/// </summary>
public class HostBehaviorTests
{
    [Fact]
    public void ArgumentList_Should_Contain_Structured_Args()
    {
        // Verify ProcessStartInfo.ArgumentList approach is used
        var startInfo = new ProcessStartInfo
        {
            FileName = "pwsh",
            UseShellExecute = false,
            CreateNoWindow = true
        };
        
        startInfo.ArgumentList.Add("-NoProfile");
        startInfo.ArgumentList.Add("-ExecutionPolicy");
        startInfo.ArgumentList.Add("Bypass");
        startInfo.ArgumentList.Add("-File");
        startInfo.ArgumentList.Add(@"C:\path\to\Open-Markdown.ps1");
        startInfo.ArgumentList.Add("-Path");
        startInfo.ArgumentList.Add(@"C:\docs\README.md");
        
        Assert.Equal(7, startInfo.ArgumentList.Count);
        Assert.Equal("-NoProfile", startInfo.ArgumentList[0]);
        Assert.Equal("-Path", startInfo.ArgumentList[5]);
        Assert.Equal(@"C:\docs\README.md", startInfo.ArgumentList[6]);
    }
    
    [Fact]
    public void ProcessStartInfo_Should_Hide_Window()
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "pwsh",
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden
        };
        
        Assert.False(startInfo.UseShellExecute);
        Assert.True(startInfo.CreateNoWindow);
        Assert.Equal(ProcessWindowStyle.Hidden, startInfo.WindowStyle);
    }
    
    [Fact]
    public void AppContext_BaseDirectory_Should_Be_Available()
    {
        // Verify we can get the base directory for path resolution
        var baseDir = AppContext.BaseDirectory;
        
        Assert.NotNull(baseDir);
        Assert.NotEmpty(baseDir);
    }
    
    [Theory]
    [InlineData("mdview:file:///C:/docs/other.md")]
    [InlineData("mdview:file:///C:/docs/other.md#heading")]
    public void Uri_AbsoluteUri_Should_Preserve_Fragment(string uriString)
    {
        // System.Uri should preserve the fragment when using AbsoluteUri
        var uri = new Uri(uriString);
        Assert.Equal(uriString, uri.AbsoluteUri);
        
        // Fragment should be accessible
        if (uriString.Contains('#'))
        {
            Assert.NotEmpty(uri.Fragment);
        }
    }
    
    [Fact]
    public void ProcessStartInfo_For_Settings_Should_UseShellExecute()
    {
        // Opening ms-settings: URIs requires UseShellExecute = true
        var startInfo = new ProcessStartInfo
        {
            FileName = "ms-settings:defaultapps",
            UseShellExecute = true
        };
        
        Assert.True(startInfo.UseShellExecute);
        Assert.Equal("ms-settings:defaultapps", startInfo.FileName);
    }
}
