from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, calendar, gmail, canvas, goals, plan, checkins

app = FastAPI(
    title="ChronoForge API",
    version="0.1.0",
    description="Ruthless schedule optimizer + goal coach backend",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(calendar.router)
app.include_router(gmail.router)
app.include_router(canvas.router)
app.include_router(goals.router)
app.include_router(plan.router)
app.include_router(checkins.router)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "chronoforge"}
