function Clean-String {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputString
    )
    return $InputString -replace '[^\x20-\x7E]', '' -replace '\s+', ' '
}

# Get the current drive letter
function Get-CurrentDrive {
    return $PWD.Path.Substring(0,1)
}


# Function to get username
function Get-Username {
    return $env:USERNAME  # Using simplest method
}

# Check WSL version and requirements
function Check-WSLRequirements {
    try {
        $wslVersion = wsl --version

        #$wslVersionLine = ($wslVersion -split "`n")[0].Trim()
        $wslVersionLine = [string]($wslVersion | Select-Object -First 1).Trim()
        $wslVersionLine = Clean-String -InputString $wslVersionLine

        # check if the wslVersionLine contains WSL version 2 (supports both English and French formats)
        if ($wslVersionLine -Match "(WSL\s+version|Version\s+WSL)\s*:\s*2\.") {
            Write-Host "WSL version 2.x detected" -ForegroundColor Green
        } else {
            Write-Host "WSL version must be 2.x. Current version: $wslVersionLine" -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "WSL not installed or outdated. Please install/update WSL first." -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
}


#update nix config
function Update-NixConfig {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ToEnv,
        [Parameter(Mandatory=$true)]
        [string]$ToDrive = "d",
        [Parameter(Mandatory=$false)]
        [string]$FromDirName = "nixos-wsl-startup",
        [Parameter(Mandatory=$false)]
        [string]$ToDirName = "nixos-wsl-startup"
    )

    # Convert drive to lowercase
    $ToDrive = $ToDrive.ToLower()

    # Find all .lock and .nix files in current directory
    $files = Get-ChildItem -Path . -Include *.lock,*.nix,*.sh -Recurse
    $filesUpdated = 0

    foreach ($file in $files) {
        try {
            # Read content as bytes to preserve exact encoding
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $content = [System.Text.Encoding]::UTF8.GetString($bytes)

            # Store original content for comparison
            $originalContent = $content

            # Make replacements
            $newContent = $content -replace "nixos-dev",$ToEnv
            $newContent = $newContent -replace "/mnt/d/","/mnt/$ToDrive/"
            $newContent = $newContent -replace "/mnt/c/","/mnt/$ToDrive/"

            # Replace directory name if different
            if ($FromDirName -ne $ToDirName) {
                $newContent = $newContent -replace "/$FromDirName/","/$ToDirName/"
                $newContent = $newContent -replace "/$FromDirName#","/$ToDirName#"
            }

            # Only write if content changed
            if ($newContent -ne $originalContent) {
                $newBytes = [System.Text.Encoding]::UTF8.GetBytes($newContent)
                [System.IO.File]::WriteAllBytes($file.FullName, $newBytes)

                Write-Host "Updated $($file.Name):" -ForegroundColor Green
                Write-Host "  - Environment: nixos-dev -> $ToEnv" -ForegroundColor Green
                Write-Host "  - Drive path: Updated to /mnt/$ToDrive/" -ForegroundColor Green
                if ($FromDirName -ne $ToDirName) {
                    Write-Host "  - Directory: $FromDirName -> $ToDirName" -ForegroundColor Green
                }
                $filesUpdated++
            }
        }
        catch {
            Write-Error "Failed to update $($file.Name): $_"
        }
    }

    Write-Host "`nTotal files updated: $filesUpdated" -ForegroundColor Cyan
}


# Configure user settings
function Configure-MySettings {
    param (
        [Parameter(Mandatory=$false)]
        [string]$DirName
    )

    # Get git user settings
    $name = git config --global user.name
    $email = git config --global user.email
    $driveLetter = Get-CurrentDrive
    $username = Get-Username
    $winusername = Get-WindowsUsername

    # Get current directory name if not provided
    if ([string]::IsNullOrWhiteSpace($DirName)) {
        $DirName = Split-Path -Leaf (Get-Location)
    }

    # Validate git settings
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Error "Git user.name is not configured. Please run: git config --global user.name 'Your Name'"
        exit 1
    }
    if ([string]::IsNullOrWhiteSpace($email)) {
        Write-Error "Git user.email is not configured. Please run: git config --global user.email 'your.email@example.com'"
        exit 1
    }

    $configPath = ".\my_config.json"
    $examplePath = ".\my_config.json.example"

    # If my_config.json doesn't exist, create it from the example template
    if (-not (Test-Path $configPath)) {
        if (Test-Path $examplePath) {
            Write-Host "Creating my_config.json from template..." -ForegroundColor Cyan
            Copy-Item -Path $examplePath -Destination $configPath
            Write-Host "Created my_config.json from my_config.json.example" -ForegroundColor Green
        }
        else {
            Write-Error "Template file my_config.json.example not found!"
            exit 1
        }
    }

    # Read existing config to preserve tokens if they exist
    $existingConfig = @{}
    if (Test-Path $configPath) {
        try {
            $existingJson = Get-Content $configPath -Raw | ConvertFrom-Json
            $existingConfig = @{
                gitlab_token = $existingJson.gitlab_token
                github_token = $existingJson.github_token
            }
        }
        catch {
            Write-Host "Could not read existing config, will create new one" -ForegroundColor Yellow
        }
    }

    # Create/update config object with user values, preserving existing tokens
    $config = @{
        name = $name
        email = $email
        dir = "/mnt/$($driveLetter.ToLower())/nix/$DirName"
        windows_name = $winusername
        home_name = $username
        gitlab_token = if ($existingConfig.gitlab_token) { $existingConfig.gitlab_token } else { "" }
        github_token = if ($existingConfig.github_token) { $existingConfig.github_token } else { "" }
    }

    # Save to JSON file with Unix line endings
    try {
        $jsonContent = ($config | ConvertTo-Json).Replace("`r`n","`n")
        [System.IO.File]::WriteAllText(
            (Resolve-Path $configPath).Path,
            $jsonContent,
            [System.Text.UTF8Encoding]::new($false)
        )
        Write-Host "Settings saved to my_config.json" -ForegroundColor Green
        Write-Host "  - Name: $name" -ForegroundColor Cyan
        Write-Host "  - Email: $email" -ForegroundColor Cyan
        Write-Host "  - Home name: $username" -ForegroundColor Cyan
        Write-Host "  - Windows name: $winusername" -ForegroundColor Cyan
        Write-Host "  - Installation dir: /mnt/$($driveLetter.ToLower())/nix/$DirName" -ForegroundColor Cyan
    }
    catch {
        Write-Error "Failed to save settings: $_"
        exit 1
    }
}

