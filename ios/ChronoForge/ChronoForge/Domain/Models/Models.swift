import Foundation

// MARK: - Auth

struct AuthStartResponse: Codable {
    let authUrl: String
}

struct AuthCallbackResponse: Codable {
    let token: String
    let email: String?
}

struct IntegrationStatus: Codable {
    let google: Bool
    let canvas: Bool
}

struct CanvasTokenRequest: Codable {
    let accessToken: String
}

// MARK: - Calendar

struct CalendarEvent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let source: String

    init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false, source: String = "google_calendar") {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.source = source
    }
}

struct CalendarEventsResponse: Codable {
    let events: [CalendarEvent]
}

// MARK: - Gmail Signals

enum SignalType: String, Codable, CaseIterable {
    case interview, deadline, application, offer, rsvp, invite, internship, hackathon, submission
}

struct GmailSignal: Codable, Identifiable {
    let id: String
    let subject: String
    let snippet: String
    let sender: String
    let date: Date
    let signalTypes: [SignalType]
}

struct GmailSignalsResponse: Codable {
    let signals: [GmailSignal]
}

// MARK: - Canvas

struct CanvasTask: Codable, Identifiable {
    let id: String
    let courseName: String
    let assignmentName: String
    let dueAt: Date?
    let pointsPossible: Double?
    let htmlUrl: String?
}

struct CanvasTasksResponse: Codable {
    let tasks: [CanvasTask]
}

// MARK: - Goals

enum TimeWindow: String, Codable, CaseIterable {
    case morning, afternoon, evening

    var displayName: String {
        switch self {
        case .morning: return "Morning (7-12)"
        case .afternoon: return "Afternoon (12-17)"
        case .evening: return "Evening (17-22)"
        }
    }
}

enum GoalCategory: String, Codable, CaseIterable {
    case study, fitness, career, personal, project, social

    var displayName: String { rawValue.capitalized }

    var iconName: String {
        switch self {
        case .study: return "book.fill"
        case .fitness: return "figure.run"
        case .career: return "briefcase.fill"
        case .personal: return "person.fill"
        case .project: return "hammer.fill"
        case .social: return "person.3.fill"
        }
    }
}

struct GoalCreate: Codable {
    let name: String
    let category: GoalCategory
    let priorityWeight: Int
    let weeklyTargetHours: Double
    let preferredTimeWindows: [TimeWindow]
    let hardDeadline: Date?

    init(name: String, category: GoalCategory = .study, priorityWeight: Int = 5,
         weeklyTargetHours: Double = 5.0, preferredTimeWindows: [TimeWindow] = [],
         hardDeadline: Date? = nil) {
        self.name = name
        self.category = category
        self.priorityWeight = priorityWeight
        self.weeklyTargetHours = weeklyTargetHours
        self.preferredTimeWindows = preferredTimeWindows
        self.hardDeadline = hardDeadline
    }
}

struct Goal: Codable, Identifiable {
    let id: String
    let name: String
    let category: GoalCategory
    let priorityWeight: Int
    let weeklyTargetHours: Double
    let preferredTimeWindows: [TimeWindow]
    let hardDeadline: Date?
    let createdAt: Date
}

struct GoalsResponse: Codable {
    let goals: [Goal]
}

// MARK: - Plan

struct PlannedBlock: Codable, Identifiable {
    var id: String { "\(goalId)-\(start.timeIntervalSince1970)" }
    let goalId: String
    let goalName: String
    let category: GoalCategory
    let start: Date
    let end: Date
    let isFixed: Bool

    var durationHours: Double {
        end.timeIntervalSince(start) / 3600
    }
}

struct UnmetGoal: Codable, Identifiable {
    var id: String { goalId }
    let goalId: String
    let goalName: String
    let targetHours: Double
    let allocatedHours: Double
    let deficitHours: Double
}

struct DayCapacity: Codable, Identifiable {
    var id: String { date }
    let date: String
    let totalHours: Double
    let allocatedHours: Double
    let spareHours: Double
}

struct TradeoffEntry: Codable {
    let goalName: String
    let hoursLost: Double
}

struct TradeoffReport: Codable {
    let newGoalName: String
    let newGoalHours: Double
    let affected: [TradeoffEntry]
    let feasible: Bool
}

struct PlanResponse: Codable {
    let blocks: [PlannedBlock]
    let unmet: [UnmetGoal]
    let capacityByDay: [DayCapacity]
    let coachingMessages: [String]
}

struct PlanGenerateRequest: Codable {
    let simulateGoal: GoalCreate?
}

// MARK: - Plan Insights (Gemini)

struct PlanInsightsResponse: Codable {
    let summary: String
    let timeBreakdown: String
    let whereToAddMore: String
    let available: Bool
}

// MARK: - Check-ins

struct CheckInCreate: Codable {
    let blockId: String
    let plannedGoalId: String
    let plannedGoalName: String
    let start: Date
    let end: Date
    let whatIDid: String
}

struct CheckIn: Codable, Identifiable {
    let id: String
    let blockId: String
    let plannedGoalId: String
    let plannedGoalName: String
    let start: Date
    let end: Date
    let whatIDid: String
    let assessment: String
    let motivationalMessage: String
    let createdAt: Date
}

struct CheckInResponse: Codable {
    let assessment: String
    let motivationalMessage: String
    let checkInId: String
}

struct CheckInsListResponse: Codable {
    let checkIns: [CheckIn]
}
