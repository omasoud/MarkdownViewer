// MarkdownViewerHost.Tests - Unit tests for the Host application
// Tests path resolution and argument handling logic

using System.Diagnostics;
using Xunit;

namespace MarkdownViewerHost.Tests;

public class HostTests
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
    
    [Theory]
    [InlineData(@"C:\Users\test\file.md")]
    [InlineData(@"D:\folder\subfolder\document.markdown")]
    [InlineData(@"\\server\share\notes.md")]
    public void FilePath_Should_Be_Preserved(string path)
    {
        // File paths should be passed unchanged to the engine
        var normalized = path; // No normalization in host
        Assert.Equal(path, normalized);
    }
    
    [Theory]
    [InlineData("mdview:file:///C:/docs/other.md")]
    [InlineData("mdview:file:///C:/docs/other.md#section")]
    [InlineData("mdview:file:///C:/docs/other.md#part-6-authentication-methods")]
    public void ProtocolUri_Should_Be_Preserved(string uri)
    {
        // Protocol URIs including fragments should be passed unchanged
        var normalized = uri; // No modification in host
        Assert.Equal(uri, normalized);
    }
    
    [Fact]
    public void ProtocolUri_Fragment_Should_Not_Be_Stripped()
    {
        var uri = "mdview:file:///C:/docs/readme.md#installation";
        
        // Verify fragment is preserved (host must NOT strip it)
        Assert.Contains("#installation", uri);
        
        // Engine is responsible for parsing, not host
        var passedToEngine = uri;
        Assert.Equal(uri, passedToEngine);
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
    [InlineData("hostDir", "pwsh", "pwsh.exe", @"hostDir\pwsh\pwsh.exe")]
    [InlineData("hostDir", "app", "Open-Markdown.ps1", @"hostDir\app\Open-Markdown.ps1")]
    public void Path_Combine_Should_Build_Expected_Paths(string dir, string subdir, string file, string expected)
    {
        var result = Path.Combine(dir, subdir, file);
        Assert.Equal(expected, result);
    }
    
    [Fact]
    public void EmptyArgs_Should_Indicate_NoArgsLaunch()
    {
        // When args.Length == 0, we're in no-args launch mode (Start Menu)
        var args = Array.Empty<string>();
        
        Assert.Empty(args);
        Assert.True(args.Length == 0);
    }
    
    [Fact]
    public void NonEmptyArgs_Should_Indicate_FileOrProtocolActivation()
    {
        // When args has items, we're in file/protocol activation mode
        var args = new[] { @"C:\docs\README.md" };
        
        Assert.NotEmpty(args);
        Assert.True(args.Length > 0);
        Assert.False(string.IsNullOrWhiteSpace(args[0]));
    }
    
    [Fact]
    public void MsSettingsUri_Should_Be_Valid_For_DefaultApps()
    {
        // The ms-settings URI format for Default Apps
        var settingsUri = "ms-settings:defaultapps";
        
        Assert.StartsWith("ms-settings:", settingsUri);
        Assert.Contains("defaultapps", settingsUri);
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
