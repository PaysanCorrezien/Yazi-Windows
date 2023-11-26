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

            # Attempt to get only content
            $rootFolder = Get-ChildItem -Path $tempExtractionPath | Where-Object { $_.PSIsContainer } | Select-Object -First 1
            if ($rootFolder) {
                Write-Host "Moving contents from $rootFolder to $DestinationPath"
                Get-ChildItem -Path $rootFolder.FullName -Recurse | Move-Item -Destination $DestinationPath -Force
            }

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
#TODO: Adapt the first function to handle both case of Yazi and git
function Install-GitForWindows {
    param (
        [string]$Repo = "git-for-windows/git",
        [switch]$Force
    )

    $latestTag = Get-GithubRelease -Repo $Repo
    if (-not $latestTag) {
        Write-Error "Failed to get the latest release for $Repo."
        return
    }

    $releaseUri = "https://api.github.com/repos/$Repo/releases/tags/$latestTag"
    $releaseResponse = Invoke-RestMethod -Uri $releaseUri -Method Get -Headers @{ Accept = "application/vnd.github.v3+json" }

    $installerAsset = $releaseResponse.assets | Where-Object { $_.name -like "*-64-bit.exe" } | Select-Object -First 1

    if ($installerAsset) {
        $tempPath = [System.IO.Path]::GetTempPath()
        $installerPath = Join-Path $tempPath $installerAsset.name

        Write-Host "Downloading Git installer: $($installerAsset.name)"
        Invoke-WebRequest -Uri $installerAsset.browser_download_url -OutFile $installerPath

        # Determine installation arguments based on -Force parameter
        $installArgs = if ($Force) { "/VERYSILENT /NORESTART" } else { "" }

        Start-Process -FilePath $installerPath -Args $installArgs -Wait -NoNewWindow

        # Optionally, remove the installer after installation
        Remove-Item -Path $installerPath

        Write-Host "Git has been installed."
    }
    else {
        Write-Error "No Git installer found in the latest release."
    }
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

# Define the destination directory for config files
$configDir = "$env:APPDATA\yazi\config"

# Check and create destination folder
if (-not (Test-Path -Path $destinationPath)) {
    New-Item -ItemType Directory -Path $destinationPath | Out-Null
    Write-Host "Destination folder created: $destinationPath"
} else {
    Write-Host "Destination folder already exists: $destinationPath"
}

# Installation Process (Get release, Download, Install)
if ($Force -or (Get-UserConfirmation "Proceed with installation for $Repo? , this will download the latest release of the app from github (Y/N)")) {
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

# HACK: Until the file come with the install
# Prompt for downloading and copying the preset files
if ($Force -or (Get-UserConfirmation "Do you want to download and install the preset configuration files? If you already have a configuration set this will overide it (Y/N)")) {
    # Ensure the config directory exists
    if (-not (Test-Path -Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir | Out-Null
        Write-Host "Config directory created: $configDir"
    }

    # Base URL for the raw content
    $baseUrl = "https://raw.githubusercontent.com/sxyazi/yazi/main/yazi-config/preset/"

    # Files to download
    $filesToDownload = @("keymap.toml", "theme.toml", "yazi.toml")

    # Download and save each file
    foreach ($file in $filesToDownload) {
        $url = $baseUrl + $file
        $destPath = Join-Path $configDir $file
        Invoke-WebRequest -Uri $url -OutFile $destPath
        Write-Host "Downloaded $file to $destPath"
    }
}

# Prompt for Git for Windows installation
if ($Force -or (Get-UserConfirmation "Do you want to install Git for Windows? (Y/N)")) {
    Install-GitForWindows -Force:$Force
}

# Prompt to add git /usr/bin to path
if ($latestRelease -and ($Force -or (Get-UserConfirmation "Do you want to add Git Linux Tools to your environment path? (Y/N)"))) {
    Add-FolderPathToEnvPath -folderPath "C:\Program Files\Git\usr\bin"
    Write-Host "Git Tools were added to your environment path."
}




