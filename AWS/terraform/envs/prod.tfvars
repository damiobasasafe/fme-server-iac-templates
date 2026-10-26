# Production environment variables
owner          = "dami-cicd-prod"
region         = "us-east-1"
public_access  = "10.0.0.0/8"

# Network
vpc_name         = "dami-fmeflow-prod-vpc"
sn_name          = "dami-fmeflow-prod-subnet"
igw_name         = "dami-fmeflow-prod-igw"
eip_name         = "dami-fmeflow-prod-eip"
nat_name         = "dami-fmeflow-prod-nat"
vpc_cidr         = "10.3.0.0/16"
public_sn1_cidr  = "10.3.0.0/20"
public_sn2_cidr  = "10.3.16.0/20"
private_sn1_cidr = "10.3.128.0/20"
private_sn2_cidr = "10.3.144.0/20"

# Load balancers
alb_name = "dami-fmeflow-prod-alb"
nlb_name = "dami-fmeflow-prod-nlb"

# Active Directory
ad_name = "prod-fmeflow.safe"

# AMI IDs - populated by Packer pipeline
fme_core_image_id   = ""
fme_engine_image_id = ""

# Secrets - injected by Jenkins from AWS Secrets Manager, do not hardcode
# ad_admin_pw   = injected at runtime
# db_admin_user = injected at runtime
# db_admin_pw   = injected at runtime
