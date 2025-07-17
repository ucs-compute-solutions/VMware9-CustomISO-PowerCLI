# Detect OS
$OS = $PSVersionTable.PSVersion.Platform
$IsMac = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)

# Check PowerCLI
function Check-PowerCLI {
    try {
        if (-not (Get-Module -ListAvailable VMware.PowerCLI)) {
            Write-Host "Installing VMware.PowerCLI..."
            Install-Module -Name VMware.PowerCLI -Force -Scope CurrentUser -AllowClobber
        } else {
            Write-Host "PowerCLI is already installed."
        }
    } catch {
        Write-Host "Error: Could not install PowerCLI module." -ForegroundColor Red
        exit 1
    }
}

# Python + pip + modules
function Check-Python {
    try {
        if ($IsMac) {
            $pythonCmd = "python3"
            $pipCmd = (Get-Command pip3 -ErrorAction SilentlyContinue).Source
            if (-not $pipCmd) {
                $pipCmd = "$pythonCmd -m pip"
            } else {
                $pipCmd = "pip3"
            }
        } else {
            $pythonCmd = "python"
            $pipCmd = (Get-Command pip -ErrorAction SilentlyContinue).Source
            if (-not $pipCmd) {
                $pipCmd = "$pythonCmd -m pip"
            } else {
                $pipCmd = "pip"
            }
        }

        $pythonPath = (Get-Command $pythonCmd -ErrorAction SilentlyContinue).Source
        if (-not $pythonPath) {
            Write-Host "Python is not installed. Please install Python 3.7.1 - 3.12" -ForegroundColor Red
            exit 1
        }

        Write-Host "Python found at: $pythonPath"

        $versionOutput = & $pythonCmd --version
        if ($versionOutput -match "Python (\d+)\.(\d+)\.(\d+)") {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            if ($major -ne 3 -or $minor -lt 7 -or $minor -gt 12) {
                Write-Host "Unsupported Python version: $versionOutput" -ForegroundColor Red
                exit 1
            }
        }

        Check-OpenSSL-In-Python $pythonCmd

        $requiredModules = @('six', 'lxml', 'psutil', 'pyopenssl')
        foreach ($module in $requiredModules) {
            if (-not (& $pipCmd show $module 2>$null)) {
                Write-Host "$module not installed. Installing..." -ForegroundColor Yellow
                & $pipCmd install $module
            } else {
                Write-Host "$module is already installed."
            }
        }

    } catch {
        Write-Host "Error verifying Python or pip modules." -ForegroundColor Red
        exit 1
    }
}

# OpenSSL version check inside Python
function Check-OpenSSL-In-Python {
    param ([string]$pythonCmd)
    try {
        $opensslVersion = & $pythonCmd -c "import ssl; print(ssl.OPENSSL_VERSION)" 2>$null
        if ($opensslVersion -match "OpenSSL (\d+)\.(\d+)\.(\d+)") {
            if ([int]$Matches[1] -ne 3) {
                Write-Host "Incompatible OpenSSL version: $opensslVersion" -ForegroundColor Red
                Install-OpenSSL
                exit 1
            } else {
                Write-Host "OpenSSL version supported: $opensslVersion"
            }
        } else {
            Write-Host " Could not parse OpenSSL version: $opensslVersion" -ForegroundColor Yellow
            Install-OpenSSL
        }
    } catch {
        Write-Host "Error checking OpenSSL version." -ForegroundColor Red
        exit 1
    }
}

# Install OpenSSL 3
function Install-OpenSSL {
    if ($IsMac) {
        $brewPath = (Get-Command brew -ErrorAction SilentlyContinue).Source
        if (-not $brewPath) {
            Write-Host "Homebrew not installed. Please install it from https://brew.sh/" -ForegroundColor Red
            exit 1
        }

        $currentUser = whoami
        $realUser = $env:SUDO_USER
        if (-not $realUser) { $realUser = $currentUser }

        try {
            Write-Host "Installing OpenSSL 3 via Homebrew..."
            & /bin/bash -c "sudo -u $realUser brew install openssl@3"
            Write-Host "Reinstalling Python to link OpenSSL 3..."
            & /bin/bash -c "sudo -u $realUser brew reinstall python@3.11"
            Write-Host "OpenSSL 3 and Python relinked." -ForegroundColor Green
        } catch {
            Write-Host "Failed to install OpenSSL via Homebrew." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Download and install OpenSSL manually from:" -ForegroundColor Cyan
        Write-Host "https://slproweb.com/products/Win32OpenSSL.html"
        Start-Process "https://slproweb.com/products/Win32OpenSSL.html"
    }
}

# Set Python path for PowerCLI
function Set-PowerCLI-PythonPath {
    try {
        if ($IsMac) {
            $pythonPath = (Get-Command python3 -ErrorAction SilentlyContinue).Source
        } else {
            $pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
        }

        Set-PowerCLIConfiguration -PythonPath $pythonPath -Scope AllUsers
        Write-Host "PowerCLI is configured to use Python at: $pythonPath"
    } catch {
        Write-Host "Error: Failed to set Python path for PowerCLI." -ForegroundColor Red
        exit 1
    }
}


# Restart shell (Windows)
function Restart-PowerShell {
    if (-not $IsMac) {
        Write-Host "Restarting PowerShell..."
        Start-Process powershell -ArgumentList "-NoExit", "-Command & {Set-ExecutionPolicy -Scope Process Bypass; & '$PSScriptRoot\cross_platform.ps1'}" -Wait
        exit 0
    } else {
        Write-Host "macOS: No shell restart needed."
        pwsh -NoExit -File "$PSScriptRoot/cross_platform.ps1"
    }
}

# Install Zenity and other tools
function Check-Install-Tools {
    if ($IsMac) {
        $env:PATH += ":/opt/homebrew/bin:/usr/local/bin:/opt/local/bin"
        $brewPath = (Get-Command brew -ErrorAction SilentlyContinue).Source
        if (-not $brewPath) {
            Write-Host "Homebrew not installed. Please install from https://brew.sh/" -ForegroundColor Red
            return
        }

        $zenityPath = (Get-Command zenity -ErrorAction SilentlyContinue).Source
        if (-not $zenityPath) {
            $currentUser = whoami
            $realUser = $env:SUDO_USER
            if (-not $realUser) { $realUser = $currentUser }
            try {
                & /bin/bash -c "sudo -u $realUser brew install zenity"
                Write-Host "Zenity installed." -ForegroundColor Green
            } catch {
                Write-Host "Failed to install Zenity." -ForegroundColor Red
            }
        } else {
            Write-Host "Zenity already installed." -ForegroundColor Green
        }
    }
}

# -------- MAIN --------
Check-Install-Tools
Check-PowerCLI
Check-Python
Set-PowerCLI-PythonPath
Restart-PowerShell
