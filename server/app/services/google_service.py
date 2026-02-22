"""Google OAuth + Calendar + Gmail integration."""

from __future__ import annotations
import urllib.parse
from datetime import datetime, timedelta, timezone
from dateutil.parser import isoparse  # type: ignore[import-untyped]

import httpx

from app.config import get_settings
from app.models.schemas import (
    CalendarEvent, GmailSignal, SignalType,
)

SCOPES = [
    "openid",
    "email",
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/gmail.readonly",
]

SIGNAL_KEYWORDS: dict[str, SignalType] = {
    "interview": SignalType.interview,
    "deadline": SignalType.deadline,
    "apply": SignalType.application,
    "application": SignalType.application,
    "offer": SignalType.offer,
    "rsvp": SignalType.rsvp,
    "invite": SignalType.invite,
    "internship": SignalType.internship,
    "hackathon": SignalType.hackathon,
    "submission": SignalType.submission,
}


def build_auth_url() -> str:
    s = get_settings()
    params = {
        "client_id": s.google_client_id,
        "redirect_uri": s.google_redirect_uri,
        "response_type": "code",
        "scope": " ".join(SCOPES),
        "access_type": "offline",
        "prompt": "consent",
    }
    return "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode(params)


async def exchange_code(code: str) -> dict:
    s = get_settings()
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "code": code,
                "client_id": s.google_client_id,
                "client_secret": s.google_client_secret,
                "redirect_uri": s.google_redirect_uri,
                "grant_type": "authorization_code",
            },
        )
        resp.raise_for_status()
        return resp.json()


async def refresh_access_token(refresh_token: str) -> dict:
    s = get_settings()
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "refresh_token": refresh_token,
                "client_id": s.google_client_id,
                "client_secret": s.google_client_secret,
                "grant_type": "refresh_token",
            },
        )
        resp.raise_for_status()
        return resp.json()


async def get_user_email(access_token: str) -> str:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        resp.raise_for_status()
        return resp.json().get("email", "unknown")


async def fetch_calendar_events(
    access_token: str,
    time_min: datetime | None = None,
    time_max: datetime | None = None,
) -> list[CalendarEvent]:
    now = datetime.now(timezone.utc)
    if time_min is None:
        time_min = now
    if time_max is None:
        time_max = now + timedelta(days=14)

    params = {
        "timeMin": time_min.isoformat(),
        "timeMax": time_max.isoformat(),
        "singleEvents": "true",
        "orderBy": "startTime",
        "maxResults": "250",
    }
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://www.googleapis.com/calendar/v3/calendars/primary/events",
            headers={"Authorization": f"Bearer {access_token}"},
            params=params,
        )
        resp.raise_for_status()
        data = resp.json()

    events: list[CalendarEvent] = []
    for item in data.get("items", []):
        start_raw = item.get("start", {})
        end_raw = item.get("end", {})
        is_all_day = "date" in start_raw and "dateTime" not in start_raw
        start_str = start_raw.get("dateTime") or start_raw.get("date", "")
        end_str = end_raw.get("dateTime") or end_raw.get("date", "")
        if not start_str or not end_str:
            continue
        events.append(CalendarEvent(
            id=item.get("id", ""),
            title=item.get("summary", "(No title)"),
            start=isoparse(start_str),
            end=isoparse(end_str),
            is_all_day=is_all_day,
        ))
    return events


async def fetch_gmail_signals(access_token: str) -> list[GmailSignal]:
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            "https://www.googleapis.com/gmail/v1/users/me/messages",
            headers={"Authorization": f"Bearer {access_token}"},
            params={"maxResults": "50", "q": "is:inbox"},
        )
        resp.raise_for_status()
        message_ids = [m["id"] for m in resp.json().get("messages", [])]

    signals: list[GmailSignal] = []
    async with httpx.AsyncClient() as client:
        for mid in message_ids:
            resp = await client.get(
                f"https://www.googleapis.com/gmail/v1/users/me/messages/{mid}",
                headers={"Authorization": f"Bearer {access_token}"},
                params={"format": "metadata", "metadataHeaders": "Subject,From,Date"},
            )
            if resp.status_code != 200:
                continue
            msg = resp.json()
            headers = {h["name"].lower(): h["value"] for h in msg.get("payload", {}).get("headers", [])}
            subject = headers.get("subject", "")
            snippet = msg.get("snippet", "")
            text = (subject + " " + snippet).lower()

            matched: list[SignalType] = []
            for kw, st in SIGNAL_KEYWORDS.items():
                if kw in text:
                    matched.append(st)

            if matched:
                date_str = headers.get("date", "")
                try:
                    date = isoparse(date_str)
                except Exception:
                    date = datetime.now(timezone.utc)

                signals.append(GmailSignal(
                    id=mid,
                    subject=subject,
                    snippet=snippet[:200],
                    sender=headers.get("from", ""),
                    date=date,
                    signal_types=matched,
                ))
    return signals