# Get secure token
function Get-SecureToken {
    Write-Host "Enter GitLab token: " -NoNewline
    
    $token = ""
    while ($true) {
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        # Skip modifier keys
        if ($key.VirtualKeyCode -in 16,17,18) { # Shift(16), Ctrl(17), Alt(18)
            continue
        }

        # Check for Enter key
        if ($key.VirtualKeyCode -eq 13) {
            Write-Host ""
            break
        }
        
        # Check for Backspace
        if ($key.VirtualKeyCode -eq 8) {
            if ($token.Length -gt 0) {
                $token = $token.Substring(0, $token.Length - 1)
                Write-Host "`b `b" -NoNewline
            }
            continue
        }
        
        # Only add printable characters
        if ($key.Character -match '[!-~]') {
            $token += $key.Character
            Write-Host "*" -NoNewline
        }
    }
    
    return $token
}

function Get-WindowsUsername {
    $rawUsername = $env:USERNAME
    $userPath = "C:\Users"
    
    # Find matching folder that might contain dots
    $userFolder = Get-ChildItem -Path $userPath -Directory | 
                 Where-Object { $_.Name -replace "\.", "" -eq $rawUsername }
    
    if ($userFolder) {
        Write-Host "Found username: $($userFolder.Name)" -ForegroundColor Green
        return $userFolder.Name
    } else {
        Write-Host "Using default username: $rawUsername" -ForegroundColor Yellow
        return $rawUsername
    }
}

# Alternative version that checks actual folder name
function Get-WindowsUsername {
    $rawUsername = $env:USERNAME
    $userPath = "C:\Users"
    
    # Find matching folder that might contain dots
    $userFolder = Get-ChildItem -Path $userPath -Directory | 
                 Where-Object { $_.Name -replace "\.", "" -eq $rawUsername }
    
    if ($userFolder) {
        Write-Host "Found username: $($userFolder.Name)" -ForegroundColor Green
        return $userFolder.Name
    } else {
        Write-Host "Using default username: $rawUsername" -ForegroundColor Yellow
        return $rawUsername
    }
}


