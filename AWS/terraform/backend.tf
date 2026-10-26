terraform {
  backend "s3" {
    bucket         = "dami-fmeflow-tfstate"
    key            = "fmeflow/${terraform.workspace}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dami-fmeflow-tfstate-lock"
    encrypt        = true
  }
}
