디스코드 AI 에이전트 봇의 코드 작성 공간

현 코드들은 LOCAL TEST 용도로 작성되어 있음


# gitaction deploy.yml
- name: K8s Secret 배포
        run: |
          kubectl delete secret bot-secrets --ignore-not-found
          kubectl create secret generic bot-secrets \
            --from-literal=GEMINI_API_KEY='${{ secrets.GEMINI_API_KEY }}' \
            --from-literal=DISCORD_BOT_TOKEN='${{ secrets.DISCORD_BOT_TOKEN }}' \
            --from-literal=DISCORD_CHANNEL_ID='${{ secrets.DISCORD_CHANNEL_ID }}'

      - name: 배포용 YAML 생성 (이미지 이름 치환)
        env:
          IMAGE_NAME: ${{ secrets.DOCKER_HUB_USERNAME }}/${{ secrets.DOCKER_HUB_REPO_BOT }}:latest
        run: |
          # 템플릿 파일의 {{IMAGE_NAME}}을 실제 시크릿 값으로 치환하여 배포
          envsubst < k8s/bot-deployment.yaml > k8s/bot-deployment-final.yaml
          kubectl apply -f k8s/bot-deployment-final.yaml

# 봇의 k3s 배포 파일 일부
apiVersion: apps/v1
kind: Deployment
metadata:
  name: discord-bot
  labels:
    app: discord-bot
spec:
  replicas: 1
  selector:
    matchLabels:
      app: discord-bot
  template:
    metadata:
      labels:
        app: discord-bot
    spec:
      containers:
      - name: bot
        # ${IMAGE_NAME}은 배포 시 envsubst에 의해 실제 이미지 경로로 바뀝니다.
        image: ${IMAGE_NAME}
        env:
        - name: GEMINI_API_KEY
          valueFrom: 
            secretKeyRef: { name: bot-secrets, key: GEMINI_API_KEY }
        - name: DISCORD_BOT_TOKEN
          valueFrom: 
            secretKeyRef: { name: bot-secrets, key: DISCORD_BOT_TOKEN }
        - name: DISCORD_CHANNEL_ID
          valueFrom: 
            secretKeyRef: { name: bot-secrets, key: DISCORD_CHANNEL_ID }
위 코드로 배포시 사용할 예정

