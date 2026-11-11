"""
audit.py — ETL audit logger.
Writes one record per ETL load to the etl_audit table.
"""
from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from sqlalchemy import text
from sqlalchemy.engine import Engine


def _file_md5(path: str | Path, chunk: int = 1 << 20) -> str:
    """Return MD5 hex digest of a file (1 MB chunks)."""
    h = hashlib.md5()
    with open(path, "rb") as f:
        while buf := f.read(chunk):
            h.update(buf)
    return h.hexdigest()


def log_audit(
    engine: Engine,
    source_name: str,
    source_file: str | Path,
    rows_read: int,
    rows_inserted: int,
    rows_rejected: int,
    null_rates: dict[str, float],
    duplicate_key_count: int,
    unmatched_joins: dict[str, int],
    notes: str = "",
    etl_version: str = "",
) -> None:
    """Insert one row into etl_audit."""
    checksum = _file_md5(source_file) if Path(source_file).exists() else ""
    record = {
        "load_timestamp": datetime.now(timezone.utc),
        "source_name": source_name,
        "source_file": str(source_file),
        "rows_read": rows_read,
        "rows_inserted": rows_inserted,
        "rows_rejected": rows_rejected,
        "null_rate_json": json.dumps(null_rates),
        "duplicate_key_count": duplicate_key_count,
        "unmatched_joins": json.dumps(unmatched_joins),
        "checksum": checksum,
        "notes": notes,
        "etl_version": etl_version or os.environ.get("GIT_SHA", "unknown"),
    }

    sql = text(
        """
        INSERT INTO etl_audit (
            load_timestamp, source_name, source_file,
            rows_read, rows_inserted, rows_rejected,
            null_rate_json, duplicate_key_count, unmatched_joins,
            checksum, notes, etl_version
        ) VALUES (
            :load_timestamp, :source_name, :source_file,
            :rows_read, :rows_inserted, :rows_rejected,
            :null_rate_json::jsonb, :duplicate_key_count, :unmatched_joins::jsonb,
            :checksum, :notes, :etl_version
        )
        """
    )
    with engine.begin() as conn:
        conn.execute(sql, record)
    print(
        f"[audit] {source_name}: "
        f"read={rows_read:,} inserted={rows_inserted:,} rejected={rows_rejected:,}"
    )
