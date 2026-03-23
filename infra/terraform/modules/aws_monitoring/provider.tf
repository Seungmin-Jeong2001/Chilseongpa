# AWS Provider 설정
provider "aws" {

  # variables.tf에서 선언한 리전 사용
  region = var.aws_region
}