from fastapi import FastAPI
from app.config import settings
from app.database import engine
from app.redis_client import redis_client

app = FastAPI(title="PadosiPro Nano API")

@app.get("/health")
async def health_check():
    return {"status": "ok"}
