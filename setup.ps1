# CST Studio Suite - AWS EC2 Setup Script
# 
# This script sets up a Windows EC2 instance for running CST simulations.
# Supports CPU instances (c5) and GPU instances (g4dn with T4, g5 with A10G).
# 
# Usage:
#   1. Launch a Windows Server 2022 EC2 instance
#   2. RDP into the instance
#   3. Open PowerShell as Administrator
#   4. If the repo is private, set a GitHub token in the session (don't hardcode it):
#        $env:GITHUB_TOKEN = "<your_token_here>"
#        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/henryczup/cst-aws-setup/main/setup.ps1" `
#          -Headers @{ Authorization = "token $env:GITHUB_TOKEN" } `
#          -OutFile C:\setup.ps1
#        C:\setup.ps1
#   5. Otherwise (public repo), run:
#        Set-ExecutionPolicy Bypass -Scope Process -Force
#        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/henryczup/cst-aws-setup/main/setup.ps1" -OutFile C:\setup.ps1
#        C:\setup.ps1
#
# Requirements:
#   - UW Madison credentials (for VPN and CST license)
#   - AWS credentials (Access Key ID and Secret Access Key)

param(
    [string]$S3Bucket = "s3://inverse-design-antenna-jobs",
    [string]$VPNPortal = "engr-split.vpn.wisc.edu",
    [string]$LicenseServer = "27001@license2.ece.wisc.edu"
)

$ErrorActionPreference = "Stop"

