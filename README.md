# Chilseongpa - Hybrid Multi-Cloud AIOps Platform

> KT Cloud 인프라 과정(2회차) 심화 프로젝트
> 

- Hybrid Multi-Cloud 환경(GCP / AWS) 기반 Kubernetes 서비스 운영 플랫폼
- Prometheus 기반 Observability와 LLM 기반 AIOps를 결합한 **장애 대응 및 운영 자동화 시스템**
- Active–Standby Hybrid Cloud 아키텍처 기반 서비스 구성
- Cloudflare Edge Routing 기반 자동 Failover 구조

---

# 1. Project Overview

Hybrid Multi-Cloud 환경 기반 서비스 운영 플랫폼

### 주요 목표

- Hybrid Multi-Cloud Infrastructure 운영
- Kubernetes 기반 서비스 배포
- Prometheus 기반 Observability 구축
- Cloudflare Edge Failover 구조 구현
- LLM 기반 AIOps 장애 분석 시스템

### 시스템 특징

| 항목 | 설명 |
| --- | --- |
| Multi-Cloud | GCP / AWS Hybrid Infrastructure |
| Deployment | Kubernetes 기반 컨테이너 배포 |
| Monitoring | Prometheus / Grafana |
| Alert System | Alertmanager 기반 장애 감지 |
| Edge Routing | Cloudflare Load Balancer |
| AIOps | Gemini API 기반 장애 분석 |

---

# 2. Architecture

Hybrid Multi-Cloud **Active–Standby 구조**

```
Users
   │
   ▼
Cloudflare Edge
(DNS / Load Balancer / Health Check)
   │
   ├───────────────┐
   │               │
   ▼               ▼
GCP Primary        AWS Standby
Kubernetes         Kubernetes
Cluster            Cluster
   │               │
   │               │
   └──────┬────────┘
          ▼
       Cloud SQL
```

### 주요 구성 요소

| 구성 요소 | 역할 |
| --- | --- |
| Cloudflare | Edge Routing / Health Check |
| GCP Kubernetes | Primary Application Cluster |
| AWS Kubernetes | Standby Application Cluster |
| Cloud SQL | Application Database |
| Monitoring Server | Prometheus 기반 Monitoring |
| AIOps Bot | Alert 기반 장애 분석 |

현재 DR 구조

```
Primary Application → GCP
Standby Application → AWS
Database → GCP
```

Application DR 중심 구조

---

# 3. Team Responsibilities

프로젝트 기능 영역 기반 역할 분리

| 담당 영역 | 최호성 | 한정현 · 이성호 | 서희정 | 박재은 | 정승민 |
| --- | --- | --- | --- | --- | --- |
| Role | Application / Kubernetes | Hybrid Cloud Infrastructure | Monitoring Infrastructure | Observability | AIOps |
| Platform / Infra | - | VPC / Compute / Kubernetes | Monitoring Server | - | - |
| Edge Routing | - | - | - | - | Cloudflare |
| CI/CD | - | - | - | - | GitHub Actions |
| Monitoring Infra | - | - | Prometheus / Grafana / Alertmanager | - | - |
| Observability | /metrics 제공 | - | - | Metric Scrape / Dashboard / Alert | - |
| Application | API / Container Image | - | - | - | - |
| Load Test | 부하 시나리오 | - | 테스트 환경 | 결과 분석 | - |
| AIOps | - | - | - | Alert 전달 | LLM 기반 장애 분석 |

---

# 4. System Workflow (End-to-End)

### Infrastructure 구축

- GCP Primary Kubernetes Cluster 구축
- AWS Standby Kubernetes Cluster 구축
- GCP Cloud SQL 생성
- AWS 환경 Cloud SQL 접근 허용 (Authorized Network)

### Edge Routing 및 CI/CD

- Cloudflare DNS 설정
- Cloudflare Load Balancer 구성
- Health Check 기반 Failover 정책
- GitHub Actions 기반 CI/CD Pipeline

