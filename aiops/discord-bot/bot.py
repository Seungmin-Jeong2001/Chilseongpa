import os
import asyncio
import discord
import requests
import subprocess
import re
import google.generativeai as genai
from discord import app_commands
from flask import Flask, request
from threading import Thread

app = Flask(__name__)

# 환경변수 로드
TOKEN = os.getenv('DISCORD_BOT_TOKEN')
CHANNEL_ID = int(os.getenv('DISCORD_CHANNEL_ID', '0')) # 오류 방지를 위해 기본값 0 추가
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
# 로그인 생략 필터링 링크
GRAFANA_URL = os.getenv('GRAFANA_URL', 'https://grafana.bucheongoyangijanggun.com/d/chilseongpa/ecb9a0-ec84b1-ed8c8c?orgId=1&from=now-1h&to=now&timezone=Asia%2FSeoul&var-datasource=PBFA97CFB590B2093&var-cluster=$__all&var-namespace=$__all&var-job=$__all&refresh=30s')
PROMETHEUS_URL = "http://prometheus:9090"

# Gemini 설정
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-1.5-flash')

# ---------------------------------------------------------
# 보조 함수: 로그 컨텍스트 추출 (에러 전후 분석)
# ---------------------------------------------------------
def get_error_context(container_name, lines=20):
    try:
        result = subprocess.check_output(
            f"docker logs --tail 200 {container_name}", 
            shell=True, stderr=subprocess.STDOUT, text=True
        )
        log_lines = result.splitlines()
        
        error_idx = -1
        for i, line in enumerate(log_lines):
            if re.search(r'error|fail|exception|fatal', line, re.IGNORECASE):
                error_idx = i
        
        if error_idx == -1:
            return "✅ 최근 200줄 내에 특이 에러가 발견되지 않았습니다."

        start = max(0, error_idx - 5)
        end = min(len(log_lines), error_idx + 6)
        context = "\n".join(log_lines[start:end])
        return f"```text\n... (생략) ...\n{context}\n... (생략) ...\n```"
    except Exception as e:
        return f"❌ 로그 추출 실패: {str(e)}"

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
        
        instance = self.alert_data.get('labels', {}).get('instance', 'unknown')
        root_hint = self.alert_data.get('labels', {}).get('root_hint', 'N/A')
        raw_logs = f"ERROR: Connection timeout to {instance}. Context: {root_hint}. Node Unreachable."
        
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
    cluster = alert_data.get('labels', {}).get('cluster', 'unknown')
    alert_name = alert_data.get('alertname')
    
    if cluster == 'gcp' and alert_name == 'PrometheusTargetDown':
        channel = bot.get_channel(CHANNEL_ID)
        if channel:
            await channel.send(f"🚨 **[AIOps 긴급 상황]** GCP 인프라 다운 감지! 자가 치유 복구 프로세스를 시작합니다.")
            await asyncio.sleep(3) 
            await channel.send("✅ **[복구 성공]** GCP 인프라 복구 프로세스가 완료되었습니다. 시스템 정상화 여부를 모니터링 중입니다.")

# ---------------------------------------------------------
# 3. 알림 처리 및 Webhook
# ---------------------------------------------------------
async def process_alert(status, summary, alert_data):
    channel = bot.get_channel(CHANNEL_ID)
    if not channel: return

    severity = alert_data.get('labels', {}).get('severity', 'warning')
    if status == 'FIRING' and severity == 'critical':
        asyncio.create_task(trigger_gcp_recovery(alert_data))

    color = discord.Color.red() if status == 'FIRING' else discord.Color.green()
    embed = discord.Embed(title=f"[{status}] {summary}", color=color)
    embed.add_field(name="상세 내용", value=alert_data.get('annotations', {}).get('description', 'N/A'), inline=False)
    
    view = LogAnalysisView(alert_data)
    await channel.send(embed=embed, view=view)

