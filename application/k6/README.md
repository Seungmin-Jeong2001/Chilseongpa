# K6 – Single API Load Test

단일 API에 부하를 유입하여 **장애 징후, 모니터링 연계, Failover 관측 가능 여부를 검증하기 위한 k6 기반 부하 테스트 구성**

---

## 1. 개요

- 테스트 대상: GCP Primary Application 단일 API
- 목적:
    - 응답 지연 및 오류율 변화 확인
    - Prometheus 메트릭 수집 및 Alert 발생 여부 확인
    - AIOps 연계 (Discord Bot / Gemini) 확인
    - 장애 조건 충족 시 Failover 관측

---

## 2. 디렉터리 구조

```
application/k6
├── Dockerfile
├── scenarios
│   └── single_api_load.js
├── results/
├── .env.testk6
├── run_k6_test.sh
└── README.md
```

---

## 3. 실행 방식

k6는 애플리케이션 내부가 아닌 **외부 트래픽 생성기**로 동작한다.

```
k6
↓
Cloudflare
↓
GCP Primary App
↓
Prometheus
↓
Alertmanager
↓
Discord Bot / Gemini
```

장애 조건 충족 시:

```
Cloudflare Health Check 실패
↓
AWS Standby 전환
```

---

## 4. 실행 방법

### 테스트 대상 구분

- test.k6.io
  - k6 스크립트 및 Docker 실행 검증용
  - 장애 유도 및 Failover 검증 불가

- your-domain
  - 실제 부하 테스트 대상
  - 장애 유도 및 Failover 관측 가능

### 기본 실행

```bash
cd application/k6

TARGET_BASE_URL="https://your-domain.com" \
TARGET_API_PATH="/health" \
HTTP_METHOD="GET" \
VUS="10" \
DURATION="30s" \
./run_k6_test.sh

```

### POST API 테스트

```
cd application/k6

TARGET_BASE_URL="https://your-domain.com" \
TARGET_API_PATH="/api/test" \
HTTP_METHOD="POST" \
VUS="100" \
DURATION="2m" \
REQUEST_INTERVAL_MS="200" \
CONTENT_TYPE="application/json" \
HEADERS_JSON='{"X-Forwarded-For":"10.10.10.10","Cache-Control":"no-cache","Pragma":"no-cache","CDN-Loop":"k6-load-test"}' \
BODY_JSON='{}' \
./run_k6_test.sh
```

---

## 5. Docker 기반 실행 (권장)

k6는 Docker 컨테이너로 실행하며 `.env.testk6` 파일을 통해 테스트 설정을 관리한다.

### Docker 이미지 빌드

```
cd application/k6
docker build -t chilseongpa-k6 .
```

### 환경 변수 파일 구성

`application/k6/.env.testk6`

#### 검증용 (k6 공식 사이트)

```
TARGET_BASE_URL=https://test.k6.io
TARGET_API_PATH=/login
HTTP_METHOD=POST
VUS=50
DURATION=30s
CONTENT_TYPE=application/x-www-form-urlencoded
BODY_JSON={"username":"test","password":"test"}
WANT_503=false
```

#### 실제 부하 테스트

```
TARGET_BASE_URL=https://your-domain.com
TARGET_API_PATH=/api/test
HTTP_METHOD=POST
VUS=500
DURATION=3m
CONTENT_TYPE=application/json
HEADERS_JSON={"Cache-Control":"no-cache","Pragma":"no-cache"}
BODY_JSON={"key":"value"}
WANT_503=true
```

---

### 실행

```
$ts = Get-Date -Format "yyyyMMdd_HHmmss"

docker run --rm `
  --ulimit nofile=65535:65535 `
  --env-file .env.testk6 `
  -v "${PWD}:/work" `
  -w /work `
  chilseongpa-k6 `
  run scenarios/single_api_load.js `
  --dns ttl=0 `
  --summary-export "results/summary_$ts.json"
```

- `--dns ttl=0`
  - DNS 캐시를 비활성화하여 Failover 시 즉시 새로운 Origin으로 요청을 전환하기 위함

- `--ulimit nofile=65535:65535`
  - 대량 동시 연결 시 파일 디스크립터 부족으로 인한 테스트 실패를 방지하기 위함

---

## 6. 환경 변수

| 변수                  | 설명                                |
| ------------------- | --------------------------------- |
| TARGET_BASE_URL     | 대상 서버 URL                         |
| TARGET_API_PATH     | API 경로                            |
| HTTP_METHOD         | GET / POST / PUT / PATCH / DELETE |
| VUS                 | Virtual Users 수                   |
| DURATION            | 테스트 실행 시간                         |
| STAGES_JSON         | 단계별 부하 설정(JSON 배열 문자열)            |
| REQUEST_INTERVAL_MS | 요청 간 대기 시간(ms)                    |
| THRESHOLD_P95_MS    | p95 응답시간 기준(ms)                   |
| CONTENT_TYPE        | 요청 Content-Type                   |
| HEADERS_JSON        | 추가 헤더(JSON 문자열)                   |
| BODY_JSON           | 요청 Body(JSON 문자열)                 |
| WANT_503            | 503 응답 관측 여부                      |


---

## 7. 결과 파일

```
application/k6/results/summary_<timestamp>.json
```

### 주요 지표

- http_req_duration : 응답 시간
- http_req_failed : 실패율
- checks : 성공률
- http_503_count : 503 발생 횟수
- http_503_rate : 503 발생 비율

---

## 8. 주의 사항

- 단일 API만 테스트한다.
- 동일 조건에서 단계적으로 부하를 증가시켜야 한다.
- Failover 검증은 장애 조건 충족 시에만 확인한다.
- /health는 경량 Endpoint일 수 있으므로 503 유도에는 적합하지 않을 수 있다.

---

## 9. 실행 순서

1. application/k6 디렉터리 이동
2. Docker 이미지 빌드
3. run_k6_test.sh 실행 또는 docker run 직접 실행
4. 결과 파일 생성
5. Prometheus / Grafana / Alertmanager / Discord 알림 확인

---

## 10. 목적 정리

- 성능 벤치마크가 아니라 운영 검증
- 장애 발생 시 시스템 반응 확인
- 모니터링 및 자동화 흐름 검증
- Cloudflare 기반 Failover 동작 관측
  