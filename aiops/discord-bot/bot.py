import os
import asyncio
import discord
from discord import app_commands
from flask import Flask, request
from threading import Thread
import google.generativeai as genai

app = Flask(__name__)

# 환경변수 로드
TOKEN = os.getenv('DISCORD_BOT_TOKEN')
CHANNEL_ID = int(os.getenv('DISCORD_CHANNEL_ID'))
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
GRAFANA_URL = os.getenv('GRAFANA_URL', 'https://monitoring.bucheongoyangijanggun.com')

# Gemini 설정
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-1.5-flash')

class ChilseongpaBot(discord.Client):
    def __init__(self):
        super().__init__(intents=discord.Intents.default())
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        # 슬래시 커맨드 동기화
        await self.tree.sync()

bot = ChilseongpaBot()

# 1. 제미나이 분석 함수 (장애 데이터 기반 프롬프트 엔지니어링)
def ask_gemini(alert_data):
    try:
        prompt = f"""
        당신은 하이브리드 클라우드 보안 전문가입니다. 다음 Alertmanager의 장애 데이터를 분석하세요.
        데이터: {alert_data}
        
        요청 사항:
        1. 장애의 핵심 원인(Root Cause) 요약
        2. 긴급 조치 가이드 (GCP/AWS 환경 고려)
        3. 예방책 제안
        답변은 한국어로, 디스코드에서 보기 좋게 마크다운 형식을 사용하세요.
        """
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        return f"⚠️ AI 분석 중 오류 발생: {str(e)}"

# 2. Webhook Endpoint
@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    # Alertmanager로부터 온 알람 리스트 순회
    for alert in data.get('alerts', []):
        status = alert.get('status', 'firing').upper()
        summary = alert.get('annotations', {}).get('summary', 'No summary')
        
        # 비동기로 디스코드 전송
        asyncio.run_coroutine_threadsafe(
            process_alert(status, summary, alert), 
            bot.loop
        )
    return "OK", 200

async def process_alert(status, summary, alert_data):
    channel = bot.get_channel(CHANNEL_ID)
    if not channel: return

    # Gemini 분석 시작
    analysis = ask_gemini(alert_data)
    
    color = discord.Color.red() if status == 'FIRING' else discord.Color.green()
    embed = discord.Embed(title=f"[{status}] {summary}", color=color)
    embed.add_field(name="💡 AI 장애 분석 리포트", value=analysis, inline=False)
    embed.set_footer(text="Chilseongpa Monitoring System with Gemini")
    
    await channel.send(embed=embed)

# 3. 슬래시 커맨드: /dashboard
@bot.tree.command(name="dashboard", description="칠성파 통합 관제 대시보드 링크를 확인합니다.")
async def dashboard(interaction: discord.Interaction):
    embed = discord.Embed(
        title="🚀 칠성파 하이브리드 클라우드 대시보드",
        description="실시간 인프라 상태를 그라파나에서 확인하세요.",
        color=discord.Color.blue()
    )
    embed.add_field(name="URL", value=f"[Grafana 바로가기]({GRAFANA_URL})")
    await interaction.response.send_message(embed=embed)

# Flask 실행 스레드
def run_flask():
    app.run(host='0.0.0.0', port=5000)

if __name__ == '__main__':
    Thread(target=run_flask).start()
    bot.run(TOKEN)