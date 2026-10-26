#!/bin/bash
set -euxo pipefail

# Dami - FME Flow Core installer for Ubuntu 24.04
# Executed by Packer during AMI build

echo "==> Updating system packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget unzip nfs-common

# Install AWS CLI v2
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

echo "==> Downloading FME Flow installer"
INSTALLER_FILE="/tmp/fme-flow-installer.run"
curl -fsSL "$INSTALLER_URL" -o "$INSTALLER_FILE"
chmod +x "$INSTALLER_FILE"

echo "==> Installing FME Flow Core (unattended)"
"$INSTALLER_FILE" --accept --quiet --nox11

echo "==> Creating config directory"
mkdir -p /opt/fmeflow
chmod 755 /opt/fmeflow

echo "==> Enabling FME Flow service"
systemctl enable fmeflow || true

echo "==> Cleaning up installer"
rm -f "$INSTALLER_FILE"
apt-get clean

echo "==> FME Flow Core install complete"
