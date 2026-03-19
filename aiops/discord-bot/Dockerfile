# 파이썬 3.9 슬림 버전: 용량 최적화와 보안성을 위해 경량 리눅스 이미지 사용
FROM python:3.9-slim

# 작업 디렉토리 생성
WORKDIR /app

# 라이브러리 설치 (캐싱을 위해 requirements.txt 먼저 복사)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 실제 봇 코드 복사
COPY bot.py .

# 웹훅을 받을 포트 58291 개방
EXPOSE 58291

# 봇 실행
CMD ["python", "bot.py"]