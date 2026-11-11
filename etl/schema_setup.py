"""
schema_setup.py — Create all tables in the database.
Run once after `docker compose up -d db`.

Usage:
    python etl/schema_setup.py
"""
from __future__ import annotations

import sys
from pathlib import Path

# Allow running from project root
sys.path.insert(0, str(Path(__file__).parent.parent))

from etl.db import get_engine, test_connection
from sqlalchemy import text


def create_schema(engine) -> None:
    schema_sql = (Path(__file__).parent.parent / "sql" / "schema.sql").read_text()
    with engine.begin() as conn:
        conn.execute(text(schema_sql))
    print("[schema_setup] All tables created (or already exist).")


if __name__ == "__main__":
    engine = get_engine()
    if not test_connection(engine):
        print("[schema_setup] Cannot reach database. Is Docker running?")
        sys.exit(1)
    create_schema(engine)
    print("[schema_setup] Done.")
