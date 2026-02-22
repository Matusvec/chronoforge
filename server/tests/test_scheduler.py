"""Unit tests for the greedy scheduler."""

import pytest
from datetime import datetime, timedelta, timezone

from app.models.schemas import (
    CalendarEvent, Goal, GoalCategory, CapacityConstraints,
    TimeWindow,
)
from app.services.scheduler import compute_free_blocks, generate_plan, FreeSlot


def _dt(year: int, month: int, day: int, hour: int = 0) -> datetime:
    return datetime(year, month, day, hour, tzinfo=timezone.utc)


class TestFreeBlocks:
    def test_empty_day_with_sleep(self):
        constraints = CapacityConstraints(sleep_start_hour=0, sleep_end_hour=7)
        day_start = _dt(2026, 3, 1)
        day_end = _dt(2026, 3, 2)

        free = compute_free_blocks(day_start, day_end, [], constraints)
        total_free = sum(s.hours for s in free)
        assert 16.5 <= total_free <= 17.0

    def test_event_subtracts_time(self):
        constraints = CapacityConstraints(sleep_start_hour=0, sleep_end_hour=7)
        day_start = _dt(2026, 3, 1)
        day_end = _dt(2026, 3, 2)

        event = CalendarEvent(
            id="e1", title="Meeting",
            start=_dt(2026, 3, 1, 10),
            end=_dt(2026, 3, 1, 12),
        )

        free = compute_free_blocks(day_start, day_end, [event], constraints)
        total_free = sum(s.hours for s in free)
        assert 14.5 <= total_free <= 15.0

    def test_overlapping_events_merge(self):
        constraints = CapacityConstraints(sleep_start_hour=0, sleep_end_hour=7)
        day_start = _dt(2026, 3, 1)
        day_end = _dt(2026, 3, 2)

        events = [
            CalendarEvent(id="e1", title="A", start=_dt(2026, 3, 1, 9), end=_dt(2026, 3, 1, 11)),
            CalendarEvent(id="e2", title="B", start=_dt(2026, 3, 1, 10), end=_dt(2026, 3, 1, 13)),
        ]

        free = compute_free_blocks(day_start, day_end, events, constraints)
        total_free = sum(s.hours for s in free)
        assert 12.5 <= total_free <= 13.0

    def test_no_free_for_allday_event(self):
        constraints = CapacityConstraints(sleep_start_hour=0, sleep_end_hour=7)
        day_start = _dt(2026, 3, 1)
        day_end = _dt(2026, 3, 2)

        event = CalendarEvent(
            id="e1", title="Holiday",
            start=day_start, end=day_end,
            is_all_day=True,
        )
        free = compute_free_blocks(day_start, day_end, [event], constraints)
        assert len(free) == 0


class TestGeneratePlan:
    def _make_goal(self, name: str, weight: int, hours: float, **kw) -> Goal:
        return Goal(
            id=name.lower().replace(" ", "_"),
            name=name,
            category=GoalCategory.study,
            priority_weight=weight,
            weekly_target_hours=hours,
            preferred_time_windows=kw.get("windows", []),
            hard_deadline=None,
            created_at=_dt(2026, 1, 1),
        )

    def test_single_goal_gets_allocated(self):
        goals = [self._make_goal("Study", 8, 10.0)]
        plan = generate_plan(
            goals=goals,
            fixed_events=[],
            constraints=CapacityConstraints(),
            start_date=_dt(2026, 3, 1),
            days=7,
        )
        allocated = sum(
            (b.end - b.start).total_seconds() / 3600
            for b in plan.blocks if not b.is_fixed
        )
        assert allocated >= 9.0

    def test_high_priority_gets_more(self):
        goals = [
            self._make_goal("Important", 10, 10.0),
            self._make_goal("Low", 1, 10.0),
        ]
        plan = generate_plan(
            goals=goals,
            fixed_events=[],
            constraints=CapacityConstraints(),
            start_date=_dt(2026, 3, 1),
            days=7,
        )
        important_hrs = sum(
            (b.end - b.start).total_seconds() / 3600
            for b in plan.blocks if b.goal_name == "Important"
        )
        low_hrs = sum(
            (b.end - b.start).total_seconds() / 3600
            for b in plan.blocks if b.goal_name == "Low"
        )
        assert important_hrs >= low_hrs

    def test_overcommit_produces_unmet(self):
        goals = [self._make_goal("Impossible", 10, 100.0)]
        plan = generate_plan(
            goals=goals,
            fixed_events=[],
            constraints=CapacityConstraints(),
            start_date=_dt(2026, 3, 1),
            days=7,
        )
        assert len(plan.unmet) > 0
        assert any("infeasible" in m.lower() or "behind" in m.lower() for m in plan.coaching_messages)

    def test_coaching_messages_present(self):
        goals = [self._make_goal("Study", 5, 5.0)]
        plan = generate_plan(
            goals=goals,
            fixed_events=[],
            constraints=CapacityConstraints(),
            start_date=_dt(2026, 3, 1),
            days=7,
        )
        assert len(plan.coaching_messages) > 0

    def test_fixed_events_appear_in_blocks(self):
        event = CalendarEvent(
            id="meeting1", title="Team Standup",
            start=_dt(2026, 3, 1, 9),
            end=_dt(2026, 3, 1, 10),
        )
        plan = generate_plan(
            goals=[],
            fixed_events=[event],
            constraints=CapacityConstraints(),
            start_date=_dt(2026, 3, 1),
            days=1,
        )
        fixed = [b for b in plan.blocks if b.is_fixed]
        assert len(fixed) == 1
        assert fixed[0].goal_name == "Team Standup"
