# AWS Standby Infrastructure

멀티 클라우드 Active-Standby 구조에서 **AWS Standby 환경**을 담당한다.

GCP Primary 장애 발생 시 Cloudflare Load Balancer가 Health Check 실패를 감지하고 AWS Standby로 트래픽을 자동 전환한다.

```
사용자
  ↓
Cloudflare Load Balancer
  ├── GCP Primary  (정상 시)
  └── AWS Standby  (장애 시 Failover) ← 여기
```

---

## 파일 구조

```
aws/
├── README.md
├── terraform/
│   ├── README.md
│   ├── main.tf                   # Terraform backend + versions
│   ├── provider.tf               # AWS provider
│   ├── network.tf                # VPC / Subnet / IGW / Route Table
│   ├── security_group.tf         # Bastion SG / k3s 노드 SG
│   ├── ec2.tf                    # Bastion + k3s 노드 EC2
│   ├── outputs.tf                # 팀원 전달값 출력
│   ├── variables.tf              # 변수 정의
│   └── terraform.tfvars.example  # 로컬 실행용 템플릿
└── ansible/
    ├── README.md
    ├── ansible.cfg
    ├── playbook.yml
    └── roles/
        ├── k3s/                  # k3s 설치 + kubeconfig
        ├── node-exporter/        # Prometheus 메트릭 수집 (:9100)
        └── cloudflared/          # Cloudflare Tunnel Pod 배포
```

---

## AWS 인프라 구조

```
VPC (10.20.0.0/16)
├── Public Subnet (10.20.1.0/24)
│   ├── k3s 노드 (t3.small)    ← Standby App + cloudflared + node-exporter
│   └── Bastion Host (t3.micro) ← 운영자 → Monitoring Server 진입점
│
└── Private Subnet (10.20.2.0/24)
    └── Monitoring Server       ← 희정님 담당
```

### Cloudflare Tunnel 방식

k3s 노드는 인바운드 포트(80/443)를 열지 않는다. EC2 내부의 `cloudflared`가 Cloudflare로 아웃바운드 연결을 먼저 맺고, Cloudflare가 그 터널을 통해 트래픽을 전달하는 방식이다.

```
사용자 → Cloudflare → Tunnel → cloudflared Pod → k3s 앱
                        ↑
           EC2가 먼저 연결을 맺어놓음 (아웃바운드)
```

---

## 팀원 전달값

`terraform apply` 완료 후 `terraform output`에서 확인

| 출력값 | 전달 대상 | 용도 |
|---|---|---|
| `bastion_sg_id` | 희정님 | Monitoring Server SG ingress 등록 |
| `vpc_id` | 희정님 | Monitoring Server 배치 VPC |
| `private_subnet_id` | 희정님 | Monitoring Server 배치 Subnet |
| `k3s_public_ip` | 희정님 | Prometheus Node Exporter scrape 대상 |

> `vpc_id`는 이미 확인된 값(`vpc-0f47503a64df96212`)을 직접 전달해도 된다.

---

## 로컬 실행

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 열어서 값 수정

terraform init
terraform plan
terraform apply
```

### Ansible 실행

```bash
cd ansible
# inventory.ini에 k3s 노드 IP 입력 후

ansible-playbook -i inventory.ini playbook.yml \
  -e "tunnel_token=<CF_TUNNEL_TOKEN>"
```
