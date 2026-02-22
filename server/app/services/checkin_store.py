"""In-memory check-in store for MVP."""

from __future__ import annotations
import uuid
from datetime import datetime, timezone
from app.models.schemas import CheckIn, CheckInCreate, CheckInResponse


class CheckInStore:
    def __init__(self) -> None:
        self._by_user: dict[str, list[CheckIn]] = {}

    def _list(self, user_id: str) -> list[CheckIn]:
        if user_id not in self._by_user:
            self._by_user[user_id] = []
        return self._by_user[user_id]

    def add(
        self,
        user_id: str,
        create: CheckInCreate,
        assessment: str,
        motivational_message: str,
    ) -> CheckIn:
        check_in = CheckIn(
            id=str(uuid.uuid4()),
            block_id=create.block_id,
            planned_goal_id=create.planned_goal_id,
            planned_goal_name=create.planned_goal_name,
            start=create.start,
            end=create.end,
            what_i_did=create.what_i_did,
            assessment=assessment,
            motivational_message=motivational_message,
            created_at=datetime.now(timezone.utc),
        )
        self._list(user_id).append(check_in)
        return check_in

    def list_recent(self, user_id: str, limit: int = 50) -> list[CheckIn]:
        all_ = sorted(self._list(user_id), key=lambda c: c.created_at, reverse=True)
        return all_[:limit]

    def get_by_block(self, user_id: str, block_id: str) -> CheckIn | None:
        for c in self._list(user_id):
            if c.block_id == block_id:
                return c
        return None

    def recent_summaries(self, user_id: str, limit: int = 10) -> list[str]:
        recent = self.list_recent(user_id, limit=limit)
        return [f"{c.planned_goal_name}: {c.what_i_did}" for c in recent]


checkin_store = CheckInStore()
