# Infra

Hybrid Multi-Cloud (GCP / AWS) 기반 인프라 구성 디렉토리입니다.  
Terraform으로 클라우드 리소스를 프로비저닝하고, Ansible로 서버 환경을 구성합니다.

---

## 디렉토리 구조

```
infra/
├── terraform/                          # 클라우드 리소스 프로비저닝
│   ├── main.tf                         # Provider 설정 및 모듈 호출
│   ├── variables.tf                    # 전역 변수 정의
│   ├── outputs.tf                      # 배포 후 출력값 정의
│   ├── terraform.tfvars.example        # 변수 입력 예시 파일 (복사 후 사용)
│   ├── ansible_inventory.tf            # Ansible inventory.ini 자동 생성
│   ├── inventory.tpl                   # inventory.ini 템플릿
│   └── modules/
│       ├── cloudflare/                 # Tunnel / Load Balancer / Access 설정
│       ├── aws/                        # VPC, EC2 (Bastion, K3s, Monitoring)
│       └── gcp/                        # VM, Cloud SQL, 서비스 계정
│
└── ansible/                            # 서버 환경 구성 자동화
    ├── ansible.cfg                     # Ansible 기본 설정
    ├── inventory.ini                   # 서버 접속 정보 (Terraform이 자동 생성)
    ├── playbook.yml                    # 전체 플레이북
    ├── secrets.sh                      # 환경변수 설정 스크립트 예시
    ├── group_vars/
    │   └── all.yml                     # 공통 변수
    └── roles/
        ├── node-exporter/              # 전체 서버 Node Exporter 설치
        ├── k3s/                        # GCP / AWS 서버 K3s 설치
        ├── docker/                     # 모니터링 서버 Docker 설치
        └── monitoring/                 # Prometheus / Grafana / Alertmanager 구성
```

---

## 전체 구성 흐름

```
① Terraform apply
   ├── Cloudflare 터널 3개 생성 (gcp / aws / monitoring)
   ├── AWS 리소스 생성 (VPC, Bastion, K3s 노드, Monitoring 서버)
   ├── GCP 리소스 생성 (VM, Cloud SQL)
   └── ansible/inventory.ini 자동 생성 (IP, 터널 토큰 포함)

② Ansible playbook 실행
   ├── 전체 서버 → Node Exporter 설치
   ├── GCP / AWS 서버 → K3s 설치
   └── Monitoring 서버 → Docker 설치 → Prometheus / Grafana / Alertmanager 구성
```

> Terraform을 먼저 실행하면 `inventory.ini`가 자동 생성됩니다.  
> 별도로 inventory.ini를 작성할 필요 없습니다.

---

## 인프라 구성 요약

| 영역 | 클라우드 | 리소스 | 역할 |
|---|---|---|---|
| Primary | GCP | VM (e2-standard-2), Cloud SQL | K3s 클러스터 (Active), DB |
| Standby | AWS | EC2 t3.small, Bastion t3.micro | K3s 클러스터 (Standby) |
| Monitoring | AWS | EC2 t3.small (EBS 30GB) | Prometheus / Grafana / Alertmanager |
| Edge | Cloudflare | Tunnel × 3, Load Balancer | Failover, 트래픽 제어 |

---

## 관련 문서

- [Terraform 가이드](./terraform/README.md)
- [Ansible 가이드](./ansible/README.md)
