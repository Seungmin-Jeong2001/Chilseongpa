# 1. 가벼운 파이썬 3.11 이미지 사용
FROM python:3.11-slim

# 2. 작업 디렉토리 설정
WORKDIR /app

# 3. 필수 도구 설치 및 캐시 정리 
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl get-docker.sh \
    && apt-get purge -y --auto-remove curl \
    && rm -rf /var/lib/apt/lists/* # 4. 필수 라이브러리 설치 (레이어 캐싱 활용)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. 봇 소스코드 및 필요한 파일 복사
COPY bot.py .

# 6. Alertmanager 웹훅 포트 개방
EXPOSE 5000

# 7. 봇 실행
CMD ["python", "bot.py"]