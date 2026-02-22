from fastapi import APIRouter, Depends, HTTPException

from app.models.schemas import (
    PlanResponse, PlanGenerateRequest, CapacityConstraints,
    CalendarEvent, TradeoffReport, PlanInsightsResponse,
)
from app.services.scheduler import generate_plan, compute_tradeoffs
from app.services.goal_store import goal_store
from app.services.jwt_service import get_current_user
from app.services.token_store import store
from app.services.google_service import fetch_calendar_events
from app.services.gemini_service import get_plan_insights

router = APIRouter(prefix="/plan", tags=["plan"])

_plan_cache: dict[str, PlanResponse] = {}


async def _get_fixed_events(user_id: str) -> list[CalendarEvent]:
    ut = store.get(user_id)
    if ut and ut.google_access_token:
        try:
            return await fetch_calendar_events(ut.google_access_token)
        except Exception:
            pass
    return []


@router.post("/generate", response_model=PlanResponse)
async def generate(
    body: PlanGenerateRequest | None = None,
    user_id: str = Depends(get_current_user),
):
    goals = goal_store.list_goals(user_id)
    events = await _get_fixed_events(user_id)
    constraints = CapacityConstraints()

    plan = generate_plan(
        goals=goals,
        fixed_events=events,
        constraints=constraints,
        simulate_goal=body.simulate_goal if body else None,
    )
    _plan_cache[user_id] = plan
    return plan


@router.get("/current", response_model=PlanResponse)
async def current_plan(user_id: str = Depends(get_current_user)):
    if user_id in _plan_cache:
        return _plan_cache[user_id]
    goals = goal_store.list_goals(user_id)
    events = await _get_fixed_events(user_id)
    constraints = CapacityConstraints()
    plan = generate_plan(goals=goals, fixed_events=events, constraints=constraints)
    _plan_cache[user_id] = plan
    return plan


@router.post("/tradeoff", response_model=TradeoffReport)
async def tradeoff(
    body: PlanGenerateRequest,
    user_id: str = Depends(get_current_user),
):
    if not body.simulate_goal:
        raise HTTPException(400, "simulate_goal is required")
    goals = goal_store.list_goals(user_id)
    events = await _get_fixed_events(user_id)
    constraints = CapacityConstraints()
    return compute_tradeoffs(goals, body.simulate_goal, events, constraints)


@router.get("/insights", response_model=PlanInsightsResponse)
async def plan_insights(user_id: str = Depends(get_current_user)):
    """Gemini-generated summary, time breakdown, and where to add more."""
    plan = _plan_cache.get(user_id)
    if not plan:
        goals = goal_store.list_goals(user_id)
        events = await _get_fixed_events(user_id)
        plan = generate_plan(
            goals=goals,
            fixed_events=events,
            constraints=CapacityConstraints(),
        )
        _plan_cache[user_id] = plan
    goals = goal_store.list_goals(user_id)
    insights = get_plan_insights(plan, goals)
    if not insights:
        return PlanInsightsResponse(
            summary="",
            time_breakdown="",
            where_to_add_more="",
            available=False,
        )
    return PlanInsightsResponse(
        summary=insights["summary"],
        time_breakdown=insights["time_breakdown"],
        where_to_add_more=insights["where_to_add_more"],
        available=True,
    )
