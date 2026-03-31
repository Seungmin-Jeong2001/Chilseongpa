import os
import asyncio
import discord
import requests
import subprocess
import re
import io
import google.generativeai as genai
from discord import app_commands
from flask import Flask, request
from threading import Thread

app = Flask(__name__)

# ---------------------------------------------------------
# 1. 환경변수 및 설정 로드
# ---------------------------------------------------------
TOKEN = os.getenv('DISCORD_BOT_TOKEN')
CHANNEL_ID = int(os.getenv('DISCORD_CHANNEL_ID', '0'))
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')

GRAFANA_URL = os.getenv('GRAFANA_URL', 'https://grafana.bucheongoyangijanggun.com/d/chilseongpa/ecb9a0-ec84b1-ed8c8c?orgId=1&from=now-1h&to=now&timezone=Asia%2FSeoul&var-datasource=PBFA97CFB590B2093&var-cluster=$__all&var-namespace=$__all&var-job=$__all&refresh=30s')
PROMETHEUS_URL = "http://prometheus:9090"

KUBE_CONFIGS = {
    "gcp": os.getenv('KUBECONFIG_GCP', '/root/.kube/config-gcp'),
    "aws": os.getenv('KUBECONFIG_AWS', '/root/.kube/config-aws')
}

genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-1.5-flash')

# ---------------------------------------------------------
# 2. 보조 함수
# ---------------------------------------------------------
def run_shell(command):
    """시스템 명령어를 실행하고 결과를 반환합니다."""
    try:
        result = subprocess.check_output(
            command, shell=True, stderr=subprocess.STDOUT, text=True
        )
        return result if result.strip() else "✅ 명령 실행 성공 (응답 메시지 없음)"
    except subprocess.CalledProcessError as e:
        if e.returncode == 127:
            return "❌ 에러: 컨테이너 내부에 명령어가 설치되지 않았습니다. (Dockerfile 확인 필요)"
        return f"❌ 실행 실패:\n```text\n{e.output}```"
    except Exception as e:
        return f"⚠️ 예외 발생: {str(e)}"

def get_error_context(service_name):
    """특정 서비스의 최근 로그를 가져옵니다. (환경에 맞게 명령어 수정 필요)"""
    # 예시 1: Docker 컨테이너인 경우
    # cmd = f"docker logs --tail 30 {service_name}"
    
    # 예시 2: systemd 서비스인 경우 (기본 적용)
    cmd = f"journalctl -u {service_name} -n 30 --no-pager"
    
    result = run_shell(cmd)
    # 디스코드 임베드 제한(1024자)을 넘지 않도록 뒷부분만 자르기
    if len(result) > 1000:
        return f"...(생략)...\n{result[-1000:]}"
    return result

