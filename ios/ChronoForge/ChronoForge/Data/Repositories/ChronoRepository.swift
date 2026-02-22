import Foundation

// MARK: - Repository Protocol

protocol ChronoRepositoryProtocol: Sendable {
    func getIntegrationStatus() async throws -> IntegrationStatus
    func getCalendarEvents() async throws -> [CalendarEvent]
    func getGmailSignals() async throws -> [GmailSignal]
    func getCanvasTasks() async throws -> [CanvasTask]
    func getGoals() async throws -> [Goal]
    func createGoal(_ goal: GoalCreate) async throws -> Goal
    func generatePlan(simulate: GoalCreate?) async throws -> PlanResponse
    func getCurrentPlan() async throws -> PlanResponse
    func getTradeoff(for goal: GoalCreate) async throws -> TradeoffReport
    func getPlanInsights() async throws -> PlanInsightsResponse
    func submitCheckIn(_ body: CheckInCreate) async throws -> CheckInResponse
    func getCheckIns() async throws -> [CheckIn]
}

// MARK: - Live Repository

final class ChronoRepository: ChronoRepositoryProtocol, @unchecked Sendable {
    private let api: APIClientProtocol

    init(api: APIClientProtocol) {
        self.api = api
    }

    func getIntegrationStatus() async throws -> IntegrationStatus {
        try await api.get("/auth/integrations/status")
    }

    func getCalendarEvents() async throws -> [CalendarEvent] {
        let formatter = ISO8601DateFormatter()
        let from = formatter.string(from: Date())
        let to = formatter.string(from: Date().addingTimeInterval(14 * 86400))
        let response: CalendarEventsResponse = try await api.get("/calendar/events", query: ["from": from, "to": to])
        return response.events
    }

    func getGmailSignals() async throws -> [GmailSignal] {
        let response: GmailSignalsResponse = try await api.get("/gmail/signals")
        return response.signals
    }

    func getCanvasTasks() async throws -> [CanvasTask] {
        let response: CanvasTasksResponse = try await api.get("/canvas/tasks")
        return response.tasks
    }

    func getGoals() async throws -> [Goal] {
        let response: GoalsResponse = try await api.get("/goals")
        return response.goals
    }

    func createGoal(_ goal: GoalCreate) async throws -> Goal {
        try await api.post("/goals", body: goal)
    }

    func generatePlan(simulate: GoalCreate? = nil) async throws -> PlanResponse {
        let request = PlanGenerateRequest(simulateGoal: simulate)
        return try await api.post("/plan/generate", body: request)
    }

    func getCurrentPlan() async throws -> PlanResponse {
        try await api.get("/plan/current")
    }

    func getTradeoff(for goal: GoalCreate) async throws -> TradeoffReport {
        let request = PlanGenerateRequest(simulateGoal: goal)
        return try await api.post("/plan/tradeoff", body: request)
    }

    func getPlanInsights() async throws -> PlanInsightsResponse {
        try await api.get("/plan/insights")
    }

    func submitCheckIn(_ body: CheckInCreate) async throws -> CheckInResponse {
        try await api.post("/checkins", body: body)
    }

    func getCheckIns() async throws -> [CheckIn] {
        let response: CheckInsListResponse = try await api.get("/checkins")
        return response.checkIns
    }
}
