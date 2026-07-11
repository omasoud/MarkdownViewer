using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

namespace ActivationDriver;

/// <summary>
/// COM interface for IApplicationActivationManager, used to programmatically
/// activate packaged apps (MSIX) for protocol, file, or launch activation.
/// </summary>
[ComImport]
[Guid("2e941141-7f97-4756-ba1d-9decde894a3d")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IApplicationActivationManager
{
    /// <summary>
    /// Activates the specified app by AUMID with optional arguments.
    /// </summary>
    int ActivateApplication(
        [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
        [MarshalAs(UnmanagedType.LPWStr)] string? arguments,
        ActivateOptions options,
        out uint processId);

    /// <summary>
    /// Activates the specified app for a protocol URI.
    /// </summary>
    int ActivateForProtocol(
        [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
        IShellItemArray itemArray,
        out uint processId);

    /// <summary>
    /// Activates the specified app for a file.
    /// </summary>
    int ActivateForFile(
        [MarshalAs(UnmanagedType.LPWStr)] string appUserModelId,
        IShellItemArray itemArray,
        [MarshalAs(UnmanagedType.LPWStr)] string? verb,
        out uint processId);
}

/// <summary>
/// CLSID for ApplicationActivationManager COM class.
/// </summary>
[ComImport]
[Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")]
internal class ApplicationActivationManager { }

/// <summary>
/// Options for ActivateApplication.
/// </summary>
[Flags]
internal enum ActivateOptions
{
    None = 0x00000000,
    DesignMode = 0x00000001,
    NoErrorUI = 0x00000002,
    NoSplashScreen = 0x00000004
}

/// <summary>
/// IShellItemArray interface for passing items to activation methods.
/// </summary>
[ComImport]
[Guid("B63EA76D-1F85-456F-A19C-48159EFA858B")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IShellItemArray
{
    // We only need BindToHandler and GetCount for our purposes
    void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppvOut);
    void GetPropertyStore(int flags, ref Guid riid, out IntPtr ppv);
    void GetPropertyDescriptionList(IntPtr keyType, ref Guid riid, out IntPtr ppv);
    void GetAttributes(int dwAttribFlags, uint sfgaoMask, out uint psfgaoAttribs);
    void GetCount(out uint pdwNumItems);
    void GetItemAt(uint dwIndex, out IShellItem ppsi);
    void EnumItems(out IntPtr ppenumShellItems);
}

/// <summary>
/// IShellItem interface.
/// </summary>
[ComImport]
[Guid("43826d1e-e718-42ee-bc55-a1e261c37bfe")]
[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IShellItem
{
    void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
    void GetParent(out IShellItem ppsi);
    void GetDisplayName(uint sigdnName, out IntPtr ppszName);
    void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
    void Compare(IShellItem psi, uint hint, out int piOrder);
}

/// <summary>
/// Native shell helper methods.
/// </summary>
internal static class ShellHelpers
{
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int SHCreateItemFromParsingName(
        [MarshalAs(UnmanagedType.LPWStr)] string path,
        IntPtr pbc,
        ref Guid riid,
        out IShellItem ppv);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int SHCreateShellItemArrayFromShellItem(
        IShellItem psi,
        ref Guid riid,
        out IShellItemArray ppv);

    /// <summary>
    /// Creates an IShellItemArray from a file path for file activation.
    /// </summary>
    public static IShellItemArray CreateShellItemArrayFromPath(string path)
    {
        Guid shellItemGuid = typeof(IShellItem).GUID;
        int hr = SHCreateItemFromParsingName(path, IntPtr.Zero, ref shellItemGuid, out IShellItem item);
        if (hr != 0)
        {
            throw new COMException($"SHCreateItemFromParsingName failed for '{path}'", hr);
        }

        Guid shellItemArrayGuid = typeof(IShellItemArray).GUID;
        hr = SHCreateShellItemArrayFromShellItem(item, ref shellItemArrayGuid, out IShellItemArray array);
        if (hr != 0)
        {
            throw new COMException($"SHCreateShellItemArrayFromShellItem failed for '{path}'", hr);
        }

        return array;
    }

    /// <summary>
    /// Creates an IShellItemArray from a URI for protocol activation.
    /// Note: For protocol activation, we pass the URI as arguments to ActivateApplication,
    /// not via ActivateForProtocol which requires a shell item.
    /// </summary>
    public static IShellItemArray CreateShellItemArrayFromUri(string uri)
    {
        // For URIs, SHCreateItemFromParsingName will handle protocol URIs
        Guid shellItemGuid = typeof(IShellItem).GUID;
        int hr = SHCreateItemFromParsingName(uri, IntPtr.Zero, ref shellItemGuid, out IShellItem item);
        if (hr != 0)
        {
            throw new COMException($"SHCreateItemFromParsingName failed for URI '{uri}'", hr);
        }

        Guid shellItemArrayGuid = typeof(IShellItemArray).GUID;
        hr = SHCreateShellItemArrayFromShellItem(item, ref shellItemArrayGuid, out IShellItemArray array);
        if (hr != 0)
        {
            throw new COMException($"SHCreateShellItemArrayFromShellItem failed for URI", hr);
        }

        return array;
    }
}
