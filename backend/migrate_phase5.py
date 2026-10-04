#!/usr/bin/env python3
"""
Phase 5 migration: add requested_time and note columns to task_selections.
Run ONCE from the backend/ directory:

    python migrate_phase5.py

Safe to run again — ALTER TABLE is skipped if the column already exists.
"""
import sqlite3, os, sys

DB_PATH = os.path.join(os.path.dirname(__file__), "padosipro.db")

def column_exists(cur, table: str, column: str) -> bool:
    cur.execute(f"PRAGMA table_info({table})")
    return any(row[1] == column for row in cur.fetchall())

def main():
    if not os.path.exists(DB_PATH):
        print(f"[SKIP] {DB_PATH} not found — the app will create it fresh on first start.")
        return

    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()

    added = []
    if not column_exists(cur, "task_selections", "requested_time"):
        cur.execute("ALTER TABLE task_selections ADD COLUMN requested_time DATETIME")
        added.append("requested_time")

    if not column_exists(cur, "task_selections", "note"):
        cur.execute("ALTER TABLE task_selections ADD COLUMN note VARCHAR(280)")
        added.append("note")

    if added:
        con.commit()
        print(f"[OK] Added columns to task_selections: {', '.join(added)}")
    else:
        print("[OK] Columns already present — nothing to do.")

    con.close()

if __name__ == "__main__":
    main()
