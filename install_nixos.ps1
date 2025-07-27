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
        [string]$ToDrive = "d"
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
            
            # Only write if content changed
            if ($newContent -ne $originalContent) {
                $newBytes = [System.Text.Encoding]::UTF8.GetBytes($newContent)
                [System.IO.File]::WriteAllBytes($file.FullName, $newBytes)
                
                Write-Host "Updated $($file.Name):" -ForegroundColor Green
                Write-Host "  - Environment: nixos-dev -> $ToEnv" -ForegroundColor Green
                Write-Host "  - Drive path: Updated to /mnt/$ToDrive/" -ForegroundColor Green
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
    # Get git user settings
    $name = git config --global user.name
    $email = git config --global user.email
    $driveLetter = Get-CurrentDrive
    $username = Get-Username
    $winusername = Get-WindowsUsername
    
    # Validate git settings
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Error "Git user.name is not configured. Please run: git config --global user.name 'Your Name'"
        exit 1
    }
    if ([string]::IsNullOrWhiteSpace($email)) {
        Write-Error "Git user.email is not configured. Please run: git config --global user.email 'your.email@example.com'"
        exit 1
    }

    # Create config object
    $config = @{
        name = $name
        email = $email
        dir = "/mnt/$($driveLetter.ToLower())"
        windows_name = $winusername
        home_name = $username
        gitlab_token = ""  
        github_token = ""
    }
    
    # Save to JSON file with Unix line endings
    try {
        $jsonContent = ($config | ConvertTo-Json).Replace("`r`n","`n")
        [System.IO.File]::WriteAllText(
            (Resolve-Path ".\my_config.json").Path,
            $jsonContent,
            [System.Text.UTF8Encoding]::new($false)
        )
        Write-Host "Settings saved to my_config.json" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to save settings: $_"
        exit 1
    }
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
            $cloneResult = git clone "https://github.com/anistajouri/LVim.git" $lvimPath
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
        $expectedHash = ([System.Text.Encoding]::UTF8.GetString((Invoke-WebRequest -Uri $nixosHashUrl).Content).Trim() -split '\s+')[0]
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
        [string]$GithubToken,
        [Parameter(Mandatory=$false)]
        [string]$Environment = "nixos-dev"
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
        $rebuildCmd = "sudo nixos-rebuild switch --flake /mnt/$DriveRoot/nix/nixos-wsl-startup#$Environment"
        wsl -d $WslName bash -c  $rebuildCmd
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to rebuild NixOS configuration"
        }

        Write-Host "`nNixOS setup completed successfully!" -ForegroundColor Green
        Write-Host "Environment: $Environment" -ForegroundColor Cyan
        Write-Host "WSL Name: $WslName" -ForegroundColor Cyan
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
        [switch]$Help
    )

    if ($Help) {
        Write-Host "Usage: .\install_nixos.ps1 -Name <environment-name>" -ForegroundColor Yellow
        Write-Host "Examples: NixOS-Dev (default), NixOS-Prod, ..." -ForegroundColor Yellow
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

    Write-Host "Using environment name: $Name" -ForegroundColor Cyan

    $driveLetter = Get-CurrentDrive -ForegroundColor Green
    $username = Get-Username
    $winusername = Get-WindowsUsername
    Write-Host "Current drive: $driveLetter"
    Write-Host "Current username: $username"
    Write-Host "Current windows username: $winusername"

    # 1. Check WSL version and requirements    
    Check-WSLRequirements

    # 2. Get and save Github token
    $token = "dummy"


    # 3. Setup environment 
    Configure-MySettings

    # 4. Update config with environment and drive installation
    $environment = $Name.ToLower()
    Write-Host "Target Environment: $environment" -ForegroundColor Cyan
    Update-NixConfig -ToEnv $environment -ToDrive $($driveLetter.ToLower())

    # 5. Install all tools : NixOS, LVim, win32yank
    Install-NixTools -DriveRoot "$driveLetter" -Name "$Name"

    # 6. Install Nix packages and configure system
    Install-NixPackages -DriveRoot $($driveLetter.ToLower()) -WslName $Name -GithubToken $token -Environment $environment
    
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