function Install-NixTools {
    param (
        [Parameter(Mandatory=$true)]
        [string]$DriveRoot,
        [Parameter(Mandatory=$true)]
        [string]$Name        
    )

    try {
        # Setup paths
        $nixRoot = "${DriveRoot}:\nix"
        $currentDir = Get-Location
        
        # Verify we're in correct directory structure
        if (-not ($currentDir.Path -like "*\nix\*")) {
            Write-Error "Current directory must be under a 'nix' folder"
            return
        }

        # Create nix root if needed
        if (-not (Test-Path $nixRoot)) {
            New-Item -Path $nixRoot -ItemType Directory -Force
            Write-Host "Created $nixRoot directory" -ForegroundColor Green
        }

        # Clone LVim repository
        $lvimPath = Join-Path $nixRoot "LVim"
        if (-not (Test-Path $lvimPath)) {
            Write-Host "Cloning LVim repository..." -ForegroundColor Cyan
            $cloneResult = git clone "https://gitlab.tech.orange/developer-experience/nix-env-setup/LVim.git" $lvimPath
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to clone LVim repository, exiting..." -ForegroundColor Red
                exit 1
            }            
            Write-Host "Cloned LVim to $lvimPath" -ForegroundColor Green
        }
        else {
            Write-Host "LVim directory already exists at $lvimPath" -ForegroundColor Yellow
        }


        # Download and verify NixOS-WSL        
        $nixosUrl = "https://github.com/nix-community/NixOS-WSL/releases/download/2411.6.0/nixos.wsl"
        $nixosHashUrl = "$nixosUrl.sha256"
        $nixosPath = Join-Path $nixRoot "nixos.wsl"

        # Check if file already exists
        if (Test-Path $nixosPath) {
            $userResponse = Read-Host "NixOS-WSL file already exists at $nixosPath. Do you want to redownload it? (Y/N)"
            if ($userResponse -eq "Y" -or $userResponse -eq "y") {
                Write-Host "Redownloading NixOS-WSL..." -ForegroundColor Cyan
                
                # Check if curl.exe is available for better performance
                if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                    Write-Host "Using curl for download..." -ForegroundColor Green
                    curl.exe -L -o $nixosPath $nixosUrl
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to download NixOS-WSL using curl"
                    }
                } else {
                    Write-Host "Using Invoke-WebRequest for download..." -ForegroundColor Yellow
                    Invoke-WebRequest -Uri $nixosUrl -OutFile $nixosPath
                }
            } else {
                Write-Host "Using existing NixOS-WSL file..." -ForegroundColor Cyan
            }
        } else {
            Write-Host "Downloading NixOS-WSL..." -ForegroundColor Cyan
            
            # Check if curl.exe is available for better performance
            if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                Write-Host "Using curl for download..." -ForegroundColor Green
                curl.exe -L -o $nixosPath $nixosUrl
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to download NixOS-WSL using curl"
                }
            } else {
                Write-Host "Using Invoke-WebRequest for download..." -ForegroundColor Yellow
                Invoke-WebRequest -Uri $nixosUrl -OutFile $nixosPath
            }
        }
        
        Write-Host "Getting hash from $nixosHashUrl..." -ForegroundColor Cyan
        $expectedHash = ([System.Text.Encoding]::UTF8.GetString((Invoke-WebRequest -Uri $nixosHashUrl -UseBasicParsing).Content).Trim() -split '\s+')[0]
        $actualHash = (Get-FileHash -Path $nixosPath -Algorithm SHA256).Hash.ToLower()

        if ($actualHash -ne $expectedHash) {
            Remove-Item $nixosPath
            throw "SHA256 hash verification failed for NixOS-WSL download"
        }
        Write-Host "Downloaded and verified NixOS-WSL to $nixosPath" -ForegroundColor Green


        # Import WSL distribution
        Write-Host "Importing NixOS WSL distribution..." -ForegroundColor Cyan
        $wslInstancePath = Join-Path $nixRoot $Name        
        $importCommand = "wsl --import $Name $wslInstancePath $nixosPath --version 2"
        $importResult = Invoke-Expression $importCommand
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to import WSL distribution:" -ForegroundColor Red
            Write-Host $importResult -ForegroundColor Red
            return
        }
        
        Write-Host "Successfully imported NixOS WSL distribution" -ForegroundColor Green
        
        # Cleanup downloaded file
        #Remove-Item $nixosPath -Force
        #Write-Host "Cleaned up temporary files" -ForegroundColor Green

        Write-Host "`nInstallation of all components complete!" -ForegroundColor Green
        Write-Host "Installed to: $nixRoot" -ForegroundColor Cyan
    }
    catch {
        Write-Error "Installation failed: $_"
    }
}


