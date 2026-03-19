import os
import discord
from discord.ext import commands
import google.generativeai as genai
from flask import Flask, request, jsonify
import threading

# 1. 환경변수 로드: 보안을 위해 코드 내에 키값을 직접 적지 않음 (Kubernetes Secret/환경변수 사용)
GEMINI_KEY = os.getenv("GEMINI_API_KEY")
DISCORD_TOKEN = os.getenv("DISCORD_BOT_TOKEN")
CHANNEL_ID = int(os.getenv("DISCORD_CHANNEL_ID", 0))

# 2. Gemini AI 설정: 구글의 LLM 모델을 사용하여 장애 원인을 분석함
genai.configure(api_key=GEMINI_KEY)
model = genai.GenerativeModel('gemini-1.5-flash')

# 3. 디스코드 봇 설정: 인텐트는 봇이 디스코드 내에서 수행할 권한임
intents = discord.Intents.default()
bot = commands.Bot(command_prefix="!", intents=intents)
app = Flask(__name__)

# 4. 웹훅 수신: Alertmanager가 보낸 JSON 데이터를 분석함
@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    # AI 프롬프트 구성: 원인 분석을 위한 상황 전달
    # 장애 데이터가 어떻게 오냐 따라 수정해야함
    #prompt = f"다음은 시스템 장애 알림이야. 원인 분석과 조치 방안을 간결하게 작성해줘:\n{str(data)}"
    response = model.generate_content(prompt)
    
    # 디스코드 메시지 전송 (비동기 루프에 작업 추가)
    bot.loop.create_task(send_alert(response.text))
    return jsonify({"status": "received"}), 200

async def send_alert(message):
    channel = bot.get_channel(CHANNEL_ID)
    if channel:
        await channel.send(f"🚨 **[장애 분석 보고서]**\n{message}")

# 5. 서버 실행: Flask 웹 서버를 별도 스레드에서 돌려 디스코드와 공존시킴
def run_flask():
    app.run(host='0.0.0.0', port=58291)

if __name__ == '__main__':
    threading.Thread(target=run_flask, daemon=True).start()
    bot.run(DISCORD_TOKEN)