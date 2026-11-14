#!/usr/bin/env python3
"""baseline-to-sqlite.py — eval baseline csv → SQLite 변환 (2026-05-02 묶음 Q NEW-23)

동기:
  - baseline.csv (현재 90+ 줄) + edd-baseline.csv (15+ 줄) 누적
  - csv는 분석 한계 (시계열 trend / 카테고리별 통과율 / 회귀 빈도 정밀)
  - SQLite로 read-only 변환 → 분석 도구 확장 여지 (Grafana / DuckDB / pandas 등)

원칙 (안전 마이그레이션):
  - csv는 그대로 유지 (eval-runner 변경 없음)
  - sqlite는 csv → 동기화 단방향 (read-only 분석용)
  - 매 변환 시 db 재생성 (idempotent)

사용:
    python3 eval/scripts/baseline-to-sqlite.py [--db PATH]
    python3 eval/scripts/baseline-to-sqlite.py --query "SELECT * FROM regression ORDER BY ts DESC LIMIT 10"

스키마:
    regression(ts TEXT PRIMARY KEY, total INT, pass INT, fail INT, pass_rate REAL)
    edd(ts TEXT PRIMARY KEY, mode TEXT, runs INT, llm INT, total INT, pass INT, fail INT, pass_rate REAL)

Exit 0 PASS / 1 ERROR
"""
import csv
import sqlite3
import sys
import argparse
from pathlib import Path

ROOT = Path("/Users/sokol/Git/ProjectGrimoire")
DEFAULT_DB = ROOT / "eval" / "results" / "baseline.db"
REG_CSV = ROOT / "eval" / "results" / "baseline.csv"
EDD_CSV = ROOT / "eval" / "results" / "edd-baseline.csv"


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--db", default=str(DEFAULT_DB), help="SQLite DB 경로")
    p.add_argument("--query", help="변환 후 SQL 즉시 실행 (분석용)")
    p.add_argument("--quiet", action="store_true")
    return p.parse_args()


def import_regression(conn):
    if not REG_CSV.exists():
        return 0
    cur = conn.cursor()
    cur.execute("DROP TABLE IF EXISTS regression")
    cur.execute("""
        CREATE TABLE regression (
            ts TEXT PRIMARY KEY,
            total INTEGER,
            pass INTEGER,
            fail INTEGER,
            pass_rate REAL
        )
    """)
    n = 0
    with open(REG_CSV) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                cur.execute(
                    "INSERT OR IGNORE INTO regression VALUES (?,?,?,?,?)",
                    (row["ts"], int(row["total"]), int(row["pass"]), int(row["fail"]),
                     float(row["pass_rate"]) if row["pass_rate"] else 0.0)
                )
                n += 1
            except (ValueError, KeyError):
                continue
    conn.commit()
    return n


def import_edd(conn):
    if not EDD_CSV.exists():
        return 0
    cur = conn.cursor()
    cur.execute("DROP TABLE IF EXISTS edd")
    cur.execute("""
        CREATE TABLE edd (
            ts TEXT PRIMARY KEY,
            mode TEXT,
            runs INTEGER,
            llm INTEGER,
            total INTEGER,
            pass INTEGER,
            fail INTEGER,
            pass_rate REAL
        )
    """)
    n = 0
    with open(EDD_CSV) as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                cur.execute(
                    "INSERT OR IGNORE INTO edd VALUES (?,?,?,?,?,?,?,?)",
                    (row["ts"], row["mode"], int(row["runs"]), int(row["llm"]),
                     int(row["total"]), int(row["pass"]), int(row["fail"]),
                     float(row["pass_rate"]))
                )
                n += 1
            except (ValueError, KeyError):
                continue
    conn.commit()
    return n


def main():
    args = parse_args()
    db_path = Path(args.db)
    db_path.parent.mkdir(parents=True, exist_ok=True)

    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(str(db_path))
    reg_n = import_regression(conn)
    edd_n = import_edd(conn)

    if not args.quiet:
        print(f"=== baseline → SQLite 변환 완료 ===")
        print(f"  DB: {db_path}")
        print(f"  regression rows: {reg_n}")
        print(f"  edd rows: {edd_n}")

    # 기본 분석 통계
    if not args.quiet:
        cur = conn.cursor()
        # 최근 10회 통과율 (regression, total ≥ 10)
        cur.execute("SELECT ts, pass, total, pass_rate FROM regression WHERE total >= 10 ORDER BY ts DESC LIMIT 10")
        rows = cur.fetchall()
        print(f"\n  최근 10회 regression (total ≥ 10):")
        for r in rows:
            print(f"    {r[0]} {r[1]}/{r[2]} = {r[3]:.4f}")

        # 카테고리 분석은 details.jsonl 필요 (별도 작업)

    if args.query:
        cur = conn.cursor()
        try:
            cur.execute(args.query)
            for row in cur.fetchall():
                print(row)
        except sqlite3.Error as e:
            print(f"❌ Query error: {e}", file=sys.stderr)
            return 1

    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
