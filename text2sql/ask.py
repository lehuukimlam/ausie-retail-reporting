"""
Ask a business question: Gemini writes SQL, DuckDB runs it read-only.

What this does:
  1. Build gold schema context
  2. Ask Gemini for one SELECT
  3. Safety-check and run on DuckDB
  4. Print SQL + result table

How to run (venv on, from the project folder):
  python -m text2sql.ask "Which store had the highest revenue?"

Needs GEMINI_API_KEY in .env and a built warehouse (pipeline already run).
"""

from __future__ import annotations

import argparse
import sys

from text2sql.executor import format_table, run_sql
from text2sql.generator import generate_sql


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Ask gold retail data a question in plain English"
    )
    parser.add_argument(
        "question",
        nargs="+",
        help='Example: Which store had the highest revenue?',
    )
    parser.add_argument(
        "--max-rows",
        type=int,
        default=50,
        help="Max rows to show (default 50)",
    )
    args = parser.parse_args(argv)
    question = " ".join(args.question).strip()

    print(f"Question: {question}")
    print("---")
    try:
        sql = generate_sql(question)
    except Exception as exc:
        print(f"Could not generate SQL: {exc}", file=sys.stderr)
        return 1

    print("SQL:")
    print(sql)
    print("---")
    try:
        columns, rows = run_sql(sql, max_rows=args.max_rows)
    except Exception as exc:
        print(f"Could not run SQL: {exc}", file=sys.stderr)
        return 1

    print("Result:")
    print(format_table(columns, rows))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