function Install-NixPackages {
    param (
        [Parameter(Mandatory=$true)]
        [string]$DriveRoot,
        [Parameter(Mandatory=$true)]
        [string]$WslName,
        [Parameter(Mandatory=$true)]
        [string]$GitlabToken,
        [Parameter(Mandatory=$false)]
        [string]$Environment = "nixos-dev",
        [Parameter(Mandatory=$false)]
        [string]$DirName = "nixos-wsl-startup"
    )

    try {

        Write-Host "Installing required Nix packages in $WslName..." -ForegroundColor Cyan

        # Install git and other packages
        $installCommands = @(
            "nix-env -iA nixos.git"
        )

# Not needed for sops right know        ,
#            "nix-env -iA nixos.age",
#            "nix-env -iA nixos.sops"

        foreach ($cmd in $installCommands) {
            Write-Host "Executing: $cmd" -ForegroundColor Yellow
            wsl -d $WslName  bash -c $cmd
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to execute: $cmd"
            }
        }



        # Execute nixos-rebuild
        Write-Host "Rebuilding NixOS configuration..." -ForegroundColor Cyan

        # First, remove the corrupted flake.lock and regenerate it
        Write-Host "Removing old flake.lock to regenerate with current inputs..." -ForegroundColor Yellow
        $removeLockCmd = "cd /mnt/$DriveRoot/nix/$DirName && rm -f flake.lock"
        wsl -d $WslName bash -c $removeLockCmd

        # Use 'boot' instead of 'switch' to avoid systemd restart issues in WSL
        # The configuration will be applied on next WSL restart
        Write-Host "Building NixOS configuration (will apply on next restart)..." -ForegroundColor Yellow
        $rebuildCmd = "sudo nixos-rebuild boot --flake /mnt/$DriveRoot/nix/$DirName#$Environment"
        wsl -d $WslName bash -c $rebuildCmd
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build NixOS configuration"
        }

        Write-Host "Configuration built successfully!" -ForegroundColor Green
        Write-Host "Restarting WSL to apply changes..." -ForegroundColor Yellow

        # Terminate the WSL instance to apply the new configuration
        wsl --terminate $WslName
        Start-Sleep -Seconds 2

        # Start it again with the new configuration
        Write-Host "Starting $WslName with new configuration..." -ForegroundColor Cyan
        wsl -d $WslName bash -c "echo 'WSL restarted successfully'" | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "WSL instance restarted successfully with new configuration!" -ForegroundColor Green
        } else {
            Write-Warning "WSL restart may have issues. Try manually: wsl --terminate $WslName && wsl -d $WslName"
        }

        Write-Host "`nNixOS setup completed successfully!" -ForegroundColor Green
        Write-Host "Environment: $Environment" -ForegroundColor Cyan
        Write-Host "WSL Name: $WslName" -ForegroundColor Cyan
        Write-Host "Directory: /mnt/$DriveRoot/nix/$DirName" -ForegroundColor Cyan
    }
    catch {
        Write-Error "Installation failed: $_"
        exit 1
    }
}


