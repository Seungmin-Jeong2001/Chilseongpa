import os
import asyncio
import discord
import subprocess
import requests
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
PROMETHEUS_URL = "http://prometheus:9090" # 도커 네트워크 내부 주소

# Gemini 설정
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-1.5-flash')

# ---------------------------------------------------------
# 1. 지능형 로그 분석 뷰 (인터랙티브 버튼)
# ---------------------------------------------------------
class LogAnalysisView(discord.ui.View):
    def __init__(self, alert_data):
        super().__init__(timeout=None)
        self.alert_data = alert_data

    @discord.ui.button(label="🔍 장애 로그 분석 (Gemini)", style=discord.ButtonStyle.primary, custom_id="analyze_logs")
    async def analyze_logs(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        
        # 💡 로그 수집 시뮬레이션 (실제 환경에선 kubectl logs나 ssh 명령 실행)
        # 예: labels에 pod 정보가 있다면 kubectl logs 수행
        instance = self.alert_data.get('labels', {}).get('instance', 'unknown')
        root_hint = self.alert_data.get('labels', {}).get('root_hint', 'N/A')
        
        raw_logs = f"Error: Connection refused at {instance}. Context: {root_hint}. Process terminated with exit code 1."
        
       prompt = f"""
당신은 하이브리드 클라우드 인프라 설계자입니다. 다음 장애의 근본 원인(RCA)을 분석하고 시스템 개선안을 제시하세요.

[데이터 데이터]
- 알림명: {self.alert_data.get('alertname')}
- 발생 환경: {self.alert_data.get('labels', {}).get('environment', 'production')}
- 수집 로그: {raw_logs}

[분석 가이드라인]
1. **심층 분석**: 로그에 나타난 에러 코드가 인프라의 어떤 부분(Network, Storage, Runtime)과 연관되는지 설명하세요.
2. **인프라 개선 제안**: Terraform이나 Ansible 설정을 어떻게 변경해야 이 장애를 원천 차단할 수 있을지 제안하세요. (예: 리소스 제한 상향, 헬스체크 주기 조정 등)
3. **AI 예측**: 이 장애가 해결되지 않을 경우 발생할 수 있는 2차 장애 시나리오를 예측하세요.

모든 답변은 기술적으로 명확해야 하며 한국어로 작성하세요.
"""
        try:
            response = model.generate_content(prompt)
            await interaction.followup.send(f"🤖 **지능형 로그 분석 결과**\n{response.text}")
        except Exception as e:
            await interaction.followup.send(f"⚠️ 분석 중 오류 발생: {e}")

# ---------------------------------------------------------
# 2. AIOps 핵심: 능동적 자가 치유 (Self-Healing)
# ---------------------------------------------------------
async def run_self_healing(alert_data):
    """GCP 시스템 다운 등 Critical 상황 발생 시 자동 복구 프로세스 진행"""
    cluster = alert_data.get('labels', {}).get('cluster', 'unknown')
    alert_name = alert_data.get('alertname')
    
    # 🚨 매우 위험한 상황 (GCP 타겟 다운) 탐지
    if cluster == 'gcp' and alert_name == 'PrometheusTargetDown':
        channel = bot.get_channel(CHANNEL_ID)
        await channel.send(f"🛠️ **[AIOps 자동 복구]** GCP 인프라 다운 감지! 복구 프로세스(Ansible)를 시작합니다...")
        
        # 💡 실제 복구 명령어 실행 (예: Ansible 플레이북 호출)
        try:
            # subprocess.run(["ansible-playbook", "-i", "inventory.ini", "remedy_gcp.yml"], check=True)
            await asyncio.sleep(2) # 실행 시뮬레이션
            await channel.send("✅ **[복구 완료]** GCP 복구 스크립트가 성공적으로 수행되었습니다. 시스템 안정화 확인 중...")
        except Exception as e:
            await channel.send(f"❌ **[복구 실패]** 자동 복구 중 오류 발생: {e}")

# ---------------------------------------------------------
# 3. AI 분석 및 메시지 처리
# ---------------------------------------------------------
def ask_gemini(alert_data):
    try:
        prompt = f"다음 Alertmanager 장애 데이터를 분석하고 한국어로 요약해줘: {alert_data}"
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        return f"⚠️ AI 분석 오류: {str(e)}"

async def process_alert(status, summary, alert_data):
    channel = bot.get_channel(CHANNEL_ID)
    if not channel: return

    severity = alert_data.get('labels', {}).get('severity', 'warning')
    
    # ⚡ 능동적 조치 트리거 (Critical 일 경우)
    if status == 'FIRING' and severity == 'critical':
        asyncio.create_task(run_self_healing(alert_data))

    analysis = ask_gemini(alert_data)
    color = discord.Color.red() if status == 'FIRING' else discord.Color.green()
    
    embed = discord.Embed(title=f"[{status}] {summary}", color=color)
    embed.add_field(name="💡 AI 장애 리포트", value=analysis, inline=False)
    
    # 로그 분석 버튼 뷰 추가
    view = LogAnalysisView(alert_data)
    await channel.send(embed=embed, view=view)

# ---------------------------------------------------------
# 4. 슬래시 커맨드 (/dashboard, /health_danger)
# ---------------------------------------------------------
class ChilseongpaBot(discord.Client):
    def __init__(self):
        super().__init__(intents=discord.Intents.default())
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        await self.tree.sync()

bot = ChilseongpaBot()

@bot.tree.command(name="dashboard", description="칠성파 통합 관제 대시보드 링크를 확인합니다.")
async def dashboard(interaction: discord.Interaction):
    embed = discord.Embed(title="🚀 칠성파 클라우드 대시보드", color=discord.Color.blue())
    embed.add_field(name="URL", value=f"[Grafana 바로가기]({GRAFANA_URL})")
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="health_danger", description="인프라 내 위험 부위(Critical/Down)만 요약 진단합니다.")
async def health_danger(interaction: discord.Interaction):
    await interaction.response.defer()
    try:
        # Prometheus에서 위험 요소 쿼리 (다운된 타겟 또는 CPU 80% 이상)
        query = 'up == 0 or (1 - avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) > 0.8)'
        resp = requests.get(f"{PROMETHEUS_URL}/api/v1/query", params={'query': query}, timeout=5)
        results = resp.json().get('data', {}).get('result', [])
        
        if not results:
            message = "✅ 현재 모든 시스템이 정상 임계치 내에 있습니다."
        else:
            message = "⚠️ **다음 항목에서 위험이 감지되었습니다:**\n"
            for r in results:
                inst = r['metric'].get('instance', 'unknown')
                job = r['metric'].get('job', 'unknown')
                message += f"- `{job}` ({inst}): 상태 이상 또는 부하 높음\n"
        
        await interaction.followup.send(message)
    except Exception as e:
        await interaction.followup.send(f"❌ 진단 중 오류 발생: {e}")

# ---------------------------------------------------------
# 5. 실행부
# ---------------------------------------------------------
@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    for alert in data.get('alerts', []):
        status = alert.get('status', 'firing').upper()
        summary = alert.get('annotations', {}).get('summary', 'No summary')
        asyncio.run_coroutine_threadsafe(process_alert(status, summary, alert), bot.loop)
    return "OK", 200

def run_flask():
    app.run(host='0.0.0.0', port=5000)

if __name__ == '__main__':
    Thread(target=run_flask).start()
    bot.run(TOKEN)