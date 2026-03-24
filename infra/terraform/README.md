# Terraform

AWS / GCP / Cloudflare 리소스를 코드로 프로비저닝합니다.  
3개 Provider(AWS, GCP, Cloudflare)를 하나의 루트에서 통합 관리합니다.

---

## 디렉토리 구조

```
terraform/
├── main.tf                     # Provider 설정, 모듈 호출 및 모듈 간 값 연결
├── variables.tf                # 전역 변수 정의 (리전, 인스턴스 타입, 도메인 등)
├── outputs.tf                  # 배포 후 출력값 (IP, SG ID 등)
├── terraform.tfvars.example    # 변수 입력 예시 — 복사 후 terraform.tfvars로 사용
├── ansible_inventory.tf        # inventory.ini 자동 생성 (local_file 리소스)
├── inventory.tpl               # inventory.ini 템플릿 (Bastion ProxyCommand 포함)
└── modules/
    ├── cloudflare/             # Tunnel, Load Balancer, Access 정책
    ├── aws/                    # VPC, Subnet, Bastion, K3s 노드, Monitoring 서버
    └── gcp/                    # VM, Cloud SQL, 서비스 계정 및 키
```

---

## 모듈 설명

### `modules/cloudflare`

Cloudflare Zero Trust 기반 인프라를 구성합니다.  
**다른 모듈보다 먼저 실행**되어 터널 토큰을 AWS / GCP 모듈에 전달합니다.

| 리소스 | 설명 |
|---|---|
| Tunnel × 3 | gcp / aws / monitoring 각 서버용 터널 생성 |
| Load Balancer | GCP(Primary) → AWS(Standby) Failover 구성 |
| Access Policy | Prometheus → GCP Node Exporter scrape용 서비스 토큰 |

### `modules/aws`

AWS 위에 Standby K3s 클러스터와 모니터링 서버를 구성합니다.

| 파일 | 생성 리소스 |
|---|---|
| `network.tf` | VPC (`10.20.0.0/16`), Public Subnet, IGW, Route Table |
| `ec2.tf` | Bastion (t3.micro), K3s 노드 (t3.small), Monitoring 서버 (t3.small) |
| `security_groups.tf` | Bastion SG, K3s SG, Monitoring SG |

**Security Group 정책 요약**

| 서버 | 인바운드 허용 |
|---|---|
| Bastion | SSH (운영자 IP) |
| K3s 노드 | SSH, 6443 (운영자 IP), 9100 (VPC 내부) |
| Monitoring | SSH, 3000/9090/9093 (Bastion SG 경유만) |

### `modules/gcp`

GCP 위에 Primary K3s 클러스터와 Cloud SQL을 구성합니다.

| 파일 | 생성 리소스 |
|---|---|
| `compute.tf` | K3s VM (e2-standard-2, Ubuntu 22.04, 50GB) |
| `network.tf` | 방화벽 — SSH(22), Node Exporter(9100) 허용 |
| `database.tf` | Cloud SQL MySQL 8.0 (`db-custom-2-7680`), DB: `hybrid_app_db` |
| `security.tf` | Cloud SQL Auth Proxy용 서비스 계정 및 키, Secret Manager 저장 |

---

## 사전 준비

### 필수 도구

- Terraform `>= 1.5.0`
- AWS CLI (인증 설정 완료)
- GCP 서비스 계정 키 (`.json`)

### terraform.tfvars 작성

```bash
cp terraform.tfvars.example terraform.tfvars
```

> `terraform.tfvars`는 시크릿이 포함되므로 **절대 Git에 커밋하지 마세요**.  
> `.gitignore`에 등록되어 있습니다.

### 주요 변수 목록

**Global**

| 변수 | 기본값 | 설명 |
|---|---|---|
| `project_name` | `chilseongpa` | 리소스 네이밍 접두어 |
| `environment` | `prod` | 배포 환경 |

**AWS**

| 변수 | 기본값 | 설명 |
|---|---|---|
| `aws_region` | `ap-northeast-2` | AWS 리전 |
| `key_name` | — | AWS 콘솔에서 미리 생성한 Key Pair 이름 |
| `instance_type` | `t3.small` | K3s 노드 인스턴스 타입 |
| `bastion_type` | `t3.micro` | Bastion 인스턴스 타입 |
| `root_volume_size` | `20` | K3s 노드 EBS 볼륨 크기 (GB) |
| `monitoring_instance_type` | `t3.small` | Monitoring 서버 인스턴스 타입 |
| `monitoring_volume_size` | `30` | Monitoring 서버 EBS 볼륨 크기 (GB) |
| `allowed_ssh_cidr` | `0.0.0.0/0` | SSH 허용 CIDR — 본인 IP로 변경 권장 |

**GCP**

| 변수 | 기본값 | 설명 |
|---|---|---|
| `gcp_project_id` | — | GCP 프로젝트 ID |
| `gcp_region` | `asia-northeast3` | GCP 리전 (서울) |
| `gcp_zone` | `asia-northeast3-a` | GCP 가용 영역 |
| `gcp_credentials` | — | GCP 서비스 계정 JSON 내용 |
| `gcp_ssh_public_key` | — | Ansible 접속용 SSH 공개키 |
| `gcp_db_password` | — | Cloud SQL root 비밀번호 |

**Cloudflare**

| 변수 | 설명 |
|---|---|
| `cf_api_token` | Cloudflare API 토큰 |
| `cf_account_id` | Cloudflare 계정 ID |
| `cf_zone_id` | Cloudflare Zone ID |
| `cf_tunnel_secret` | 터널 암호화용 시크릿 (32바이트 이상) — `openssl rand -base64 32`로 생성 |

---

## 실행 순서

```bash
cd infra/terraform

# 1. 초기화
terraform init

# 2. 실행 계획 확인
terraform plan

# 3. 리소스 생성
terraform apply
```

apply 완료 후 `infra/ansible/inventory.ini`가 자동으로 생성됩니다.

### 주요 output 값

| output | 설명 |
|---|---|
| `gcp_k3s_ephemeral_ip` | GCP K3s VM 공인 IP (Ansible 초기 접속용) |
| `aws_bastion_public_ip` | AWS Bastion 공인 IP |
| `aws_k3s_public_ip` | AWS K3s 노드 공인 IP |
| `aws_monitoring_public_ip` | AWS Monitoring 서버 공인 IP |
| `gcp_db_proxy_sa_key` | Cloud SQL Proxy JSON 키 (sensitive) |

### 리소스 삭제

```bash
terraform destroy
```

---

## 주의사항

- GCP `compute.tf`에 주석 처리된 이전 코드가 남아 있습니다 — 삭제해도 됩니다.
- `allowed_ssh_cidr` 기본값이 `0.0.0.0/0`입니다. 운영 환경에서는 반드시 본인 IP(`x.x.x.x/32`)로 변경하세요.
- `gcp_db_password`, `cf_tunnel_secret` 등 민감 변수는 `terraform output`에서 숨겨집니다. 확인 시 `terraform output -raw <output명>`을 사용하세요.
