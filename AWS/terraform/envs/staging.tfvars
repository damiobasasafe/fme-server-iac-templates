# Staging environment variables
owner          = "dami-cicd-staging"
region         = "us-east-1"
public_access  = "0.0.0.0/0"

# Network
vpc_name         = "dami-fmeflow-staging-vpc"
sn_name          = "dami-fmeflow-staging-subnet"
igw_name         = "dami-fmeflow-staging-igw"
eip_name         = "dami-fmeflow-staging-eip"
nat_name         = "dami-fmeflow-staging-nat"
vpc_cidr         = "10.2.0.0/16"
public_sn1_cidr  = "10.2.0.0/20"
public_sn2_cidr  = "10.2.16.0/20"
private_sn1_cidr = "10.2.128.0/20"
private_sn2_cidr = "10.2.144.0/20"

# Load balancers
alb_name = "dami-fmeflow-staging-alb"
nlb_name = "dami-fmeflow-staging-nlb"

# Active Directory
ad_name = "staging-fmeflow.safe"

# AMI IDs - populated by Packer pipeline
fme_core_image_id   = ""
fme_engine_image_id = ""

# Secrets - injected by Jenkins from AWS Secrets Manager, do not hardcode
# ad_admin_pw   = injected at runtime
# db_admin_user = injected at runtime
# db_admin_pw   = injected at runtime
