terraform {
  backend "s3" {
    bucket         = "ecs-node-terraform-state-977b8614"
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
