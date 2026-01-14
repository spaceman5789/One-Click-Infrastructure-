import os
import psycopg2
from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/health/db")
def health_db():
    conn = psycopg2.connect(
        host=os.getenv("DB_HOST", "127.0.0.1"),
        port=int(os.getenv("DB_PORT", "5432")),
        user=os.getenv("DB_USER", "app"),
        password=os.getenv("DB_PASSWORD", "apppass"),
        dbname=os.getenv("DB_NAME", "appdb"),
        connect_timeout=2,
    )
    conn.close()
    return {"db": "ok"}