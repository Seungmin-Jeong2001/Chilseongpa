
# aiops/Dockerfile
FROM python:3.10-slim

WORKDIR /app

# 필수 라이브러리 설치 (discord.py, flask, google-generativeai 등)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 봇 소스코드 복사
COPY bot.py .

# Alertmanager의 웹훅을 받을 포트 (예: 5000)
EXPOSE 5000

CMD ["python", "bot.py"]