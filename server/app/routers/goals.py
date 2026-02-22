from fastapi import APIRouter, Depends

from app.models.schemas import GoalCreate, Goal, GoalsResponse
from app.services.goal_store import goal_store
from app.services.jwt_service import get_current_user

router = APIRouter(prefix="/goals", tags=["goals"])


@router.get("", response_model=GoalsResponse)
async def list_goals(user_id: str = Depends(get_current_user)):
    return GoalsResponse(goals=goal_store.list_goals(user_id))


@router.post("", response_model=Goal)
async def create_goal(
    body: GoalCreate,
    user_id: str = Depends(get_current_user),
):
    return goal_store.create_goal(user_id, body)
