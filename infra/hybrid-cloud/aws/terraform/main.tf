terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # ansible/inventory.ini 자동 생성용 (로컬 실행 전용)
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # backend "s3" {
  #  bucket         = "hybrid-project-terraform-state"
  #  key            = "aws-standby/terraform.tfstate"
  #  region         = "ap-northeast-2"
  #  dynamodb_table = "hybrid-project-terraform-lock"
  #  encrypt        = true
  # }
}
