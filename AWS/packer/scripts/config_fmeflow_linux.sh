#!/bin/bash
set -euxo pipefail

# Dami - FME Flow runtime configuration script for Ubuntu 24.04
# Runs at instance launch via user data to configure FME Flow
# against the environment-specific database, storage and hostname

FME_CONF_DIR="/opt/fmeflow/fmeflowconfig"

# ── Fetch values from AWS Secrets Manager ─────────────────────────────────────
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

get_secret() {
  aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$1" \
    --query SecretString \
    --output text
}

RDS_SECRET=$(get_secret "dami-fmeflow-rds-secret")
DB_HOST=$(echo "$RDS_SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['host'])")
DB_USER=$(echo "$RDS_SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
DB_PASS=$(echo "$RDS_SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

# ── External hostname from load balancer tag ───────────────────────────────────
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
EXTERNAL_HOSTNAME=$(aws ec2 describe-tags \
  --region "$REGION" \
  --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=ExternalHostname" \
  --query 'Tags[0].Value' --output text)

# ── Mount shared NFS (FSx) ────────────────────────────────────────────────────
FSX_SECRET=$(get_secret "dami-fmeflow-fsx-secret")
FSX_DNS=$(echo "$FSX_SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['dns_name'])")

mkdir -p /fmeflow-repository
mount -t nfs -o nfsvers=4.1 "${FSX_DNS}:/share/fmeflow" /fmeflow-repository

# Persist mount
echo "${FSX_DNS}:/share/fmeflow /fmeflow-repository nfs nfsvers=4.1,defaults 0 0" >> /etc/fstab

# ── Write FME Flow configuration ──────────────────────────────────────────────
cat > "${FME_CONF_DIR}/values-modified.yml" <<EOF
database:
  host: ${DB_HOST}
  port: 5432
  username: ${DB_USER}
  password: ${DB_PASS}

externalHostname: ${EXTERNAL_HOSTNAME}

repository:
  path: /fmeflow-repository
EOF

# ── Restart FME Flow ──────────────────────────────────────────────────────────
systemctl restart fmeflow

echo "==> FME Flow configuration complete"
