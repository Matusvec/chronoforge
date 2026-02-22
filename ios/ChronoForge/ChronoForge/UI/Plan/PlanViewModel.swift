import Foundation

@MainActor
final class PlanViewModel: ObservableObject {
    @Published var plan: PlanResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDate: Date = Date()

    private let repository: ChronoRepositoryProtocol

    init(repository: ChronoRepositoryProtocol) {
        self.repository = repository
    }

    func loadPlan() async {
        isLoading = true
        errorMessage = nil
        do {
            plan = try await repository.generatePlan(simulate: nil)
            if let plan {
                await PlanCache.shared.save(plan)
            }
        } catch {
            errorMessage = error.localizedDescription
            plan = await PlanCache.shared.load()
        }
        isLoading = false
    }

    var dates: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return (0..<14).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    func blocks(for date: Date) -> [PlannedBlock] {
        let cal = Calendar.current
        return (plan?.blocks ?? [])
            .filter { cal.isDate($0.start, inSameDayAs: date) }
            .sorted { $0.start < $1.start }
    }

    func capacity(for date: Date) -> DayCapacity? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return plan?.capacityByDay.first { $0.date == key }
    }
}