### Monitoring Infrastructure

- GCP Monitoring Server
- Prometheus / Grafana / Alertmanager
- Kubernetes 관리 UI

### Application Deployment

- Backend API 서비스
- Docker Container Image
- Kubernetes Deployment
- Prometheus Metric Endpoint (`/metrics`)

### Observability 구성

- Prometheus Metric Scrape
- Grafana Dashboard
- Prometheus Alert Rule
- Alertmanager Webhook

### Load Test

- JMeter 기반 부하 테스트
- 시스템 성능 검증
- Monitoring 데이터 검증

### Alert System

- Prometheus Alert Trigger
- Alertmanager Webhook 전달

### AIOps 분석

- Discord Bot Alert 수신
- Gemini API 기반 장애 분석
- Discord 메시지 기반 결과 전달

### Failover

- Cloudflare Health Check
- Primary 장애 감지
- AWS Standby 트래픽 전환

---

# 5. Operational Architecture

운영 관점 **6계층 구조**

```
Client Layer
↓
Edge Routing Layer
↓
Application Layer
↓
Data Layer
↓
Monitoring / Observability Layer
↓
AIOps Layer
```

### Layer 역할

| Layer | 역할 |
| --- | --- |
| Client | 사용자 요청 |
| Edge Routing | Cloudflare 트래픽 제어 |
| Application | Kubernetes 기반 서비스 |
| Data | Cloud SQL |
| Monitoring | Prometheus 기반 시스템 관측 |
| AIOps | LLM 기반 장애 분석 |

---

# 6. CI/CD Pipeline

GitHub 기반 자동 배포 구조

```
GitHub Repository
     │
     ▼
GitHub Actions
     │
     ▼
Docker Image Build
     │
     ▼
Container Registry
     │
     ▼
kubectl apply
     │
     ├── GCP Kubernetes Cluster
     └── AWS Kubernetes Cluster
```

### 배포 전략

Primary / Standby 동일 버전 유지

```
Primary / Standby 동시 배포
```

---

# 7. Observability

중앙 Monitoring Server 기반 관측 시스템

```
Application Pod /metrics
       │
       ▼
Prometheus
(GCP Monitoring Server)
       │
       ├── Grafana Dashboard
       └── Alertmanager
              │
              ▼
           Discord Bot
              │
              ▼
           Gemini API
```

### 주요 기능

- Kubernetes Cluster Metrics 수집
- Application Metrics 수집
- Grafana Dashboard 시각화
- Alert 기반 장애 탐지

---

# 8. Failure Handling

장애 발생 시 **Failover + 장애 분석 동시 수행**

### Failover

```
GCP Primary 장애
↓
Cloudflare Health Check 실패
↓
AWS Standby 트래픽 전환
```

Cloudflare 기반 자동 장애 전환

### 장애 분석

```
Prometheus Alert
↓
Alertmanager
↓
Discord Bot
↓
Gemini 분석
```

LLM 기반 장애 원인 분석

---

# 9. Project Structure

```
chilseongpa
 ├ infra
 │   ├ hybrid-cloud
 │   │   ├ gcp
 │   │   │   ├ terraform
 │   │   │   └ ansible
 │   │   └ aws
 │   │       ├ terraform
 │   │       └ ansible
 │   │
 │   └ monitoring-infra
 │       ├ terraform
 │       └ ansible
 │
 ├ application
 │   ├ backend
 │   └ k8s
 │
 ├ observability
 │   ├ prometheus
 │   ├ grafana
 │   └ alertmanager
 │
 ├ platform
 │   └ cicd
 │
 └ aiops
     └ discord-bot
```

### Directory 역할

| Directory | 역할 |
| --- | --- |
| infra | Hybrid Cloud Infrastructure |
| application | Backend Application |
| observability | Monitoring / Observability |
| platform | CI/CD Pipeline |
| aiops | AIOps 운영 자동화 |