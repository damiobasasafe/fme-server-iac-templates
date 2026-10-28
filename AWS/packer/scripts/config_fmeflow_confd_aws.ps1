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

# ── Update FME Flow database config to point at RDS ───────────────────────────
# FME Flow stores its DB connection in fmeDatabaseConfig.txt under the Server dir.
# The default install points at localhost:7082 (embedded PG). We replace that
# with the RDS endpoint so FME Flow uses the shared persistent database.
$dbConfigPath = Join-Path $fmeDir "Server\fmeDatabaseConfig.txt"
if (Test-Path $dbConfigPath) {
    Log "Updating database config: $dbConfigPath"
    $dbConfig = Get-Content $dbConfigPath -Raw
    $dbConfig = $dbConfig -replace 'DB_JDBC_URL=jdbc:postgresql://[^\r\n]+', "DB_JDBC_URL=jdbc:postgresql://${databasehostname}:5432/fmeflow"
    $dbConfig = $dbConfig -replace 'DB_USERNAME=[^\r\n]+',                   "DB_USERNAME=$databaseUsername"
    $dbConfig = $dbConfig -replace 'DB_PASSWORD=[^\r\n]+',                   "DB_PASSWORD=$databasePassword"
    Set-Content -Path $dbConfigPath -Value $dbConfig -Encoding UTF8
    Log "Database config updated to RDS endpoint: $databasehostname"
} else {
    Log "WARNING: fmeDatabaseConfig.txt not found at $dbConfigPath — skipping DB config update"
}

# ── Update external hostname in FME Flow web config ───────────────────────────
$webConfigPath = Join-Path $fmeDir "Server\fmeFlowWebApplicationConfig.txt"
if (Test-Path $webConfigPath) {
    Log "Updating web application config: $webConfigPath"
    $webConfig = Get-Content $webConfigPath -Raw
    $webConfig = $webConfig -replace 'EXTERNALHOSTNAME=[^\r\n]*', "EXTERNALHOSTNAME=$externalhostname"
    Set-Content -Path $webConfigPath -Value $webConfig -Encoding UTF8
    Log "External hostname set to: $externalhostname"
}

# ── Open Windows Firewall ports for FME Flow and ALB health checks ─────────────
Log "Opening Windows Firewall ports for FME Flow..."
$fwRules = @(
    @{ Name = "FME Flow HTTP";      Port = 80   },
    @{ Name = "FME Flow WebSocket"; Port = 7078 },
    @{ Name = "FME Flow Engine Reg";Port = 7070 },
    @{ Name = "FME Flow Engine HC"; Port = 7082 }
)
foreach ($rule in $fwRules) {
    New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -Protocol TCP `
        -LocalPort $rule.Port -Action Allow -ErrorAction SilentlyContinue | Out-Null
    Log "Firewall: opened port $($rule.Port) ($($rule.Name))"
}

# ── Write shared encryption key from SSM ──────────────────────────────────────
# FME Flow encrypts named connection passwords with fme_flow_key.jceks.
# Each fresh install generates a unique key, so cross-environment project
# promotion fails if the keys differ ("cannot find key to decrypt" error).
# We write the shared key from SSM before services start so FME Flow picks
# it up on first launch. All environments that need to import DEV projects
# must have the same key — it is stored at /fmeflow/shared/encryption-key.
$keyParam = "/fmeflow/shared/encryption-key"
try {
    $region   = (Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/placement/region" -UseBasicParsing).Trim()
    $keyB64   = (Get-SSMParameter -Name $keyParam -WithDecryption $true -Region $region).Value.Trim()
    $keyBytes = [System.Convert]::FromBase64String($keyB64)
    $keyDir   = "C:\ProgramData\Safe Software\FMEFlow\key"
    if (-not (Test-Path $keyDir)) { New-Item -ItemType Directory -Path $keyDir -Force | Out-Null }
    $keyFile  = Join-Path $keyDir "fme_flow_key.jceks"
    [System.IO.File]::WriteAllBytes($keyFile, $keyBytes)
    Log "Encryption key written from SSM ($keyParam) — $($keyBytes.Length) bytes"
} catch {
    Log "WARNING: Could not write encryption key from SSM ($keyParam): $_"
    Log "FME Flow will generate its own key. Cross-environment project promotion"
    Log "will fail if named connections have stored passwords — re-enter them manually after import."
}

# ── Enable and start FME Flow services ────────────────────────────────────────
Log "Enabling and starting FME Flow services..."
$serviceOrder = @("FME Flow Database", "FME Flow Core", "FMEFlowAppServer", "FME Flow Engines")
foreach ($svcName in $serviceOrder) {
    $s = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($s) {
        Log "Starting service: $($s.Name)"
        Set-Service  -Name $s.Name -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name $s.Name -ErrorAction SilentlyContinue
    }
}

# Verify services are running
Start-Sleep -Seconds 15
Log "Service status after start:"
Get-Service | Where-Object { $_.Name -like "*fme*" } | ForEach-Object {
    Log "  $($_.Name) -> $($_.Status)"
}

# ── Verify FME Flow health endpoint is responding ──────────────────────────────
Log "Waiting for FME Flow to become healthy..."
$maxAttempts = 20
$attempt = 0
$healthy = $false
while ($attempt -lt $maxAttempts -and -not $healthy) {
    $attempt++
    try {
        $r = Invoke-WebRequest -Uri "http://localhost/fmeapiv4/healthcheck/liveness" -UseBasicParsing -TimeoutSec 10
        if ($r.StatusCode -eq 200) {
            $healthy = $true
            Log "FME Flow is healthy (attempt $attempt)"
        }
    } catch {
        Log "Attempt $attempt: not ready yet - $($_.Exception.Message)"
        Start-Sleep -Seconds 15
    }
}

if (-not $healthy) {
    Log "WARNING: FME Flow did not become healthy within expected time. Check service logs."
} else {
    Log "FME Flow is up and responding."
}

Log "=== FME Flow Core Configuration Complete ==="
