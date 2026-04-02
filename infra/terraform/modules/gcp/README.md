# Terraform — GCP Module

GCP Primary 환경의 네트워크, 컴퓨팅, 데이터베이스 리소스를 코드로 프로비저닝합니다.

---

## 사전 준비

Terraform 실행 전, GCP 프로젝트에 필요한 API를 활성화하세요.

```bash
gcloud services enable compute.googleapis.com \
                       secretmanager.googleapis.com \
                       sqladmin.googleapis.com \
                       monitoring.googleapis.com
```

---

## 파일 역할

| 파일           | 역할                                                                              |
| -------------- | --------------------------------------------------------------------------------- |
| `network.tf`   | 커스텀 VPC / 서브넷 생성, 방화벽 규칙 (SSH, 내부 메트릭 포트)                    |
| `compute.tf`   | K3s Primary VM (e2-standard-2), Monitoring VM (e2-small) 생성                    |
| `database.tf`  | Cloud SQL MySQL 8.0 생성                                                          |
| `security.tf`  | Cloud SQL Auth Proxy용 서비스 계정 및 키 발급                                     |
| `variables.tf` | 프로젝트 ID, 리전, SSH 공개키, DB 비밀번호 등 변수 정의                           |
| `outputs.tf`   | K3s 공인 IP, K3s 내부 IP, Monitoring 공인 IP, DB 연결 정보 출력                  |

---

## 네트워크 구성

### VPC / 서브넷

| 리소스  | 이름                             | CIDR           |
| ------- | -------------------------------- | -------------- |
| VPC     | `{project}-{env}-vpc`            | —              |
| 서브넷  | `{project}-{env}-subnet`         | `10.30.0.0/24` |

### 방화벽 규칙

| 규칙                        | 허용 포트                 | 대상 태그      | 소스              |
| --------------------------- | ------------------------- | -------------- | ----------------- |
| `allow-ssh`                 | 22                        | k3s-node, monitoring-node | 0.0.0.0/0 |
| `allow-internal-metrics`    | 9100 / 30800 / 30080      | k3s-node       | monitoring-node   |

> `allow-internal-metrics`는 GCP 내부 태그 기반 룰입니다.  
> Monitoring VM(`monitoring-node`)에서 K3s VM(`k3s-node`)의 메트릭 포트만 허용합니다.

---

## 컴퓨팅 리소스

| VM                  | 타입           | 용도                                                  |
| ------------------- | -------------- | ----------------------------------------------------- |
| K3s Primary Node    | e2-standard-2  | Kubernetes (K3s) Primary 클러스터                     |
| Monitoring Server   | e2-small       | Prometheus / Grafana / Alertmanager / Discord Bot     |

- 두 VM 모두 Ubuntu 22.04, 50GB SSD, 동일 VPC/서브넷에 배치
- Monitoring VM은 startup script로 cloudflared (monitoring 터널) 자동 설치

---

## 주요 Output

| output                        | 설명                                      |
| ----------------------------- | ----------------------------------------- |
| `k3s_ephemeral_ip`            | K3s VM 공인 IP (Ansible 접속용)           |
| `k3s_internal_ip`             | K3s VM 내부 IP (Prometheus scrape용)      |
| `monitoring_ephemeral_ip`     | Monitoring VM 공인 IP (Ansible 접속용)    |
| `db_proxy_sa_key`             | Cloud SQL Auth Proxy 서비스 계정 JSON 키  |
| `db_instance_connection_name` | Cloud SQL 연결 문자열                     |
