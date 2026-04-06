# Infra

Hybrid Multi-Cloud (GCP Primary / AWS Standby) 기반 인프라 구성 디렉토리입니다.  
Terraform으로 클라우드 리소스를 프로비저닝하고, Ansible로 서버 환경을 구성합니다.

---

## 디렉토리 구조

```
infra/
├── setup-ssh.sh                        # terraform output 읽어 ~/.ssh/config 자동 구성
├── terraform/                          # 클라우드 리소스 프로비저닝
│   ├── main.tf                         # Provider 설정 및 모듈 호출
│   ├── variables.tf                    # 전역 변수 정의
│   ├── outputs.tf                      # 배포 후 출력값 정의
│   ├── terraform.tfvars.example        # 변수 입력 예시 파일 (복사 후 사용)
│   ├── ansible_inventory.tf            # Ansible inventory.ini 자동 생성
│   ├── inventory.tpl                   # inventory.ini 템플릿
│   └── modules/
│       ├── cloudflare/                 # Tunnel / Load Balancer / Access 설정
│       ├── aws/                        # VPC, EC2 (Bastion, K3s)
│       └── gcp/                        # VPC, VM (K3s, Monitoring), Cloud SQL, 서비스 계정
│
└── ansible/                            # 서버 환경 구성 자동화
    ├── ansible.cfg                     # Ansible 기본 설정
    ├── inventory.ini                   # 서버 접속 정보 (Terraform이 자동 생성, Git 제외)
    ├── playbook.yml                    # 전체 플레이북
    ├── secrets.sh                      # 환경변수 설정 스크립트
    ├── group_vars/
    │   └── all.yml                     # 공통 변수
    └── roles/
        ├── node-exporter/              # K3s 서버 Node Exporter 설치
        ├── k3s/                        # GCP / AWS 서버 K3s + cloudflared 설치
        ├── docker/                     # Monitoring 서버 Docker 설치
        └── monitoring/                 # Prometheus / Grafana / Alertmanager / Discord Bot 구성
```

---

## 전체 구성 흐름

```
① Terraform apply
   ├── Cloudflare 터널 3개 생성 (gcp / aws / monitoring)
   ├── AWS 리소스 생성
   │   ├── Public Subnet: Bastion, NAT Gateway
   │   └── Private Subnet: K3s Standby Node
   ├── GCP 리소스 생성
   │   ├── 커스텀 VPC / 서브넷 / 방화벽
   │   ├── VM: K3s Primary Node, Monitoring Server
   │   └── Cloud SQL
   └── ansible/inventory.ini 자동 생성 (IP, 터널 토큰 포함)

② setup-ssh.sh 실행 (선택)
   └── ~/.ssh/config에 Bastion / K3s / Monitoring 접속 설정 자동 생성

③ Ansible playbook 실행
   ├── GCP / AWS K3s 서버 → Node Exporter 설치
   ├── GCP / AWS K3s 서버 → K3s 설치
   └── GCP Monitoring 서버 → Docker → Prometheus / Grafana / Alertmanager / Discord Bot 구성
```

> Terraform을 먼저 실행하면 `inventory.ini`가 자동 생성됩니다.  
> 별도로 inventory.ini를 작성할 필요 없습니다.

---

## 인프라 구성 요약

| 영역       | 클라우드   | 서브넷  | 리소스                        | 역할                                              |
| ---------- | ---------- | ------- | ----------------------------- | ------------------------------------------------- |
| Ac    | GCP        | Private | VM (e2-standard-2), Cloud SQL | K3s 클러스터 (Active), DB                         |
| Monitoring | GCP        | Private | VM (e2-small)                 | Prometheus / Grafana / Alertmanager / Discord Bot |
| Standby    | AWS        | Private | EC2 t3.small                  | K3s 클러스터 (Standby)                            |
| Bastion    | AWS        | Public  | EC2 t3.micro                  | SSH 진입점 (AWS)                                  |
| NAT        | AWS        | Public  | NAT Gateway                   | AWS Private Subnet 아웃바운드                     |
| Edge       | Cloudflare | —       | Tunnel × 3, Load Balancer     | Failover, 트래픽 제어                             |

---

## 관련 문서

- [Terraform 가이드](./terraform/README.md)
- [Ansible 가이드](./ansible/README.md)
