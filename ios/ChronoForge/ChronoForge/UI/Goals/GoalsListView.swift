import SwiftUI

struct GoalsListView: View {
    @StateObject var viewModel: GoalsViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.goals) { goal in
                    GoalRow(goal: goal)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showingAddGoal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .refreshable { await viewModel.loadGoals() }
            .task { await viewModel.loadGoals() }
            .overlay {
                if viewModel.isLoading && viewModel.goals.isEmpty {
                    ProgressView()
                }
            }
            .sheet(isPresented: $viewModel.showingAddGoal) {
                AddGoalView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingTradeoff) {
                if let report = viewModel.tradeoffResult {
                    TradeoffView(report: report)
                }
            }
        }
    }
}

// MARK: - Goal Row

struct GoalRow: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: goal.category.iconName)
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 36, height: 36)
                .background(categoryColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 8) {
                    Label("\(goal.weeklyTargetHours, specifier: "%.0f")h/wk", systemImage: "clock")
                    Label("P\(goal.priorityWeight)", systemImage: "arrow.up.right")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let deadline = goal.hardDeadline {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Deadline")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(deadline.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryColor: Color {
        switch goal.category {
        case .study: return .blue
        case .fitness: return .green
        case .career: return .orange
        case .personal: return .purple
        case .project: return .cyan
        case .social: return .pink
        }
    }
}

// MARK: - Add Goal View

struct AddGoalView: View {
    @ObservedObject var viewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: GoalCategory = .study
    @State private var priorityWeight = 5
    @State private var weeklyHours = 5.0
    @State private var selectedWindows: Set<TimeWindow> = []
    @State private var hasDeadline = false
    @State private var deadline = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Goal name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(GoalCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.iconName).tag(cat)
                        }
                    }
                }

                Section("Effort") {
                    Stepper("Priority: \(priorityWeight)", value: $priorityWeight, in: 1...10)
                    HStack {
                        Text("Weekly hours")
                        Spacer()
                        TextField("Hours", value: $weeklyHours, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section("Preferred Times") {
                    ForEach(TimeWindow.allCases, id: \.self) { window in
                        Toggle(window.displayName, isOn: Binding(
                            get: { selectedWindows.contains(window) },
                            set: { if $0 { selectedWindows.insert(window) } else { selectedWindows.remove(window) } }
                        ))
                    }
                }

                Section("Deadline") {
                    Toggle("Has deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Due", selection: $deadline, displayedComponents: [.date])
                    }
                }

                Section {
                    Button("Can I add this?") {
                        Task { await viewModel.simulateGoal(buildGoal()) }
                    }
                    .foregroundStyle(.orange)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await viewModel.createGoal(buildGoal())
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func buildGoal() -> GoalCreate {
        GoalCreate(
            name: name,
            category: category,
            priorityWeight: priorityWeight,
            weeklyTargetHours: weeklyHours,
            preferredTimeWindows: Array(selectedWindows),
            hardDeadline: hasDeadline ? deadline : nil
        )
    }
}

// MARK: - Tradeoff View

struct TradeoffView: View {
    let report: TradeoffReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: report.feasible ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(report.feasible ? .green : .red)

                Text(report.feasible ? "Feasible" : "Infeasible")
                    .font(.title2.weight(.bold))

                Text("Adding \"\(report.newGoalName)\" would get \(report.newGoalHours, specifier: "%.1f")h over 2 weeks.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if !report.affected.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goals that lose time:")
                            .font(.headline)

                        ForEach(report.affected, id: \.goalName) { entry in
                            HStack {
                                Text(entry.goalName)
                                Spacer()
                                Text("-\(entry.hoursLost, specifier: "%.1f")h")
                                    .foregroundStyle(.red)
                                    .fontWeight(.semibold)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Tradeoff Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
