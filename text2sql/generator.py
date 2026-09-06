"""
Ask Gemini to turn a business question into DuckDB SQL (gold tables only).

What this does:
  Sends the gold schema text plus your question to Google Gemini, then
  returns a single SQL SELECT statement.

Needs:
  GEMINI_API_KEY in your local .env (from Google AI Studio, free tier).

How to use:
  Called by text2sql.ask — or import generate_sql(question).
"""

from __future__ import annotations

import os
import re
from pathlib import Path

from dotenv import load_dotenv

from text2sql.schema import build_schema_prompt

ROOT = Path(__file__).resolve().parents[1]

# Fast free-tier friendly model; change in .env if needed
DEFAULT_MODEL = "gemini-3.6-flash"


def _strip_sql_fence(text: str) -> str:
    """Remove markdown code fences if the model wraps the SQL."""
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:sql)?\s*", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\s*```$", "", cleaned)
    return cleaned.strip().rstrip(";")


def _load_settings() -> tuple[str, str]:
    """Read key + model from .env each call (override stale process env / Streamlit cache)."""
    load_dotenv(ROOT / ".env", override=True)
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    model = (os.environ.get("GEMINI_MODEL") or DEFAULT_MODEL).strip()
    return api_key, model


def generate_sql(question: str) -> str:
    api_key, model = _load_settings()
    if not api_key:
        raise RuntimeError(
            "Missing GEMINI_API_KEY in .env. "
            "Get a free key from Google AI Studio and add it locally."
        )

    from google import genai

    schema = build_schema_prompt()
    prompt = (
        f"{schema}\n"
        "Return ONLY one DuckDB SQL SELECT query. No explanation.\n"
        f"Question: {question}\n"
    )

    client = genai.Client(api_key=api_key)
    response = client.models.generate_content(
        model=model,
        contents=prompt,
    )
    if not response.text:
        raise RuntimeError("Gemini returned an empty response.")

    return _strip_sql_fence(response.text)


def main() -> None:
    import sys

    question = " ".join(sys.argv[1:]).strip() or "Total revenue including GST by store"
    print(generate_sql(question))


if __name__ == "__main__":
    main()
