# CST Studio Suite - AWS EC2 Setup Script
# 
# This script sets up a Windows EC2 instance for running CST simulations.
# 
# Usage:
#   1. Launch a Windows Server 2022 EC2 instance
#   2. RDP into the instance
#   3. Open PowerShell as Administrator
#   4. Run: Set-ExecutionPolicy Bypass -Scope Process -Force
#   5. Run: .\setup.ps1
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

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  CST Studio Suite - AWS Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Install AWS CLI
Write-Host "[1/5] Installing AWS CLI..." -ForegroundColor Yellow
$awsInstaller = "$env:TEMP\AWSCLIV2.msi"
if (!(Test-Path "C:\Program Files\Amazon\AWSCLIV2\aws.exe")) {
    Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $awsInstaller
    Start-Process msiexec.exe -ArgumentList "/i", $awsInstaller, "/quiet" -Wait
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Done." -ForegroundColor Green
} else {
    Write-Host "  Already installed." -ForegroundColor Green
}

# Step 2: Configure AWS
Write-Host ""
Write-Host "[2/5] Configuring AWS credentials..." -ForegroundColor Yellow
Write-Host "  Enter your AWS credentials when prompted:" -ForegroundColor White
Write-Host ""
& "C:\Program Files\Amazon\AWSCLIV2\aws.exe" configure

# Step 3: Install WebView2 Runtime (required for GlobalProtect)
Write-Host ""
Write-Host "[3/5] Installing WebView2 Runtime..." -ForegroundColor Yellow
$webview2Installer = "$env:TEMP\MicrosoftEdgeWebview2Setup.exe"
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $webview2Installer
Start-Process -FilePath $webview2Installer -Args "/silent /install" -Wait
Write-Host "  Done." -ForegroundColor Green

# Step 4: Install GlobalProtect VPN
Write-Host ""
Write-Host "[4/5] Installing GlobalProtect VPN..." -ForegroundColor Yellow
$gpInstaller = "$env:TEMP\globalprotect.msi"
& "C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 cp "$S3Bucket/installers/globalprotect.msi" $gpInstaller
Start-Process msiexec.exe -ArgumentList "/i", $gpInstaller, "/quiet" -Wait
Write-Host "  Done." -ForegroundColor Green

# Step 5: Download CST Installer
Write-Host ""
Write-Host "[5/5] Downloading CST Studio Suite (~8.5 GB)..." -ForegroundColor Yellow
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
Write-Host "2. INSTALL CST" -ForegroundColor White
Write-Host "   - Run this command:" -ForegroundColor Gray
Write-Host "     C:\CST_Installer\SIMULIA_CST_Studio_Suite.Windows64\setup.exe" -ForegroundColor Cyan
Write-Host "   - License type: FlexNet" -ForegroundColor Gray
Write-Host "   - License server: $LicenseServer" -ForegroundColor Gray
Write-Host ""
Write-Host "3. RUN CST" -ForegroundColor White
Write-Host "   - Open CST Studio Suite from Start Menu" -ForegroundColor Gray
Write-Host "   - Open your project files" -ForegroundColor Gray
Write-Host ""
Write-Host "4. STOP INSTANCE WHEN DONE" -ForegroundColor Red
Write-Host "   - AWS Console -> EC2 -> Actions -> Stop instance" -ForegroundColor Gray
Write-Host "   - This stops billing (~`$0.68/hour for c5.4xlarge)" -ForegroundColor Gray
Write-Host ""
