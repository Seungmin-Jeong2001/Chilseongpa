# ==============================================================================
# [variables.tf] 하드코딩을 방지하고, 환경(Dev/Prod)이 바뀔 때 유연하게 
# 대처하기 위해 사용하는 변수 저장소입니다.
# ==============================================================================

variable "project_id" {
  description = "GCP 프로젝트 ID (GitHub Secrets: TF_VAR_project_id에서 보안 주입)"
  type        = string
}

variable "region" {
  description = "인프라가 배포될 리전 (AWS와 통신 지연을 막기 위해 서울로 고정)"
  type        = string
  default     = "asia-northeast3" # 아키텍트의 결정: 서울 리전
}

variable "zone" {
  description = "인프라가 배포될 가용 영역"
  type        = string
  default     = "asia-northeast3-a"
}

variable "db_password" {
  # 💡 수정된 설명: 파일이 아닌 GitHub Secrets를 통한 보안 주입임을 명시
  description = "Cloud SQL Root 비밀번호 (GitHub Secrets: TF_VAR_db_password를 통해 주입)"
  type        = string
  sensitive   = true # 비밀번호가 로그나 화면에 노출되는 것을 방지
}
variable "ssh_public_key" {
  description = "Ansible 접속을 허용할 SSH 공개키(자물쇠)"
  type        = string
}
