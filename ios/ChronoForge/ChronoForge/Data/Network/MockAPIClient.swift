import Foundation

/// Mock API client for running the iOS app without a live server.
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await Task.sleep(for: .milliseconds(300))
        return try decode(mockData(for: path, method: "GET"))
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B? = Optional<String>.none) async throws -> T {
        try await Task.sleep(for: .milliseconds(300))
        return try decode(mockData(for: path, method: "POST"))
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func mockData(for path: String, method: String = "GET") -> Data {
        if path.contains("/integrations/status") {
            return encode(IntegrationStatus(google: true, canvas: true))
        }
        if path.contains("/calendar/events") {
            return encode(CalendarEventsResponse(events: Self.mockEvents))
        }
        if path.contains("/gmail/signals") {
            return encode(GmailSignalsResponse(signals: Self.mockSignals))
        }
        if path.contains("/canvas/tasks") {
            return encode(CanvasTasksResponse(tasks: Self.mockTasks))
        }
        if path.contains("/goals") {
            return encode(GoalsResponse(goals: Self.mockGoals))
        }
        if path.contains("/plan/insights") {
            return encode(PlanInsightsResponse(
                summary: "Your time is split across Study, Interview Prep, and Fitness. You're slightly behind on Interview Prep but have spare capacity in the afternoons.",
                timeBreakdown: "• Fixed: Team Standup, lectures, meetings (~2h/day)\n• Study/Homework: ~2h/day\n• Interview Prep: ~1.5h/day\n• Fitness: ~1h/day",
                whereToAddMore: "Use the 11.5h spare per day in afternoon slots for Interview Prep to close the 2h deficit. Evening slots are also underused.",
                available: true
            ))
        }
        if path.contains("/plan") {
            return encode(Self.mockPlan)
        }
        if path.contains("/checkins") {
            if method == "POST" {
                return encode(CheckInResponse(
                    assessment: "That lines up with your plan. You stayed on goal.",
                    motivationalMessage: "If you keep this up, you'll be interview-ready in 2 weeks.",
                    checkInId: "mock-checkin-1"
                ))
            }
            return encode(CheckInsListResponse(checkIns: Self.mockCheckIns))
        }
        return "{}".data(using: .utf8)!
    }

    private func encode<T: Encodable>(_ value: T) -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(value)) ?? Data()
    }

    // MARK: - Mock Data

    private static let today = Calendar.current.startOfDay(for: Date())

    static let mockEvents: [CalendarEvent] = [
        CalendarEvent(
            id: "ev1", title: "Team Standup",
            start: today.addingTimeInterval(9 * 3600),
            end: today.addingTimeInterval(9.5 * 3600)
        ),
        CalendarEvent(
            id: "ev2", title: "CS 301 Lecture",
            start: today.addingTimeInterval(11 * 3600),
            end: today.addingTimeInterval(12.5 * 3600)
        ),
        CalendarEvent(
            id: "ev3", title: "Gym",
            start: today.addingTimeInterval(17 * 3600),
            end: today.addingTimeInterval(18 * 3600)
        ),
        CalendarEvent(
            id: "ev4", title: "Project Meeting",
            start: today.addingTimeInterval(14 * 3600),
            end: today.addingTimeInterval(15 * 3600)
        ),
    ]

    static let mockSignals: [GmailSignal] = [
        GmailSignal(
            id: "sig1", subject: "Software Engineering Internship Application",
            snippet: "Thank you for applying to our internship program...",
            sender: "careers@techcorp.com", date: today.addingTimeInterval(-86400),
            signalTypes: [.internship, .application]
        ),
        GmailSignal(
            id: "sig2", subject: "Hackathon Registration Confirmation",
            snippet: "You're registered for HackMIT 2026...",
            sender: "team@hackmit.org", date: today.addingTimeInterval(-3600),
            signalTypes: [.hackathon, .rsvp]
        ),
        GmailSignal(
            id: "sig3", subject: "Interview Scheduled - Google",
            snippet: "Your technical interview is scheduled for...",
            sender: "recruit@google.com", date: today,
            signalTypes: [.interview, .invite]
        ),
    ]

    static let mockTasks: [CanvasTask] = [
        CanvasTask(
            id: "t1", courseName: "CS 301 - Algorithms",
            assignmentName: "Problem Set 5: Dynamic Programming",
            dueAt: today.addingTimeInterval(2 * 86400),
            pointsPossible: 100, htmlUrl: nil
        ),
        CanvasTask(
            id: "t2", courseName: "MATH 240 - Linear Algebra",
            assignmentName: "Homework 7: Eigenvalues",
            dueAt: today.addingTimeInterval(4 * 86400),
            pointsPossible: 50, htmlUrl: nil
        ),
        CanvasTask(
            id: "t3", courseName: "CS 301 - Algorithms",
            assignmentName: "Midterm Exam",
            dueAt: today.addingTimeInterval(7 * 86400),
            pointsPossible: 200, htmlUrl: nil
        ),
    ]

    static let mockGoals: [Goal] = [
        Goal(id: "g1", name: "Study / Homework", category: .study,
             priorityWeight: 7, weeklyTargetHours: 10,
             preferredTimeWindows: [.morning, .afternoon],
             hardDeadline: nil, createdAt: today.addingTimeInterval(-7 * 86400)),
        Goal(id: "g2", name: "Interview Prep", category: .career,
             priorityWeight: 9, weeklyTargetHours: 8,
             preferredTimeWindows: [.morning],
             hardDeadline: today.addingTimeInterval(14 * 86400),
             createdAt: today.addingTimeInterval(-3 * 86400)),
        Goal(id: "g3", name: "Fitness", category: .fitness,
             priorityWeight: 5, weeklyTargetHours: 4,
             preferredTimeWindows: [.evening],
             hardDeadline: nil, createdAt: today.addingTimeInterval(-14 * 86400)),
    ]

    static let mockPlan: PlanResponse = {
        var blocks: [PlannedBlock] = []
        let base = today

        for day in 0..<14 {
            let dayBase = base.addingTimeInterval(Double(day) * 86400)

            blocks.append(PlannedBlock(
                goalId: "ev_standup", goalName: "Team Standup", category: .personal,
                start: dayBase.addingTimeInterval(9 * 3600),
                end: dayBase.addingTimeInterval(9.5 * 3600), isFixed: true
            ))

            blocks.append(PlannedBlock(
                goalId: "g2", goalName: "Interview Prep", category: .career,
                start: dayBase.addingTimeInterval(7.5 * 3600),
                end: dayBase.addingTimeInterval(9 * 3600), isFixed: false
            ))

            blocks.append(PlannedBlock(
                goalId: "g1", goalName: "Study / Homework", category: .study,
                start: dayBase.addingTimeInterval(10 * 3600),
                end: dayBase.addingTimeInterval(11 * 3600), isFixed: false
            ))

            blocks.append(PlannedBlock(
                goalId: "g1", goalName: "Study / Homework", category: .study,
                start: dayBase.addingTimeInterval(13 * 3600),
                end: dayBase.addingTimeInterval(14 * 3600), isFixed: false
            ))

            blocks.append(PlannedBlock(
                goalId: "g3", goalName: "Fitness", category: .fitness,
                start: dayBase.addingTimeInterval(17 * 3600),
                end: dayBase.addingTimeInterval(18 * 3600), isFixed: false
            ))
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current
        let capacity = (0..<14).map { day in
            DayCapacity(
                date: dateFormatter.string(from: base.addingTimeInterval(Double(day) * 86400)),
                totalHours: 17, allocatedHours: 5.5, spareHours: 11.5
            )
        }

        return PlanResponse(
            blocks: blocks,
            unmet: [
                UnmetGoal(goalId: "g2", goalName: "Interview Prep",
                         targetHours: 16, allocatedHours: 14, deficitHours: 2)
            ],
            capacityByDay: capacity,
            coachingMessages: [
                "You're behind on 'Interview Prep' by 2.0 hours. Fix it today.",
                "All other goals on track. Don't get comfortable — maintain the pace."
            ]
        )
    }()

    static let mockCheckIns: [CheckIn] = []
}
