# Terraform — AWS Standby

AWS Standby 환경의 인프라를 Terraform으로 정의한다.

---

## 파일 역할

| 파일 | 역할 |
|---|---|
| `main.tf` | Terraform backend (S3) + required versions |
| `provider.tf` | AWS provider 설정 |
| `network.tf` | VPC / Subnet / IGW / Route Table |
| `security_group.tf` | Bastion SG / k3s 노드 SG |
| `ec2.tf` | Bastion Host + k3s 노드 EC2 |
| `outputs.tf` | 팀원 전달값 출력 |
| `variables.tf` | 변수 정의 |
| `terraform.tfvars.example` | 로컬 실행용 변수 템플릿 |

---

## 생성되는 리소스

```
VPC (10.20.0.0/16)
├── Internet Gateway
├── Public Subnet (10.20.1.0/24)
│   ├── Route Table (0.0.0.0/0 → IGW)
│   ├── k3s 노드 EC2 (t3.small)
│   └── Bastion Host EC2 (t3.micro)
└── Private Subnet (10.20.2.0/24)
    └── (희정님 Monitoring Server 배치 예정)
```

---

## Security Group 정책

**k3s 노드 SG**

| 포트 | 용도 | 허용 |
|---|---|---|
| 22 | SSH | 운영자 IP |
| 6443 | Kubernetes API | 운영자 IP |
| 9100 | Node Exporter | 0.0.0.0/0 (희정님 IP 확정 후 수정 예정) |
| outbound | 전체 허용 | cloudflared Tunnel / 패키지 설치 등 |

**Bastion SG**

| 포트 | 용도 | 허용 |
|---|---|---|
| 22 | SSH | 운영자 IP |
| outbound | 전체 허용 | Monitoring Server 접근 |

---

## 팀원 전달값

| 출력값 | 전달 대상 | 용도 |
|---|---|---|
| `bastion_sg_id` | 희정님 | Monitoring Server SG ingress 등록 |
| `vpc_id` | 희정님 | Monitoring Server 배치 VPC |
| `private_subnet_id` | 희정님 | Monitoring Server 배치 Subnet |
| `k3s_public_ip` | 희정님 | Prometheus Node Exporter scrape 대상 |

---

## 로컬 실행

```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 값 수정 후

terraform init
terraform plan
terraform apply
```
