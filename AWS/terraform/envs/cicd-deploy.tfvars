# CICD-deploy environment variables
# Clean deployment for demo — all resources prefixed with cicd-deploy
owner          = "cicd-deploy"
region         = "us-east-1"
public_access  = "0.0.0.0/0"

# Network
vpc_name         = "cicd-deploy-vpc"
sn_name          = "cicd-deploy-subnet"
igw_name         = "cicd-deploy-igw"
eip_name         = "cicd-deploy-eip"
nat_name         = "cicd-deploy-nat"
vpc_cidr         = "10.2.0.0/16"
public_sn1_cidr  = "10.2.0.0/20"
public_sn2_cidr  = "10.2.16.0/20"
private_sn1_cidr = "10.2.128.0/20"
private_sn2_cidr = "10.2.144.0/20"

# Load balancers
alb_name = "cicd-deploy-alb"
nlb_name = "cicd-deploy-nlb"

# Active Directory
ad_name = "cicd-deploy.safe"

# AMI IDs - populated by Build 1 (Packer pipeline), leave blank to trigger error
# fme_core_image_id   = ""  <- injected by Jenkins from Packer output
# fme_engine_image_id = ""  <- injected by Jenkins from Packer output

# Secrets - injected by Jenkins at runtime, never hardcoded here
# ad_admin_pw   = injected at runtime
# db_admin_user = injected at runtime
# db_admin_pw   = injected at runtime
