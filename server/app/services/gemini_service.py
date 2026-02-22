"""
Gemini API integration for plan insights, time breakdown, and check-in assessment.
All prompts keep the 'ruthless coach' tone.
"""

from __future__ import annotations
import json
import re
from datetime import datetime

from app.config import get_settings
from app.models.schemas import PlanResponse, Goal, PlannedBlock, DayCapacity


def _client():
    try:
        import google.generativeai as genai
        key = get_settings().gemini_api_key
        if not key:
            return None
        genai.configure(api_key=key)
        return genai.GenerativeModel("gemini-1.5-flash")
    except Exception:
        return None


def get_plan_insights(plan: PlanResponse, goals: list[Goal]) -> dict[str, str] | None:
    """
    Ask Gemini for a short summary, time breakdown, and where the user can add more.
    Returns None if Gemini is not configured.
    """
    model = _client()
    if not model:
        return None

    blocks_text = "\n".join(
        f"- {b.start.strftime('%H:%M')}–{b.end.strftime('%H:%M')}: {b.goal_name}"
        + (" (fixed)" if b.is_fixed else "")
        for b in plan.blocks[:50]
    )
    capacity_text = "\n".join(
        f"- {c.date}: {c.allocated_hours:.1f}h allocated, {c.spare_hours:.1f}h spare"
        for c in plan.capacity_by_day[:14]
    )
    goals_text = "\n".join(
        f"- {g.name}: {g.weekly_target_hours}h/week, priority {g.priority_weight}"
        for g in goals
    )
    unmet_text = "\n".join(
        f"- {u.goal_name}: {u.deficit_hours:.1f}h short"
        for u in plan.unmet
    ) if plan.unmet else "None"

    prompt = f"""You are a ruthless schedule coach. Given this user's plan and goals, reply in JSON only with exactly these three keys (no markdown, no code block):
- "summary": 2–3 sentences on how their time is split and whether they're on track.
- "time_breakdown": A short bullet list of where their hours go (by category/goal).
- "where_to_add_more": 1–2 sentences on where they still have room (spare hours, underused days) and what to prioritize. Be direct.

Plan blocks (next 14 days):
{blocks_text}

Daily capacity:
{capacity_text}

Goals:
{goals_text}

Unmet goals (deficit):
{unmet_text}
"""

    try:
        response = model.generate_content(prompt)
        text = (response.text or "").strip()
        # Strip markdown code block if present
        if text.startswith("```"):
            text = re.sub(r"^```\w*\n?", "", text)
            text = re.sub(r"\n?```\s*$", "", text)
        data = json.loads(text)
        return {
            "summary": data.get("summary", ""),
            "time_breakdown": data.get("time_breakdown", ""),
            "where_to_add_more": data.get("where_to_add_more", ""),
        }
    except Exception:
        return None


def process_checkin(
    planned_goal_name: str,
    start: datetime,
    end: datetime,
    what_user_did: str,
    recent_summaries: list[str],
) -> tuple[str, str] | None:
    """
    Get assessment (honesty/alignment) and a short motivational message.
    Returns (assessment, motivational_message) or None if Gemini unavailable.
    """
    model = _client()
    if not model:
        return None

    slot_desc = f"{start.strftime('%H:%M')}–{end.strftime('%H:%M')} ({planned_goal_name})"
    recent = "\n".join(recent_summaries[-5:]) if recent_summaries else "None yet."

    prompt = f"""You are a ruthless but encouraging coach. The user had a planned block: {slot_desc}. They said they did: "{what_user_did}".

Reply in JSON only with exactly these two keys (no markdown, no code block):
- "assessment": One short sentence on how well what they did matches the plan (honesty/alignment). Be direct but fair.
- "motivational_message": One short sentence motivating them: e.g. "If you keep this up, you'll be [specific positive outcome] in [timeframe]." or "One more block like this and [concrete result]." Be specific and encouraging.

Recent check-ins (for context):
{recent}
"""

    try:
        response = model.generate_content(prompt)
        text = (response.text or "").strip()
        if text.startswith("```"):
            text = re.sub(r"^```\w*\n?", "", text)
            text = re.sub(r"\n?```\s*$", "", text)
        data = json.loads(text)
        return (
            data.get("assessment", "No assessment."),
            data.get("motivational_message", "Keep going."),
        )
    except Exception:
        return None
