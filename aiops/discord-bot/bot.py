import os
import requests
from flask import Flask, request
import discord
import asyncio
from threading import Thread

app = Flask(__name__)

# 환경변수 로드 (앤서블이 배달해줄 값들)
TOKEN = os.getenv('DISCORD_BOT_TOKEN')
CHANNEL_ID = int(os.getenv('DISCORD_CHANNEL_ID'))
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')

# 1. 제미나이 분석 함수
def ask_gemini(alert_data):
    # 여기서 Gemini API를 호출하여 장애 분석
    # (실제 구현 시 google-generativeai 라이브러리 사용)
    prompt = f"다음 서버 장애를 분석하고 조치 방법을 알려줘: {alert_data}"
    # ... API 호출 로직 ...
    return "AI 분석 결과: CPU 점유율이 높습니다. 80번 포트 프로세스를 확인하세요."

# 2. Alertmanager로부터 데이터를 받는 '귀' (Webhook Endpoint)
@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    analysis = ask_gemini(data) # 제미나이에게 물어보기
    
    # 디스코드로 전송 (비동기 처리)
    asyncio.run_coroutine_threadsafe(send_to_discord(analysis), loop)
    return "OK", 200

# 3. 디스코드로 메시지를 쏘는 '입'
async def send_to_discord(message):
    channel = bot.get_channel(CHANNEL_ID)
    if channel:
        await channel.send(f"🚨 **장애 분석 보고서** 🚨\n{message}")

# 봇 실행 환경 설정
intents = discord.Intents.default()
bot = discord.Client(intents=intents)
loop = asyncio.get_event_loop()

@bot.event
async def on_ready():
    print(f'Logged in as {bot.user}')

# Flask와 Discord Bot을 동시에 실행
if __name__ == '__main__':
    # Flask를 별도 스레드에서 실행
    Thread(target=lambda: app.run(host='0.0.0.0', port=5000)).start()
    bot.run(TOKEN)

