"""Canvas LMS integration — supports both OAuth2 and personal access token."""

from __future__ import annotations
import urllib.parse
from datetime import datetime, timezone

import httpx
from dateutil.parser import isoparse  # type: ignore[import-untyped]

from app.config import get_settings
from app.models.schemas import CanvasTask


def build_auth_url() -> str:
    s = get_settings()
    params = {
        "client_id": s.canvas_client_id,
        "response_type": "code",
        "redirect_uri": s.canvas_redirect_uri,
        "scope": "url:GET|/api/v1/courses url:GET|/api/v1/users/:user_id/courses "
                 "url:GET|/api/v1/courses/:course_id/assignments",
    }
    return f"{s.canvas_base_url}/login/oauth2/auth?" + urllib.parse.urlencode(params)


async def exchange_code(code: str) -> dict:
    s = get_settings()
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{s.canvas_base_url}/login/oauth2/token",
            data={
                "grant_type": "authorization_code",
                "client_id": s.canvas_client_id,
                "client_secret": s.canvas_client_secret,
                "redirect_uri": s.canvas_redirect_uri,
                "code": code,
            },
        )
        resp.raise_for_status()
        return resp.json()


async def fetch_tasks(access_token: str) -> list[CanvasTask]:
    s = get_settings()
    base = s.canvas_base_url
    headers = {"Authorization": f"Bearer {access_token}"}

    async with httpx.AsyncClient() as client:
        courses_resp = await client.get(
            f"{base}/api/v1/courses",
            headers=headers,
            params={"enrollment_state": "active", "per_page": "50"},
        )
        if courses_resp.status_code != 200:
            return []
        courses = courses_resp.json()

    tasks: list[CanvasTask] = []
    now = datetime.now(timezone.utc)

    async with httpx.AsyncClient() as client:
        for course in courses:
            cid = course.get("id")
            cname = course.get("name", "Unknown Course")
            resp = await client.get(
                f"{base}/api/v1/courses/{cid}/assignments",
                headers=headers,
                params={
                    "per_page": "50",
                    "order_by": "due_at",
                    "bucket": "upcoming",
                },
            )
            if resp.status_code != 200:
                continue
            for a in resp.json():
                due_str = a.get("due_at")
                due_at = None
                if due_str:
                    try:
                        due_at = isoparse(due_str)
                    except Exception:
                        continue
                    if due_at < now:
                        continue
                tasks.append(CanvasTask(
                    id=str(a.get("id", "")),
                    course_name=cname,
                    assignment_name=a.get("name", ""),
                    due_at=due_at,
                    points_possible=a.get("points_possible"),
                    html_url=a.get("html_url"),
                ))

    tasks.sort(key=lambda t: t.due_at or datetime.max.replace(tzinfo=timezone.utc))
    return tasks