# Main execution
function Main {
    param (
        [Parameter(Mandatory=$false)]
        [string]$Name = "NixOS-Dev",  # Default value set to NixOS-Dev
        [Parameter(Mandatory=$false)]
        [string]$DirName,  # Optional custom directory name (defaults to current directory name)
        [switch]$Help
    )

    if ($Help) {
        Write-Host "Usage: .\install_nixos.ps1 -Name <environment-name> [-DirName <directory-name>]" -ForegroundColor Yellow
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  .\install_nixos.ps1 -Name NixOS-Dev" -ForegroundColor Cyan
        Write-Host "  .\install_nixos.ps1 -Name NixOS-Prod -DirName config-wsl-1" -ForegroundColor Cyan
        Write-Host "" -ForegroundColor Yellow
        Write-Host "The DirName parameter allows you to use a different directory name than the default." -ForegroundColor Yellow
        Write-Host "If not specified, it will use the current directory name." -ForegroundColor Yellow
        exit 0
    }

    # Validate that the Name parameter starts with "nixos-"
    if (-not $Name.ToLower().StartsWith("nixos-")) {
        Write-Host "Error: Environment name must start with 'nixos-'" -ForegroundColor Red
        Write-Host "Your provided value: $Name" -ForegroundColor Red
        Write-Host "Correct format examples: nixos-dev, nixos-prod" -ForegroundColor Yellow
        exit 1
    }

    # Check current directory path
    $currentPath = Get-Location

    # Check if path starts with any drive letter followed by :\nix
    if (-not ($currentPath.Path -match "^[A-Z]:\\nix")) {
        Write-Error "Script must be run from a subdirectory under X:\nix (current path: $currentPath)"
        Write-Host "Please change to a directory under X:\nix" -ForegroundColor Yellow
        exit 1
    }

    # Get current directory name if DirName not specified
    if ([string]::IsNullOrWhiteSpace($DirName)) {
        $DirName = Split-Path -Leaf $currentPath
        Write-Host "Using current directory name: $DirName" -ForegroundColor Cyan
    } else {
        Write-Host "Using custom directory name: $DirName" -ForegroundColor Cyan
    }

    Write-Host "Using environment name: $Name" -ForegroundColor Cyan

    $driveLetter = Get-CurrentDrive -ForegroundColor Green
    $username = Get-Username
    $winusername = Get-WindowsUsername
    Write-Host "Current drive: $driveLetter"
    Write-Host "Current username: $username"
    Write-Host "Current windows username: $winusername"
    Write-Host "Installation directory: $DirName" -ForegroundColor Cyan

    # 1. Check WSL version and requirements    
    Check-WSLRequirements

    # 2. Get and save GitLab token
    $token = "dummy"
#    Write-Host "`nSetup GitLab credentials:" -ForegroundColor Cyan
#    $token = Get-SecureToken
#    if ($token) {
#        try {
#            $credPath = "C:\Users\$winusername\.git-credentials"
            
            # Read existing credentials
#            $existingCreds = @()
#            if (Test-Path $credPath) {
#                $existingCreds = Get-Content $credPath
#            }

            # Remove old GitLab entries
#            $existingCreds = $existingCreds | Where-Object { 
#                -not ($_ -like "*gitlab.tech.orange*" -or $_ -like "*gitlab.com*")
#            }

            # Add new entries
#            $entries = @(
#                "https://${token}:${token}@gitlab.tech.orange",
#                "https://${token}:${token}@gitlab.com"
#            )

            # Save unique entries
#            $allCreds = $existingCreds + $entries
#            $allCreds | Select-Object -Unique | Set-Content $credPath

#            Write-Host "GitLab token saved successfully" -ForegroundColor Green
#        }
#        catch {
#            Write-Error "Failed to save token: $_"
#        }
#    }

    # 3. Setup environment
    Configure-MySettings -DirName $DirName

    # 4. Update config with environment and drive installation
    # Determine source directory name from current directory for replacement
    $currentDirName = Split-Path -Leaf $currentPath
    $environment = $Name.ToLower()
    Write-Host "Target Environment: $environment" -ForegroundColor Cyan
    Update-NixConfig -ToEnv $environment -ToDrive $($driveLetter.ToLower()) -FromDirName $currentDirName -ToDirName $DirName

    # 5. Install all tools : NixOS, LVim, win32yank
    Install-NixTools -DriveRoot "$driveLetter" -Name "$Name"

    # 6. Install Nix packages and configure system
    Install-NixPackages -DriveRoot $($driveLetter.ToLower()) -WslName $Name -GitlabToken $token -Environment $environment -DirName $DirName
    
    Write-Host "Initial setup complete. dbus issue to be ignored as linked to graphics." -ForegroundColor Green
    Write-Host "Run 'wsl -d $Name' to enter the WSL environment and continue with the remaining steps." -ForegroundColor Yellow
}

# Run the script
$scriptArgs = $args
if ($scriptArgs) {
    Main @scriptArgs
} else {
    Main -Name "NixOS-Dev"  # Explicitly pass default value
}