"""HTTP client for Supabase Edge Function `send-fcm-push` (FCM v1)."""

import json
import logging
import os
from typing import Any, Mapping, Optional, Sequence

import requests

logger = logging.getLogger(__name__)


def _function_url() -> str:
    explicit = os.environ.get("SUPABASE_FUNCTIONS_URL", "").strip().rstrip("/")
    if explicit:
        return explicit
    base = os.environ.get("SUPABASE_URL", "").strip().rstrip("/")
    if not base:
        return ""
    return f"{base}/functions/v1/send-fcm-push"


def dispatch_fcm_to_users(
    user_uuids: Sequence[str],
    title: str,
    body: str,
    data: Optional[Mapping[str, Any]] = None,
) -> Optional[dict]:
    """
    POST to Edge Function. Returns parsed JSON on success, None if skipped or hard failure.

    Requires PUSH_DISPATCH_SECRET and either SUPABASE_FUNCTIONS_URL or SUPABASE_URL.
    """
    secret = os.environ.get("PUSH_DISPATCH_SECRET", "").strip()
    url = _function_url()
    if not secret or not url:
        logger.debug("FCM dispatch skipped: set PUSH_DISPATCH_SECRET and SUPABASE_URL (or SUPABASE_FUNCTIONS_URL)")
        return None

    ids = list(dict.fromkeys(u for u in user_uuids if u and str(u).strip()))
    if not ids:
        return None

    payload: dict[str, Any] = {"user_ids": ids, "title": title, "body": body}
    if data:
        payload["data"] = {str(k): v if isinstance(v, str) else json.dumps(v) for k, v in data.items()}

    try:
        r = requests.post(
            url,
            headers={
                "Authorization": f"Bearer {secret}",
                "Content-Type": "application/json",
            },
            data=json.dumps(payload),
            timeout=20,
        )
        if not r.ok:
            logger.warning("FCM dispatch HTTP %s: %s", r.status_code, (r.text or "")[:500])
            return None
        return r.json()
    except requests.RequestException as e:
        logger.warning("FCM dispatch request failed: %s", e)
        return None
