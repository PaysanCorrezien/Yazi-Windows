param (
    [string]$winPath
)

# Specify your editor here
$editor = "lvim"

# Correctly format the Windows path for WSL path conversion
$wslCompatiblePath = $winPath -replace '\\', '/'

# Convert Windows file path to WSL path
$wslPath = wsl wslpath -a -u "$wslCompatiblePath" | Out-String
$wslPath = $wslPath.Trim()

# Determine the Windows directory of the file
$winFileDir = Split-Path -Parent $winPath

# Correctly format the Windows directory path for WSL path conversion
$wslCompatibleDir = $winFileDir -replace '\\', '/'

# Convert Windows directory path to WSL path
$wslFileDir = wsl wslpath -a -u "$wslCompatibleDir" | Out-String
$wslFileDir = $wslFileDir.Trim()

# Get filename without extension to use as session name
$fileName = [System.IO.Path]::GetFileNameWithoutExtension($winPath)

# Ensure the tmux session doesn't already exist
$sessionExists = wsl tmux has-session -t $fileName 2>$null
if (-not $sessionExists) {
    wsl tmux new-session -d -s $fileName
}

# Construct the command to change directory in tmux and then open the file in the editor
$tmuxCommand = "cd '$wslFileDir'; $editor '$wslPath'"

# Send the command to tmux
wsl tmux send-keys -t $fileName "$tmuxCommand" C-m

