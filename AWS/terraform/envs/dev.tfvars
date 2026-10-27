# Dev environment variables
owner          = "dami-cicd-dev"
region         = "us-east-1"
public_access  = "0.0.0.0/0"

# Network
vpc_name         = "dami-fmeflow-dev-vpc"
sn_name          = "dami-fmeflow-dev-subnet"
igw_name         = "dami-fmeflow-dev-igw"
eip_name         = "dami-fmeflow-dev-eip"
nat_name         = "dami-fmeflow-dev-nat"
vpc_cidr         = "10.1.0.0/16"
public_sn1_cidr  = "10.1.0.0/20"
public_sn2_cidr  = "10.1.16.0/20"
private_sn1_cidr = "10.1.128.0/20"
private_sn2_cidr = "10.1.144.0/20"

# Load balancers
alb_name = "dami-fmeflow-dev-alb"
nlb_name = "dami-fmeflow-dev-nlb"

# Active Directory
ad_name = "dev-fmeflow.safe"

# AMI IDs - populated by Packer pipeline (build #22, 2026-10-27) - Windows Server 2022
fme_core_image_id   = "ami-0d6e973bf8df479f4"
fme_engine_image_id = "ami-05b6e33e6cdc40473"

# Secrets - injected by Jenkins from AWS Secrets Manager, do not hardcode
# ad_admin_pw  = injected at runtime
# db_admin_user = injected at runtime
# db_admin_pw  = injected at runtime
