from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query

from app.models.schemas import CalendarEventsResponse
from app.services.google_service import fetch_calendar_events
from app.services.jwt_service import get_current_user
from app.services.token_store import store

router = APIRouter(prefix="/calendar", tags=["calendar"])


@router.get("/events", response_model=CalendarEventsResponse)
async def get_events(
    user_id: str = Depends(get_current_user),
    from_date: datetime | None = Query(None, alias="from"),
    to_date: datetime | None = Query(None, alias="to"),
):
    ut = store.get(user_id)
    if not ut or not ut.google_access_token:
        raise HTTPException(401, "Google not connected. Please reconnect.")

    try:
        events = await fetch_calendar_events(ut.google_access_token, from_date, to_date)
    except Exception:
        raise HTTPException(502, "Failed to fetch calendar events")

    return CalendarEventsResponse(events=events)
