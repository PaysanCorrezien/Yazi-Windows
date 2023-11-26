# Directly use $args to access all arguments
Add-Type -AssemblyName System.Windows.Forms
$paths = New-Object System.Collections.Specialized.StringCollection

foreach ($arg in $args) {
    $paths.Add($arg)
}

[System.Windows.Forms.Clipboard]::SetFileDropList($paths)

# # For logging purposes
# "Received arguments: $($args -join ', ')" | Out-File "C:\temp\drag_logps1.txt"

