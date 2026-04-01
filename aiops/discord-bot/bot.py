import os
import asyncio
import discord
import requests
import subprocess
import io
import time
from google import genai
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

# 그라파나 및 프로메테우스 설정
GRAFANA_URL = os.getenv('GRAFANA_URL', 'https://grafana.bucheongoyangijanggun.com/d/chilseongpa/ecb9a0-ec84b1-ed8c8c?orgId=1&from=now-1h&to=now&timezone=Asia%2FSeoul')
PROMETHEUS_URL = "http://prometheus:9090"

# Kubeconfig 경로 (GCP/AWS 하이브리드)
KUBE_CONFIGS = {
    "gcp": os.getenv('KUBECONFIG_GCP', '/root/.kube/config-gcp'),
    "aws": os.getenv('KUBECONFIG_AWS', '/root/.kube/config-aws')
}

# 최신 Gemini AI SDK 설정 (google-genai)
client = genai.Client(api_key=GEMINI_API_KEY)
MODEL_ID = "gemini-2.0-flash" # 최신 안정화 모델로 설정

# ---------------------------------------------------------
# 2. 보조 함수 (쉘 명령어 및 API 호출)
# ---------------------------------------------------------
def run_shell(command):
    """시스템 명령어를 실행하고 결과를 반환합니다."""
    try:
        result = subprocess.check_output(
            command, shell=True, stderr=subprocess.STDOUT, text=True
        )
        return result if result.strip() else "✅ 명령 실행 성공 (응답 메시지 없음)"
    except subprocess.CalledProcessError as e:
        return f"❌ 실행 실패 (Exit Code {e.returncode}):\n```text\n{e.output}```"
    except Exception as e:
        return f"⚠️ 예외 발생: {str(e)}"

async def generate_content_with_retry(prompt):
    """지수 백오프를 적용한 Gemini API 호출 함수 (최대 5회 재시도)"""
    retries = 5
    for i in range(retries):
        try:
            response = client.models.generate_content(
                model=MODEL_ID,
                contents=prompt
            )
            return response.text
        except Exception as e:
            # 429 오류(할당량 초과) 발생 시 재시도 로직
            if "429" in str(e) and i < retries - 1:
                wait_time = 2 ** i # 1s, 2s, 4s, 8s, 16s 대기
                await asyncio.sleep(wait_time)
                continue
            raise e # 마지막 시도까지 실패하거나 다른 오류면 발생시킴

# ---------------------------------------------------------
# 3. AI 진단 뷰 (LogAnalysisView)
# ---------------------------------------------------------
class LogAnalysisView(discord.ui.View):
    def __init__(self, cluster_name, pod_name, log_content):
        super().__init__(timeout=None)
        self.cluster_name = cluster_name
        self.pod_name = pod_name
        self.log_content = log_content

    @discord.ui.button(label="🔍 Gemini SRE 지능형 진단", style=discord.ButtonStyle.primary, custom_id="analyze_k8s_logs")
    async def analyze_logs(self, interaction: discord.Interaction, button: discord.ui.Button):
        # 1. 즉시 응답 지연 (Discord 3초 제한 방지)
        await interaction.response.defer()
        
        # 2. 사용자에게 진단 시작 알림 보내기 (상태 피드백)
        status_msg = await interaction.followup.send("🤖 **Gemini SRE가 로그를 분석 중입니다...** 잠시만 기다려 주세요! ⏳")

        # 3. 프롬프트 구성
        prompt = f"""
        당신은 AWS/GCP 하이브리드 인프라를 관리하는 시니어 SRE 전문가입니다.
        현재 '{self.cluster_name}' 환경의 '{self.pod_name}'에서 장애가 의심됩니다.

        [수집된 로그 데이터]
        {self.log_content}

        [요청 사항]
        1. **원인 진단**: 로그를 분석하여 현재 상태와 문제 원인을 진단하세요.
        2. **즉각 조치**: 해결을 위해 터미널에서 즉시 실행할 명령어(kubectl 등)를 제시하세요.
        3. **재발 방지**: 향후 동일 장애를 방지하기 위한 인프라 보안점을 제안하세요.

        [출력 규칙]
        - 한국어로, 이모지를 섞어 마크다운 형식으로 답변하세요.
        - 답변이 2000자를 넘을 경우 가독성을 위해 섹션을 명확히 나누어 작성하세요.
        """

        try:
            # 4. 재시도 로직이 포함된 API 호출
            ai_text = await generate_content_with_retry(prompt)

            # 5. 글자 수 제한(2000자) 대응 로직
            header = f"🤖 **Gemini SRE 진단 리포트 ({self.pod_name})**\n"
            full_response = header + ai_text

            if len(full_response) <= 2000:
                await interaction.followup.send(full_response)
            else:
                # 메시지를 1900자 단위로 쪼개서 전송
                chunks = [full_response[i:i+1900] for i in range(0, len(full_response), 1900)]
                for n, chunk in enumerate(chunks):
                    await interaction.followup.send(f"(파트 {n+1}/{len(chunks)})\n{chunk}")
            
        except Exception as e:
            error_msg = str(e)
            if "429" in error_msg:
                friendly_error = "⚠️ **Gemini API 할당량이 초과되었습니다.**\n무료 티어 제한으로 인해 잠시 후(약 1분 뒤) 다시 시도해 주세요. 🙇‍♂️"
            else:
                friendly_error = f"⚠️ AI 분석 중 오류 발생: {error_msg[:1500]}"
            await interaction.followup.send(friendly_error)

