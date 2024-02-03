# For no prompt install
param (
  [switch]$Force
)

# This one use /releases, /latest is more commonly used but dont work for Yazi
function Get-GithubRelease
{
  param (
    [string]$Repo
  )

  try
  {
    $uri = "https://api.github.com/repos/$Repo/releases"
    Write-Host "Requesting URL: $uri"
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers @{ Accept = "application/vnd.github.v3+json" }
        
    if ($response.Count -gt 0)
    {
      $latestRelease = $response | Sort-Object -Property published_at -Descending | Select-Object -First 1
      Write-Host "Latest release found: Tag $($latestRelease.tag_name), Published on $($latestRelease.published_at)"
      return $latestRelease.tag_name
    } else
    {
      Write-Host "No releases found for $Repo."
      return $null
    }
  } catch
  {
    Write-Host "Error encountered: $_"
    return $null
  }
}

function Get-PlatformAndArchitecture
{
  Write-Host "Determining system platform and architecture..."
  $os = [System.Environment]::OSVersion.Platform
  $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture

  Write-Host "OS Platform: $os, Architecture: $arch"

  $platform = switch ($os)
  {
    'Win32NT'
    { 'pc-windows-msvc' 
    }
    'Unix'
    { 'unknown-linux-gnu' 
    } # You might need to refine this for specific Unix variants
    'MacOSX'
    { 'apple-darwin' 
    }
    default
    { $os.ToString().ToLower() 
    } # Default case if it's a different/unknown platform
  }

  $architecture = switch ($arch)
  {
    'X64'
    { 'x86_64' 
    }
    'Arm64'
    { 'aarch64' 
    }
    default
    { $arch.ToString().ToLower() 
    } # Default case if it's a different/unknown architecture
  }

  Write-Host "Mapped Platform: $platform, Mapped Architecture: $architecture"
  return @{ Platform = $platform; Architecture = $architecture }
}

function Get-AssetFromGitHubRelease
{
  param (
    [string]$Repo,
    [string]$TagName,
    [PSCustomObject]$PlatformAndArchitecture
  )

  Write-Host "Requesting URL: https://api.github.com/repos/$Repo/releases/tags/$TagName"
  $uri = "https://api.github.com/repos/$Repo/releases/tags/$TagName"
  $response = Invoke-RestMethod -Uri $uri -Method Get -Headers @{ Accept = "application/vnd.github.v3+json" }
  Write-Host "The following assets are available in the release: $($response.assets.name -join ', ')"

  # Adjust the pattern to reflect the correct order
  $pattern = "*$($PlatformAndArchitecture.Architecture)*$($PlatformAndArchitecture.Platform)*.zip"
  Write-Host "Asset search pattern: $pattern"

  foreach ($asset in $response.assets)
  {
    Write-Host "Checking asset: $($asset.name)"
    if ($asset.name -like $pattern)
    {
      Write-Host "Asset found: $($asset.name)"
      return $asset
    }
  }

  Write-Host "No asset found matching the pattern: $pattern"
  exit 1
}


function DownloadAndExtract
{
  param (
    [PSCustomObject]$Asset,
    [string]$DestinationPath
  )

  $tempPath = [System.IO.Path]::GetTempPath()
  $tempFile = Join-Path $tempPath $Asset.name
  $downloadUrl = $Asset.browser_download_url

  Write-Host "Downloading ZIP to temporary folder: $tempFile"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile

  $tempExtractionPath = New-Item -ItemType Directory -Path (Join-Path $tempPath ([System.IO.Path]::GetRandomFileName())) -Force
  Write-Host "Extracting ZIP to temporary folder: $tempExtractionPath"
  Expand-Archive -LiteralPath $tempFile -DestinationPath $tempExtractionPath -Force

  # Attempt to get only content
  $rootFolder = Get-ChildItem -Path $tempExtractionPath | Where-Object { $_.PSIsContainer } | Select-Object -First 1
  if ($rootFolder)
  {
    Write-Host "Moving contents from $rootFolder to $DestinationPath"
    Get-ChildItem -Path $rootFolder.FullName -Recurse | ForEach-Object {
      $targetPath = Join-Path $DestinationPath $_.FullName.Substring($rootFolder.FullName.Length)
      if (Test-Path $targetPath)
      {
        if (Test-Path $targetPath -PathType Container)
        {
          # Merge directory contents
          Write-Host "Merging directory: $targetPath"
          # No action needed, as sub-files/-directories will be handled individually
        } else
        {
          # Overwrite file
          Write-Host "Overwriting file: $targetPath"
          Remove-Item $targetPath -Force
        }
      } else
      {
        $dirPath = [System.IO.Path]::GetDirectoryName($targetPath)
        if (!(Test-Path $dirPath))
        {
          New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        }
      }
      # Check if source is a directory, skip moving as its contents are handled individually
      if (!(Test-Path $_.FullName -PathType Container))
      {
        Move-Item $_.FullName -Destination $targetPath -Force
      }
    }
  }

  Write-Host "Cleaning up temporary files."
  Remove-Item -Path $tempFile
  Remove-Item -Path $tempExtractionPath -Recurse -Force

  return $DestinationPath
}

