# For no prompt install
param (
    [switch]$Force
)

# This one use /releases, /latest is more commonly used but dont work for Yazi
function Get-GithubRelease {
    param (
        [string]$Repo
    )

    try {
        $uri = "https://api.github.com/repos/$Repo/releases"
        Write-Host "Requesting URL: $uri"
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers @{ Accept = "application/vnd.github.v3+json" }
        
        if ($response.Count -gt 0) {
            $latestRelease = $response | Sort-Object -Property published_at -Descending | Select-Object -First 1
            Write-Host "Latest release found: Tag $($latestRelease.tag_name), Published on $($latestRelease.published_at)"
            return $latestRelease.tag_name
        } else {
            Write-Host "No releases found for $Repo."
            return $null
        }
    }
    catch {
        Write-Host "Error encountered: $_"
        return $null
    }
}


function Get-GithubRepo {
    param (
        [string]$Repo,
        [string]$TagName,
        [string]$DestinationPath,
        [string]$Platform = "windows"  # Default to 'windows'. Change as needed.
    )

    try {
        $uri = "https://api.github.com/repos/$Repo/releases/tags/$TagName"
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers @{ Accept = "application/vnd.github.v3+json" }

        $asset = $response.assets | Where-Object { $_.name -like "*$Platform*.zip" } | Select-Object -First 1

        if ($asset) {
            $tempPath = [System.IO.Path]::GetTempPath()
            $tempFile = Join-Path $tempPath $asset.name
            $downloadUrl = $asset.browser_download_url

            Write-Host "Downloading ZIP to temporary folder: $tempFile"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile

            $tempExtractionPath = New-Item -ItemType Directory -Path (Join-Path $tempPath ([System.IO.Path]::GetRandomFileName())) -Force
            Write-Host "Extracting ZIP to temporary folder: $tempExtractionPath"
            Expand-Archive -LiteralPath $tempFile -DestinationPath $tempExtractionPath -Force

            Write-Host "Moving contents to $DestinationPath"
            Get-ChildItem -Path $tempExtractionPath -Recurse | Move-Item -Destination $DestinationPath -Force

            Write-Host "Cleaning up temporary files."
            Remove-Item -Path $tempFile
            Remove-Item -Path $tempExtractionPath -Recurse -Force

            return $DestinationPath
        }
        else {
            Write-Error "No downloadable ZIP asset found for $Platform platform in $Repo release $TagName"
            return $null
        }
    }
    catch {
        Write-Host "Error encountered: $_"
        return $null
    }
}


function Add-FolderPathToEnvPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$folderPath
    )

    try {
        # Check if the folder path exists
        if (-Not (Test-Path -Path $folderPath)) {
            throw "Folder path does not exist: $folderPath"
        }

        # Get the current PATH environment variable for the user
        $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")

        # Check if the folder path is already in the PATH
        if ($currentPath -split ';' -contains $folderPath) {
            Write-Host "Folder path already in PATH: $folderPath"
            return
        }

        # Add folder path to the PATH environment variable
        $newPath = $currentPath + ';' + $folderPath
        [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")

        # Verify if the folder path was added
        $updatedPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        if ($updatedPath -split ';' -contains $folderPath) {
            Write-Host "Folder path added to PATH successfully: $folderPath"
        } else {
            throw "Failed to add folder path to PATH"
        }
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}
function Create-WeztermYaziShortcut {
    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath "WezTerm Yazi.lnk"

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    
    $Shortcut.TargetPath = "C:\Program Files\WezTerm\wezterm-gui.exe"
    $Shortcut.Arguments = "-e pwsh.exe -NoExit -Command `"& { `$Host.UI.RawUI.WindowTitle = 'TUI File Explorer - Yazi';  yazi }`""
    $Shortcut.WorkingDirectory = "C:\Program Files\WezTerm"
    $Shortcut.IconLocation = "C:\Program Files\WezTerm\wezterm-gui.exe"
    $Shortcut.Save()

    Write-Host "Shortcut created at $shortcutPath"
}

function Get-UserConfirmation {
    param (
        [string]$Message
    )
    $userInput = Read-Host -Prompt $Message
    return $userInput -eq 'Y'
}



# Start of the program
# user/appdata/local/ folder is more common for program, maybe change this ?
$Repo = "sxyazi/yazi"
$destinationPath = "$env:APPDATA\yazi\bin"

# Check and create destination folder
if (-not (Test-Path -Path $destinationPath)) {
    New-Item -ItemType Directory -Path $destinationPath | Out-Null
    Write-Host "Destination folder created: $destinationPath"
} else {
    Write-Host "Destination folder already exists: $destinationPath"
}

# Installation Process (Get release, Download, Install)
if ($Force -or (Get-UserConfirmation "Proceed with installation for $Repo? (Y/N)")) {
    $latestRelease = Get-GithubRelease -Repo $Repo

    if ($latestRelease) {
        Get-GithubRepo -Repo $Repo -TagName $latestRelease -DestinationPath $destinationPath -Force:$Force
    } else {
        Write-Host "No latest release found for $Repo."
    }
}

# Prompt for adding to environment path
if ($latestRelease -and ($Force -or (Get-UserConfirmation "Do you want to add $destinationPath to your environment path? (Y/N)"))) {
    Add-FolderPathToEnvPath -folderPath $destinationPath
    Write-Host "$destinationPath has been added to your environment path."
}
# Prompt for creating WezTerm Yazi Shortcut
if ($Force -or (Get-UserConfirmation "Do you want to create a WezTerm Yazi shortcut on your desktop? (Y/N)")) {
    Create-WeztermYaziShortcut
}
Write-Host "You need to restart you shell to Access Yazi"
