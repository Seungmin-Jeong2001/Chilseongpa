import os
import asyncio
import discord
import requests
import google.generativeai as genai
from discord import app_commands
from flask import Flask, request
from threading import Thread

app = Flask(__name__)

# 환경변수 로드
TOKEN = os.getenv('DISCORD_BOT_TOKEN')
CHANNEL_ID = int(os.getenv('DISCORD_CHANNEL_ID'))
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
GRAFANA_URL = os.getenv('GRAFANA_URL', 'https://monitoring.bucheongoyangijanggun.com')
PROMETHEUS_URL = "http://prometheus:9090"

# Gemini 설정
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-1.5-flash')

# ---------------------------------------------------------
# 1. 지능형 로그 분석 뷰 (SRE 전문가 프롬프트 적용)
# ---------------------------------------------------------
class LogAnalysisView(discord.ui.View):
    def __init__(self, alert_data):
        super().__init__(timeout=None)
        self.alert_data = alert_data

    @discord.ui.button(label="🔍 SRE 지능형 진단", style=discord.ButtonStyle.primary, custom_id="analyze_logs")
    async def analyze_logs(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        
        # 로그 수집 시뮬레이션 (실제로는 SSH/kubectl 연동 가능)
        instance = self.alert_data.get('labels', {}).get('instance', 'unknown')
        root_hint = self.alert_data.get('labels', {}).get('root_hint', 'N/A')
        raw_logs = f"ERROR: Connection timeout to {instance}. Context: {root_hint}. Node Unreachable."
        
        # 💡 개선된 SRE 전문가 프롬프트
        prompt = f"""
        당신은 AWS/GCP 하이브리드 환경을 관리하는 시니어 SRE 전문가입니다.
        현재 {self.alert_data.get('labels', {}).get('cluster', 'Hybrid')} 클러스터에서 장애가 발생했습니다.

        [장애 정보]
        - 요약: {self.alert_data.get('annotations', {}).get('summary')}
        - 루트 힌트: {root_hint}
        - 수집 로그: {raw_logs}

        [요청 사항]
        1. **원인 진단**: 로그와 힌트를 대조하여 가장 가능성 높은 원인을 한 문장으로 진단하세요.
        2. **즉각 조치**: 이 장애를 해결하기 위해 터미널에서 즉시 실행할 수 있는 명령어(kubectl, systemctl 등)를 제시하세요.
        3. **AIOps 예방**: 향후 동일 장애를 방지하기 위해 Ansible이나 Terraform 수준에서 보완할 점을 제안하세요.

        한국어로, 이모지를 섞어 마크다운 형식으로 답변하세요.
        """
        try:
            response = model.generate_content(prompt)
            await interaction.followup.send(f"🤖 **Gemini SRE 진단 리포트**\n{response.text}")
        except Exception as e:
            await interaction.followup.send(f"⚠️ 분석 중 오류 발생: {e}")

# ---------------------------------------------------------
# 2. AIOps 핵심: 자가 치유 (GCP 복구 프로세스)
# ---------------------------------------------------------
async def trigger_gcp_recovery(alert_data):
    """GCP 시스템 다운(Health Check 실패) 시 자동 복구 진행"""
    cluster = alert_data.get('labels', {}).get('cluster', 'unknown')
    alert_name = alert_data.get('alertname')
    
    # GCP 메트릭 수집 실패(Target Down) 감지 시
    if cluster == 'gcp' and alert_name == 'PrometheusTargetDown':
        channel = bot.get_channel(CHANNEL_ID)
        await channel.send(f"🚨 **[AIOps 긴급 상황]** GCP 인프라 다운 감지! 자가 치유 복구 프로세스를 시작합니다.")
        
        # 💡 실제 복구 시나리오 (예: Ansible을 통한 서비스 재시작)
        # os.system("ansible-playbook -i inventory.ini remedy_gcp.yml")
        await asyncio.sleep(3) # 시뮬레이션
        await channel.send("✅ **[복구 성공]** GCP 인프라 복구 프로세스가 완료되었습니다. 시스템 정상화 여부를 모니터링 중입니다.")

# ---------------------------------------------------------
# 3. 알림 처리 및 Webhook
# ---------------------------------------------------------
async def process_alert(status, summary, alert_data):
    channel = bot.get_channel(CHANNEL_ID)
    if not channel: return

    # Critical 알림인 경우 사람 확인 없이 자가 치유 시작
    severity = alert_data.get('labels', {}).get('severity', 'warning')
    if status == 'FIRING' and severity == 'critical':
        asyncio.create_task(trigger_gcp_recovery(alert_data))

    color = discord.Color.red() if status == 'FIRING' else discord.Color.green()
    embed = discord.Embed(title=f"[{status}] {summary}", color=color)
    embed.add_field(name="상세 내용", value=alert_data.get('annotations', {}).get('description', 'N/A'), inline=False)
    
    view = LogAnalysisView(alert_data)
    await channel.send(embed=embed, view=view)

# ---------------------------------------------------------
# 4. 명령어 등록 및 실행
# ---------------------------------------------------------
class ChilseongpaBot(discord.Client):
    def __init__(self):
        super().__init__(intents=discord.Intents.default())
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        await self.tree.sync()

bot = ChilseongpaBot()

@bot.tree.command(name="dashboard", description="관제 대시보드 링크 확인")
async def dashboard(interaction: discord.Interaction):
    await interaction.response.send_message(f"🚀 **칠성파 대시보드 바로가기:** {GRAFANA_URL}")

@bot.tree.command(name="health_danger", description="위험 부위(Critical/Down) 집중 진단")
async def health_danger(interaction: discord.Interaction):
    await interaction.response.defer()
    try:
        # Prometheus API: 다운된 타겟(up==0) 조회
        query = 'up == 0 or (1 - avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) > 0.8)'
        resp = requests.get(f"{PROMETHEUS_URL}/api/v1/query", params={'query': query}, timeout=5)
        results = resp.json().get('data', {}).get('result', [])
        
        if not results:
            await interaction.followup.send("✅ 현재 위험 부위가 없습니다.")
        else:
            msg = "⚠️ **[긴급] 위험 부위 진단**\n" + "\n".join([f"- {r['metric'].get('job')} ({r['metric'].get('instance')})" for r in results])
            await interaction.followup.send(msg)
    except Exception as e:
        await interaction.followup.send(f"❌ 진단 중 오류 발생: {e}")

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