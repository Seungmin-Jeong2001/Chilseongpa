# Monitoring Server Infrastructure - Terraform

## 프로젝트 목적

멀티 클라우드 환경(GCP / AWS)에서 실행되는 Kubernetes 및 애플리케이션 메트릭을 중앙에서 수집하는 **Monitoring Server**를 Terraform으로 구성합니다.

- EC2 Instance + Security Group + Root Volume(gp3) 구성
- Site-to-Site VPN 기반 Private Network를 통해 Kubernetes 및 애플리케이션 메트릭 수집
- Bastion Host를 통한 안전한 운영자 접근
- 재현 가능한 인프라 환경 구축


---

## Terraform 구조
```
terraform/
├ main.tf
├ provider.tf
├ security_group.tf
├ ec2.tf
├ outputs.tf
├ variables.tf
└ terraform.tfvars
```

## terraform.tfvars
- 환경별 값
```
# 인스턴스 정보
instance_type = "t3.small"
ami_id = "ami-xxxxxxxx"

# 네트워크 정보
vpc_id = "vpc-xxxxxxxx"
subnet_id = "subnet-xxxxxxxx"
key_name = "monitoring-key"

# 보안 및 연결 정보
bastion_sg_id = "sg-xxxxxxxxxxxxxxxxx"
vpn_cidr = [
  "10.xxx.x.x/xx",  # GCP 클러스터 CIDR
  "10.xxx.x.x/xx"    # AWS 클러스터 CIDR
]
```
- GitHub Actions에서는 TF_VAR_* 환경 변수를 통해 주입

---

## Terraform 실행
1. 초기화
```
terraform init
```
2. 코드 검증
```
terraform validate
# Success! The configuration is valid.
```
3. 실행 계획 확인
```
terraform plan
# 예시 출력
# Plan: 2 to add, 0 to change, 0 to destroy
```
4. 인프라 생성
```
terraform apply
# Resources: 2 added, 0 changed, 0 destroyed
```
5. 인프라 제거
```
terraform destroy
# 삭제 확인 후 yes 입력
```

---

## 핵심 보안 및 접근 모델
- 관리 트래픽 → Bastion Host Security Group
- 메트릭 트래픽 → VPN CIDR
- Public IP 노출 없음, Least Privilege 적용
- Zero Trust 보안 모델 준수

---

## Monitoring Server Security Group
- 관리 트래픽: SSH, Grafana, Prometheus UI, Alertmanager UI → Bastion Host Security Group을 통해서만 허용
- 메트릭 트래픽: Node Exporter, App /metrics → VPN CIDR에서만 허용
- Outbound 트래픽: 모든 트래픽 허용 (0.0.0.0/0)
1. 관리 트래픽 (SSH, Grafana, Prometheus UI, Alertmanager UI)
   - 접근 경로: Bastion Host Security Group
   - Public IP를 통한 직접 접근 없음 → Zero Trust, Least Privilege 준수
2. 메트릭 트래픽 (Node Exporter 9100, App /metrics 8080)
   - 접근 경로: VPN CIDR
   - GCP / AWS 클러스터 양쪽 Private Network 대역 포함 → 두 클러스터 모두 접근 가능
3. Outbound 트래픽
   - 모든 트래픽 허용(0.0.0.0/0) → Monitoring Server가 외부 패키지 다운로드, Alert Webhook 전송 등 수행 가능

### 설계 의도
- Public IP를 통한 직접 접근 금지
- 트래픽 유형별 완전 분리
- 최소 권한(Least Privilege) 적용
- Zero Trust 모델 준수

### 사용 방법
- EC2 Monitoring Server에 연결할 때는 반드시 Bastion Host를 경유
- Kubernetes Cluster에서 메트릭을 수집할 때는 VPN을 통해서만 접근 가능
  