param (
    [string]$path
)

$logPath = "$env:APPDATA\yazi\WindowsEnhancement\OpenDetails.log"

$cSharpCode = @'
using System;
using System.Runtime.InteropServices;

public class FileProperties
{
    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    public static extern bool ShellExecuteEx(ref SHELLEXECUTEINFO lpExecInfo);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct SHELLEXECUTEINFO
    {
        public int cbSize;
        public uint fMask;
        public IntPtr hwnd;
        [MarshalAs(UnmanagedType.LPTStr)]
        public string lpVerb;
        [MarshalAs(UnmanagedType.LPTStr)]
        public string lpFile;
        [MarshalAs(UnmanagedType.LPTStr)]
        public string lpParameters;
        [MarshalAs(UnmanagedType.LPTStr)]
        public string lpDirectory;
        public int nShow;
        public IntPtr hInstApp;
        public IntPtr lpIDList;
        [MarshalAs(UnmanagedType.LPTStr)]
        public string lpClass;
        public IntPtr hkeyClass;
        public uint dwHotKey;
        public IntPtr hIcon;
        public IntPtr hProcess;
    }

    public static void ShowFileProperties(string filename)
    {
        SHELLEXECUTEINFO info = new SHELLEXECUTEINFO();
        info.cbSize = System.Runtime.InteropServices.Marshal.SizeOf(info);
        info.lpVerb = "properties";
        info.lpFile = filename;
        info.nShow = 1;
        info.fMask = 0x0000000C;
        info.hwnd = IntPtr.Zero;
        ShellExecuteEx(ref info);
    }
}
'@

# Check if the type already exists before adding it
if (-not ([Type]::GetType("FileProperties"))) {
    Add-Type -TypeDefinition $cSharpCode -Language CSharp
}

$executingUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$loggedInUser = "$([System.Environment]::UserDomainName)\$([System.Environment]::UserName)"

if ($executingUser -eq $loggedInUser) {
    if (Test-Path -Path $path) {
        "Debug: Path exists." | Out-File -FilePath $logPath -Append
        try {
            $result = [FileProperties]::ShowFileProperties($path)
            "Debug: ShowFileProperties result: $result" | Out-File -FilePath $logPath -Append
            #TODO: Handle this better
            Start-Sleep -Seconds 10  # Sleep for 10 seconds
        }
        catch {
            $errorMessage = $_.Exception.Message
            "Error: Unable to show file properties. Error message: $errorMessage" | Out-File -FilePath $logPath -Append
            "Error: Unable to show file properties. Error message: $errorMessage"
        }
    } else {
        "Debug: Path does not exist." | Out-File -FilePath $logPath -Append
    }
} else {
    "Error: Mismatch between executing user and logged-in user. Cannot proceed." | Out-File -FilePath $logPath -Append
}



