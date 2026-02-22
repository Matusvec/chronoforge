from fastapi import APIRouter, Query, HTTPException

from app.models.schemas import (
    AuthStartResponse, AuthCallbackResponse,
    CanvasTokenRequest, IntegrationStatus,
)
from app.services import google_service, canvas_service
from app.services.token_store import store
from app.services.jwt_service import create_token, get_current_user
from fastapi import Depends

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/google/start", response_model=AuthStartResponse)
async def google_start():
    return AuthStartResponse(auth_url=google_service.build_auth_url())


@router.get("/google/callback", response_model=AuthCallbackResponse)
async def google_callback(code: str = Query(...)):
    try:
        tokens = await google_service.exchange_code(code)
    except Exception as e:
        raise HTTPException(400, f"OAuth exchange failed: {e}")

    access_token = tokens["access_token"]
    refresh_token = tokens.get("refresh_token", "")
    email = await google_service.get_user_email(access_token)

    user_id = email
    ut = store.get_or_create(user_id)
    ut.google_access_token = access_token
    ut.email = email
    if refresh_token:
        ut.set_google_refresh(refresh_token)

    jwt_token = create_token(user_id)
    return AuthCallbackResponse(token=jwt_token, email=email)


@router.post("/canvas/start", response_model=AuthStartResponse)
async def canvas_start():
    return AuthStartResponse(auth_url=canvas_service.build_auth_url())


@router.get("/canvas/callback", response_model=AuthCallbackResponse)
async def canvas_callback(
    code: str = Query(...),
    user_id: str = Depends(get_current_user),
):
    try:
        tokens = await canvas_service.exchange_code(code)
    except Exception as e:
        raise HTTPException(400, f"Canvas OAuth failed: {e}")

    ut = store.get_or_create(user_id)
    ut.canvas_access_token = tokens.get("access_token", "")
    return AuthCallbackResponse(token=create_token(user_id), email=ut.email)


@router.post("/integrations/canvas/token")
async def canvas_token(
    body: CanvasTokenRequest,
    user_id: str = Depends(get_current_user),
):
    ut = store.get_or_create(user_id)
    ut.canvas_access_token = body.access_token
    return {"status": "ok"}


@router.get("/integrations/status", response_model=IntegrationStatus)
async def integration_status(user_id: str = Depends(get_current_user)):
    ut = store.get(user_id)
    if not ut:
        return IntegrationStatus()
    return IntegrationStatus(
        google=ut.google_access_token is not None,
        canvas=ut.canvas_access_token is not None,
    )
