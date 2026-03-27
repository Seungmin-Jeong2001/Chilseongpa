# Chilseongpa Project Architecture

이 문서는 프로젝트의 하이브리드 멀티 클라우드 인프라 및 애플리케이션 아키텍처를 설명합니다.

## 1. 전체 시스템 아키텍처 (Hybrid Multi-Cloud)

```mermaid
graph TB
    subgraph "External / User"
        User((User))
        Discord((Discord))
    end

    subgraph "Cloudflare (Edge / Network)"
        CF_LB[Cloudflare Load Balancer]
        CF_Tunnel[Cloudflare Tunnel]
    end

    subgraph "GCP (Primary Region)"
        direction TB
        subgraph "GCP K3s Cluster"
            FE_G[Frontend: React/Nginx]
            BE_G[Backend: FastAPI]
            Proxy_G[Cloud SQL Auth Proxy]
        end
        DB[(Cloud SQL: MySQL)]
        Exporter_G[Node Exporter]
    end

    subgraph "AWS (Standby & Monitoring Region)"
        direction TB
        subgraph "AWS K3s Cluster (Standby)"
            FE_A[Frontend: React/Nginx]
            BE_A[Backend: FastAPI]
        end

        subgraph "Monitoring Stack (Private Subnet)"
            Prom[Prometheus]
            Grafana[Grafana]
            AM[Alertmanager]
            Bot[AIOps Discord Bot]
        end

        Bastion[AWS Bastion Host (Public Subnet)]
    end

    %% Traffic Flow
    User --> CF_LB
    CF_LB -- "Primary" --> CF_Tunnel -- "GCP Tunnel" --> FE_G
    CF_LB -- "Failover" --> CF_Tunnel -- "AWS Tunnel" --> FE_A
    
    FE_G --> BE_G
    BE_G --> Proxy_G --> DB

    %% Observability & AIOps Flow
    Prom --> Grafana
    Prom --> AM
    AM --> Bot
    Bot -- "AI Analysis" --> Gemini[Google Gemini AI]
    Bot -- "Webhook" --> Discord

    %% Metrics Collection (Primary Path: SSH Tunnel via Bastion)
    Prom -- "1. Scrape Request" --> Bastion
    Bastion -- "2. SSH Tunnel / Port Forwarding" --> Exporter_G
    Exporter_G -- "3. Metrics Data" --> Bastion
    Bastion -- "4. Response" --> Prom
```

---

## 2. 구성 요소 상세

### 2.1 Infrastructure (IaC)
- **Terraform**: AWS, GCP, Cloudflare 자원 관리 및 프로비저닝.
- **Ansible**: 인스턴스 초기 설정, K3s 설치, 모니터링 스택(Docker Compose) 배포.

### 2.2 Application Stack
- **Frontend**: React + Nginx (Dockerized).
- **Backend**: FastAPI (Python) - GCP Cloud SQL과 연결.
- **Database**: GCP Cloud SQL (MySQL 8.0), `Cloud SQL Auth Proxy`를 통해 보안 연결.
- **Orchestration**: K3s (Lightweight Kubernetes).

### 2.3 Observability & AIOps
- **Prometheus**: GCP/AWS 노드 및 애플리케이션 메트릭 수집.
- **Grafana**: 지표 시각화 대시보드.
- **Alertmanager**: 임계치 초과 시 경고 발생.
- **AIOps Bot**: `bot.py`가 Alertmanager의 웹훅을 수신하여 Gemini AI에 장애 분석 요청 후 디스코드로 보고.

---

## 3. 메트릭 수집 전략 (Bastion Bridge Scraping)

본 프로젝트는 비용 최적화를 위해 **NAT Gateway를 사용하지 않고**, AWS Bastion Host를 징검다리로 활용하여 프라이빗 서브넷에 위치한 Prometheus가 GCP의 데이터를 수집합니다.

### 3.1 작동 원리 (SSH Port Forwarding)
1.  **Bastion 연결**: Monitoring 서버(AWS Private)에서 Bastion(AWS Public)으로 SSH 연결을 생성합니다.
2.  **포트 포워딩**: Bastion의 특정 포트를 GCP 노드의 Node Exporter(9100) 포트와 터널링으로 연결합니다.
3.  **데이터 수집**: Prometheus는 `localhost` 또는 `Bastion IP`의 포워딩된 포트를 타겟으로 삼아 메트릭을 수집합니다.

### 3.2 장점 및 고려사항
*   **비용 절감**: 고가의 NAT Gateway 리소스를 생성하지 않고 기존 Bastion 리소스를 재활용합니다.
*   **보안**: 모든 통신이 SSH 암호화 터널을 통해 이루어지며, 외부로 직접 노출되는 포트를 최소화합니다.
*   **안정성**: Bastion은 Public/Private 서브넷 간의 유일한 게이트웨이 역할을 수행하며 통제된 통신 경로를 제공합니다.

---

## 4. 장애 대응 시나리오 (DR)
1.  **GCP 장애 발생**: Cloudflare Load Balancer가 헬스체크 실패를 감지.
2.  **자동 페일오버**: 모든 트래픽을 AWS Standby Cluster로 즉시 전환.
3.  **알림**: Alertmanager가 장애 감지 -> AIOps Bot이 Gemini 분석과 함께 디스코드 알림 발송.
