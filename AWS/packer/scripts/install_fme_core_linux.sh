#!/bin/bash
set -euxo pipefail

# Dami - FME Flow Core installer for Ubuntu 24.04
# Executed by Packer during AMI build

echo "==> Updating system packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget unzip nfs-common awscli

echo "==> Downloading FME Flow installer"
INSTALLER_FILE="/tmp/fme-flow-installer.run"
curl -fsSL "$INSTALLER_URL" -o "$INSTALLER_FILE"
chmod +x "$INSTALLER_FILE"

echo "==> Installing FME Flow Core (unattended)"
"$INSTALLER_FILE" \
  --mode unattended \
  --fmeflow_role core \
  --acceptLicense yes

echo "==> Creating config directory"
mkdir -p /opt/fmeflow
chmod 755 /opt/fmeflow

echo "==> Enabling FME Flow service"
systemctl enable fmeflow || true

echo "==> Cleaning up installer"
rm -f "$INSTALLER_FILE"
apt-get clean

echo "==> FME Flow Core install complete"
