# CST Studio Suite - AWS EC2 Setup Script
# 
# This script sets up a Windows EC2 instance for running CST simulations.
# 
# Usage:
#   1. Launch a Windows Server 2022 EC2 instance
#   2. RDP into the instance
#   3. Open PowerShell as Administrator
#   4. If the repo is private, set a GitHub token in the session (don’t hardcode it):
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

# Step 1: Install Chocolatey (package manager)
Write-Host "[1/10] Installing Chocolatey..." -ForegroundColor Yellow
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already installed." -ForegroundColor Green
}

# Step 2: Install Git for Windows
Write-Host "[2/10] Installing Git for Windows..." -ForegroundColor Yellow
if (!(Test-Path "C:\Program Files\Git\bin\git.exe")) {
    choco install git -y --no-progress
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already installed." -ForegroundColor Green
}

# Step 3: Install Google Chrome
Write-Host "[3/10] Installing Google Chrome..." -ForegroundColor Yellow
if (!(Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe")) {
    choco install googlechrome -y --no-progress --ignore-checksums
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already installed." -ForegroundColor Green
}

# Step 4: Install AWS CLI
Write-Host "[4/10] Installing AWS CLI..." -ForegroundColor Yellow
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
Write-Host "[5/10] Installing Python 3.9..." -ForegroundColor Yellow
if (!(Get-Command python -ErrorAction SilentlyContinue) -or !((python --version 2>&1) -match "3\.9")) {
    choco install python39 -y --no-progress
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already installed." -ForegroundColor Green
}

# Step 6: Configure AWS
Write-Host ""
Write-Host "[6/10] Configuring AWS credentials..." -ForegroundColor Yellow
Write-Host "  Enter your AWS credentials when prompted:" -ForegroundColor White
Write-Host ""
& "C:\Program Files\Amazon\AWSCLIV2\aws.exe" configure

# Step 7: Install WebView2 Runtime (required for GlobalProtect)
Write-Host ""
Write-Host "[7/10] Installing WebView2 Runtime..." -ForegroundColor Yellow
$webview2Installer = "$env:TEMP\MicrosoftEdgeWebview2Setup.exe"
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $webview2Installer
Start-Process -FilePath $webview2Installer -Args "/silent /install" -Wait
Write-Host "  Done." -ForegroundColor Green

# Step 8: Install GlobalProtect VPN
Write-Host ""
Write-Host "[8/10] Installing GlobalProtect VPN..." -ForegroundColor Yellow
$gpInstaller = "$env:TEMP\globalprotect.msi"
& "C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 cp "$S3Bucket/installers/globalprotect.msi" $gpInstaller
Start-Process msiexec.exe -ArgumentList "/i", $gpInstaller, "/quiet" -Wait
Write-Host "  Done." -ForegroundColor Green

# Step 9: Download CST Installer
Write-Host ""
Write-Host "[9/10] Downloading CST Studio Suite (~8.5 GB)..." -ForegroundColor Yellow
Write-Host "  This will take several minutes..." -ForegroundColor Gray
$cstZip = "C:\CST_Installer.zip"
$cstDir = "C:\CST_Installer"
if (!(Test-Path $cstDir)) {
    & "C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 cp "$S3Bucket/installers/CST_S2_2022.CST_S2_2022.SIMULIA_CST_Studio_Suite.Windows64.zip" $cstZip
    Write-Host "  Extracting (this takes a few minutes)..." -ForegroundColor Gray
    Expand-Archive -Path $cstZip -DestinationPath $cstDir -Force
    Remove-Item $cstZip -Force
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already downloaded." -ForegroundColor Green
}

# Step 10: Launch CST Installer
$cstSetup = "C:\CST_Installer\SIMULIA_CST_Studio_Suite.Windows64\setup.exe"
Write-Host ""
Write-Host "[10/10] Launching CST installer..." -ForegroundColor Yellow
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
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. CONNECT TO VPN" -ForegroundColor White
Write-Host "   - Open GlobalProtect from Start Menu" -ForegroundColor Gray
Write-Host "   - Portal: $VPNPortal" -ForegroundColor Gray
Write-Host "   - Login with your UW credentials" -ForegroundColor Gray
Write-Host ""
Write-Host "2. RUN CST" -ForegroundColor White
Write-Host "   - Open CST Studio Suite from Start Menu" -ForegroundColor Gray
Write-Host "   - Open your project files" -ForegroundColor Gray
Write-Host ""
Write-Host "3. STOP INSTANCE WHEN DONE" -ForegroundColor Red
Write-Host "   - AWS Console -> EC2 -> Actions -> Stop instance" -ForegroundColor Gray
Write-Host "   - This stops billing (~`$0.68/hour for c5.4xlarge)" -ForegroundColor Gray
Write-Host ""
