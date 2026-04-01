from fastapi import FastAPI, HTTPException
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import Histogram
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError
from contextlib import asynccontextmanager
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os
import time
import uuid


# --- 1. 모니터링 메트릭 수집기 설정 ---
DB_LATENCY = Histogram(
    'db_operation_latency_seconds',
    'Database operation latency in seconds',
    ['operation']
)


DB_USER = os.getenv("DB_USER", "")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")        # K8s Secret에서 주입
DB_HOST = os.getenv("DB_HOST", "127.0.0.1")       # Cloud SQL Proxy sidecar
DB_NAME = os.getenv("DB_NAME", "hybrid_app_db")

DATABASE_URL = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:3306/{DB_NAME}"

engine = create_engine(
    DATABASE_URL,
    pool_size=10,        # 기본 유지 커넥션 수
    max_overflow=20,     # 피크 시 추가 허용 커넥션 (최대 30개)
    pool_timeout=30,     # 커넥션 대기 최대 30초, 초과 시 에러
    pool_recycle=1800,   # 30분마다 커넥션 재생성 → 좀비 커넥션 방지
    pool_pre_ping=True   # 사용 전 커넥션 생존 여부 확인
)

# --- 3. 앱 시작 시 더미 테이블 생성 ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup: yield 이전 블록
    create_table_query = """
    CREATE TABLE IF NOT EXISTS dummy_data (
        id VARCHAR(50) PRIMARY KEY,
        value VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    """
    for attempt in range(10):
        try:
            with engine.begin() as connection:
                connection.execute(text(create_table_query))
            print("Table 'dummy_data' ensured.")
            break
        except Exception as e:
            print(f"Failed to create table (attempt {attempt + 1}/10): {e}")
            if attempt < 9:
                time.sleep(3)

    yield  # 앱 실행 구간

    # shutdown: yield 이후 블록
    engine.dispose()  
    print("DB connection pool disposed.")

app = FastAPI(title="Hybrid Cloud API", lifespan=lifespan)

# frontend와 연결
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 4. 모니터링 메트릭 수집기 설정(/metrics) ---
Instrumentator().instrument(app).expose(
    app,
    include_in_schema=False,   # Swagger UI에서 숨김
    tags=["monitoring"]
)

# --- 5. API 엔드포인트 ---
@app.get("/health")
def health_check():
    start_time = time.time()
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        # DB 지연 시간 기록
        DB_LATENCY.labels(operation='health').observe(time.time() - start_time)
        return {"status": "ok", "message": "Primary Pool is Healthy"}
    except OperationalError:
        # 실패 시에도 지연 시간 기록
        DB_LATENCY.labels(operation='health').observe(time.time() - start_time)
        raise HTTPException(status_code=503, detail="Database Connection Failed.")

@app.post("/api/data")
def write_dummy_data():
    start_time = time.time()
    try:
        with engine.begin() as connection:
            connection.execute(
                text("INSERT INTO dummy_data (id, value) VALUES (:id, :value)"),
                {"id": str(uuid.uuid4()), "value": f"test-payload-{time.time()}"}
            )
        return {"status": "success", "operation": "write"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # 지연 시간 기록
        DB_LATENCY.labels(operation='write').observe(time.time() - start_time)


@app.get("/api/data")
def read_dummy_data():
    start_time = time.time()
    try:
        with engine.connect() as connection:
            result = connection.execute(
                text("SELECT id, value FROM dummy_data ORDER BY created_at DESC LIMIT 5")
            )
            rows = [{"id": row[0], "value": row[1]} for row in result]
        return {"status": "success", "operation": "read", "data": rows}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # 지연 시간 기록
        DB_LATENCY.labels(operation='read').observe(time.time() - start_time)


