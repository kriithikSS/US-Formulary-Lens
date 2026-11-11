"""
db.py — SQLAlchemy engine factory.
Reads connection params from environment / .env file.
"""
from __future__ import annotations

import os
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from dotenv import load_dotenv

load_dotenv()


def get_engine(schema: str | None = None) -> Engine:
    """Return a SQLAlchemy engine connected to the configured PostgreSQL database."""
    host = os.environ["DB_HOST"]
    port = os.environ.get("DB_PORT", "5432")
    name = os.environ["DB_NAME"]
    user = os.environ["DB_USER"]
    password = os.environ["DB_PASSWORD"]

    url = f"postgresql+psycopg://{user}:{password}@{host}:{port}/{name}"
    connect_args: dict = {}
    if schema:
        connect_args["options"] = f"-csearch_path={schema}"

    engine = create_engine(
        url,
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=10,
        connect_args=connect_args,
    )
    return engine


def test_connection(engine: Engine) -> bool:
    """Return True if the database is reachable."""
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception as exc:
        print(f"[db] Connection failed: {exc}")
        return False
