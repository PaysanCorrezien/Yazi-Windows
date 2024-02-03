This repo include the scripts i use to make [yazi](https://github.com/sxyazi/yazi) even better on Windows

# 🔖 Prerequisite

For the Yazi installer, nothing the script should handle everything
If you wish to use my settings :

- Pwsh aka Powershell Core or you will need to replace pwsh.exe by powershell.exe on every script

# 🪄 Yazi Installation Script

The installation script will cover the installation of the program,
adding it to `PATH` ( allowing system to use it) and creation of a shortcut to launch it with wezterm,
It can also install git-for-windows from github and make the `file` util available on `path`.
It Also prompt to download the `preset` conf file provide by Yazi
Install `scoop` recommanded packages
And it Can Install wezterm from winget

\_This script doesn't install the recommanded package like fzf zoxide
The icon is created With default wezterm path from `winget` installation, if you use a portable version adjust it

## 👷 Using the script

### 📦 Using the installer

Open powershell and run:
_This will prompt you for the installation of all the components_

```powershell
iex (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/PaysanCorrezien/Yazi-Windows/master/Install.ps1' -UseBasicParsing).Content
```

### 🤖 Unnatended installation

_This will install everything without prompt_

```powershell
iex ((Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/PaysanCorrezien/Yazi-Windows/master/Install.ps1' -UseBasicParsing).Content + ' -Force')
```

** Always check script before running it from a random repo like mine **

# 🌟 Features enhancement

This repo include multiple script that offer some functionnality that are realy usefull on windows explorer :

- Open Details tab of a file
- Open powershell in current dir
- Open powershell in current dir as admin ( UAC will prompt ! )
- Drag and drop one or multiple files
- Open explorer in current working directory

And one more that i like a lot and is working perfectly for my use case :

- Open In WSLTmux , which create a session in tmux with the name of file as session name, cd into the directory of the file, and open it in Neovim
  This one is working on my `special` use case but can give you inspiration to make something that feet your need.

## How to install

Open powershell and clone the repo :

```powershell
$dirPath = "$env:APPDATA\yazi\WindowsEnhancement"; New-Item -ItemType Directory -Path $dirPath -Force | Out-Null; git clone "https://github.com/PaysanCorrezien/Yazi-Windows.git" $dirPath
```

## Using it

To use those function we need to edit the keymap.toml file provided by the preset [here](https://github.com/sxyazi/yazi/tree/main/yazi-config/preset)
On my `keymap.toml` on `$env:APPDATA\yazi\config\` , on the keymap array at the end i added :

```toml
  # Open windows Explorer in current working directory ( for features missing in yazi for now)
   on = ["g", "e" ], exec = "shell 'explorer .'", desc = "Open Explorer here" },
  # Allow to drag one or multiples Files like dragon on linux. To copy in emails for example
  # remove --confirm to check the command before running it
  { on = [ "c", "D" ], exec= '''
    shell 'pwsh.exe -ex Bypass -C "& $env:APPDATA\yazi\WindowsEnhancement\Drag.ps1 %*"' --confirm
  ''', desc= "Drag File(s)"},
  # Open the windows File explorer property Tab
  { on = [ "c", "P" ], exec= '''
    shell 'pwsh.exe -ex Bypass -C "& $env:APPDATA\yazi\WindowsEnhancement\OpenFileDetails.ps1 %1' --confirm
  ''', desc= "Open File Details"},
  # Open Powershell As User
  { on= [ "g", "p" ], exec= '''
    shell 'pwsh.exe -ex Bypass -C "& env:APPDATA\yazi\WindowsEnhancement\PowershellSession.ps1 %1 "' --confirm
  ''', desc= "Open PowerShell Here"},
  # Open Powershell As Admin / Will Prompt UAC
  # TODO : Open in default terminal not classic powershell
  {  on= [ "g", "P" ], exec= '''
    shell 'pwsh.exe -ex Bypass -C "& $env:APPDATA\yazi\WindowsEnhancement\PowershellSession.ps1 -Admin %1 "' --confirm
  ''', desc= "Open PowerShell as Admin" },
  # Open in $EDITOR inside TMUX on WSLSIDE
  # Create a new tmux session from filename , cd into parent folder, open it in choosen editor
  # The script OpenInWslTmux.ps1 need to be edited with name of the app
  {  on= [ "g", "T" ], exec= '''
    shell 'pwsh.exe -ex Bypass -C "& $env:APPDATA\yazi\WindowsEnhancement\OpenInWSLTmux.ps1 %1"' --confirm
  ''', desc= "Open File In TMUX EDITOR" },
```

## Neovim User

If you are a neovim user like me, you probably want to replace the default `opener` of the config which is `code` (VSCODE).
You can change it like this in `yazi.toml`:

```toml
[opener]
edit = [{ exec = '$EDITOR "$@"', block = true, for = "unix" }, { exec = '''
  pwsh.exe -NoProfile -Command "nvim %*"
''', block = true, for = "windows" }]
```

## 📜 File association

On Windows, file association are a mess, settings them system wide automatically is realy hard.
To make Yazi open most of the file with Neovim, we can just set most of the files assocations directly in the Yazi config.

This is a WIP list of file association that I added to `yazi.toml` mostly `ai` generated.
There may be errors.

```toml
  # PowerShell Scripts
  { mime = "text/x-powershell", use = [
    "edit",
    "reveal",
  ] },
  { mime = "application/x-powershell", use = [
    "edit",
    "reveal",
  ] },
  #
  # Batch Files
  { mime = "application/bat", use = [
    "edit",
    "reveal",
  ] },
  { mime = "application/x-bat", use = [
    "edit",
    "reveal",
  ] },
  { mime = "text/plain", name = "*.bat", use = [
    "edit",
    "reveal",
  ] },

  # Text Files
  { mime = "text/plain", use = [
    "edit",
    "reveal",
  ] },

  # .config Files
  { mime = "application/xml", name = "*.config", use = [
    "edit",
    "reveal",
  ] },

  # Makefiles
  { mime = "text/x-makefile", use = [
    "edit",
    "reveal",
  ] },
  { mime = "text/plain", name = "Makefile", use = [
    "edit",
    "reveal",
  ] },

  # Dockerfiles
  { mime = "text/x-dockerfile", use = [
    "edit",
    "reveal",
  ] },
  #
  # INI Files
  { mime = "text/plain", name = "*.ini", use = [
    "edit",
    "reveal",
  ] },

  # .env Files
  { mime = "text/plain", name = "*.env", use = [
    "edit",
    "reveal",
  ] },

  # Java Properties Files
  { mime = "text/x-java-properties", use = [
    "edit",
    "reveal",
  ] },

  # Apache Configuration Files (.htaccess)
  { mime = "text/plain", name = ".htaccess", use = [
    "edit",
    "reveal",
  ] },

  # Shell Profiles (like .bashrc, .zshrc)
  { mime = "application/x-shellscript", name = ".*rc", use = [
    "edit",
    "reveal",
  ] },

  # Git Configuration Files (.gitignore, .gitconfig)
  { mime = "text/plain", name = ".gitignore", use = [
    "edit",
    "reveal",
  ] },
  { mime = "text/plain", name = ".gitconfig", use = [
    "edit",
    "reveal",
  ] },

  # Vim Configuration Files (.vimrc)
  { mime = "text/plain", name = ".vimrc", use = [
    "edit",
    "reveal",
  ] },

  # C and C++
  { mime = "text/x-c", use = [
    "edit",
    "reveal",
  ] },
  { mime = "text/x-c++", use = [
    "edit",
    "reveal",
  ] },
  { mime = "text/x-chdr", use = [
    "edit",
    "reveal",
  ] },
  { mime = "text/x-c++hdr", use = [
    "edit",
    "reveal",
  ] },
  { mime = "text/x-csrc", use = [
    "edit",
    "reveal",
  ] },
  { mime = "text/x-c++src", use = [
    "edit",
    "reveal",
  ] },

  # C#
  { mime = "text/x-csharp", use = [
    "edit",
    "reveal",
  ] },

  # Java
  { mime = "text/x-java", use = [
    "edit",
    "reveal",
  ] },

  # Python
  { mime = "text/x-python", use = [
    "edit",
    "reveal",
  ] },

  # TypeScript
  { mime = "application/typescript", use = [
    "edit",
    "reveal",
  ] },

  # PHP
  { mime = "application/x-httpd-php", use = [
    "edit",
    "reveal",
  ] },

  # Ruby
  { mime = "application/x-ruby", use = [
    "edit",
    "reveal",
  ] },

  # Go
  { mime = "text/x-go", use = [
    "edit",
    "reveal",
  ] },

  # Rust
  { mime = "text/rust", use = [
    "edit",
    "reveal",
  ] },

  # Shell Scripts
  { mime = "application/x-shellscript", use = [
    "edit",
    "reveal",
  ] },

  # Perl
  { mime = "text/x-perl", use = [
    "edit",
    "reveal",
  ] },

  # Lua
  { mime = "text/x-lua", use = [
    "edit",
    "reveal",
  ] },

  # YAML
  { mime = "text/yaml", use = [
    "edit",
    "reveal",
  ] },

  # TOML
  { mime = "application/toml", use = [
    "edit",
    "reveal",
  ] },

  # JSON
  { mime = "application/json", use = [
    "edit",
    "reveal",
  ] },

  # XML
  { mime = "application/xml", use = [
    "edit",
    "reveal",
  ] },

  # HTML
  { mime = "text/html", use = [
    "edit",
    "reveal",
  ] },

  # CSS
  { mime = "text/css", use = [
    "edit",
    "reveal",
  ] },

  # Markdown
  { mime = "text/markdown", use = [
    "edit",
    "reveal",
  ] },

  # SQL
  { mime = "application/sql", use = [
    "edit",
    "reveal",
  ] },

  # Bash/Zsh
  { mime = "application/x-shellscript", use = [
    "edit",
    "reveal",
  ] },
  { mime = "*", use = [
    "open",
    "reveal",
  ] },
```
