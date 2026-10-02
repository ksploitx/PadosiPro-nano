from fastapi import FastAPI
from contextlib import asynccontextmanager
from app.config import settings
from app.database import engine, Base
from app.redis_client import redis_client
from app.routers import auth
from app.models import User, Profile, OtpCode, Task, TaskSelection

@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield

app = FastAPI(title="PadosiPro Nano API", lifespan=lifespan)

app.include_router(auth.router)

@app.get("/health")
async def health_check():
    return {"status": "ok"}