# ---------------------------------------------------------
# 4. 디스코드 봇 클래스 및 슬래시 명령어
# ---------------------------------------------------------
class ChilseongpaBot(discord.Client):
    def __init__(self):
        super().__init__(intents=discord.Intents.default())
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        await self.tree.sync()
        print("🚀 [System] 모든 K8s 관제 커맨드가 동기화되었습니다.")

bot = ChilseongpaBot()

# [Command] /help
@bot.tree.command(name="help", description="칠성파 봇의 명령어 가이드를 확인합니다.")
async def help_command(interaction: discord.Interaction):
    embed = discord.Embed(title="📖 Chilseongpa AIOps 가이드", color=discord.Color.blue())
    embed.add_field(name="☸️ K8s 하이브리드 관제", value="`/k8s_ps`: GCP/AWS 전체 파드 상태 조회\n`/k8s_logs`: 파드 로그 검색 및 AI 지능형 진단", inline=False)
    embed.add_field(name="📊 모니터링", value="`/dashboard`: 그라파나 이동\n`/health_danger`: 프로메테우스 위험 부위 진단", inline=False)
    embed.set_footer(text="Chilseongpa Project | AI Powered Operations")
    await interaction.response.send_message(embed=embed)

# [Command] /k8s_ps
@bot.tree.command(name="k8s_ps", description="클러스터의 파드 상태를 조회합니다.")
@app_commands.choices(cluster=[
    app_commands.Choice(name="GCP Main", value="gcp"),
    app_commands.Choice(name="AWS Sub", value="aws")
])
async def k8s_ps(interaction: discord.Interaction, cluster: app_commands.Choice[str]):
    await interaction.response.defer()
    config = KUBE_CONFIGS.get(cluster.value)
    result = run_shell(f"kubectl --kubeconfig={config} get pods -A")
    
    header = f"☸️ **{cluster.name} 파드 상태 리포트**\n"
    if len(result) > 1900:
        with io.StringIO(result) as f:
            file = discord.File(f, filename=f"{cluster.value}_pods.txt")
            await interaction.followup.send(header + "(결과가 길어 파일로 전송합니다.)", file=file)
    else:
        await interaction.followup.send(f"{header}```text\n{result}```")

