import Foundation

@MainActor
final class GoalsViewModel: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var tradeoffResult: TradeoffReport?
    @Published var showingTradeoff = false
    @Published var showingAddGoal = false

    private let repository: ChronoRepositoryProtocol

    init(repository: ChronoRepositoryProtocol) {
        self.repository = repository
    }

    func loadGoals() async {
        isLoading = true
        errorMessage = nil
        do {
            goals = try await repository.getGoals()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createGoal(_ goal: GoalCreate) async {
        do {
            let newGoal = try await repository.createGoal(goal)
            goals.append(newGoal)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func simulateGoal(_ goal: GoalCreate) async {
        do {
            tradeoffResult = try await repository.getTradeoff(for: goal)
            showingTradeoff = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
