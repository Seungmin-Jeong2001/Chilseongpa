import os
import asyncio
import discord
import aiohttp
import json
import io
import time
from google import genai
from discord import app_commands
from flask import Flask, request
from threading import Thread

# ---------------------------------------------------------
# 1. 환경변수 및 설정 로드
# ---------------------------------------------------------
TOKEN = os.getenv('DISCORD_BOT_TOKEN')
CHANNEL_ID = int(os.getenv('DISCORD_CHANNEL_ID', '0'))
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')

# 대시보드 및 프로메테우스 URL
GRAFANA_URL = os.getenv('GRAFANA_URL', 'https://grafana.bucheongoyangijanggun.com')
PROMETHEUS_URL = "http://prometheus:9090"

# Kubeconfig 경로 (GCP/AWS 하이브리드)
KUBE_CONFIGS = {
    "gcp": os.getenv('KUBECONFIG_GCP', '/root/.kube/config-gcp'),
    "aws": os.getenv('KUBECONFIG_AWS', '/root/.kube/config-aws')
}

client = genai.Client(api_key=GEMINI_API_KEY)
MODEL_ID = "gemini-2.5-flash"
app = Flask(__name__)

# ---------------------------------------------------------
# 2. 공통 유틸리티 함수
# ---------------------------------------------------------
async def run_shell(command):
    """비동기 방식으로 쉘 명령어를 실행합니다."""
    try:
        process = await asyncio.create_subprocess_shell(
            command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        stdout, stderr = await process.communicate()
        
        if process.returncode == 0:
            result = stdout.decode().strip()
            return result if result else "✅ 결과가 비어있습니다 (명령 성공)."
        else:
            return f"❌ 실행 실패 (Code {process.returncode}):\n{stderr.decode()}"
    except Exception as e:
        return f"⚠️ 예외 발생: {str(e)}"

async def send_smart_message(interaction, header, content, filename="result.txt"):
    """디스코드 2,000자 제한을 고려하여 전송 방식을 결정합니다."""
    if len(header) + len(content) + 10 <= 2000:
        await interaction.followup.send(f"{header}\n```text\n{content}```")
    elif len(content) <= 4000:
        await interaction.followup.send(f"{header} (내용이 길어 나누어 전송합니다.)")
        chunks = [content[i:i+1900] for i in range(0, len(content), 1900)]
        for chunk in chunks:
            await interaction.followup.send(f"```text\n{chunk}```")
    else:
        with io.BytesIO(content.encode('utf-8')) as f:
            file = discord.File(f, filename=filename)
            await interaction.followup.send(content=f"{header}\n⚠️ 내용이 너무 길어 파일로 전송합니다.", file=file)

async def generate_content_with_retry(prompt):
    """Gemini API 호출 (할당량 초과 시 지수 백오프 재시도)"""
    retries = 5
    for i in range(retries):
        try:
            response = client.models.generate_content(model=MODEL_ID, contents=prompt)
            return response.text
        except Exception as e:
            if "429" in str(e) and i < retries - 1:
                await asyncio.sleep(2 ** i)
                continue
            raise e

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
        await interaction.response.defer()
        await interaction.followup.send("🤖 **Gemini SRE가 원인을 분석 중입니다...** ⏳")

        prompt = f"""
        당신은 하이브리드 클라우드(AWS/GCP) 전문가 SRE입니다. 
        '{self.cluster_name}' 환경의 '{self.pod_name}' 로그/이벤트를 분석하고 다음을 한국어로 답변하세요:
        1. 원인 분석, 2. 조치 명령어(kubectl), 3. 재발 방지책.
        
        [데이터]
        {self.log_content}
        """

        try:
            ai_text = await generate_content_with_retry(prompt)
            header = f"🤖 **Gemini SRE 진단 리포트 ({self.pod_name})**"
            
            if len(ai_text) <= 1900:
                await interaction.followup.send(f"{header}\n{ai_text}")
            else:
                chunks = [ai_text[i:i+1900] for i in range(0, len(ai_text), 1900)]
                for n, chunk in enumerate(chunks):
                    await interaction.followup.send(f"**[진단 파트 {n+1}/{len(chunks)}]**\n{chunk}")
                    
        except Exception as e:
            await interaction.followup.send(f"⚠️ 진단 오류: {str(e)[:1500]}")

# ---------------------------------------------------------
# 4. 디스코드 봇 클래스 및 명령어
# ---------------------------------------------------------
class ChilseongpaBot(discord.Client):
    def __init__(self):
        super().__init__(intents=discord.Intents.default())
        self.tree = app_commands.CommandTree(self)

    async def setup_hook(self):
        await self.tree.sync()
        print("🚀 [System] Chilseongpa AIOps 시스템 기동 완료")

bot = ChilseongpaBot()

@bot.tree.command(name="help", description="명령어 가이드")
async def help_command(interaction: discord.Interaction):
    embed = discord.Embed(title="📖 Chilseongpa AIOps 가이드", color=discord.Color.blue())
    embed.add_field(name="☸️ 관제", value="`/k8s_ps`, `/k8s_logs`", inline=True)
    embed.add_field(name="📊 분석", value="`/dashboard`, `/health_danger`", inline=True)
    await interaction.response.send_message(embed=embed)

@bot.tree.command(name="k8s_ps", description="파드 상태 조회")
@app_commands.choices(cluster=[
    app_commands.Choice(name="GCP Main", value="gcp"),
    app_commands.Choice(name="AWS Sub", value="aws")
])
async def k8s_ps(interaction: discord.Interaction, cluster: app_commands.Choice[str]):
    await interaction.response.defer()
    config = KUBE_CONFIGS.get(cluster.value)
    result = await run_shell(f"kubectl --kubeconfig={config} get pods -A")
    header = f"☸️ **{cluster.name} 파드 상태**"
    await send_smart_message(interaction, header, result, filename=f"{cluster.value}_pods.txt")

@bot.tree.command(name="k8s_logs", description="로그 조회 및 AI 진단")
@app_commands.choices(cluster=[
    app_commands.Choice(name="GCP Main", value="gcp"),
    app_commands.Choice(name="AWS Sub", value="aws")
])
async def k8s_logs(interaction: discord.Interaction, cluster: app_commands.Choice[str], pod_name: str, namespace: str = "default"):
    await interaction.response.defer()
    config = KUBE_CONFIGS.get(cluster.value)
    logs = await run_shell(f"kubectl --kubeconfig={config} logs {pod_name} -n {namespace} --tail=30")
    
    embed = discord.Embed(title=f"📋 로그 리포트: {pod_name}", color=discord.Color.orange())
    safe_logs = logs if len(logs) <= 1000 else f"...(중략)...\n{logs[-950:]}"
    embed.add_field(name="최신 로그 (Tail 30)", value=f"```text\n{safe_logs}```")
    
    view = LogAnalysisView(cluster.name, pod_name, logs)
    view.add_item(discord.ui.Button(label="📊 그라파나", url=GRAFANA_URL, style=discord.ButtonStyle.link))
    await interaction.followup.send(embed=embed, view=view)

@bot.tree.command(name="health_danger", description="전체 클러스터 위험 부위 진단")
async def health_danger(interaction: discord.Interaction):
    await interaction.response.defer()
    async with aiohttp.ClientSession() as session:
        try:
            async with session.get(f"{PROMETHEUS_URL}/api/v1/query", params={'query': 'up == 0'}, timeout=5) as resp:
                data = await resp.json()
                results = data.get('data', {}).get('result', [])
                if not results:
                    await interaction.followup.send("✅ 모든 시스템이 정상(UP)입니다.")
                else:
                    msg = "⚠️ **위험 탐지 목록**\n" + "\n".join([f"- {r['metric'].get('job')} ({r['metric'].get('cluster')})" for r in results])
                    await interaction.followup.send(msg)
        except Exception as e:
            await interaction.followup.send(f"❌ 조회 실패: {e}")

@bot.tree.command(name="dashboard", description="대시보드 링크")
async def dashboard(interaction: discord.Interaction):
    await interaction.response.send_message(f"🚀 **Grafana:** {GRAFANA_URL}")

# ---------------------------------------------------------
# 5. Webhook 처리 (Prometheus & Cloudflare)
# ---------------------------------------------------------

async def process_alert(status, summary, description):
    """Prometheus 알림 전송"""
    await bot.wait_until_ready()
    channel = bot.get_channel(CHANNEL_ID)
    if not channel: channel = await bot.fetch_channel(CHANNEL_ID)

    color = discord.Color.red() if status == 'FIRING' else discord.Color.green()
    embed = discord.Embed(title=f"[{status}] {summary}", description=description[:1000], color=color)
    view = LogAnalysisView("Alertmanager", summary, description)
    await channel.send(embed=embed, view=view)

async def process_cloudflare_alert(data):
    """Cloudflare LB 알림 전송"""
    await bot.wait_until_ready()
    channel = bot.get_channel(CHANNEL_ID)
    if not channel: channel = await bot.fetch_channel(CHANNEL_ID)

    text = data.get('text', '상태 변경 감지')
    color = discord.Color.red() if "Unhealthy" in text else discord.Color.green()
    
    embed = discord.Embed(
        title="🌐 [Cloudflare LB Alert] 외부 관제 신호",
        description=text,
        color=color
    )
    view = LogAnalysisView("Cloudflare LB", "Infrastructure", text)
    await channel.send(embed=embed, view=view)

@app.route('/webhook', methods=['POST'])
def prometheus_webhook():
    data = request.json
    loop = bot.loop
    for alert in data.get('alerts', []):
        status = alert.get('status', 'firing').upper()
        summary = alert.get('annotations', {}).get('summary', 'No summary')
        desc = alert.get('annotations', {}).get('description', 'No description')
        asyncio.run_coroutine_threadsafe(process_alert(status, summary, desc), loop)
    return "OK", 200

@app.route('/cloudflare-alert', methods=['POST'])
def cloudflare_webhook():
    data = request.json
    loop = bot.loop
    asyncio.run_coroutine_threadsafe(process_cloudflare_alert(data), loop)
    return "OK", 200

def run_flask():
    app.run(host='0.0.0.0', port=5000)

# ---------------------------------------------------------
# 6. 메인 실행
# ---------------------------------------------------------
if __name__ == '__main__':
    # Flask 서버를 별도 스레드에서 실행
    Thread(target=run_flask, daemon=True).start()
    # 디스코드 봇 실행
    bot.run(TOKEN)