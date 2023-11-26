param (
    [string]$path,
    [switch]$Admin
)

# Determine if the path is a file or a directory
if (Test-Path -Path $path -PathType Leaf) {
    $directory = Split-Path -Path $path
} elseif (Test-Path -Path $path -PathType Container) {
    $directory = $path
} else {
    Write-Host "The path does not exist."
    exit
}

# Decide whether to start PowerShell as admin or regular user
if ($Admin) {
    Start-Process pwsh.exe -ArgumentList "-NoExit", "-Command cd '$directory'" -Verb RunAs
} else {
    Start-Process pwsh.exe -ArgumentList "-NoExit", "-Command cd '$directory'"
}

