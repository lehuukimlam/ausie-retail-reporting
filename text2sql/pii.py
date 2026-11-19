"""
Mask emails and phone numbers before text is sent to an external AI.

Used on the user question (and any other outbound prompt text). Synthetic
demo data still should not leave the laptop in cleartext toward Gemini.
"""

from __future__ import annotations

import re

# Practical patterns — portfolio hardening, not a full telecom library.
EMAIL_RE = re.compile(
    r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b",
)
# AU-ish and general: +61…, 04xx xxx xxx, (02) xxxx xxxx, bare 10+ digit runs
PHONE_RE = re.compile(
    r"""
    (?<!\w)
    (?:
        \+?\d{1,3}[\s.-]?\(?\d{1,4}\)?[\s.-]?\d{3,4}[\s.-]?\d{3,4}
        |
        \(?\d{2,4}\)?[\s.-]?\d{3,4}[\s.-]?\d{3,4}
    )
    (?!\w)
    """,
    re.VERBOSE,
)


def mask_emails(text: str) -> str:
    return EMAIL_RE.sub("[email masked]", text)


def mask_phones(text: str) -> str:
    return PHONE_RE.sub("[phone masked]", text)


def mask_pii(text: str) -> str:
    """Mask emails then phones in outbound text for the AI."""
    if not text:
        return text
    return mask_phones(mask_emails(text))