# Ensure modern TLS for downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  CST Studio Suite - AWS Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Detect GPU instance (supports both IMDSv1 and IMDSv2)
function Get-EC2InstanceType {
    try {
        # Try IMDSv2 first (requires token)
        $token = Invoke-RestMethod -Uri "http://169.254.169.254/latest/api/token" `
            -Method PUT `
            -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "21600"} `
            -TimeoutSec 2 `
            -ErrorAction Stop
        
        $instanceType = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-type" `
            -Headers @{"X-aws-ec2-metadata-token" = $token} `
            -TimeoutSec 2
        
        return $instanceType
    } catch {
        try {
            # Fall back to IMDSv1
            $instanceType = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-type" -TimeoutSec 2
            return $instanceType
        } catch {
            return $null
        }
    }
}

$instanceType = Get-EC2InstanceType
$isGPUInstance = $instanceType -match "^(g[0-9]+|p[0-9]+)"

if ($instanceType) {
    Write-Host "Instance Type: $instanceType" -ForegroundColor Cyan
    if ($isGPUInstance) {
        Write-Host "GPU Detected! Will install NVIDIA drivers." -ForegroundColor Magenta
    }
    Write-Host ""
} else {
    Write-Host "Could not detect instance type from EC2 metadata" -ForegroundColor Yellow
    Write-Host ""
}

# Step 1: Install Chocolatey (package manager)
Write-Host "[1/11] Installing Chocolatey..." -ForegroundColor Yellow
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already installed." -ForegroundColor Green
}

# Step 2: Install Git for Windows
Write-Host "[2/11] Installing Git for Windows..." -ForegroundColor Yellow
if (!(Test-Path "C:\Program Files\Git\bin\git.exe")) {
    choco install git -y --no-progress
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already installed." -ForegroundColor Green
}

# Step 3: Install Google Chrome
Write-Host "[3/11] Installing Google Chrome..." -ForegroundColor Yellow
if (!(Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe")) {
    choco install googlechrome -y --no-progress --ignore-checksums --force
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already installed." -ForegroundColor Green
}

# Step 4: Install AWS CLI
Write-Host "[4/11] Installing AWS CLI..." -ForegroundColor Yellow
$awsInstaller = "$env:TEMP\AWSCLIV2.msi"
if (!(Test-Path "C:\Program Files\Amazon\AWSCLIV2\aws.exe")) {
    Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $awsInstaller
    Start-Process msiexec.exe -ArgumentList "/i", $awsInstaller, "/quiet" -Wait
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already installed." -ForegroundColor Green
}

# Step 5: Install Python 3.9
Write-Host ""
Write-Host "[5/11] Installing Python 3.9..." -ForegroundColor Yellow
if (!(Get-Command python -ErrorAction SilentlyContinue) -or !((python --version 2>&1) -match "3\.9")) {
    choco install python39 -y --no-progress
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already installed." -ForegroundColor Green
}

# Step 6: Configure AWS
Write-Host ""
Write-Host "[6/11] Configuring AWS credentials..." -ForegroundColor Yellow
Write-Host "  Enter your AWS credentials when prompted:" -ForegroundColor White
Write-Host ""
& "C:\Program Files\Amazon\AWSCLIV2\aws.exe" configure

# Step 7: Install NVIDIA GPU Drivers (if GPU instance)
Write-Host ""
Write-Host "[7/11] GPU Driver Setup..." -ForegroundColor Yellow
if ($isGPUInstance) {
    # Check if NVIDIA driver is already installed
    $nvidiaInstalled = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" }
    
    if ($nvidiaInstalled) {
        Write-Host "  NVIDIA driver already installed: $($nvidiaInstalled.Name)" -ForegroundColor Green
    } else {
        Write-Host "  Downloading NVIDIA GRID drivers for AWS GPU instances..." -ForegroundColor Gray
        Write-Host "  (This may take a few minutes)" -ForegroundColor Gray
        
        # Create driver directory
        $driverDir = "C:\NVIDIA_Drivers"
        New-Item -ItemType Directory -Path $driverDir -Force | Out-Null
        
        # Download NVIDIA GRID drivers from AWS S3 bucket
        # AWS provides pre-packaged drivers for GPU instances
        & "C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 cp --recursive "s3://ec2-windows-nvidia-drivers/latest/" $driverDir
        
        # Find and run the driver installer
        $driverExe = Get-ChildItem -Path $driverDir -Filter "*.exe" -Recurse | Select-Object -First 1
        
        if ($driverExe) {
            Write-Host "  Installing NVIDIA driver: $($driverExe.Name)" -ForegroundColor Gray
            Write-Host "  This will take several minutes..." -ForegroundColor Gray
            
            # Silent install with reboot suppressed
            Start-Process -FilePath $driverExe.FullName -ArgumentList "/s", "/n" -Wait
            
            Write-Host "  NVIDIA driver installed!" -ForegroundColor Green
            Write-Host ""
            Write-Host "  *** IMPORTANT: A REBOOT IS REQUIRED ***" -ForegroundColor Red
            Write-Host "  After setup completes, restart the instance for GPU to work." -ForegroundColor Red
            $global:needsReboot = $true
        } else {
            Write-Host "  WARNING: Could not find NVIDIA driver installer" -ForegroundColor Yellow
            Write-Host "  You may need to install drivers manually from:" -ForegroundColor Yellow
            Write-Host "  https://www.nvidia.com/Download/index.aspx" -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "  Skipped (not a GPU instance)" -ForegroundColor Gray
}

# Step 8: Install WebView2 Runtime (required for GlobalProtect)
Write-Host ""
Write-Host "[8/11] Installing WebView2 Runtime..." -ForegroundColor Yellow
$webview2Installer = "$env:TEMP\MicrosoftEdgeWebview2Setup.exe"
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $webview2Installer
Start-Process -FilePath $webview2Installer -Args "/silent /install" -Wait
Write-Host "  Done." -ForegroundColor Green

# Step 9: Install GlobalProtect VPN
Write-Host ""
Write-Host "[9/11] Installing GlobalProtect VPN..." -ForegroundColor Yellow
$gpInstaller = "$env:TEMP\globalprotect.msi"
& "C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 cp "$S3Bucket/installers/globalprotect.msi" $gpInstaller
Start-Process msiexec.exe -ArgumentList "/i", $gpInstaller, "/quiet" -Wait
Write-Host "  Done." -ForegroundColor Green

# Step 10: Download CST Installer
Write-Host ""
Write-Host "[10/11] Downloading CST Studio Suite (~8.5 GB)..." -ForegroundColor Yellow
Write-Host "  This will take several minutes..." -ForegroundColor Gray
$cstZip = "C:\CST_Installer.zip"
$cstDir = "C:\CST_Installer"
if (!(Test-Path $cstDir)) {
    & "C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 cp "$S3Bucket/installers/CST_S2_2025.CST_S2_2025.SIMULIA_CST_Studio_Suite.Windows64.zip" $cstZip
    Write-Host "  Extracting (this takes a few minutes)..." -ForegroundColor Gray
    Expand-Archive -Path $cstZip -DestinationPath $cstDir -Force
    Remove-Item $cstZip -Force
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already downloaded." -ForegroundColor Green
}

# Step 11: Launch CST Installer
$cstSetup = "C:\CST_Installer\SIMULIA_CST_Studio_Suite.Windows64\setup.exe"
Write-Host ""
Write-Host "[11/11] Launching CST installer..." -ForegroundColor Yellow
if (Test-Path $cstSetup) {
    Write-Host "  Running: $cstSetup" -ForegroundColor Gray
    Start-Process -FilePath $cstSetup -Wait
    Write-Host "  Installer finished (check above for any prompts)." -ForegroundColor Green
} else {
    Write-Host "  Installer not found at $cstSetup. Please verify the download/extract step." -ForegroundColor Red
}

# Done!
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

if ($global:needsReboot) {
    Write-Host "*** REBOOT REQUIRED FOR GPU DRIVERS ***" -ForegroundColor Red
    Write-Host "Run this command to reboot now:" -ForegroundColor Yellow
    Write-Host "  Restart-Computer -Force" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "After reboot, reconnect via RDP and continue with VPN setup." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. CONNECT TO VPN" -ForegroundColor White
Write-Host "   - Open GlobalProtect from Start Menu" -ForegroundColor Gray
Write-Host "   - Portal: $VPNPortal" -ForegroundColor Gray
Write-Host "   - Login with your UW credentials" -ForegroundColor Gray
Write-Host ""

if ($isGPUInstance) {
    Write-Host "2. VERIFY GPU IN CST" -ForegroundColor White
    Write-Host "   - Open CST Studio Suite" -ForegroundColor Gray
    Write-Host "   - Go to: Simulation > Solver > GPU Computing" -ForegroundColor Gray
    Write-Host "   - Your GPU should appear (T4 for g4dn, A10G for g5)" -ForegroundColor Gray
    Write-Host "   - Enable GPU acceleration for supported solvers" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. RUN CST WITH GPU" -ForegroundColor White
    Write-Host "   - Transient/Time Domain solver supports GPU acceleration" -ForegroundColor Gray
    Write-Host "   - Frequency Domain solver supports GPU acceleration" -ForegroundColor Gray
    Write-Host "   - Check 'Use hardware acceleration' in solver settings" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. STOP INSTANCE WHEN DONE" -ForegroundColor Red
    Write-Host "   - AWS Console -> EC2 -> Actions -> Stop instance" -ForegroundColor Gray
    Write-Host "   - g5.xlarge costs ~`$1.01/hour - don't forget to stop!" -ForegroundColor Gray
} else {
    Write-Host "2. RUN CST" -ForegroundColor White
    Write-Host "   - Open CST Studio Suite from Start Menu" -ForegroundColor Gray
    Write-Host "   - Open your project files" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. STOP INSTANCE WHEN DONE" -ForegroundColor Red
    Write-Host "   - AWS Console -> EC2 -> Actions -> Stop instance" -ForegroundColor Gray
    Write-Host "   - c5.4xlarge costs ~`$0.68/hour" -ForegroundColor Gray
}
Write-Host ""

# Offer to verify GPU if installed
if ($isGPUInstance -and !$global:needsReboot) {
    Write-Host "Checking GPU status..." -ForegroundColor Yellow
    $gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" }
    if ($gpu) {
        Write-Host "  GPU detected: $($gpu.Name)" -ForegroundColor Green
        
        # Try to run nvidia-smi if available
        $nvidiaSmi = "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
        if (Test-Path $nvidiaSmi) {
            Write-Host ""
            Write-Host "GPU Details:" -ForegroundColor Cyan
            & $nvidiaSmi
        }
    } else {
        Write-Host "  GPU not detected yet. Please reboot first." -ForegroundColor Yellow
    }
}
