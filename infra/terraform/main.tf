# -------------------------------------------------------------------
# 1. Terraform & Providers 설정
# -------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.0" }
    google     = { source = "hashicorp/google", version = "~> 5.0" }
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 4.0" }
    random     = { source = "hashicorp/random", version = "~> 3.0" }
    local      = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

provider "aws" {
  region = var.aws_region # 기본값 ap-northeast-2
}

provider "cloudflare" {
  api_token = var.cf_api_token
}

provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
  credentials = file(var.gcp_credentials)
}

# -------------------------------------------------------------------
# 2. Cloudflare 모듈 (통합 관제 및 터널 예약)
# 모든 서비스의 터널 토큰과 로드밸런서(Failover) 설정을 가장 먼저 수행합니다.
# -------------------------------------------------------------------
module "cloudflare" {
  source                = "./modules/cloudflare"
  cf_account_id         = var.cf_account_id
  cf_zone_id            = var.cf_zone_id
  cf_tunnel_secret      = var.cf_tunnel_secret
  project_name          = var.project_name
  environment           = var.environment

  # 서비스 도메인 설정
  app_domain            = "app.bucheongoyangijanggun.com"
  monitoring_domain     = "monitor.bucheongoyangijanggun.com"
}

# -------------------------------------------------------------------
# 3. AWS 모듈 (네트워크 소유 및 Standby 인프라)
# VPC와 퍼블릭 서브넷을 직접 생성하며, Cloudflare 터널 토큰을 주입받습니다.
# -------------------------------------------------------------------
module "aws" {
  source             = "./modules/aws"
  project_name       = var.project_name
  environment        = var.environment
  
  # 네트워크 설정 (기존 network 모듈의 역할을 내재화)
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = var.availability_zone
  
  # Cloudflare 터널 토큰 주입
  tunnel_token       = module.cloudflare.aws_tunnel_token
  
  # 기타 변수 (인스턴스 타입, 키페어 등)
  key_name           = var.key_name
  allowed_ssh_cidr   = var.allowed_ssh_cidr

  # EC2 인스턴스 타입 및 볼륨 설정
  instance_type    = var.instance_type    # k3s 노드 인스턴스 타입
  bastion_type     = var.bastion_type     # Bastion 인스턴스 타입
  root_volume_size = var.root_volume_size # Root EBS 볼륨 크기

  # Monitoring Server 인스턴스 타입 및 볼륨 설정
  monitoring_instance_type = var.monitoring_instance_type
  monitoring_volume_size   = var.monitoring_volume_size
}

# -------------------------------------------------------------------
# 4. GCP 모듈 (Primary 인프라)
# Cloudflare 터널 토큰을 주입받아 메인 서비스를 구동합니다.
# -------------------------------------------------------------------
module "gcp" { # gcp 클라우드 코드 추가 안하면서 오류 코드 남아 있음
  source       = "./modules/gcp"
  project_name = var.project_name
  environment  = var.environment
  gcp_project_id   = var.gcp_project_id
  gcp_region       = var.gcp_region
  gcp_zone         = var.gcp_zone
  
  # Cloudflare 터널 토큰 주입
  tunnel_token = module.cloudflare.gcp_tunnel_token
  
  # 보안 주입 변수
  gcp_db_password  = var.gcp_db_password
  gcp_ssh_public_key = var.gcp_ssh_public_key
  gcp_credentials  = var.gcp_credentials
}

/*
# -------------------------------------------------------------------
# 5. Monitoring 모듈 (AWS 상의 관제 인프라)
# AWS 모듈이 생성한 VPC ID를 공유받으며, 전용 터널 토큰을 주입받습니다.
# -------------------------------------------------------------------
module "monitoring" {
  source              = "./modules/aws_monitoring"
  
  # AWS 모듈과의 의존성 연결 (중요: AWS 모듈의 Output과 연결됨)
  vpc_id              = module.aws.vpc_id
  bastion_sg_id       = module.aws.bastion_sg_id
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
  monitoring_domain = var.monitoring_domain
  subnet_id = var.

  # Cloudflare 터널 토큰 주입 (가장 핵심)
  # 이 토큰 하나로 서버 내부에서 cloudflared 서비스가 구동됩니다.
  tunnel_token        = module.cloudflare.monitoring_tunnel_token
  
  # 인스턴스 설정
  ami_id              = var.monitoring_ami_id
  key_name            = var.key_name
  
  # 모니터링 전용 사양을 쓰고 싶다면 아래와 같이 연결 (없으면 모듈 내 default 사용)
  instance_type     = var.instance_type 
}
*/