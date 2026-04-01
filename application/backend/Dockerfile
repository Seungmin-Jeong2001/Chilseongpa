# ==========================================
# 1단계: 빌더(Builder) 스테이지 (패키지 컴파일 및 설치)
# ==========================================
FROM python:3.10-slim AS builder

WORKDIR /app

# 패키지 컴파일에 필요한 도구 설치 (최종 이미지에는 안 들어감)
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev python3-dev && \
    rm -rf /var/lib/apt/lists/*

# 패키지 이동을 쉽게 하기 위해 도커 내부에서도 가상환경(venv) 생성
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 의존성 패키지 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ==========================================
# 2단계: 런타임(Runtime) 스테이지 (최종 이미지)
# ==========================================
FROM python:3.10-slim

WORKDIR /app

# 실행에만 필요한 아주 가벼운 DB 라이브러리(libpq5)만 설치
RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq5 curl netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

# 1단계(builder)에서 설치가 끝난 가상환경 폴더만 통째로 가져오기
COPY --from=builder /opt/venv /opt/venv

# 도커 환경변수를 가상환경으로 설정
ENV PATH="/opt/venv/bin:$PATH"

COPY main.py .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]