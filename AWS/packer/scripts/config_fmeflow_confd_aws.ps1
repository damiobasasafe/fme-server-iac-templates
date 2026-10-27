# Dami - FME Flow Core Runtime Configuration Script
# Baked into the AMI at C:\ by Packer; invoked via Windows Scheduled Task from EC2 user data
# Runs AFTER the instance has domain-joined (SSM association triggers reboot first)
#
# Parameters passed by user_data_core.tftpl:
#   -databasehostname   RDS endpoint
#   -databasePassword   RDS admin password
#   -databaseUsername   RDS admin username
#   -externalhostname   ALB DNS name
#   -storageAccountName FSx DNS name
#   -storageAccountKey  AD admin password (used to mount FSx)

param(
    [Parameter(Mandatory)][string]$databasehostname,
    [Parameter(Mandatory)][string]$databasePassword,
    [Parameter(Mandatory)][string]$databaseUsername,
    [Parameter(Mandatory)][string]$externalhostname,
    [Parameter(Mandatory)][string]$storageAccountName,
    [Parameter(Mandatory)][string]$storageAccountKey
)

$ErrorActionPreference = 'Stop'
$logFile = "C:\fme-core-config.log"

function Log {
    param([string]$msg)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Log "=== FME Flow Core Configuration Starting ==="
Log "Database host:     $databasehostname"
Log "External hostname: $externalhostname"
Log "FSx DNS:           $storageAccountName"

# ── Resolve AD domain NetBIOS name from the joined domain ─────────────────────
$domainFqdn   = (Get-WmiObject Win32_ComputerSystem).Domain
$domainNetbios = $domainFqdn.Split('.')[0].ToUpper()
Log "Domain FQDN: $domainFqdn | NetBIOS: $domainNetbios"

# ── Mount FSx share ────────────────────────────────────────────────────────────
$fsxPath = "\\$storageAccountName\share"
$adUser  = "$domainNetbios\Admin"
Log "Mounting $fsxPath as $adUser..."

$secPw = ConvertTo-SecureString $storageAccountKey -AsPlainText -Force
$cred  = New-Object System.Management.Automation.PSCredential($adUser, $secPw)

# Remove existing mapping if any
if (Test-Path "Z:\") { Remove-PSDrive -Name Z -Force -ErrorAction SilentlyContinue }
net use Z: /delete /y 2>$null

New-PSDrive -Name Z -PSProvider FileSystem -Root $fsxPath -Credential $cred -Persist
Log "FSx mounted at Z:"

# Create FME Flow repository folder on shared storage
$repoPath = "Z:\fmeflow-repository"
if (-not (Test-Path $repoPath)) {
    New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
    Log "Created repository folder: $repoPath"
}

# ── Locate FME Flow installation directory ─────────────────────────────────────
$fmeCandidates = @(
    "C:\Program Files\FMEServer",
    "C:\Program Files\FMEFlow",
    "C:\FMEServer",
    "C:\FMEFlow"
)
$fmeDir = $fmeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $fmeDir) { throw "FME Flow installation directory not found" }
Log "FME Flow directory: $fmeDir"

# ── Write FME Flow configuration ───────────────────────────────────────────────
# FME Flow 2024+ uses a YAML values override file
$configDir  = Join-Path $fmeDir "fmeflowconfig"
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

$valuesFile = Join-Path $configDir "values-modified.yml"
$config = @"
database:
  host: $databasehostname
  port: 5432
  username: $databaseUsername
  password: $databasePassword

externalHostname: $externalhostname

repository:
  path: $($repoPath -replace '\\','/')
"@

Log "Writing config to $valuesFile"
$config | Set-Content -Path $valuesFile -Encoding UTF8
Log "Config written."

# ── Enable and start FME Flow service ─────────────────────────────────────────
$serviceNames = @("FMEServer", "FMEFlow", "fmeserver", "fmeflow")
$fmeSvc = $null
foreach ($name in $serviceNames) {
    $s = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($s) { $fmeSvc = $s; break }
}

if ($fmeSvc) {
    Log "Enabling and starting service: $($fmeSvc.Name)"
    Set-Service -Name $fmeSvc.Name -StartupType Automatic
    Start-Service -Name $fmeSvc.Name
    Log "Service started."
} else {
    Log "WARNING: No FME Flow service found. Services available:"
    Get-Service | Where-Object { $_.Name -like "*fme*" } | ForEach-Object { Log "  $($_.Name)" }
}

Log "=== FME Flow Core Configuration Complete ==="