function Get-GithubRepo
{
  param (
    [string]$Repo,
    [string]$TagName,
    [string]$DestinationPath,
    [string]$Platform = "windows"  # Default to 'windows'. Change as needed.
  )

  try
  {
    $PlatformAndArchitecture = Get-PlatformAndArchitecture
    Write-Host "System platform and architecture detected: $($PlatformAndArchitecture.Platform), $($PlatformAndArchitecture.Architecture)"

    $asset = Get-AssetFromGitHubRelease -Repo $Repo -TagName $TagName -PlatformAndArchitecture $PlatformAndArchitecture
    if ($asset)
    {
      DownloadAndExtract -Asset $asset -DestinationPath $DestinationPath
    } else
    {
      Write-Error "No downloadable ZIP asset found for $($PlatformAndArchitecture.Platform) platform in $Repo release $TagName"
      return $null
    }
  } catch
  {
    Write-Host "Error encountered: $_"
    return $null
  }
}

function InstallScoopExtras
{

  # Install the optional dependencies (recommended):
  $command = "scoop install unar jq poppler fd ripgrep fzf zoxide"
  Write-Host "Running command: $command"
  Invoke-Expression $command

}

function Add-FolderPathToEnvPath
{
  param(
    [Parameter(Mandatory=$true)]
    [string]$folderPath
  )

  try
  {
    # Check if the folder path exists
    if (-Not (Test-Path -Path $folderPath))
    {
      throw "Folder path does not exist: $folderPath"
    }

    # Get the current PATH environment variable for the user
    $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")

    # Check if the folder path is already in the PATH
    if ($currentPath -split ';' -contains $folderPath)
    {
      Write-Host "Folder path already in PATH: $folderPath"
      return
    }

    # Add folder path to the PATH environment variable
    $newPath = $currentPath + ';' + $folderPath
    [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")

    # Verify if the folder path was added
    $updatedPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($updatedPath -split ';' -contains $folderPath)
    {
      Write-Host "Folder path added to User PATH successfully: $folderPath"
    } else
    {
      throw "Failed to add folder path to PATH"
    }
  } catch
  {
    Write-Error "An error occurred: $_"
  }
}
function Create-WeztermYaziShortcut
{
  $desktopPath = [System.Environment]::GetFolderPath('Desktop')
  $shortcutPath = Join-Path $desktopPath "Yazi.lnk"

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
function Install-GitForWindows
{
  param (
    [string]$Repo = "git-for-windows/git",
    [switch]$Force
  )

  $latestTag = Get-GithubRelease -Repo $Repo
  if (-not $latestTag)
  {
    Write-Error "Failed to get the latest release for $Repo."
    return
  }

  $releaseUri = "https://api.github.com/repos/$Repo/releases/tags/$latestTag"
  $releaseResponse = Invoke-RestMethod -Uri $releaseUri -Method Get -Headers @{ Accept = "application/vnd.github.v3+json" }

  $installerAsset = $releaseResponse.assets | Where-Object { $_.name -like "*-64-bit.exe" } | Select-Object -First 1

  if ($installerAsset)
  {
    $tempPath = [System.IO.Path]::GetTempPath()
    $installerPath = Join-Path $tempPath $installerAsset.name

    Write-Host "Downloading Git installer: $($installerAsset.name)"
    Invoke-WebRequest -Uri $installerAsset.browser_download_url -OutFile $installerPath

    # Run the installer
    if ($Force)
    {
      Start-Process -FilePath $installerPath -Args "/VERYSILENT /NORESTART" -Wait -NoNewWindow
    } else
    {
      Start-Process -FilePath $installerPath -Wait -NoNewWindow
    }

    # Optionally, remove the installer after installation
    Remove-Item -Path $installerPath

    Write-Host "Git has been installed."
  } else
  {
    Write-Error "No Git installer found in the latest release."
  }
}

function Is-WingetAvailable
{
  try
  {
    $null = winget --version
    return $true
  } catch
  {
    Write-Host "Winget is not available on this system."
    return $false
  }
}

# Install Wezterm
function Install-Wezterm
{
  param (
    [switch]$Force
  )

  if (Is-WingetAvailable)
  {
    $command = "winget install wez.wezterm"
    Write-Host "Running command: $command"
    try
    {
      Invoke-Expression $command
      Write-Host "Wezterm has been installed successfully."
    } catch
    {
      Write-Error "Failed to install Wezterm. Error: $_"
    }
  }
}

function Get-UserConfirmation
{
  param (
    [string]$Message
  )
    
  do
  {
    $userInput = Read-Host -Prompt "$Message"
    # Treat Enter (empty input) as 'Y'
    if (-not $userInput)
    {
      $userInput = 'Y'
    }
  }
  # Loop until the user enters 'Y', 'y', 'N', or 'n'
  until ($userInput -eq 'Y' -or $userInput -eq 'y' -or $userInput -eq 'N' -or $userInput -eq 'n')
    
  # Return $true if the input is 'Y' or 'y'; otherwise, return $false
  return $userInput -eq 'Y' -or $userInput -eq 'y'
}



# Start of the program
# user/appdata/local/ folder is more common for program, maybe change this ?
$Repo = "sxyazi/yazi"
$destinationPath = "$env:APPDATA\yazi\bin"

# Define the destination directory for config files
$configDir = "$env:APPDATA\yazi\config"

# Check and create destination folder
if (-not (Test-Path -Path $destinationPath))
{
  New-Item -ItemType Directory -Path $destinationPath | Out-Null
  Write-Host "Destination folder created: $destinationPath"
} else
{
  Write-Host "Destination folder already exists: $destinationPath"
}
# Select one of the installation method
# $choice = Read-Host "Select an installation method: 1. Scoop 2. github 3. Manual(build with rust)"
$choice = READ-HOST "Select an installation method: 1. Scoop 2. github release, type either 1 or 2"
switch ($choice)
{
  1
  {
    $command = "scoop install yazi"
    Write-Host "Running command: $command"
    Invoke-Expression $command
  }
  2
  {
    Write-Host "Installing from GitHub"
    # Installation Process (Get release, Download, Install)
    if ($Force -or (Get-UserConfirmation "Proceed with installation for Yazi ? , this will download the latest release of the app from github (Y/N)"))
    {
      $latestRelease = Get-GithubRelease -Repo $Repo

      if ($latestRelease)
      {
        Get-GithubRepo -Repo $Repo -TagName $latestRelease -DestinationPath $destinationPath -Force:$Force
      } else
      {
        Write-Host "No latest release found for $Repo."
      }
    }
  }
  # 3
  # {
  #   Write-Host "Manual installation is not yet supported."
  #   # TODO: provide a way to choose repo destination and clone it
  #   # clone the repo
  #   # maybe with a way to pass build args ?
  #   # cd to the repo, and build the project
  #   #
  #   # TODO:
  #   # Allow to choose branch, pr commit with git arguments
  #   # and make this even better with global powershell arg like -build to launch this directly to not run the rest of GUI ?
  #   # to be able to build nightly quickly
  #
  # }
  default
  {
    Write-Host "Invalid choice. Exiting."
    return
  }
}

# Prompt for adding to environment path
if ($latestRelease -and ($Force -or (Get-UserConfirmation "Do you want to add $destinationPath to your environment path? (Y/N)")))
{
  Add-FolderPathToEnvPath -folderPath $destinationPath
  Write-Host "$destinationPath has been added to your environment path."
}
# Prompt for creating WezTerm Yazi Shortcut
if ($Force -or (Get-UserConfirmation "Do you want to create a WezTerm Yazi shortcut on your desktop? (Y/N)"))
{
  Create-WeztermYaziShortcut
}

# HACK: Until the file come with the install
# Prompt for downloading and copying the preset files
if ($Force -or (Get-UserConfirmation "Do you want to download and install the preset configuration files? If you already have a configuration set this will overide it (Y/N)"))
{
  # Ensure the config directory exists
  if (-not (Test-Path -Path $configDir))
  {
    New-Item -ItemType Directory -Path $configDir | Out-Null
    Write-Host "Config directory created: $configDir"
  }

  # Base URL for the raw content
  $baseUrl = "https://raw.githubusercontent.com/sxyazi/yazi/main/yazi-config/preset/"

  # Files to download
  $filesToDownload = @("keymap.toml", "theme.toml", "yazi.toml")

  # Download and save each file
  foreach ($file in $filesToDownload)
  {
    $url = $baseUrl + $file
    $destPath = Join-Path $configDir $file
    Invoke-WebRequest -Uri $url -OutFile $destPath
    Write-Host "Downloaded $file to $destPath"
  }
}


# Prompt to add git /usr/bin to path
if ($Force -or (Get-UserConfirmation "Do you want to install Git for Windows ? This will download the latest release from 'https://github.com/git-for-windows/git'
which provides `file` that yazi require to detect mimetype. 
This will launch Git setup and wait it proceed (Y/N)"))
{
  Install-GitForWindows -Force:$Force
}

if ($Force -or (Get-UserConfirmation "Do you want to install Wezterm?
This will install wezterm via `winget` if winget is available (Y/N)"))
{
  Install-Wezterm -Force:$Force
}
if ($Force -or (Get-UserConfirmation "Do you want to install the extras dependencies via scoop (you need to have scoop installed):
This will execute 'scoop install unar jq poppler fd ripgrep fzf zoxide' ? (Y/N)"))
{
  InstallScoopExtras
}
