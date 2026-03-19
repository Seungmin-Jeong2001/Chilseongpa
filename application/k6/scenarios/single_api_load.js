import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter, Rate } from 'k6/metrics';

// ------------------------------
// Environment Variables
// 실행 시 docker / CLI에서 주입되는 설정값
// ------------------------------
const TARGET_BASE_URL = (__ENV.TARGET_BASE_URL || '').trim();   // 대상 도메인 (필수)
const TARGET_API_PATH = (__ENV.TARGET_API_PATH || '/health').trim(); // 호출 API 경로
const HTTP_METHOD = (__ENV.HTTP_METHOD || 'GET').trim().toUpperCase(); // HTTP 메서드

const REQUEST_INTERVAL_MS = Number(__ENV.REQUEST_INTERVAL_MS || 0); // 요청 간 sleep(ms)
const THRESHOLD_P95_MS = Number(__ENV.THRESHOLD_P95_MS || 3000); // p95 기준값
const CONTENT_TYPE = (__ENV.CONTENT_TYPE || 'application/json').trim(); // 요청 타입
const HEADERS_JSON = (__ENV.HEADERS_JSON || '').trim(); // 추가 헤더(JSON 문자열)
const BODY_JSON = (__ENV.BODY_JSON || '').trim(); // 요청 바디(JSON 문자열)

const VUS = Number(__ENV.VUS || 100); // 최대 동시 사용자 수
const DURATION = (__ENV.DURATION || '2m').trim(); // 최대 부하 유지 시간
const STAGES_JSON = (__ENV.STAGES_JSON || '').trim(); // 사용자 정의 단계 설정

const WANT_503 = String(__ENV.WANT_503 || 'true').toLowerCase() === 'true'; // 장애 유도 여부

// ------------------------------
// Custom Metrics
// k6 기본 메트릭 외 추가로 503 관측용
// ------------------------------
const http503Count = new Counter('http_503_count'); // 503 총 발생 횟수
const http503Rate = new Rate('http_503_rate');      // 503 발생 비율

// ------------------------------
// Validation
// 필수 입력값 검증 (초기 실행 실패 방지)
// ------------------------------
if (!TARGET_BASE_URL) {
  throw new Error('TARGET_BASE_URL is required');
}

if (!TARGET_API_PATH.startsWith('/')) {
  throw new Error('TARGET_API_PATH must start with "/"');
}

// 최종 요청 URL 생성 (슬래시 중복 방지)
const FULL_URL = `${TARGET_BASE_URL.replace(/\/$/, '')}${TARGET_API_PATH}`;

// ------------------------------
// Helpers
// ------------------------------

// JSON 문자열 → 객체 변환
function parseJsonOrEmpty(raw, fieldName) {
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch (error) {
    throw new Error(`${fieldName} must be valid JSON: ${error.message}`);
  }
}

// 부하 단계 구성 (ramping-vus)
function buildStages() {
  if (STAGES_JSON) {
    try {
      const parsed = JSON.parse(STAGES_JSON);

      if (!Array.isArray(parsed)) {
        throw new Error('STAGES_JSON must be an array');
      }

      return parsed;
    } catch (error) {
      throw new Error(`Invalid STAGES_JSON: ${error.message}`);
    }
  }

  // 기본 단계: 25% → 50% → 75% → 100%
  return [
    { duration: '30s', target: Math.max(10, Math.floor(VUS * 0.25)) },
    { duration: '30s', target: Math.max(30, Math.floor(VUS * 0.5)) },
    { duration: '30s', target: Math.max(50, Math.floor(VUS * 0.75)) },
    { duration: DURATION, target: VUS },
  ];
}

// Content-Type에 맞게 request body 생성
function buildRequestBody(bodyObject) {
  if (HTTP_METHOD === 'GET') {
    return null;
  }

  // form-urlencoded 처리
  if (CONTENT_TYPE === 'application/x-www-form-urlencoded') {
    return Object.entries(bodyObject)
      .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`)
      .join('&');
  }

  // 기본 JSON
  return JSON.stringify(bodyObject);
}

// ------------------------------
// Header / Body 구성
// ------------------------------
const extraHeaders = parseJsonOrEmpty(HEADERS_JSON, 'HEADERS_JSON');
const requestBodyObject = parseJsonOrEmpty(BODY_JSON, 'BODY_JSON');

// 기본 헤더 + 캐시 우회 (Cloudflare 대응)
const requestHeaders = {
  'Content-Type': CONTENT_TYPE,
  'Cache-Control': 'no-cache',
  Pragma: 'no-cache',
  'CDN-Loop': 'k6-load-test',
  ...extraHeaders,
};

const requestBody = buildRequestBody(requestBodyObject);
const stages = buildStages();

// ------------------------------
// Options (k6 설정)
// ------------------------------
export const options = {
  scenarios: {
    overload_test: {
      executor: 'ramping-vus', // 점진적 부하 증가
      startVUs: 0,
      stages,
      gracefulRampDown: '0s', // 종료 시 즉시 감소
    },
  },
  thresholds: {
    // 공통 기준
    http_req_duration: [`p(95)<${THRESHOLD_P95_MS}`],

    // 테스트 목적에 따라 기준 분리
    ...(WANT_503
      ? {
          http_503_rate: ['rate>0'], // 장애 발생 확인
        }
      : {
          http_req_failed: ['rate<0.05'], // 실패율 제한
          checks: ['rate>0.95'], // 정상 응답 비율
        }),
  },
};

// ------------------------------
// Request Dispatcher
// 실제 HTTP 요청 수행
// ------------------------------
function sendRequest() {
  const params = {
    headers: requestHeaders,
    timeout: '30s',
    tags: {
      endpoint: TARGET_API_PATH,
      method: HTTP_METHOD,
      test_type: WANT_503 ? 'failure-observation' : 'normal-validation',
    },
  };

  switch (HTTP_METHOD) {
    case 'GET':
      return http.get(FULL_URL, params);
    case 'POST':
      return http.post(FULL_URL, requestBody, params);
    case 'PUT':
      return http.put(FULL_URL, requestBody, params);
    case 'PATCH':
      return http.patch(FULL_URL, requestBody, params);
    case 'DELETE':
      return http.del(FULL_URL, requestBody, params);
    default:
      throw new Error(`Unsupported HTTP_METHOD: ${HTTP_METHOD}`);
  }
}

// ------------------------------
// Main Execution Loop
// VU마다 반복 실행
// ------------------------------
export default function () {
  const response = sendRequest();

  const is503 = response.status === 503;

  // 503 발생 추적
  if (is503) {
    http503Count.add(1);
    http503Rate.add(true);
  } else {
    http503Rate.add(false);
  }

  // 기본 응답 검증
  check(response, {
    'response received': (res) => res !== null,
    'status valid': (res) =>
      (res.status >= 200 && res.status < 400) || res.status === 503,
  });

  // 요청 간 간격 제어
  if (REQUEST_INTERVAL_MS > 0) {
    sleep(REQUEST_INTERVAL_MS / 1000);
  }
}