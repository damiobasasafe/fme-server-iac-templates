# Dami - FME Flow Core Windows Install Script
# Runs during Packer AMI build on Windows Server 2022
# Downloads and silently installs FME Flow, leaves services disabled for runtime config

$ErrorActionPreference = 'Stop'

function Log { param([string]$msg) Write-Host "$(Get-Date -Format 'HH:mm:ss') [CORE] $msg" }

Log "=== FME Flow Core Windows Install ==="
Log "Installer URL: $env:INSTALLER_URL"

# ── Disable IE Enhanced Security (allows Invoke-WebRequest to work) ───────────
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name IsInstalled -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name IsInstalled -Value 0 -ErrorAction SilentlyContinue

# ── Download installer ─────────────────────────────────────────────────────────
$installer = "C:\fme-flow-installer.exe"
Log "Downloading installer..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $env:INSTALLER_URL -OutFile $installer -UseBasicParsing
Log "Download complete. Size: $((Get-Item $installer).Length / 1MB -as [int]) MB"

# ── Silent install ─────────────────────────────────────────────────────────────
# FME Flow Windows uses NSIS installer; /S = silent, /ROLE=Core for distributed
Log "Running silent install (role=Core)..."
$proc = Start-Process -FilePath $installer -ArgumentList "/S /ROLE=Core" -Wait -PassThru -NoNewWindow
Log "Installer exit code: $($proc.ExitCode)"

if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    # 3010 = success, reboot required - acceptable for AMI build
    Log "WARNING: Unexpected exit code $($proc.ExitCode). Checking if FME Flow installed anyway..."
}

# ── Verify installation ────────────────────────────────────────────────────────
$fmePaths = @(
    "C:\Program Files\FMEServer",
    "C:\Program Files\FMEFlow",
    "C:\FMEServer",
    "C:\FMEFlow"
)

$fmeDir = $null
foreach ($path in $fmePaths) {
    if (Test-Path $path) {
        $fmeDir = $path
        Log "FME Flow found at: $fmeDir"
        break
    }
}

if (-not $fmeDir) {
    throw "FME Flow installation directory not found. Install likely failed."
}

# ── Disable FME services (configured at runtime, not at AMI bake time) ────────
Log "Disabling FME services until runtime configuration..."
$serviceNames = @("FMEServer", "FMEFlow", "fmeflow", "fmeserver", "FME Server", "FME Flow")
foreach ($svc in $serviceNames) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) {
        Log "Disabling service: $($s.Name)"
        Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue
    }
}

# ── Cleanup ────────────────────────────────────────────────────────────────────
Log "Cleaning up installer..."
Remove-Item -Path $installer -Force -ErrorAction SilentlyContinue

# ── Reset EC2Launch state so user data runs on first instance boot ─────────────
# Without this, EC2Launch sees the .run-once marker left from the Packer build
# and skips user data entirely when new instances launch from this AMI.
Log "Resetting EC2Launch state for clean first-boot on instance launch..."
$ec2LaunchBin = "C:\ProgramData\Amazon\EC2Launch\bin\EC2Launch.exe"
if (Test-Path $ec2LaunchBin) {
    & $ec2LaunchBin reset --block
    Log "EC2Launch reset complete."
} else {
    Log "WARNING: EC2Launch binary not found at expected path, skipping reset."
}

Log "=== FME Flow Core Windows Install Complete ==="