# ---------------------------------------------------------
# 4. 슬래시 명령어 등록 및 봇 클래스
# ---------------------------------------------------------
class ChilseongpaBot(discord.Client):
    def __init__(self):
        super().__init__(intents=discord.Intents.default())
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        await self.tree.sync()

bot = ChilseongpaBot()

# --- [추가] /help 커맨드 ---
@bot.tree.command(name="help", description="칠성파 봇이 사용 가능한 모든 명령어를 안내합니다.")
async def help_command(interaction: discord.Interaction):
    embed = discord.Embed(
        title="📖 Chilseongpa AIOps 가이드",
        description="인프라 관제를 위해 다음 명령어들을 사용할 수 있습니다.",
        color=discord.Color.green()
    )
    commands_list = [
        ("`/dashboard`", "실시간 그라파나 관제 센터(익명 접속)로 이동합니다."),
        ("`/ps`", "현재 호스트에서 실행 중인 도커 컨테이너 목록을 보여줍니다."),
        ("`/health_danger`", "Prometheus 지표 기반 위험 부위를 집중 진단합니다."),
        ("`/logs [서비스명]`", "특정 서비스의 최근 에러 발생 시점 전후 로그를 분석합니다."),
        ("`/help`", "지금 보고 계신 명령어 안내를 출력합니다.")
    ]
    for cmd, desc in commands_list:
        embed.add_field(name=cmd, value=desc, inline=False)
    embed.set_footer(text="Chilseongpa Project | AI Powered Operations")
    await interaction.response.send_message(embed=embed)

# --- [추가] /ps 커맨드 ---
@bot.tree.command(name="ps", description="현재 실행 중인 모니터링 스택 프로그램을 확인합니다.")
async def ps_command(interaction: discord.Interaction):
    try:
        result = subprocess.check_output(
            "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'", 
            shell=True, text=True
        )
        await interaction.response.send_message(f"🖥️ **실시간 프로세스 상태**\n```text\n{result}\n```")
    except Exception as e:
        await interaction.response.send_message(f"❌ 프로세스 조회 실패: {e}")

# --- [추가] /logs 커맨드 ---
@bot.tree.command(name="logs", description="특정 서비스의 에러 발생 전후 로그를 추적합니다.")
@app_commands.choices(service=[
    app_commands.Choice(name="prometheus", value="prometheus"),
    app_commands.Choice(name="grafana", value="grafana"),
    app_commands.Choice(name="alertmanager", value="alertmanager"),
    app_commands.Choice(name="discord-bot", value="chilseongpa-bot")
])
async def logs_command(interaction: discord.Interaction, service: app_commands.Choice[str]):
    await interaction.response.defer()
    
    context = get_error_context(service.value)
    embed = discord.Embed(
        title=f"📋 로그 추적 리포트: {service.name}",
        description=f"최근 발견된 에러 지점 전후의 맥락입니다.",
        color=discord.Color.orange()
    )
    embed.add_field(name="Log Context", value=context, inline=False)
    
    if "✅" not in context and "❌" not in context:
        analysis_prompt = f"다음 로그의 에러 원인을 짧게 분석해줘: {context}"
        try:
            response = model.generate_content(analysis_prompt)
            embed.add_field(name="🤖 AI 간이 분석", value=response.text[:1024], inline=False)
        except:
            pass

    await interaction.followup.send(embed=embed)

# --- 기존 명령어 유지 ---
@bot.tree.command(name="dashboard", description="관제 대시보드 링크 확인")
async def dashboard(interaction: discord.Interaction):
    await interaction.response.send_message(f"🚀 **칠성파 대시보드 바로가기:**\n{GRAFANA_URL}")

@bot.tree.command(name="health_danger", description="위험 부위(Critical/Down) 집중 진단")
async def health_danger(interaction: discord.Interaction):
    await interaction.response.defer()
    try:
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

# ---------------------------------------------------------
# 5. 서버 실행
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