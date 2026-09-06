"""
Simple web chat to ask gold retail data questions.

What this does:
  Opens a browser page where you type a question. Gemini writes SQL,
  DuckDB runs it read-only, and results show as a table.

How to run (venv on, from the project folder):
  pip install streamlit google-genai
  streamlit run text2sql/app.py

Needs:
  - GEMINI_API_KEY in local .env
  - Warehouse already built (run the pipeline once)
"""

from __future__ import annotations

import sys
from pathlib import Path

import streamlit as st

# Allow `streamlit run text2sql/app.py` to import the package
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from text2sql.executor import run_sql
from text2sql.generator import generate_sql

SUGGESTIONS = [
    "Which store had the highest revenue?",
    "Total revenue by channel",
    "Top 5 products by revenue including GST",
    "How many return lines do we have?",
    "Revenue by state",
]


def main() -> None:
    st.set_page_config(page_title="Ask retail data", page_icon="📊", layout="wide")
    st.title("Ask your retail data")
    st.caption(
        "Questions use reporting tables only (gold). "
        "Same numbers as Power BI. Read-only — nothing is changed."
    )

    st.subheader("Try a question")
    cols = st.columns(len(SUGGESTIONS))
    picked = None
    for i, suggestion in enumerate(SUGGESTIONS):
        if cols[i].button(suggestion, use_container_width=True):
            picked = suggestion

    question = st.text_input(
        "Your question",
        value=picked or "",
        placeholder="e.g. Which store had the highest revenue?",
    )
    show_sql = st.checkbox("Show SQL", value=False)
    ask = st.button("Ask", type="primary")

    if not ask:
        return

    q = (picked or question).strip()
    if not q:
        st.warning("Type a question or click a suggestion.")
        return

    with st.spinner("Writing SQL and running on gold…"):
        try:
            sql = generate_sql(q)
        except Exception as exc:
            st.error(f"Could not generate SQL: {exc}")
            return

        if show_sql:
            st.code(sql, language="sql")

        try:
            columns, rows = run_sql(sql, max_rows=200)
        except Exception as exc:
            st.error(f"Could not run SQL: {exc}")
            if not show_sql:
                with st.expander("SQL that failed"):
                    st.code(sql, language="sql")
            return

    if not rows:
        st.info("No rows returned.")
        return

    st.success(f"{len(rows)} row(s)")
    st.dataframe(
        [dict(zip(columns, row)) for row in rows],
        use_container_width=True,
    )


if __name__ == "__main__":
    main()
