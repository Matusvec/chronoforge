import XCTest
@testable import ChronoForge

final class ChronoForgeTests: XCTestCase {

    // MARK: - Model Decoding Tests

    func testDecodePlanResponse() throws {
        let json = """
        {
            "blocks": [
                {
                    "goal_id": "g1",
                    "goal_name": "Study",
                    "category": "study",
                    "start": "2026-03-01T09:00:00Z",
                    "end": "2026-03-01T11:00:00Z",
                    "is_fixed": false
                }
            ],
            "unmet": [
                {
                    "goal_id": "g2",
                    "goal_name": "Fitness",
                    "target_hours": 10.0,
                    "allocated_hours": 6.0,
                    "deficit_hours": 4.0
                }
            ],
            "capacity_by_day": [
                {
                    "date": "2026-03-01",
                    "total_hours": 17.0,
                    "allocated_hours": 5.0,
                    "spare_hours": 12.0
                }
            ],
            "coaching_messages": [
                "You're behind on 'Fitness' by 4.0 hours. Fix it today."
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let plan = try decoder.decode(PlanResponse.self, from: json)
        XCTAssertEqual(plan.blocks.count, 1)
        XCTAssertEqual(plan.blocks[0].goalName, "Study")
        XCTAssertEqual(plan.blocks[0].category, .study)
        XCTAssertFalse(plan.blocks[0].isFixed)
        XCTAssertEqual(plan.unmet.count, 1)
        XCTAssertEqual(plan.unmet[0].deficitHours, 4.0)
        XCTAssertEqual(plan.capacityByDay.count, 1)
        XCTAssertEqual(plan.coachingMessages.count, 1)
    }

    func testDecodeGoal() throws {
        let json = """
        {
            "id": "abc",
            "name": "Interview Prep",
            "category": "career",
            "priority_weight": 9,
            "weekly_target_hours": 8.0,
            "preferred_time_windows": ["morning"],
            "hard_deadline": "2026-04-01T00:00:00Z",
            "created_at": "2026-03-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let goal = try decoder.decode(Goal.self, from: json)
        XCTAssertEqual(goal.name, "Interview Prep")
        XCTAssertEqual(goal.category, .career)
        XCTAssertEqual(goal.priorityWeight, 9)
        XCTAssertEqual(goal.preferredTimeWindows, [.morning])
        XCTAssertNotNil(goal.hardDeadline)
    }

    func testDecodeTradeoffReport() throws {
        let json = """
        {
            "new_goal_name": "Side Project",
            "new_goal_hours": 6.5,
            "affected": [
                {"goal_name": "Study", "hours_lost": 2.0}
            ],
            "feasible": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let report = try decoder.decode(TradeoffReport.self, from: json)
        XCTAssertEqual(report.newGoalName, "Side Project")
        XCTAssertTrue(report.feasible)
        XCTAssertEqual(report.affected.count, 1)
        XCTAssertEqual(report.affected[0].hoursLost, 2.0)
    }

    func testDecodeGmailSignal() throws {
        let json = """
        {
            "id": "sig1",
            "subject": "Interview Invite",
            "snippet": "You have been invited...",
            "sender": "hr@company.com",
            "date": "2026-03-01T12:00:00Z",
            "signal_types": ["interview", "invite"]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let signal = try decoder.decode(GmailSignal.self, from: json)
        XCTAssertEqual(signal.signalTypes.count, 2)
        XCTAssert(signal.signalTypes.contains(.interview))
        XCTAssert(signal.signalTypes.contains(.invite))
    }

    // MARK: - ViewModel Tests

    func testDashboardViewModelLoadsData() async throws {
        let mockAPI = MockAPIClient()
        let repo = ChronoRepository(api: mockAPI)
        let vm = await DashboardViewModel(repository: repo)

        await vm.loadData()

        let blocksCount = await vm.todayBlocks.count
        XCTAssertGreaterThan(blocksCount, 0)

        let messages = await vm.coachingMessages
        XCTAssertFalse(messages.isEmpty)
    }

    func testGoalsViewModelLoadsGoals() async throws {
        let mockAPI = MockAPIClient()
        let repo = ChronoRepository(api: mockAPI)
        let vm = await GoalsViewModel(repository: repo)

        await vm.loadGoals()

        let count = await vm.goals.count
        XCTAssertGreaterThan(count, 0)
    }

    func testPlanViewModelLoadsBlocks() async throws {
        let mockAPI = MockAPIClient()
        let repo = ChronoRepository(api: mockAPI)
        let vm = await PlanViewModel(repository: repo)

        await vm.loadPlan()

        let plan = await vm.plan
        XCTAssertNotNil(plan)
        XCTAssertGreaterThan(plan!.blocks.count, 0)
    }
}
