# CST Studio Suite on AWS

Run CST Studio Suite simulations on AWS EC2 with UW Madison license.

## Prerequisites

- AWS account
- UW Madison credentials (NetID) for VPN and CST license

## Quick Start

### 1. Launch EC2 Instance

1. Go to [AWS EC2 Console](https://console.aws.amazon.com/ec2)
2. Click **Launch Instance**
3. Configure:
   - **Name**: `cst-workstation`
   - **AMI**: Windows Server 2019 Base
   - **Instance type**: `c5.4xlarge` (16 vCPU, recommended) or `c5.2xlarge` (8 vCPU, cheaper)
   - **Key pair**: Create new or select existing (you'll need this for RDP password)
   - **Security group**: Create new, allow **RDP (port 3389)** from "My IP"
   - **Storage**: 100 GB gp3
4. Click **Launch Instance**
5. Wait 4-5 minutes for Windows to initialize

### 2. Connect via Remote Desktop

1. In EC2 Console, select your instance
2. Click **Connect** → **RDP client** tab
3. Click **Get password** → Upload your `.pem` key file → **Decrypt password**
4. Note the **Public DNS** and **Password**
5. Open Remote Desktop:
   - **Windows**: Search for "Remote Desktop Connection"
   - **Mac**: Install "Microsoft Remote Desktop" from App Store
6. Connect:
   - **Computer**: Public DNS (or Public IP)
   - **Username**: `Administrator`
   - **Password**: (decrypted password)

### 3. Run Setup Script

Once connected via RDP, open **PowerShell as Administrator**:

**If the repo is private (GitHub token required):**

1. Create a **fine-grained personal access token** at <https://github.com/settings/tokens?type=beta> with at least **Contents: Read-only** for this repo.
2. On the EC2 instance, set the token in the session (don’t hardcode it in scripts):

```powershell
$env:GITHUB_TOKEN = "<your_token_here>"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/henryczup/cst-aws-setup/main/setup.ps1" `
  -Headers @{ Authorization = "token $env:GITHUB_TOKEN" } `
  -OutFile C:\setup.ps1
C:\setup.ps1
```

Tip: Clear the variable when done: `Remove-Item Env:\GITHUB_TOKEN`.

**If the repo is public:** skip the token and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/henryczup/cst-aws-setup/main/setup.ps1" -OutFile C:\setup.ps1

C:\setup.ps1
```

Enter your AWS credentials when prompted.

### 4. Connect VPN

1. Open **GlobalProtect** from Start Menu
2. Portal: `engr-split.vpn.wisc.edu`
3. Login with your UW NetID and password
4. Wait for "Connected" status

### 5. Install CST

Run in PowerShell:

```powershell
C:\CST_Installer\SIMULIA_CST_Studio_Suite.Windows64\setup.exe
```

During installation:
- License type: **FlexNet**
- License server: `27001@license2.ece.wisc.edu`

### 6. Use CST

- Open **CST Studio Suite** from Start Menu
- Transfer your project files via:
  - Copy/paste through RDP
  - Upload to S3 and download: `aws s3 cp s3://bucket/file.cst C:\`
  - Use OneDrive/Google Drive

### 7. Stop Instance When Done

**Important!** Stop the instance to avoid charges:

1. AWS Console → EC2 → Instances
2. Select your instance
3. **Instance state** → **Stop instance**

## Resume Later

1. AWS Console → EC2 → Select your stopped instance
2. **Instance state** → **Start instance**
3. Wait 2 minutes
4. Get the **new Public IP** (it changes after restart)
5. RDP in with the **same password**
6. Connect VPN (GlobalProtect)
7. Use CST

## Costs

| Instance Type | vCPU | RAM | $/Hour |
|---------------|------|-----|--------|
| c5.xlarge | 4 | 8 GB | $0.17 |
| c5.2xlarge | 8 | 16 GB | $0.34 |
| c5.4xlarge | 16 | 32 GB | $0.68 |
| Stopped | - | - | ~$0.01/hr (storage only) |

**Tips:**
- Stop instance when not using it
- Use Spot Instances for 60-90% savings (may be interrupted)
- Delete instance completely when project is done

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Can't connect via RDP | Wait 5 min after launch; check security group allows your IP |
| GlobalProtect won't connect | Make sure WebView2 is installed (setup script does this) |
| CST license error | VPN must be connected; verify license server address |
| Slow performance | Use larger instance type (c5.4xlarge or c5.9xlarge) |

## Files in S3

The setup script downloads from:
```
s3://inverse-design-antenna-jobs/installers/
├── globalprotect.msi
└── CST_S2_2022...Windows64.zip
```

Contact Henry if you need AWS credentials or S3 access.