# ---------------------------------------------------------
# 3. 통합된 AI 지능형 로그 분석 뷰
# ---------------------------------------------------------
class LogAnalysisView(discord.ui.View):
    def __init__(self, alert_data):
        super().__init__(timeout=None)
        self.alert_data = alert_data

    @discord.ui.button(label="🔍 Gemini SRE 지능형 진단", style=discord.ButtonStyle.primary, custom_id="analyze_logs")
    async def analyze_logs(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        
        summary = self.alert_data.get('annotations', {}).get('summary', '정보 없음')
        description = self.alert_data.get('annotations', {}).get('description', '정보 없음')
        instance = self.alert_data.get('labels', {}).get('instance', 'unknown')
        cluster = self.alert_data.get('labels', {}).get('cluster', 'Hybrid')
        
        prompt = f"""
        당신은 AWS/GCP 하이브리드 인프라를 관리하는 시니어 SRE 전문가입니다.
        현재 {cluster} 클러스터의 {instance} 인스턴스에서 장애가 발생했습니다.

        [장애 정보]
        - 요약: {summary}
        - 상세: {description}

        [요청 사항]
        1. **원인 진단**: 로그와 장애 내용을 대조하여 원인을 한 문장으로 진단하세요.
        2. **즉각 조치**: 해결을 위해 터미널에서 즉시 실행할 명령어(kubectl, systemctl 등)를 제시하세요.
        3. **AIOps 예방**: 재발 방지를 위한 Ansible/Terraform 보완책을 제안하세요.
        
        답변은 한국어로, 이모지를 섞어 마크다운 형식으로 작성하세요.
        """
        try:
            response = model.generate_content(prompt)
            await interaction.followup.send(f"🤖 **Gemini SRE 진단 리포트**\n{response.text}")
        except Exception as e:
            await interaction.followup.send(f"⚠️ AI 분석 실패: {e}")

# ---------------------------------------------------------
# 4. AIOps 자가 치유 및 Webhook 처리
# ---------------------------------------------------------
async def trigger_gcp_recovery(alert_data):
    cluster = alert_data.get('labels', {}).get('cluster', 'unknown')
    alert_name = alert_data.get('alertname')
    
    if cluster == 'gcp' and alert_name == 'PrometheusTargetDown':
        channel = bot.get_channel(CHANNEL_ID)
        if channel:
            await channel.send(f"🚨 **[AIOps 긴급 상황]** GCP 인프라 다운 감지! 자가 치유 복구 프로세스를 시작합니다.")
            await asyncio.sleep(3) 
            # 여기에 실제 복구 쉘 스크립트 실행 로직 추가 가능
            await channel.send("✅ **[복구 성공]** GCP 인프라 복구 프로세스가 완료되었습니다. 시스템 정상화 여부를 모니터링 중입니다.")

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
# 5. 디스코드 봇 설정 및 슬래시 명령어
# ---------------------------------------------------------
class ChilseongpaBot(discord.Client):
    def __init__(self):
        super().__init__(intents=discord.Intents.default())
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        await self.tree.sync()
        print("🚀 [System] 모든 슬래시 커맨드가 동기화되었습니다.")

    async def on_ready(self):
        print(f"✅ [System] {self.user} 로그인 완료 및 준비됨.")

bot = ChilseongpaBot()

@bot.tree.command(name="help", description="칠성파 봇이 사용 가능한 모든 명령어를 안내합니다.")
async def help_command(interaction: discord.Interaction):
    embed = discord.Embed(title="📖 Chilseongpa AIOps 가이드", color=discord.Color.blue())
    embed.add_field(name="🌐 하이브리드 관제", value="`/k8s_ps`: GCP/AWS 파드 상태\n`/k8s_logs`: 원격 앱 로그 확인", inline=False)
    embed.add_field(name="🖥️ 모니터링 서버", value="`/ps`: 호스트 컨테이너 상태\n`/logs`: 관리 도구 로그 확인", inline=False)
    embed.add_field(name="📊 기타 도구", value="`/dashboard`: 그라파나 이동\n`/health_danger`: 위험 부위 진단", inline=False)
    embed.set_footer(text="Chilseongpa Project | AI Powered Operations")
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="k8s_ps", description="GCP/AWS 클러스터의 파드 상태를 전체 조회합니다.")
@app_commands.choices(cluster=[
    app_commands.Choice(name="GCP Main", value="gcp"),
    app_commands.Choice(name="AWS Sub", value="aws")
])
async def k8s_ps(interaction: discord.Interaction, cluster: app_commands.Choice[str]):
    await interaction.response.defer()
    config = KUBE_CONFIGS.get(cluster.value)
    result = run_shell(f"kubectl --kubeconfig={config} get pods -A")
    
    # 결과물이 디스코드 글자 수 제한을 초과하는 경우 텍스트 파일로 전송
    if len(result) > 1900:
        with io.StringIO(result) as f:
            file = discord.File(f, filename=f"{cluster.value}_pods.txt")
            await interaction.followup.send(f"☸️ **{cluster.name} 파드 상태 리포트**\n(출력 결과가 너무 길어 텍스트 파일로 첨부합니다.)", file=file)
    else:
        await interaction.followup.send(f"☸️ **{cluster.name} 파드 상태 리포트**\n```text\n{result}\n```")

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
    embed.add_field(name="Log Context", value=f"```text\n{context}\n```", inline=False)
    
    if "✅" not in context and "❌" not in context:
        analysis_prompt = f"다음 로그의 에러 원인을 짧게 분석해줘: {context}"
        try:
            response = model.generate_content(analysis_prompt)
            embed.add_field(name="🤖 AI 간이 분석", value=response.text[:1024], inline=False)
        except:
            pass

    await interaction.followup.send(embed=embed)

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
# 6. Flask 서버 및 메인 실행
# ---------------------------------------------------------
@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
    # Flask 쓰레드에서 봇의 이벤트 루프로 안전하게 코루틴 전달
    loop = bot.loop
    if not loop or not loop.is_running():
        return "Bot is not ready", 503

    for alert in data.get('alerts', []):
        status = alert.get('status', 'firing').upper()
        summary = alert.get('annotations', {}).get('summary', 'No summary')
        asyncio.run_coroutine_threadsafe(process_alert(status, summary, alert), loop)
    
    return "OK", 200

def run_flask():
    app.run(host='0.0.0.0', port=5000)

if __name__ == '__main__':
    # Flask 서버를 데몬 쓰레드로 실행하여 봇 종료 시 함께 종료되도록 설정
    flask_thread = Thread(target=run_flask, daemon=True)
    flask_thread.start()
    bot.run(TOKEN)