# [Command] /k8s_logs
@bot.tree.command(name="k8s_logs", description="파드의 최신 로그 20줄을 확인하고 AI 진단을 시작합니다.")
@app_commands.choices(cluster=[
    app_commands.Choice(name="GCP Main", value="gcp"),
    app_commands.Choice(name="AWS Sub", value="aws")
])
@app_commands.describe(pod_name="로그를 확인할 파드 이름", namespace="네임스페이스 (기본: default)")
async def k8s_logs(
    interaction: discord.Interaction, 
    cluster: app_commands.Choice[str], 
    pod_name: str, 
    namespace: str = "default"
):
    await interaction.response.defer()
    config = KUBE_CONFIGS.get(cluster.value)
    
    # 파드 로그 추출 (최신 20줄)
    logs = run_shell(f"kubectl --kubeconfig={config} logs {pod_name} -n {namespace} --tail=20")
    
    embed = discord.Embed(
        title=f"📋 로그 리포트: {cluster.name}",
        description=f"**Target:** `{pod_name}` (Namespace: `{namespace}`)",
        color=discord.Color.orange()
    )
    
    # 디스코드 필드 값(1024자 제한) 방어
    safe_logs = logs if len(logs) <= 1000 else f"...(로그 초과로 생략)...\n{logs[-950:]}"
    embed.add_field(name="최신 20줄 로그", value=f"```text\n{safe_logs}\n```", inline=False)
    
    # 뷰 생성 및 대시보드 버튼 연동
    view = LogAnalysisView(cluster.name, pod_name, logs)
    view.add_item(discord.ui.Button(label="📊 그라파나 대시보드", url=GRAFANA_URL, style=discord.ButtonStyle.link))
    
    await interaction.followup.send(embed=embed, view=view)

# [Command] /dashboard
@bot.tree.command(name="dashboard", description="관제 대시보드 링크 확인")
async def dashboard(interaction: discord.Interaction):
    await interaction.response.send_message(f"🚀 **칠성파 대시보드:** {GRAFANA_URL}")

# [Command] /health_danger
@bot.tree.command(name="health_danger", description="위험 부위(Critical/Down) 집중 진단")
async def health_danger(interaction: discord.Interaction):
    await interaction.response.defer()
    try:
        query = 'up == 0 or (1 - avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) > 0.8)'
        resp = requests.get(f"{PROMETHEUS_URL}/api/v1/query", params={'query': query}, timeout=5)
        results = resp.json().get('data', {}).get('result', [])
        
        if not results:
            await interaction.followup.send("✅ 현재 모든 시스템이 정상 가동 중입니다.")
        else:
            msg = "⚠️ **[긴급] 위험 부위 탐지 리포트**\n"
            for r in results:
                instance = r['metric'].get('instance', 'N/A')
                job = r['metric'].get('job', 'N/A')
                msg += f"- `{job}` ({instance})\n"
            await interaction.followup.send(msg)
    except Exception as e:
        await interaction.followup.send(f"❌ 진단 중 오류 발생: {e}")

# ---------------------------------------------------------
# 5. 서버 실행 및 Webhook 처리 (Alertmanager 연동)
# ---------------------------------------------------------
async def process_alert(status, summary, alert_data):
    channel = bot.get_channel(CHANNEL_ID)
    if not channel: return
    
    color = discord.Color.red() if status == 'FIRING' else discord.Color.green()
    embed = discord.Embed(title=f"[{status}] {summary}", color=color)
    desc = alert_data.get('annotations', {}).get('description', '정보 없음')
    
    # 상세 내용도 1024자 제한 방어
    safe_desc = desc if len(desc) <= 1000 else desc[:1000]
    embed.add_field(name="장애 상세", value=safe_desc, inline=False)
    
    # 알림 발생 시에도 AI 진단 버튼 제공
    view = LogAnalysisView("Alertmanager", summary, desc)
    view.add_item(discord.ui.Button(label="🚀 대시보드 이동", url=GRAFANA_URL, style=discord.ButtonStyle.link))
    await channel.send(embed=embed, view=view)

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.json
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
    # Flask 서버를 데몬 쓰레드로 실행
    Thread(target=run_flask, daemon=True).start()
    bot.run(TOKEN)