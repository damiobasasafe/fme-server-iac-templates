packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "installer_url" {
  type = string
}

variable "source_ami" {
  type    = string
  default = "ami-0d6dd9e8265d48906" # Ubuntu 24.04 LTS us-east-1
}

variable "tags" {
  type = map(string)
  default = {
    ManagedBy = "Dami-CICD"
    OS        = "Ubuntu-24.04"
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

# ── Core AMI ──────────────────────────────────────────────────────────────────
source "amazon-ebs" "fme_core_linux" {
  ami_name      = "dami-fme-core-linux-${local.timestamp}"
  communicator  = "ssh"
  instance_type = "m5.large"
  region        = var.region
  source_ami    = var.source_ami
  ssh_username  = "ubuntu"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 100
    volume_type           = "gp3"
    delete_on_termination = true
  }

  aws_polling {
    delay_seconds = 30
    max_attempts  = 60
  }

  tags            = merge(var.tags, { Role = "fme-core" })
  run_tags        = merge(var.tags, { Role = "fme-core" })
  run_volume_tags = merge(var.tags, { Role = "fme-core" })
  snapshot_tags   = merge(var.tags, { Role = "fme-core" })
}

# ── Engine AMI ────────────────────────────────────────────────────────────────
source "amazon-ebs" "fme_engine_linux" {
  ami_name      = "dami-fme-engine-linux-${local.timestamp}"
  communicator  = "ssh"
  instance_type = "m5.large"
  region        = var.region
  source_ami    = var.source_ami
  ssh_username  = "ubuntu"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 100
    volume_type           = "gp3"
    delete_on_termination = true
  }

  aws_polling {
    delay_seconds = 30
    max_attempts  = 60
  }

  tags            = merge(var.tags, { Role = "fme-engine" })
  run_tags        = merge(var.tags, { Role = "fme-engine" })
  run_volume_tags = merge(var.tags, { Role = "fme-engine" })
  snapshot_tags   = merge(var.tags, { Role = "fme-engine" })
}

# ── Core Build ────────────────────────────────────────────────────────────────
build {
  name    = "dami-fme-core-linux"
  sources = ["source.amazon-ebs.fme_core_linux"]

  provisioner "shell" {
    script = "scripts/install_fme_core_linux.sh"
    environment_vars = [
      "INSTALLER_URL=${var.installer_url}",
      "FME_ROLE=core"
    ]
    execute_command = "sudo -E bash '{{ .Path }}'"
  }

  provisioner "file" {
    source      = "scripts/config_fmeflow_linux.sh"
    destination = "/opt/fmeflow/config_fmeflow_linux.sh"
  }
}

# ── Engine Build ──────────────────────────────────────────────────────────────
build {
  name    = "dami-fme-engine-linux"
  sources = ["source.amazon-ebs.fme_engine_linux"]

  provisioner "shell" {
    script = "scripts/install_fme_engine_linux.sh"
    environment_vars = [
      "INSTALLER_URL=${var.installer_url}",
      "FME_ROLE=engine"
    ]
    execute_command = "sudo -E bash '{{ .Path }}'"
  }

  provisioner "file" {
    source      = "scripts/config_fmeflow_linux.sh"
    destination = "/opt/fmeflow/config_fmeflow_linux.sh"
  }
}
