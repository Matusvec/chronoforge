from fastapi import APIRouter, Depends, HTTPException

from app.models.schemas import GmailSignalsResponse
from app.services.google_service import fetch_gmail_signals
from app.services.jwt_service import get_current_user
from app.services.token_store import store

router = APIRouter(prefix="/gmail", tags=["gmail"])


@router.get("/signals", response_model=GmailSignalsResponse)
async def get_signals(user_id: str = Depends(get_current_user)):
    ut = store.get(user_id)
    if not ut or not ut.google_access_token:
        raise HTTPException(401, "Google not connected. Please reconnect.")

    try:
        signals = await fetch_gmail_signals(ut.google_access_token)
    except Exception:
        raise HTTPException(502, "Failed to fetch Gmail signals")

    return GmailSignalsResponse(signals=signals)
