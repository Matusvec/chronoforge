"""
Greedy schedule allocator for ChronoForge MVP.

Algorithm:
1. Build free blocks by subtracting fixed events + sleep windows from each day.
2. Sort goals by priority_weight descending.
3. For each goal, allocate hours from free blocks that match preferred
   time windows first, then spill into any remaining free block.
4. Track unmet goals, spare capacity, and generate coaching messages.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, time, timezone
from app.models.schemas import (
    CalendarEvent, Goal, GoalCategory, CapacityConstraints,
    PlannedBlock, UnmetGoal, DayCapacity, PlanResponse,
    TimeWindow, TradeoffReport, TradeoffEntry, GoalCreate,
)

SLOT_MINUTES = 30


@dataclass
class FreeSlot:
    start: datetime
    end: datetime

    @property
    def hours(self) -> float:
        return (self.end - self.start).total_seconds() / 3600


def _time_window_range(window: TimeWindow) -> tuple[int, int]:
    return {
        TimeWindow.morning: (7, 12),
        TimeWindow.afternoon: (12, 17),
        TimeWindow.evening: (17, 22),
    }[window]


def _slot_in_window(slot: FreeSlot, window: TimeWindow) -> bool:
    lo, hi = _time_window_range(window)
    return slot.start.hour >= lo and slot.end.hour <= hi


def compute_free_blocks(
    day_start: datetime,
    day_end: datetime,
    fixed_events: list[CalendarEvent],
    constraints: CapacityConstraints,
) -> list[FreeSlot]:
    """
    Subtract fixed events and sleep window from [day_start, day_end].
    Returns sorted list of free slots (minimum SLOT_MINUTES long).
    """
    blocked: list[tuple[datetime, datetime]] = []

    sleep_start = day_start.replace(
        hour=constraints.sleep_start_hour, minute=0, second=0, microsecond=0
    )
    sleep_end = day_start.replace(
        hour=constraints.sleep_end_hour, minute=0, second=0, microsecond=0
    )
    if constraints.sleep_start_hour < constraints.sleep_end_hour:
        blocked.append((sleep_start, sleep_end))
    else:
        blocked.append((day_start, sleep_end))
        next_sleep = day_start.replace(
            hour=constraints.sleep_start_hour, minute=0, second=0, microsecond=0
        )
        blocked.append((next_sleep, day_end))

    for ev in fixed_events:
        if ev.is_all_day:
            blocked.append((day_start, day_end))
        else:
            ev_start = max(ev.start, day_start)
            ev_end = min(ev.end, day_end)
            if ev_start < ev_end:
                blocked.append((ev_start, ev_end))

    blocked.sort(key=lambda b: b[0])

    merged: list[tuple[datetime, datetime]] = []
    for s, e in blocked:
        if merged and s <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], e))
        else:
            merged.append((s, e))

    free: list[FreeSlot] = []
    cursor = day_start
    for bs, be in merged:
        if cursor < bs:
            free.append(FreeSlot(start=cursor, end=bs))
        cursor = max(cursor, be)
    if cursor < day_end:
        free.append(FreeSlot(start=cursor, end=day_end))

    min_dur = timedelta(minutes=SLOT_MINUTES)
    return [f for f in free if (f.end - f.start) >= min_dur]


def _split_slot(slot: FreeSlot, hours_needed: float) -> tuple[FreeSlot, FreeSlot | None]:
    """Take hours_needed from the start of slot; return (taken, remainder or None)."""
    take_dur = timedelta(hours=min(hours_needed, slot.hours))
    taken = FreeSlot(start=slot.start, end=slot.start + take_dur)
    remainder_start = slot.start + take_dur
    if remainder_start < slot.end - timedelta(minutes=SLOT_MINUTES - 1):
        return taken, FreeSlot(start=remainder_start, end=slot.end)
    return taken, None


def generate_plan(
    goals: list[Goal],
    fixed_events: list[CalendarEvent],
    constraints: CapacityConstraints,
    start_date: datetime | None = None,
    days: int = 14,
    simulate_goal: GoalCreate | None = None,
) -> PlanResponse:
    if start_date is None:
        start_date = datetime.now(timezone.utc).replace(
            hour=0, minute=0, second=0, microsecond=0
        )

    working_goals = list(goals)
    if simulate_goal:
        working_goals.append(Goal(
            id="__simulated__",
            name=simulate_goal.name,
            category=simulate_goal.category,
            priority_weight=simulate_goal.priority_weight,
            weekly_target_hours=simulate_goal.weekly_target_hours,
            preferred_time_windows=simulate_goal.preferred_time_windows,
            hard_deadline=simulate_goal.hard_deadline,
            created_at=datetime.now(timezone.utc),
        ))

    working_goals.sort(key=lambda g: g.priority_weight, reverse=True)

    all_blocks: list[PlannedBlock] = []
    capacity_by_day: list[DayCapacity] = []

    goal_allocated: dict[str, float] = {g.id: 0.0 for g in working_goals}
    weekly_target: dict[str, float] = {g.id: g.weekly_target_hours for g in working_goals}

    for d in range(days):
        day_dt = start_date + timedelta(days=d)
        day_start = day_dt.replace(hour=0, minute=0, second=0, microsecond=0)
        day_end = day_start + timedelta(hours=24)

        day_events = [
            e for e in fixed_events
            if e.end > day_start and e.start < day_end
        ]

        for ev in day_events:
            all_blocks.append(PlannedBlock(
                goal_id=ev.id,
                goal_name=ev.title,
                category=GoalCategory.personal,
                start=max(ev.start, day_start),
                end=min(ev.end, day_end),
                is_fixed=True,
            ))

        free_slots = compute_free_blocks(day_start, day_end, day_events, constraints)
        total_free = sum(s.hours for s in free_slots)
        day_allocated = 0.0
        daily_deep_used = 0.0

        for goal in working_goals:
            weekly_fraction = weekly_target[goal.id] / 7.0
            remaining = weekly_target[goal.id] - goal_allocated[goal.id]
            daily_budget = min(weekly_fraction * 1.5, remaining)

            if daily_budget <= 0 or daily_deep_used >= constraints.daily_max_deep_work_hours:
                continue
            if day_allocated >= constraints.daily_max_total_scheduled_hours:
                break

            can_allocate = min(
                daily_budget,
                constraints.daily_max_deep_work_hours - daily_deep_used,
                constraints.daily_max_total_scheduled_hours - day_allocated,
            )

            preferred = [s for s in free_slots if
                         any(_slot_in_window(s, w) for w in goal.preferred_time_windows)]
            ordered = preferred + [s for s in free_slots if s not in preferred]

            still_need = can_allocate
            new_free: list[FreeSlot] = []
            for slot in ordered:
                if still_need <= 0:
                    new_free.append(slot)
                    continue
                taken, remainder = _split_slot(slot, still_need)
                all_blocks.append(PlannedBlock(
                    goal_id=goal.id,
                    goal_name=goal.name,
                    category=goal.category,
                    start=taken.start,
                    end=taken.end,
                ))
                still_need -= taken.hours
                goal_allocated[goal.id] += taken.hours
                daily_deep_used += taken.hours
                day_allocated += taken.hours
                if remainder:
                    new_free.append(remainder)

            free_slots = new_free

        spare = sum(s.hours for s in free_slots)
        capacity_by_day.append(DayCapacity(
            date=day_dt.strftime("%Y-%m-%d"),
            total_hours=round(total_free, 2),
            allocated_hours=round(day_allocated, 2),
            spare_hours=round(spare, 2),
        ))

    unmet: list[UnmetGoal] = []
    for goal in working_goals:
        alloc = goal_allocated.get(goal.id, 0.0)
        target = weekly_target[goal.id] * (days / 7.0)
        if alloc < target - 0.5:
            unmet.append(UnmetGoal(
                goal_id=goal.id,
                goal_name=goal.name,
                target_hours=round(target, 1),
                allocated_hours=round(alloc, 1),
                deficit_hours=round(target - alloc, 1),
            ))

    coaching = _generate_coaching(working_goals, goal_allocated, unmet, days)

    all_blocks.sort(key=lambda b: b.start)

    return PlanResponse(
        blocks=all_blocks,
        unmet=unmet,
        capacity_by_day=capacity_by_day,
        coaching_messages=coaching,
    )


def compute_tradeoffs(
    existing_goals: list[Goal],
    new_goal: GoalCreate,
    fixed_events: list[CalendarEvent],
    constraints: CapacityConstraints,
) -> TradeoffReport:
    plan_without = generate_plan(existing_goals, fixed_events, constraints)
    plan_with = generate_plan(existing_goals, fixed_events, constraints, simulate_goal=new_goal)

    without_alloc: dict[str, float] = {}
    for b in plan_without.blocks:
        if not b.is_fixed:
            without_alloc[b.goal_name] = without_alloc.get(b.goal_name, 0.0) + (
                (b.end - b.start).total_seconds() / 3600
            )

    with_alloc: dict[str, float] = {}
    for b in plan_with.blocks:
        if not b.is_fixed:
            with_alloc[b.goal_name] = with_alloc.get(b.goal_name, 0.0) + (
                (b.end - b.start).total_seconds() / 3600
            )

    affected: list[TradeoffEntry] = []
    for name, hours in without_alloc.items():
        if name == new_goal.name:
            continue
        new_hours = with_alloc.get(name, 0.0)
        if hours - new_hours > 0.5:
            affected.append(TradeoffEntry(
                goal_name=name,
                hours_lost=round(hours - new_hours, 1),
            ))

    new_alloc = with_alloc.get(new_goal.name, 0.0)
    target = new_goal.weekly_target_hours * 2
    feasible = new_alloc >= target * 0.8

    return TradeoffReport(
        new_goal_name=new_goal.name,
        new_goal_hours=round(new_alloc, 1),
        affected=affected,
        feasible=feasible,
    )


def _generate_coaching(
    goals: list[Goal],
    allocated: dict[str, float],
    unmet: list[UnmetGoal],
    days: int,
) -> list[str]:
    messages: list[str] = []

    if unmet:
        total_deficit = sum(u.deficit_hours for u in unmet)
        if total_deficit > 10:
            messages.append(
                f"Your plan is infeasible. You're short {total_deficit:.0f} hours. "
                "Remove something or accept failure."
            )
        for u in unmet:
            messages.append(
                f"You're behind on '{u.goal_name}' by {u.deficit_hours:.1f} hours. "
                "Fix it today."
            )

    overcommit_count = sum(
        1 for g in goals
        if allocated.get(g.id, 0.0) > g.weekly_target_hours * (days / 7.0)
    )
    if overcommit_count == 0 and not unmet:
        messages.append("All goals on track. Don't get comfortable — maintain the pace.")

    return messages
