from fastapi import APIRouter, Depends, HTTPException

from app.models.schemas import CanvasTasksResponse
from app.services.canvas_service import fetch_tasks
from app.services.jwt_service import get_current_user
from app.services.token_store import store

router = APIRouter(prefix="/canvas", tags=["canvas"])


@router.get("/tasks", response_model=CanvasTasksResponse)
async def get_tasks(user_id: str = Depends(get_current_user)):
    ut = store.get(user_id)
    if not ut or not ut.canvas_access_token:
        raise HTTPException(401, "Canvas not connected. Please reconnect.")

    try:
        tasks = await fetch_tasks(ut.canvas_access_token)
    except Exception:
        raise HTTPException(502, "Failed to fetch Canvas tasks")

    return CanvasTasksResponse(tasks=tasks)
