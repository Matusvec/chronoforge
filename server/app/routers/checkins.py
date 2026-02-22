from fastapi import APIRouter, Depends, HTTPException

from app.models.schemas import (
    CheckInCreate, CheckIn, CheckInResponse, CheckInsListResponse,
)
from app.services.checkin_store import checkin_store
from app.services.gemini_service import process_checkin
from app.services.jwt_service import get_current_user

router = APIRouter(prefix="/checkins", tags=["checkins"])


@router.post("", response_model=CheckInResponse)
async def submit_checkin(
    body: CheckInCreate,
    user_id: str = Depends(get_current_user),
):
    """Submit what you did for a time block; get Gemini assessment + motivational message."""
    recent = checkin_store.recent_summaries(user_id)
    result = process_checkin(
        planned_goal_name=body.planned_goal_name,
        start=body.start,
        end=body.end,
        what_user_did=body.what_i_did,
        recent_summaries=recent,
    )
    if not result:
        raise HTTPException(
            503,
            "Gemini is not configured. Set GEMINI_API_KEY to enable check-in insights.",
        )
    assessment, motivational_message = result
    check_in = checkin_store.add(
        user_id=user_id,
        create=body,
        assessment=assessment,
        motivational_message=motivational_message,
    )
    return CheckInResponse(
        assessment=check_in.assessment,
        motivational_message=check_in.motivational_message,
        check_in_id=check_in.id,
    )


@router.get("", response_model=CheckInsListResponse)
async def list_checkins(
    user_id: str = Depends(get_current_user),
    limit: int = 50,
):
    """List recent check-ins for honesty tracking / dashboard."""
    check_ins = checkin_store.list_recent(user_id, limit=limit)
    return CheckInsListResponse(check_ins=check_ins)
