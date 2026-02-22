"""In-memory goal store for MVP."""

from __future__ import annotations
import uuid
from datetime import datetime, timezone
from app.models.schemas import Goal, GoalCreate, GoalCategory


def _default_study_goal() -> Goal:
    return Goal(
        id=str(uuid.uuid4()),
        name="Study / Homework",
        category=GoalCategory.study,
        priority_weight=7,
        weekly_target_hours=10.0,
        preferred_time_windows=[],
        hard_deadline=None,
        created_at=datetime.now(timezone.utc),
    )


class GoalStore:
    def __init__(self) -> None:
        self._goals: dict[str, dict[str, Goal]] = {}

    def _ensure_user(self, user_id: str) -> dict[str, Goal]:
        if user_id not in self._goals:
            default = _default_study_goal()
            self._goals[user_id] = {default.id: default}
        return self._goals[user_id]

    def list_goals(self, user_id: str) -> list[Goal]:
        return list(self._ensure_user(user_id).values())

    def create_goal(self, user_id: str, data: GoalCreate) -> Goal:
        goals = self._ensure_user(user_id)
        goal = Goal(
            id=str(uuid.uuid4()),
            created_at=datetime.now(timezone.utc),
            **data.model_dump(),
        )
        goals[goal.id] = goal
        return goal

    def get_goal(self, user_id: str, goal_id: str) -> Goal | None:
        return self._ensure_user(user_id).get(goal_id)


goal_store = GoalStore()
