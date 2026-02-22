"""
Shared JSON models between server and iOS.
All datetime strings use ISO-8601 format.
"""

from __future__ import annotations
from datetime import datetime
from enum import Enum
from pydantic import BaseModel, Field


# ── Auth ──────────────────────────────────────────────────────────────

class AuthStartResponse(BaseModel):
    auth_url: str

class AuthCallbackResponse(BaseModel):
    token: str
    email: str | None = None

class IntegrationStatus(BaseModel):
    google: bool = False
    canvas: bool = False

class CanvasTokenRequest(BaseModel):
    access_token: str


# ── Calendar ──────────────────────────────────────────────────────────

class CalendarEvent(BaseModel):
    id: str
    title: str
    start: datetime
    end: datetime
    is_all_day: bool = False
    source: str = "google_calendar"

class CalendarEventsResponse(BaseModel):
    events: list[CalendarEvent]


# ── Gmail Signals ─────────────────────────────────────────────────────

class SignalType(str, Enum):
    interview = "interview"
    deadline = "deadline"
    application = "application"
    offer = "offer"
    rsvp = "rsvp"
    invite = "invite"
    internship = "internship"
    hackathon = "hackathon"
    submission = "submission"

class GmailSignal(BaseModel):
    id: str
    subject: str
    snippet: str
    sender: str
    date: datetime
    signal_types: list[SignalType]

class GmailSignalsResponse(BaseModel):
    signals: list[GmailSignal]


# ── Canvas ────────────────────────────────────────────────────────────

class CanvasTask(BaseModel):
    id: str
    course_name: str
    assignment_name: str
    due_at: datetime | None = None
    points_possible: float | None = None
    html_url: str | None = None

class CanvasTasksResponse(BaseModel):
    tasks: list[CanvasTask]


# ── Goals ─────────────────────────────────────────────────────────────

class TimeWindow(str, Enum):
    morning = "morning"       # 7-12
    afternoon = "afternoon"   # 12-17
    evening = "evening"       # 17-22

class GoalCategory(str, Enum):
    study = "study"
    fitness = "fitness"
    career = "career"
    personal = "personal"
    project = "project"
    social = "social"

class GoalCreate(BaseModel):
    name: str
    category: GoalCategory = GoalCategory.study
    priority_weight: int = Field(ge=1, le=10, default=5)
    weekly_target_hours: float = Field(gt=0, default=5.0)
    preferred_time_windows: list[TimeWindow] = []
    hard_deadline: datetime | None = None

class Goal(GoalCreate):
    id: str
    created_at: datetime

class GoalsResponse(BaseModel):
    goals: list[Goal]


# ── Capacity Constraints ─────────────────────────────────────────────

class CapacityConstraints(BaseModel):
    daily_max_deep_work_hours: float = 4.0
    daily_max_total_scheduled_hours: float = 12.0
    sleep_start_hour: int = 0   # midnight
    sleep_end_hour: int = 7


# ── Plan / Schedule ──────────────────────────────────────────────────

class PlannedBlock(BaseModel):
    goal_id: str
    goal_name: str
    category: GoalCategory
    start: datetime
    end: datetime
    is_fixed: bool = False  # True for calendar events

class UnmetGoal(BaseModel):
    goal_id: str
    goal_name: str
    target_hours: float
    allocated_hours: float
    deficit_hours: float

class DayCapacity(BaseModel):
    date: str  # YYYY-MM-DD
    total_hours: float
    allocated_hours: float
    spare_hours: float

class TradeoffEntry(BaseModel):
    goal_name: str
    hours_lost: float

class TradeoffReport(BaseModel):
    new_goal_name: str
    new_goal_hours: float
    affected: list[TradeoffEntry]
    feasible: bool

class PlanResponse(BaseModel):
    blocks: list[PlannedBlock]
    unmet: list[UnmetGoal]
    capacity_by_day: list[DayCapacity]
    coaching_messages: list[str]

class PlanGenerateRequest(BaseModel):
    simulate_goal: GoalCreate | None = None


# ── Coaching ──────────────────────────────────────────────────────────

class CoachingMessage(BaseModel):
    message: str
    severity: str = "info"  # info, warning, critical


# ── Plan Insights (Gemini) ───────────────────────────────────────────

class PlanInsightsResponse(BaseModel):
    summary: str
    time_breakdown: str
    where_to_add_more: str
    available: bool = True  # False when Gemini API key not configured


# ── Check-ins (post-slot reflection + honesty tracking) ────────────────

class CheckInCreate(BaseModel):
    block_id: str
    planned_goal_id: str
    planned_goal_name: str
    start: datetime
    end: datetime
    what_i_did: str

class CheckIn(CheckInCreate):
    id: str
    assessment: str
    motivational_message: str
    created_at: datetime

class CheckInResponse(BaseModel):
    assessment: str
    motivational_message: str
    check_in_id: str

class CheckInsListResponse(BaseModel):
    check_ins: list[CheckIn]
