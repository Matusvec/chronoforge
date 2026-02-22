# ChronoForge Roadmap

## v0.2 — Smarter Scheduling
- [ ] Replace greedy allocator with ILP/CP-SAT solver (Google OR-Tools)
  - Optimal allocation respecting all constraints simultaneously
  - Support for hard deadlines as true constraints, not just sort order
  - Minimize total priority-weighted under-allocation
- [ ] Break/buffer time between blocks (configurable 5-15 min)
- [ ] Recurring event patterns (auto-detect weekly patterns)

## v0.3 — Push Notifications
- [ ] APNs integration for real-time push notifications
- [ ] Server-side push scheduler (check for upcoming events/deadlines)
- [ ] Rich notifications with quick actions (snooze, mark done, reschedule)

## v0.3.5 — Gemini enhancements (done in MVP)
- [x] Plan insights: summary, time breakdown, where to add more
- [x] Check-ins: post-slot “what did you do?” with assessment + motivational message
- [ ] Use Gemini to suggest how to split time (alternative to pure greedy allocator)
- [ ] Honesty score / streak based on check-in history

## v0.4 — Better NLP for Gmail Signals
- [ ] Use a local NLP model or OpenAI API for smarter email classification
- [ ] Extract dates, companies, and action items from email body
- [ ] Auto-create goals/tasks from detected opportunities
- [ ] Spam/marketing filter to reduce noise

## v0.5 — Calendar Write-back
- [ ] Apple Calendar integration (EventKit) for local calendar sync
- [ ] Google Calendar write-back: create planned blocks as calendar events
- [ ] Two-way sync: detect manual changes and re-optimize
- [ ] Color-code blocks by goal category

## v0.6 — Persistent Storage
- [ ] PostgreSQL backend (replace in-memory stores)
- [ ] User accounts with proper registration
- [ ] Multi-device sync
- [ ] Data export (iCal, CSV)

## v0.7 — Analytics & Insights
- [ ] Weekly review: planned vs. actual hours
- [ ] Streak tracking per goal
- [ ] Productivity trend graphs
- [ ] "Ruthless coach" report card with letter grades

## v0.8 — Social & Collaboration
- [ ] Shared goals (study groups, project teams)
- [ ] Accountability partner notifications
- [ ] Team capacity planning

## Future Considerations
- [ ] Apple Watch companion (glanceable timeline)
- [ ] Widget for today's next block
- [ ] Siri Shortcuts integration
- [ ] Android app (Kotlin Multiplatform)
