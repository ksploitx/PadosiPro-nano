from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    DATABASE_URL: str = "sqlite+aiosqlite:///./padosipro.db"
    REDIS_URL: str = "redis://localhost:6379/0"
    JWT_SECRET: str = "supersecretjwtkey"
    SMTP_HOST: str = "localhost"
    SMTP_PORT: int = 1025

    class Config:
        env_file = ".env"

settings = Settings()
