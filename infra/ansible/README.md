# Ansible

Terraform으로 생성된 서버에 K3s, Docker, 모니터링 스택을 자동으로 구성합니다.

---

## 디렉토리 구조

```
ansible/
├── ansible.cfg                         # Ansible 기본 설정
├── inventory.ini                       # 서버 접속 정보 (Terraform apply 시 자동 생성)
├── playbook.yml                        # 전체 플레이북
├── secrets.sh                          # 환경변수 설정 스크립트
├── group_vars/
│   └── all.yml                         # 공통 변수
└── roles/
    ├── node-exporter/tasks/main.yml    # Node Exporter v1.7.0 설치 (중복 설치 방지)
    ├── k3s/tasks/main.yml              # K3s 설치
    ├── docker/
    │   ├── tasks/main.yml              # Docker CE 설치, 로그 로테이션 설정
    │   └── handlers/main.yml           # Docker 재시작 핸들러
    └── monitoring/
        ├── tasks/main.yml              # EBS 마운트, 설정 렌더링, 스택 실행
        ├── handlers/main.yml           # Prometheus reload 핸들러
        └── templates/                  # Jinja2 설정 템플릿
            ├── prometheus.yml.j2
            ├── alertmanager.yml.j2
            ├── alert.rules.yml.j2
            ├── docker-compose.yml.j2   # Prometheus / Grafana / Alertmanager / Discord Bot
            ├── datasource.yml.j2
            └── dashboard.yml.j2
```

---

## Playbook 구성

`playbook.yml` 실행 시 호스트 그룹에 따라 아래 순서로 역할을 수행합니다.

| Play               | 대상 호스트                | 수행 작업                                                               |
| ------------------ | -------------------------- | ----------------------------------------------------------------------- |
| Node Exporter 설치 | `aws_nodes`, `gcp_primary` | Node Exporter v1.7.0 설치 및 systemd 등록                               |
| GCP K3s 구축       | `gcp_primary`              | K3s 독립 클러스터 설치                                                  |
| AWS K3s 구축       | `aws_nodes`                | K3s 독립 클러스터 설치                                                  |
| 모니터링 센터 구축 | `aws-monitor`              | Docker CE 설치 → Prometheus / Grafana / Alertmanager / Discord Bot 실행 |

> Bastion 서버에는 Node Exporter를 설치하지 않습니다.  
> cloudflared는 EC2 `user_data`에서 서버 생성 시 자동 설치됩니다. (Ansible 불필요)

---

## 사전 준비

### 1. Ansible 설치

```bash
pip install ansible
```

### 2. inventory.ini 확인

`infra/terraform`에서 `terraform apply`를 완료하면 `inventory.ini`가 자동으로 생성됩니다.

생성된 `inventory.ini` 구조:

```ini
[gcp_primary]
gcp-main ansible_host=<GCP_IP> tunnel_token=<...> db_conn=<...>

[aws_bastion]
aws-bastion ansible_host=<BASTION_PUBLIC_IP>

[aws_nodes]
aws-sub     ansible_host=<K3S_PRIVATE_IP>         tunnel_token=<...>
aws-monitor ansible_host=<MONITORING_PRIVATE_IP>  tunnel_token=<...>

[aws_nodes:vars]
# K3s / Monitoring은 Private Subnet → Bastion ProxyCommand 경유
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q ubuntu@<BASTION_IP> ..."'

[all:vars]
ansible_user=ubuntu
cf_client_id="<...>"
cf_client_secret="<...>"
```

### 3. 환경변수 설정

`secrets.sh`의 값을 채운 뒤 실행하세요.

```bash
source infra/ansible/secrets.sh
```

| 환경변수            | 설명                                                   |
| ------------------- | ------------------------------------------------------ |
| `ALERT_WEBHOOK_URL` | Discord Webhook URL (Alertmanager → Discord Bot)       |
| `CF_CLIENT_ID`      | Cloudflare Access Client ID (Prometheus scrape 인증용) |
| `CF_CLIENT_SECRET`  | Cloudflare Access Client Secret                        |

> `CF_CLIENT_ID` / `CF_CLIENT_SECRET`은 Terraform apply 후 아래 명령으로 확인할 수 있습니다.
>
> ```bash
> cd infra/terraform
> terraform output cf_access_client_id
> terraform output -raw cf_access_client_secret
> ```

---

## 실행 방법

### 접속 테스트

```bash
cd infra/ansible
ansible all -m ping
```

### 전체 플레이북 실행

```bash
ansible-playbook playbook.yml -e "storage_setup_enabled=false"
```

### 특정 호스트만 실행

```bash
ansible-playbook playbook.yml --limit aws-monitor -e "storage_setup_enabled=false"
ansible-playbook playbook.yml --limit gcp_primary
ansible-playbook playbook.yml --limit aws_nodes
```

---

## ansible.cfg 주요 설정

| 설정                | 값                             | 설명                                          |
| ------------------- | ------------------------------ | --------------------------------------------- |
| `inventory`         | `./inventory.ini`              | 인벤토리 파일 경로                            |
| `host_key_checking` | `False`                        | 최초 접속 시 SSH 지문 체크 생략               |
| `remote_user`       | `ubuntu`                       | 기본 접속 유저                                |
| `pipelining`        | `True`                         | SSH 연결 속도 최적화                          |
| `control_path`      | `/tmp/ansible-ssh-%%h-%%p-%%r` | Bastion ProxyCommand 사용 시 필요한 소켓 경로 |

---

## 참고사항

- K3s / Monitoring 서버는 Private Subnet에 배치되어 있어 Bastion ProxyCommand를 경유해서 접속합니다.
- Prometheus는 Cloudflare Zero Trust Tunnel을 경유해서 GCP / AWS 메트릭을 수집합니다. (`CF-Access` 헤더 인증)
- `monitoring` role은 Jinja2 템플릿(`templates/*.j2`)을 렌더링하여 설정을 서버에 배포합니다.
