packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Dynamically resolve the latest Windows Server 2022 AMI
data "amazon-ami" "windows_2022" {
  filters = {
    name                = "Windows_Server-2022-English-Full-Base-*"
    virtualization-type = "hvm"
  }
  owners      = ["amazon"]
  most_recent = true
  region      = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "installer_url" {
  type        = string
  description = "URL to the FME Flow Windows installer (.exe)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to use for Packer build instances"
}

variable "subnet_id" {
  type        = string
  description = "Public subnet ID to use for Packer build instances"
}

variable "tags" {
  type = map(string)
  default = {
    ManagedBy = "Dami-CICD"
    OS        = "Windows-Server-2022"
  }
}

locals {
  timestamp    = regex_replace(timestamp(), "[- TZ:]", "")
  winrm_password = "Dami-Packer-B00t-2026!"

  # Bootstrap user data: set known password and enable WinRM HTTP
  # EC2Launch v2 on Server 2022 runs this on first boot
  winrm_userdata = <<-EOF
    <powershell>
    net user Administrator "${local.winrm_password}"
    winrm quickconfig -q
    winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'
    winrm set winrm/config '@{MaxTimeoutms="1800000"}'
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'
    netsh advfirewall firewall add rule name="WinRM-HTTP" protocol=TCP dir=in localport=5985 action=allow
    </powershell>
  EOF
}

# ── Core Source ───────────────────────────────────────────────────────────────
source "amazon-ebs" "fme_core_windows" {
  ami_name      = "dami-fme-core-windows-${local.timestamp}"
  communicator  = "winrm"
  instance_type = "m5.large"
  region        = var.region
  source_ami    = data.amazon-ami.windows_2022.id

  vpc_id                      = var.vpc_id
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true

  winrm_username = "Administrator"
  winrm_password = local.winrm_password
  winrm_use_ssl  = false
  winrm_port     = 5985
  winrm_timeout  = "20m"

  user_data = local.winrm_userdata

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 100
    volume_type           = "gp3"
    delete_on_termination = true
  }

  aws_polling {
    delay_seconds = 30
    max_attempts  = 120
  }

  tags            = merge(var.tags, { Role = "fme-core" })
  run_tags        = merge(var.tags, { Role = "fme-core" })
  run_volume_tags = merge(var.tags, { Role = "fme-core" })
  snapshot_tags   = merge(var.tags, { Role = "fme-core" })
}

# ── Engine Source ─────────────────────────────────────────────────────────────
source "amazon-ebs" "fme_engine_windows" {
  ami_name      = "dami-fme-engine-windows-${local.timestamp}"
  communicator  = "winrm"
  instance_type = "m5.large"
  region        = var.region
  source_ami    = data.amazon-ami.windows_2022.id

  vpc_id                      = var.vpc_id
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true

  winrm_username = "Administrator"
  winrm_password = local.winrm_password
  winrm_use_ssl  = false
  winrm_port     = 5985
  winrm_timeout  = "20m"

  user_data = local.winrm_userdata

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 100
    volume_type           = "gp3"
    delete_on_termination = true
  }

  aws_polling {
    delay_seconds = 30
    max_attempts  = 120
  }

  tags            = merge(var.tags, { Role = "fme-engine" })
  run_tags        = merge(var.tags, { Role = "fme-engine" })
  run_volume_tags = merge(var.tags, { Role = "fme-engine" })
  snapshot_tags   = merge(var.tags, { Role = "fme-engine" })
}

# ── Core Build ────────────────────────────────────────────────────────────────
build {
  name    = "dami-fme-core-windows"
  sources = ["source.amazon-ebs.fme_core_windows"]

  # Install FME Flow
  provisioner "powershell" {
    script = "scripts/install_fme_core_windows.ps1"
    environment_vars = [
      "INSTALLER_URL=${var.installer_url}",
      "FME_ROLE=core"
    ]
  }

  # Bake the runtime config script into the AMI at C:\
  provisioner "file" {
    source      = "scripts/config_fmeflow_confd_aws.ps1"
    destination = "C:/config_fmeflow_confd_aws.ps1"
  }
}

# ── Engine Build ──────────────────────────────────────────────────────────────
build {
  name    = "dami-fme-engine-windows"
  sources = ["source.amazon-ebs.fme_engine_windows"]

  # Install FME Flow
  provisioner "powershell" {
    script = "scripts/install_fme_engine_windows.ps1"
    environment_vars = [
      "INSTALLER_URL=${var.installer_url}",
      "FME_ROLE=engine"
    ]
  }

  # Bake the runtime engine config script into the AMI at C:\
  provisioner "file" {
    source      = "scripts/config_fmeflow_confd_engine_aws.ps1"
    destination = "C:/config_fmeflow_confd_engine_aws.ps1"
  }
}
