import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var todayBlocks: [PlannedBlock] = []
    @Published var signals: [GmailSignal] = []
    @Published var upcomingTasks: [CanvasTask] = []
    @Published var capacityToday: DayCapacity?
    @Published var coachingMessages: [String] = []
    @Published var planInsights: PlanInsightsResponse?
    @Published var checkIns: [CheckIn] = []
    @Published var blockAwaitingCheckIn: PlannedBlock?
    @Published var lastCheckInResult: (assessment: String, motivational: String)?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var needsReconnect = false

    private let repository: ChronoRepositoryProtocol

    init(repository: ChronoRepositoryProtocol) {
        self.repository = repository
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil
        needsReconnect = false

        do {
            async let planResult = repository.getCurrentPlan()
            async let signalsResult = repository.getGmailSignals()
            async let tasksResult = repository.getCanvasTasks()

            let plan = try await planResult

            await PlanCache.shared.save(plan)

            let todayStr = ISO8601DateFormatter.string(
                from: Date(), timeZone: .current, formatOptions: .withFullDate
            )
            let cal = Calendar.current
            todayBlocks = plan.blocks.filter { cal.isDateInToday($0.start) }
                .sorted { $0.start < $1.start }
            capacityToday = plan.capacityByDay.first { $0.date == todayStr }
            coachingMessages = plan.coachingMessages

            signals = (try? await signalsResult) ?? []
            upcomingTasks = (try? await tasksResult) ?? []

            NotificationService.shared.scheduleBlockReminders(blocks: plan.blocks)
            NotificationService.shared.scheduleDueDateReminders(tasks: upcomingTasks)

            planInsights = try? await repository.getPlanInsights()
            checkIns = (try? await repository.getCheckIns()) ?? []
            blockAwaitingCheckIn = nextBlockNeedingCheckIn(todayBlocks: todayBlocks, checkIns: checkIns)

        } catch let error as APIError where error.isUnauthorized {
            needsReconnect = true
            if let cached = await PlanCache.shared.load() {
                let cal = Calendar.current
                todayBlocks = cached.blocks.filter { cal.isDateInToday($0.start) }
                coachingMessages = cached.coachingMessages + ["⚠️ Showing cached data. Reconnect to refresh."]
            }
        } catch {
            errorMessage = error.localizedDescription
            if let cached = await PlanCache.shared.load() {
                let cal = Calendar.current
                todayBlocks = cached.blocks.filter { cal.isDateInToday($0.start) }
                coachingMessages = cached.coachingMessages + ["⚠️ Offline. Showing last known plan."]
            }
        }

        isLoading = false
    }

    var nextBlock: PlannedBlock? {
        todayBlocks.first { $0.start > Date() }
    }

    var totalAllocatedToday: Double {
        capacityToday?.allocatedHours ?? 0
    }

    var totalFreeToday: Double {
        capacityToday?.spareHours ?? 0
    }

    var capacityFraction: Double {
        guard let cap = capacityToday, cap.totalHours > 0 else { return 0 }
        return cap.allocatedHours / cap.totalHours
    }

    /// First block that has ended, is not fixed, and has no check-in yet.
    private func nextBlockNeedingCheckIn(todayBlocks: [PlannedBlock], checkIns: [CheckIn]) -> PlannedBlock? {
        let now = Date()
        let checkedBlockIds = Set(checkIns.map(\.blockId))
        return todayBlocks.first { block in
            !block.isFixed && block.end < now && block.end.timeIntervalSince(now) > -2 * 3600 && !checkedBlockIds.contains(blockId(for: block))
        }
    }

    func blockId(for block: PlannedBlock) -> String {
        "\(block.goalId)-\(block.start.timeIntervalSince1970)"
    }

    func submitCheckIn(block: PlannedBlock, whatIDid: String) async {
        let body = CheckInCreate(
            blockId: blockId(for: block),
            plannedGoalId: block.goalId,
            plannedGoalName: block.goalName,
            start: block.start,
            end: block.end,
            whatIDid: whatIDid
        )
        do {
            let response = try await repository.submitCheckIn(body)
            lastCheckInResult = (response.assessment, response.motivationalMessage)
            checkIns = (try? await repository.getCheckIns()) ?? []
            blockAwaitingCheckIn = nextBlockNeedingCheckIn(todayBlocks: todayBlocks, checkIns: checkIns)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissCheckInResult() {
        lastCheckInResult = nil
    }

    func dismissCheckInPrompt() {
        blockAwaitingCheckIn = nil
    }
}
