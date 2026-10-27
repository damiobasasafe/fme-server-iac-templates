# Dami - FME Flow Engine Windows Install Script
# Runs during Packer AMI build on Windows Server 2022
# Downloads and silently installs FME Flow engine, leaves services disabled for runtime config

$ErrorActionPreference = 'Stop'

function Log { param([string]$msg) Write-Host "$(Get-Date -Format 'HH:mm:ss') [ENGINE] $msg" }

Log "=== FME Flow Engine Windows Install ==="
Log "Installer URL: $env:INSTALLER_URL"

# ── Disable IE Enhanced Security ───────────────────────────────────────────────
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name IsInstalled -Value 0 -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name IsInstalled -Value 0 -ErrorAction SilentlyContinue

# ── Download installer ─────────────────────────────────────────────────────────
$installer = "C:\fme-flow-installer.exe"
Log "Downloading installer..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $env:INSTALLER_URL -OutFile $installer -UseBasicParsing
Log "Download complete. Size: $((Get-Item $installer).Length / 1MB -as [int]) MB"

# ── Silent install ─────────────────────────────────────────────────────────────
Log "Running silent install (role=Engine)..."
$proc = Start-Process -FilePath $installer -ArgumentList "/S /ROLE=Engine" -Wait -PassThru -NoNewWindow
Log "Installer exit code: $($proc.ExitCode)"

if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
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

# ── Disable FME services ───────────────────────────────────────────────────────
Log "Disabling FME services until runtime configuration..."
$serviceNames = @("FMEServer", "FMEFlow", "fmeflow", "fmeserver", "FMEServerEngine", "FMEFlowEngine")
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

Log "=== FME Flow Engine Windows Install Complete ==="
