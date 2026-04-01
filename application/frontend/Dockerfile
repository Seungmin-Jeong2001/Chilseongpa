# ==========================================
# Step 1: 빌드 환경 (요리사)
# ==========================================
FROM node:20-alpine AS builder

# 작업 디렉토리 설정
WORKDIR /app

# 부품 목록(package.json)을 먼저 복사하고 설치 (캐시 최적화)
COPY package.json package-lock.json ./
RUN npm install

# 나머지 모든 소스 코드를 복사하고 압축(빌드) 진행
COPY . .
RUN npm run build
# (Vite로 빌드하면 /app/dist 폴더에 최종 결과물이 생깁니다)

# ==========================================
# Step 2: 실행 환경 (서빙 전용 웹 서버)
# ==========================================
FROM nginx:alpine

# 1단계(builder)에서 완성된 결과물(dist 폴더)만 Nginx의 서빙 폴더로 쏙 빼옵니다.
COPY --from=builder /app/dist /usr/share/nginx/html

# 80번 포트 개방
EXPOSE 80

# Nginx 실행
CMD ["nginx", "-g", "daemon off;"]