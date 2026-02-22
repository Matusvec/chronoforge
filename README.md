# ChronoForge

**Ruthless schedule optimizer + goal coach.**

ChronoForge compiles your priorities, constraints, and calendar into an executable weekly plan. It ingests Google Calendar events, Gmail signals (interview invites, deadlines, hackathons), and Canvas LMS assignments, then runs a greedy allocator to pack your goals into free time blocks — and tells you exactly what doesn't fit.

## Architecture

```
chronoforge/
├── server/          # Python FastAPI backend
│   ├── app/
│   │   ├── main.py          # FastAPI entry point
│   │   ├── config.py        # Environment-based settings
│   │   ├── models/
│   │   │   └── schemas.py   # Pydantic models (shared JSON contract)
│   │   ├── routers/
│   │   │   ├── auth.py      # Google OAuth + Canvas auth
│   │   │   ├── calendar.py  # GET /calendar/events
│   │   │   ├── gmail.py     # GET /gmail/signals
│   │   │   ├── canvas.py    # GET /canvas/tasks
│   │   │   ├── goals.py     # CRUD /goals
│   │   │   └── plan.py      # POST /plan/generate, GET /plan/current
│   │   └── services/
│   │       ├── scheduler.py     # Greedy allocator + coaching
│   │       ├── google_service.py
│   │       ├── canvas_service.py
│   │       ├── token_store.py   # Encrypted token storage
│   │       ├── crypto.py        # Fernet encryption
│   │       ├── jwt_service.py   # JWT auth
│   │       └── goal_store.py    # In-memory goal storage
│   └── tests/
│       └── test_scheduler.py
├── ios/             # SwiftUI iOS app (iOS 17+)
│   └── ChronoForge/
│       ├── ChronoForge/
│       │   ├── App/             # Entry point, DI container, root view
│       │   ├── Domain/Models/   # Swift Codable models (mirrors server schemas)
│       │   ├── Data/Network/    # APIClient + MockAPIClient
│       │   ├── Data/Repositories/
│       │   ├── Data/Cache/      # Offline plan cache
│       │   ├── UI/Onboarding/   # Google + Canvas connection
│       │   ├── UI/Dashboard/    # Today timeline + capacity gauge
│       │   ├── UI/Goals/        # Goal CRUD + tradeoff simulator
│       │   ├── UI/Plan/         # 2-week plan view
│       │   └── Services/        # AuthManager, NotificationService
│       └── ChronoForgeTests/
└── ROADMAP.md
```

## Setup

### Prerequisites

- Python 3.11+
- Xcode 15+ (for iOS app)
- A Google Cloud project with OAuth 2.0 credentials
- (Optional) Canvas LMS developer key or personal access token

### 1. Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a new project (or select existing)
3. Enable **Google Calendar API** and **Gmail API**
4. Create **OAuth 2.0 Client ID** (type: Web application)
   - Authorized redirect URI: `http://localhost:8000/auth/google/callback`
5. Copy the Client ID and Client Secret

### 2. Canvas LMS Configuration

**Option A: Personal Access Token** (simplest for MVP)
1. In Canvas, go to Account → Settings → New Access Token
2. Copy the token — you'll paste it in the iOS app onboarding

**Option B: OAuth2 Developer Key**
1. Admin → Developer Keys → Add Developer Key
2. Redirect URI: `http://localhost:8000/auth/canvas/callback`
3. Copy Client ID and Client Secret

### 3. Gemini API (optional)

Enables AI-powered plan insights (time breakdown, where to add more) and check-in assessment + motivational messages.

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey) (or [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → Create API key for Generative Language API).
2. Create an API key and add it to `.env`:
   ```
   GEMINI_API_KEY=your-gemini-api-key
   ```
3. Without `GEMINI_API_KEY`, the app still runs: plan insights will be empty and check-ins will return 503 (use mock/demo mode on iOS to see the UI).

### 4. Run the Server

```bash
cd server

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your Google/Canvas credentials

# Generate a Fernet encryption key
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# Paste the output as TOKEN_ENCRYPTION_KEY in .env

# Run the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

### 5. Run Server Tests

```bash
cd server
pytest tests/ -v
```

### 6. Run the iOS App

1. Open `ios/ChronoForge/ChronoForge.xcodeproj` in Xcode
2. Select a simulator (iPhone 15, iOS 17+)
3. Build and run (⌘R)

**Fake/Demo Mode:** To run without a live server, add `--fake-mode` to the scheme's launch arguments:
- Product → Scheme → Edit Scheme → Run → Arguments → Add `--fake-mode`

### 7. Connect the iOS App to the Server

If running on a physical device, update the `baseURL` in `DependencyContainer.swift` to your machine's local IP address (e.g., `http://192.168.1.100:8000`).

For the simulator, `http://localhost:8000` works by default.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/google/start` | Returns Google OAuth URL |
| GET | `/auth/google/callback?code=...` | Exchanges code for JWT |
| POST | `/auth/canvas/start` | Returns Canvas OAuth URL |
| GET | `/auth/canvas/callback?code=...` | Exchanges Canvas code |
| POST | `/auth/integrations/canvas/token` | Save Canvas personal token |
| GET | `/auth/integrations/status` | Integration connection status |
| GET | `/calendar/events?from=...&to=...` | Google Calendar events |
| GET | `/gmail/signals` | Gmail opportunity signals |
| GET | `/canvas/tasks` | Canvas upcoming assignments |
| GET | `/goals` | List user goals |
| POST | `/goals` | Create a new goal |
| POST | `/plan/generate` | Generate optimized plan |
| GET | `/plan/current` | Get cached current plan |
| POST | `/plan/tradeoff` | Simulate adding a goal |
| GET | `/plan/insights` | Gemini: summary, time breakdown, where to add more |
| POST | `/checkins` | Submit what you did for a block (Gemini assessment + motivational message) |
| GET | `/checkins` | List recent check-ins |

## Shared JSON Models

Models are defined in `server/app/models/schemas.py` (Python/Pydantic) and mirrored in `ios/ChronoForge/ChronoForge/Domain/Models/Models.swift` (Swift/Codable). Both use snake_case JSON keys; the iOS client converts automatically via `keyDecodingStrategy = .convertFromSnakeCase`.

Key models: `CalendarEvent`, `GmailSignal`, `CanvasTask`, `Goal`, `GoalCreate`, `PlanResponse`, `PlannedBlock`, `UnmetGoal`, `DayCapacity`, `TradeoffReport`.

## License

See [LICENSE](LICENSE).
