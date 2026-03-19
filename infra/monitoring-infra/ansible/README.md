# Monitoring Server Configuration - Ansible

## 프로젝트 목적

AWS Private Subnet에 구성된 **Monitoring Server**에 대해   
Prometheus, Grafana, Alertmanager 기반 **Monitoring Stack**을 Ansible로 자동 설치 및 구성합니다.

- Docker 기반 Monitoring Stack 구성
- Prometheus / Grafana / Alertmanager 자동 배포
- Cloudflare Zero Trust 기반 Kubernetes 메트릭 수집
- Bastion Host를 통한 운영자 접근 제어
- EBS 마운트 및 데이터 영속성 구성
- 동일 환경 재현 가능한 서버 설정 자동화
    

---

## Ansible 구조

```
ansible/
├ inventory/
│  ├ local.ini
│  └ aws.ini
├ group_vars/
│  └ all.yml
├ roles/
│  ├ docker/                     # Docker 설치 및 설정
│  │  ├ tasks/main.yml
│  │  └ handlers/main.yml
│  └ monitoring/                 # Monitoring Stack 구성 및 실행
│     ├ tasks/main.yml
│     ├ handlers/main.yml
│     └ templates/               # Prometheus / Alertmanager / Grafana 설정 템플릿
│        ├ prometheus.yml.j2
│        ├ docker-compose.yml.j2
│        ├ alertmanager.yml.j2
│        ├ alert.rules.yml.j2
│        ├ datasource.yml.j2
│        └ dashboard.yml.j2
├ site.yml                      # 전체 배포 진입점
└ README.md
```

---

## inventory / 변수 설정

### local vs aws 차이
- local: 빠른 검증을 위해 Role 내부 templates 파일 사용
- aws: 실제 운영 환경으로 observability 레이어 설정 파일 사용
- config_render_mode는 Prometheus 및 Grafana provisioning 파일 처리 방식(template/copy) 제어
  - prometheus.yml
  - grafana datasource
  - grafana dashboard provider
- Alertmanager 및 Alert Rule 파일은 template 방식으로 고정

### inventory/aws.ini
- 운영 환경 대상 서버 정보
- Ansible 실행 환경(Controller) 내 /opt/chilseongpa 경로에 clone된 repository 기준으로 observability 설정 파일을 참조
- observability 설정 파일은 Monitoring Server가 아니라 Ansible 실행 환경에 존재 필요

### inventory/local.ini
- 로컬 검증용 Inventory
- EBS 마운트 및 디스크 작업 제외
- Ansible Role 내부 templates 디렉토리를 기준으로 파일을 참조

### group_vars/all.yml
- GitHub Actions에서 환경 변수로 주입
    - `CF_CLIENT_ID` : Cloudflare Access Client ID
    - `CF_CLIENT_SECRET` : Cloudflare Access Client Secret
    - `ALERT_WEBHOOK_URL` : Discord Webhook URL

---

## Ansible 실행

### 1. 문법 검증

```
ansible-playbook -i inventory/aws.ini site.yml --syntax-check
```

### 2. Ping 확인

```
ansible all -i inventory/aws.ini -m ping
```

### 3. 배포 실행

```
ansible-playbook -i inventory/aws.ini site.yml
```

### 4. 특정 Role만 실행

```
ansible-playbook -i inventory/aws.ini site.yml --tags docker
ansible-playbook -i inventory/aws.ini site.yml --tags monitoring
```

---

## 핵심 구성 요소

### docker 역할

- Docker Engine 및 Compose 설치
- Docker daemon 설정
- Docker 서비스 활성화 및 자동 시작

### monitoring 역할

- Prometheus / Grafana / Alertmanager 구성 및 실행
- Docker Compose 기반 서비스 배포
- Grafana provisioning 자동 적용
- Alert Rule 및 Webhook 설정
- EBS 마운트 및 데이터 디렉토리 권한 설정
- Prometheus Lifecycle API 기반 설정 reload

---

## 보안 및 네트워크 모델

- 관리 트래픽: Bastion Host 경유 SSH 및 UI 접근
- 메트릭 수집: Cloudflare Zero Trust 기반 outbound HTTPS
- Public IP 직접 접근 없음
- Private Subnet 기반 운영
- 최소 권한(Least Privilege) 적용

---

## Monitoring Stack 동작 구조

- Prometheus는 Kubernetes로부터 inbound 요청을 받지 않는다.
- Prometheus는 Cloudflare Zero Trust Tunnel을 통해 outbound 방식으로 `/metrics`를 수집한다.
- Monitoring Server는 운영자만 Bastion Host를 통해 접근한다.
- Grafana / Prometheus / Alertmanager UI는 Bastion 경유 접근만 허용한다.

---
## Prometheus 설정 Reload 조건

- Prometheus 컨테이너 실행 시 --web.enable-lifecycle 옵션 활성화 필요
- 해당 옵션이 없으면 /-/reload API 호출 동작 x 

---

## Observability 연동 구조

- observability 디렉토리는 Prometheus, Grafana, Alertmanager 설정의 단일 원본(Source of Truth)
- monitoring-infra는 해당 설정을 배포하는 역할만 수행
- 설정 변경은 observability 레이어에서 관리

---

## 실행 결과 디렉토리

- monitoring_base_dir (예: /opt/monitoring, /workspace/.monitoring)는 Ansible 실행 시 생성되는 runtime 디렉토리다.
- docker-compose.yml 및 Prometheus / Grafana / Alertmanager 설정 파일이 이 경로에 배치된다.
- 해당 디렉토리는 Git에 포함하지 않는다.

---

## 검증 포인트

### 로컬 검증

- Ansible 문법 확인
- 템플릿 렌더링 확인
- docker-compose.yml 생성 확인
- Prometheus / Alertmanager 설정 파일 생성 확인
- Grafana provisioning 파일 생성 확인

### AWS 검증

- EBS 자동 mount 확인
- `/var/lib/prometheus`, `/var/lib/grafana` 권한 확인
- Docker daemon 정상 동작 확인
- Monitoring Stack 컨테이너 실행 확인
- Prometheus scrape 정상 확인
- Alert 발생 및 Discord 전송 확인
- 재부팅 후 자동 기동 확인

---

## 운영 확인 명령어

### 컨테이너 상태 확인

```
docker ps
```

### Prometheus readiness 확인

```
# readiness 확인
curl http://localhost:9090/-/ready

# 설정 reload (필요 시)
curl -X POST http://localhost:9090/-/reload
```

### Alertmanager readiness 확인

```
curl http://localhost:9093/-/ready
```

---

## 장애 확인 포인트

- SSH 접속 실패
    - `ProxyJump` 설정 확인
    - Bastion 접근 가능 여부 확인
- 환경 변수 누락
    - `CF_CLIENT_ID`
    - `CF_CLIENT_SECRET`
    - `ALERT_WEBHOOK_URL`
- Docker 실행 실패
    - daemon 상태 확인
    - `docker ps` / `systemctl status docker`
- UI 접근 실패
    - 3000 / 9090 / 9093 포트 포워딩 및 Security Group 확인
- Prometheus scrape 실패
    - Cloudflare Access 인증 헤더 확인
    - 대상 endpoint DNS 및 HTTPS 응답 확인

### EBS 디바이스 주의사항
- AWS Nitro 기반 인스턴스에서는 디바이스명이 /dev/xvdf가 아닌 /dev/nvme* 형태로 변경될 수 있다.
- ebs_device_name 변수는 실제 attach된 디바이스 기준으로 확인 후 설정해야 한다.
- 잘못된 디바이스 지정 시 mount 실패 발생
  