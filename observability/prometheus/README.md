# Prometheus

AWS Monitoring Server (EC2 Private Subnet)에서 운영되는 Prometheus 설정 디렉토리
GCP / AWS 멀티 클러스터 메트릭을 수집하고 Alert Rule을 평가

---

## 디렉토리 구조

```
prometheus/
├── prometheus.yml            # Prometheus 메인 설정
├── alert.rules.yml           # Alert Rule (node / pod / cluster / backend)
└── README.md
```

---

## Scrape 대상

| job_name | 대상 | 수집 방식 | 포트 |
|----------|------|-----------|------|
| prometheus | Prometheus self | Direct | 9090 |
| gcp-cloudsql | stackdriver-exporter | localhost | 9255 |
| gcp-kubernetes-nodes | GCP Node Exporter | Zero Trust Tunnel | 443 |
| gcp-kubernetes-pods | GCP Pod /metrics | Zero Trust Tunnel | 443 |
| gcp-backend | GCP backend /actuator/prometheus | Zero Trust Tunnel | 443 |
| aws-kubernetes-nodes | AWS Node Exporter | Direct (kubernetes_sd) | 9100 |
| aws-kubernetes-pods | AWS Pod /metrics | Direct (kubernetes_sd) | - |
| aws-backend | AWS backend /actuator/prometheus | Direct (kubernetes_sd) | 8080 |

---

## 수집 메트릭

```
CPU Usage          node_cpu_seconds_total
Memory Usage       node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes
HTTP Status        backend_http_requests_total
Pod Status         kube_pod_status_phase
Container 재시작   kube_pod_container_status_restarts_total
JVM Memory         backend_jvm_memory_used_bytes / backend_jvm_memory_max_bytes
DB 연결            backend_db_connections_active
Cloud SQL CPU      cloudsql_cpu_utilization
Cloud SQL Memory   cloudsql_memory_used_bytes
```


## Alert Rule 임계값

| 항목 | warning | critical |
|------|---------|----------|
| Node CPU | 70% | 85% |
| Node Memory | 70% | 85% |
| HTTP 5xx Error Rate | 1% | 5% |
| HTTP 4xx Error Rate | 5% | 10% |
| Container Restart (5m) | 1회 | 5회 |
| Failed Pod | 1개 | 3개 |
| Pending Pod | 1개 | 3개 |
| JVM Heap | 80% | 90% |

[Threshold 기준 - Grafana Dashboard 패널과 동일]
Node CPU / Memory    : 70% → warning  / 85% → critical
HTTP 5xx Error Rate  : 1%  → warning  / 5%  → critical
HTTP 4xx Error Rate  : 5%  → warning  / 10% → critical
Container Restart    : 1회 → warning  / 5회 → critical (5m)
Failed Pod           : 1개 → warning  / 3개 → critical
Pending Pod          : 1개 → warning  / 3개 → critical

---
