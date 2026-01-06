using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;

namespace ActivationDriver;

/// <summary>
/// Command-line tool to trigger packaged app activations using IApplicationActivationManager.
/// Used for E2E testing of MSIX-packaged apps.
/// 
/// Usage:
///   ActivationDriver.exe --aumid "PackageFamilyName!App" --launch
///   ActivationDriver.exe --aumid "PackageFamilyName!App" --protocol "mdview:file:///C:/test.md#section"
///   ActivationDriver.exe --aumid "PackageFamilyName!App" --file "C:\test.md"
/// </summary>
internal class Program
{
    private static int Main(string[] args)
    {
        try
        {
            return Run(args);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error: {ex.Message}");
            if (ex.InnerException != null)
            {
                Console.Error.WriteLine($"Inner: {ex.InnerException.Message}");
            }
            return 1;
        }
    }

    private static int Run(string[] args)
    {
        if (args.Length == 0 || args.Contains("--help") || args.Contains("-h"))
        {
            PrintUsage();
            return 0;
        }

        string? aumid = null;
        string? protocolUri = null;
        string? filePath = null;
        bool launch = false;
        bool waitForExit = false;
        int waitTimeoutMs = 5000;

        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i].ToLowerInvariant())
            {
                case "--aumid":
                    if (i + 1 < args.Length) aumid = args[++i];
                    break;
                case "--protocol":
                    if (i + 1 < args.Length) protocolUri = args[++i];
                    break;
                case "--file":
                    if (i + 1 < args.Length) filePath = args[++i];
                    break;
                case "--launch":
                    launch = true;
                    break;
                case "--wait":
                    waitForExit = true;
                    break;
                case "--timeout":
                    if (i + 1 < args.Length) waitTimeoutMs = int.Parse(args[++i]);
                    break;
            }
        }

        if (string.IsNullOrEmpty(aumid))
        {
            Console.Error.WriteLine("Error: --aumid is required");
            PrintUsage();
            return 1;
        }

        int activationCount = (launch ? 1 : 0) + (!string.IsNullOrEmpty(protocolUri) ? 1 : 0) + (!string.IsNullOrEmpty(filePath) ? 1 : 0);
        if (activationCount == 0)
        {
            Console.Error.WriteLine("Error: Specify --launch, --protocol, or --file");
            PrintUsage();
            return 1;
        }

        if (activationCount > 1)
        {
            Console.Error.WriteLine("Error: Specify only one of --launch, --protocol, or --file");
            return 1;
        }

        var aam = (IApplicationActivationManager)new ApplicationActivationManager();

        uint processId = 0;
        int hr;

        // At this point aumid is guaranteed non-null due to earlier check
        string appId = aumid!;

        if (launch)
        {
            Console.WriteLine($"Activating app (launch): {appId}");
            hr = aam.ActivateApplication(appId, null, ActivateOptions.NoSplashScreen, out processId);
            CheckHResult(hr, "ActivateApplication");
        }
        else if (!string.IsNullOrEmpty(protocolUri))
        {
            Console.WriteLine($"Activating app (protocol): {appId}");
            Console.WriteLine($"  URI: {protocolUri}");

            // Use ActivateForProtocol to trigger true protocol activation.
            // This causes Windows to deliver ProtocolActivatedEventArgs via AppInstance,
            // which validates that the MSIX protocol extension is correctly registered.
            var itemArray = ShellHelpers.CreateShellItemArrayFromUri(protocolUri);
            hr = aam.ActivateForProtocol(appId, itemArray, out processId);
            CheckHResult(hr, "ActivateForProtocol");
        }
        else if (!string.IsNullOrEmpty(filePath))
        {
            Console.WriteLine($"Activating app (file): {appId}");
            Console.WriteLine($"  File: {filePath}");

            if (!File.Exists(filePath))
            {
                Console.Error.WriteLine($"Warning: File does not exist: {filePath}");
            }

            var itemArray = ShellHelpers.CreateShellItemArrayFromPath(filePath!);
            hr = aam.ActivateForFile(appId, itemArray, "open", out processId);
            CheckHResult(hr, "ActivateForFile");
        }

        Console.WriteLine($"Activation successful. Process ID: {processId}");

        if (waitForExit && processId != 0)
        {
            Console.WriteLine($"Waiting for process {processId} to exit (timeout: {waitTimeoutMs}ms)...");
            try
            {
                var process = Process.GetProcessById((int)processId);
                if (process.WaitForExit(waitTimeoutMs))
                {
                    Console.WriteLine($"Process exited with code: {process.ExitCode}");
                    return process.ExitCode;
                }
                else
                {
                    Console.WriteLine("Process did not exit within timeout");
                }
            }
            catch (ArgumentException)
            {
                Console.WriteLine("Process already exited");
            }
        }

        return 0;
    }

    private static void CheckHResult(int hr, string operation)
    {
        if (hr != 0)
        {
            throw new COMException($"{operation} failed with HRESULT 0x{hr:X8}", hr);
        }
    }

    private static void PrintUsage()
    {
        Console.WriteLine(@"
ActivationDriver - Trigger packaged app activations for E2E testing

Usage:
  ActivationDriver.exe --aumid <AUMID> --launch
  ActivationDriver.exe --aumid <AUMID> --protocol <URI>
  ActivationDriver.exe --aumid <AUMID> --file <PATH>

Options:
  --aumid <AUMID>       Application User Model ID (PackageFamilyName!ApplicationId)
  --launch              Basic launch activation (no arguments)
  --protocol <URI>      Protocol activation with the specified URI
  --file <PATH>         File activation with the specified file path
  --wait                Wait for the activated process to exit
  --timeout <MS>        Timeout for --wait in milliseconds (default: 5000)

Examples:
  ActivationDriver.exe --aumid ""MarkdownViewer_1234abcd!App"" --launch
  ActivationDriver.exe --aumid ""MarkdownViewer_1234abcd!App"" --protocol ""mdview:file:///C:/test.md#section""
  ActivationDriver.exe --aumid ""MarkdownViewer_1234abcd!App"" --file ""C:\Users\Public\Documents\test.md""
".Trim());
    }
}
