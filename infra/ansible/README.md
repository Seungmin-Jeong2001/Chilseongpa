# Ansible

Terraform으로 생성된 서버에 K3s, Docker, 모니터링 스택을 자동으로 구성합니다.

---

## 디렉토리 구조

```
ansible/
├── ansible.cfg                         # Ansible 기본 설정
├── inventory.ini                       # 서버 접속 정보 (Terraform apply 시 자동 생성)
├── playbook.yml                        # 전체 플레이북
├── secrets.sh                          # 환경변수 설정 스크립트 예시
├── group_vars/
│   └── all.yml                         # 공통 변수
└── roles/
    ├── node-exporter/tasks/main.yml    # Node Exporter v1.7.0 설치 및 systemd 등록
    ├── k3s/tasks/main.yml              # K3s 설치 (중복 설치 방지 포함)
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
            ├── docker-compose.yml.j2
            ├── datasource.yml.j2
            └── dashboard.yml.j2
```

---

## Playbook 구성

`playbook.yml` 실행 시 호스트 그룹에 따라 아래 순서로 역할을 수행합니다.

| Play | 대상 호스트 | 수행 작업 |
|---|---|---|
| 기본 환경 구성 | `all` | Node Exporter v1.7.0 설치 및 systemd 등록 |
| GCP K3s 구축 | `gcp_main` | K3s 독립 클러스터 설치 |
| AWS K3s 구축 | `aws_sub` | K3s 독립 클러스터 설치 |
| 모니터링 센터 구축 | `aws-monitor` | Docker CE 설치 → EBS 마운트 → Prometheus / Grafana / Alertmanager 실행 |

> `playbook.yml`의 호스트 그룹명(`gcp_main`, `aws_sub`, `aws-monitor`)과  
> `inventory.ini`의 호스트 별칭(`gcp-main`, `aws-sub`, `aws-monitor`)이 일치해야 합니다.

---

## 사전 준비

### 1. Ansible 설치

```bash
pip install ansible
```

### 2. inventory.ini 확인

`infra/terraform`에서 `terraform apply`를 완료하면 `inventory.ini`가 자동으로 생성됩니다.  
수동으로 작성할 경우 `infra/terraform/inventory.tpl`을 참고하세요.

생성된 `inventory.ini`의 구조는 아래와 같습니다.

```ini
[gcp_primary]
gcp-main ansible_host=<GCP_IP> tunnel_token=<...> db_conn=<...>

[aws_bastion]
aws-bastion ansible_host=<BASTION_PUBLIC_IP>

[aws_nodes]
aws-sub     ansible_host=<AWS_K3S_PUBLIC_IP>       tunnel_token=<...>
aws-monitor ansible_host=<MONITORING_PRIVATE_IP>   tunnel_token=<...>

[aws_nodes:vars]
# Monitoring 서버는 Private IP로 등록되며, Bastion을 ProxyCommand로 경유하여 접속합니다
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -q ubuntu@<BASTION_IP> ..."'

[all:vars]
ansible_user=ubuntu
cf_client_id="<...>"
cf_client_secret="<...>"
```

### 3. 환경변수 설정

`group_vars/all.yml`에서 아래 3개 값을 환경변수로 주입합니다.  
`secrets.sh`의 값을 채운 뒤 실행하세요.

```bash
# secrets.sh 수정 후
source infra/ansible/secrets.sh
```

| 환경변수 | 설명 |
|---|---|
| `ALERT_WEBHOOK_URL` | Discord Webhook URL (Alertmanager → Discord 알림 전송) |
| `CF_CLIENT_ID` | Cloudflare Access Client ID (Prometheus scrape 인증용) |
| `CF_CLIENT_SECRET` | Cloudflare Access Client Secret |

> `CF_CLIENT_ID` / `CF_CLIENT_SECRET`은 Terraform apply 후 아래 명령으로 확인할 수 있습니다.
> ```bash
> cd infra/terraform
> terraform output cf_access_client_id
> terraform output -raw cf_access_client_secret
> ```

### 참고: group_vars 고정 변수

환경변수가 아닌 `all.yml`에 직접 정의된 변수입니다.

| 변수 | 값 | 설명 |
|---|---|---|
| `project_name` | `chilseongpa` | 프로젝트명 |
| `node_exporter_version` | `1.7.0` | Node Exporter 설치 버전 |
| `ebs_device_name` | `/dev/xvdf` | Monitoring 서버 EBS 장치명 |

### 4. monitoring role 변수 확인

`monitoring` role의 EBS 마운트 작업은 `storage_setup_enabled` 변수로 활성화 여부를 제어합니다.  
이 변수는 `group_vars/all.yml`에 정의되어 있지 않으므로, 실행 전 직접 지정해야 합니다.

```bash
# EBS 마운트 포함하여 실행
ansible-playbook playbook.yml -e "storage_setup_enabled=true"

# EBS 마운트 없이 실행
ansible-playbook playbook.yml -e "storage_setup_enabled=false"
```

---

## 실행 방법

### 접속 테스트

```bash
cd infra/ansible
ansible all -m ping
```

### 전체 플레이북 실행

```bash
ansible-playbook playbook.yml -e "storage_setup_enabled=true"
```

### 특정 호스트만 실행

```bash
ansible-playbook playbook.yml --limit aws-monitor -e "storage_setup_enabled=true"
ansible-playbook playbook.yml --limit gcp_main
ansible-playbook playbook.yml --limit aws_sub
```

---

## ansible.cfg 주요 설정

| 설정 | 값 | 설명 |
|---|---|---|
| `inventory` | `./inventory.ini` | 인벤토리 파일 경로 |
| `host_key_checking` | `False` | 최초 접속 시 SSH 지문 체크 생략 |
| `remote_user` | `ubuntu` | 기본 접속 유저 |
| `pipelining` | `True` | SSH 연결 속도 최적화 |
| `control_path` | `/tmp/ansible-ssh-%%h-%%p-%%r` | Bastion ProxyCommand 사용 시 필요한 소켓 경로 |

---

## 참고사항

- Monitoring 서버(`aws-monitor`)는 Public IP가 있지만 `inventory.ini`에는 **Private IP**로 등록됩니다. Bastion을 ProxyCommand로 경유하여 접속하는 구조입니다.
- `monitoring` role은 Jinja2 템플릿(`templates/*.j2`)을 렌더링하여 Prometheus / Alertmanager / Grafana 설정을 서버에 배포합니다.
