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
    ├── aws/                    # VPC, Subnet, Bastion, K3s 노드
    └── gcp/                    # 커스텀 VPC, VM (K3s, Monitoring), Cloud SQL, 서비스 계정
```

---

## 모듈 설명

### `modules/cloudflare`

Cloudflare Zero Trust 기반 인프라를 구성합니다.  
**다른 모듈보다 먼저 실행**되어 터널 토큰을 AWS / GCP 모듈에 전달합니다.

| 리소스        | 설명                                                         |
| ------------- | ------------------------------------------------------------ |
| Tunnel × 3    | gcp / aws / monitoring 각 서버용 터널 생성                   |
| Load Balancer | GCP(Primary) → AWS(Standby) Failover 구성                    |
| Access Policy | Prometheus → AWS Node Exporter/App/kube-state-metrics scrape용 서비스 토큰 |

> GCP 메트릭은 GCP 내부 직접 통신으로 수집하므로 Cloudflare Access가 불필요합니다.  
> AWS 메트릭만 Cloudflare Zero Trust 터널을 경유합니다.

### `modules/aws`

AWS 위에 Standby K3s 클러스터를 구성합니다.

| 파일                 | 생성 리소스                                                                       |
| -------------------- | --------------------------------------------------------------------------------- |
| `network.tf`         | VPC (`10.20.0.0/16`), Public Subnet, Private Subnet, IGW, NAT Gateway, Route Table |
| `ec2.tf`             | Bastion (t3.micro / Public), K3s 노드 (t3.small / Private)                        |
| `security_groups.tf` | Bastion SG, K3s SG                                                                |

**서브넷 구성**

| 서브넷  | CIDR           | 배치 서버            |
| ------- | -------------- | -------------------- |
| Public  | `10.20.1.0/24` | Bastion, NAT Gateway |
| Private | `10.20.2.0/24` | K3s Standby Node     |

**Security Group 정책**

| 서버     | 인바운드 허용                            |
| -------- | ---------------------------------------- |
| Bastion  | SSH (운영자 IP)                          |
| K3s 노드 | SSH (Bastion SG), 6443 / 9100 (VPC 내부) |

> K3s는 Private Subnet에 배치되어 외부 직접 접근이 불가능합니다.  
> 모든 아웃바운드는 NAT Gateway를 경유합니다. (cloudflared Tunnel 연결 포함)

### `modules/gcp`

GCP 위에 Primary K3s 클러스터, Monitoring 서버, Cloud SQL을 구성합니다.

| 파일          | 생성 리소스                                                                                   |
| ------------- | --------------------------------------------------------------------------------------------- |
| `network.tf`  | 커스텀 VPC / 서브넷, 방화벽 — SSH(22), 내부 메트릭 포트(9100 / 30800 / 30080)               |
| `compute.tf`  | K3s VM (e2-standard-2, Ubuntu 22.04, 50GB), Monitoring VM (e2-small, Ubuntu 22.04, 50GB)     |
| `database.tf` | Cloud SQL MySQL 8.0 (`db-custom-2-7680`), DB: `hybrid_app_db`                                |
| `security.tf` | Cloud SQL Auth Proxy용 서비스 계정 및 키                                                      |

> Monitoring VM은 GCP 내부 네트워크로 K3s 노드(9100 / 30800 / 30080)에 직접 접근합니다.  
> 방화벽은 `monitoring-node` → `k3s-node` 태그 기반으로 허용합니다.

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

### 주요 변수 목록

**AWS**

| 변수                       | 기본값           | 설명                                        |
| -------------------------- | ---------------- | ------------------------------------------- |
| `aws_region`               | `ap-northeast-2` | AWS 리전                                    |
| `key_name`                 | —                | AWS 콘솔에서 미리 생성한 Key Pair 이름      |
| `vpc_cidr`                 | `10.20.0.0/16`   | VPC CIDR                                    |
| `public_subnet_cidr`       | `10.20.1.0/24`   | Public Subnet CIDR                          |
| `private_subnet_cidr`      | `10.20.2.0/24`   | Private Subnet CIDR                         |
| `allowed_ssh_cidr`         | `0.0.0.0/0`      | Bastion SSH 허용 CIDR — 본인 IP로 변경 권장 |
| `instance_type`            | `t3.small`       | K3s 노드 인스턴스 타입                      |
| `bastion_type`             | `t3.micro`       | Bastion 인스턴스 타입                       |
| `monitoring_instance_type` | `t3.small`       | Monitoring 서버 인스턴스 타입               |

**GCP**

| 변수                 | 설명                                              |
| -------------------- | ------------------------------------------------- |
| `gcp_project_id`     | GCP 프로젝트 ID                                   |
| `gcp_credentials`    | GCP 서비스 계정 JSON 파일 경로                    |
| `gcp_ssh_public_key` | Ansible 접속용 SSH 공개키 (`my_gcp_key.pub` 내용) |
| `gcp_db_password`    | Cloud SQL root 비밀번호                           |

**Cloudflare**

| 변수               | 설명                                                    |
| ------------------ | ------------------------------------------------------- |
| `cf_api_token`     | Cloudflare API 토큰                                     |
| `cf_account_id`    | Cloudflare 계정 ID                                      |
| `cf_zone_id`       | Cloudflare Zone ID                                      |
| `cf_tunnel_secret` | 터널 암호화용 시크릿 — `openssl rand -base64 32`로 생성 |

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

# 4. SSH config 자동 생성 (선택)
bash ../setup-ssh.sh
```

`terraform apply` 완료 후:

- `infra/ansible/inventory.ini` 자동 생성
- `setup-ssh.sh` 실행 시 `~/.ssh/config`에 접속 설정 자동 등록

### setup-ssh.sh 실행 후 접속 방법

```bash
ssh gcp-k3s        # GCP K3s Primary 노드
ssh gcp-monitoring # GCP Monitoring 서버
ssh aws-bastion    # AWS Bastion Host
ssh aws-k3s        # AWS K3s Standby 노드 (Bastion 자동 경유)
```

### 주요 output 값

| output                       | 설명                                                   |
| ---------------------------- | ------------------------------------------------------ |
| `aws_bastion_public_ip`      | AWS Bastion 공인 IP                                    |
| `aws_k3s_private_ip`         | AWS K3s 노드 Private IP                                |
| `gcp_k3s_ephemeral_ip`       | GCP K3s VM 공인 IP                                     |
| `gcp_monitoring_ephemeral_ip`| GCP Monitoring 서버 공인 IP                            |
| `cf_access_client_id`        | Cloudflare Access Client ID (Prometheus scrape 인증용) |

### 리소스 삭제

```bash
terraform destroy
```

---

## 주의사항

- `allowed_ssh_cidr` 기본값이 `0.0.0.0/0`입니다. 운영 환경에서는 반드시 본인 IP(`x.x.x.x/32`)로 변경하세요.
- AWS K3s 서버는 Private Subnet에 있어 직접 SSH 접속이 불가능합니다. 반드시 Bastion을 경유하세요.
- GCP K3s / Monitoring 서버는 공인 IP가 있으며 `my_gcp_key`로 직접 접속합니다.
- `terraform.tfvars`는 시크릿이 포함되므로 절대 Git에 커밋하지 마세요.
- `inventory.ini`는 Terraform이 자동 생성하며 민감 정보가 포함되어 있어 Git에서 제외됩니다.
