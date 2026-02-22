import SwiftUI

struct DashboardView: View {
    @StateObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    coachingSection
                    capacityGauge
                    geminiInsightsSection
                    timelineSection
                    alertsSection
                }
                .padding()
            }
            .navigationTitle("Today")
            .refreshable { await viewModel.loadData() }
            .task { await viewModel.loadData() }
            .overlay {
                if viewModel.isLoading && viewModel.todayBlocks.isEmpty {
                    ProgressView("Forging your plan...")
                }
            }
            .overlay(alignment: .top) {
                if viewModel.needsReconnect {
                    reconnectBanner
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel.blockAwaitingCheckIn != nil },
                set: { if !$0 { viewModel.dismissCheckInPrompt() } }
            )) {
                if let block = viewModel.blockAwaitingCheckIn {
                    CheckInSheet(
                        block: block,
                        onSubmit: { text in
                            await viewModel.submitCheckIn(block: block, whatIDid: text)
                            viewModel.dismissCheckInPrompt()
                        },
                        onDismiss: { viewModel.dismissCheckInPrompt() }
                    )
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel.lastCheckInResult != nil },
                set: { if !$0 { viewModel.dismissCheckInResult() } }
            )) {
                if let result = viewModel.lastCheckInResult {
                    CheckInResultSheet(assessment: result.assessment, motivational: result.motivational) {
                        viewModel.dismissCheckInResult()
                    }
                }
            }
        }
    }

    // MARK: - Gemini Insights

    private var geminiInsightsSection: some View {
        Group {
            if let insights = viewModel.planInsights, insights.available, !insights.summary.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Your time at a glance", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.purple)
                    Text(insights.summary)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    if !insights.timeBreakdown.isEmpty {
                        Text(insights.timeBreakdown)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !insights.whereToAddMore.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.orange)
                            Text(insights.whereToAddMore)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Coaching

    private var coachingSection: some View {
        VStack(spacing: 8) {
            ForEach(Array(viewModel.coachingMessages.enumerated()), id: \.offset) { _, msg in
                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Capacity Gauge

    private var capacityGauge: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Capacity")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1fh / %.1fh",
                            viewModel.totalAllocatedToday,
                            viewModel.totalAllocatedToday + viewModel.totalFreeToday))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))

                    RoundedRectangle(cornerRadius: 8)
                        .fill(gaugeColor.gradient)
                        .frame(width: geo.size.width * min(viewModel.capacityFraction, 1.0))
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var gaugeColor: Color {
        let frac = viewModel.capacityFraction
        if frac < 0.6 { return .green }
        if frac < 0.85 { return .orange }
        return .red
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)

            if viewModel.todayBlocks.isEmpty {
                Text("No blocks today.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(viewModel.todayBlocks) { block in
                    TimelineBlockRow(
                        block: block,
                        onLogTap: { viewModel.blockAwaitingCheckIn = $0 }
                    )
                }
            }
        }
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let next = viewModel.nextBlock {
                alertCard(
                    icon: "clock.badge.exclamationmark",
                    color: .blue,
                    title: "Next Up",
                    detail: "\(next.goalName) at \(next.start.formatted(date: .omitted, time: .shortened))"
                )
            }

            ForEach(viewModel.upcomingTasks.prefix(3)) { task in
                alertCard(
                    icon: "doc.text.fill",
                    color: .purple,
                    title: task.courseName,
                    detail: "\(task.assignmentName) — due \(task.dueAt?.formatted(date: .abbreviated, time: .shortened) ?? "TBD")"
                )
            }

            ForEach(viewModel.signals.prefix(3)) { signal in
                alertCard(
                    icon: "envelope.badge.fill",
                    color: .red,
                    title: signal.subject,
                    detail: signal.snippet
                )
            }
        }
    }

    private func alertCard(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var reconnectBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Session expired. Please reconnect your accounts.")
                .font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding()
    }
}

// MARK: - CheckInSheet

struct CheckInSheet: View {
    let block: PlannedBlock
    let onSubmit: (String) async -> Void
    let onDismiss: () -> Void
    @State private var whatIDid = ""
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("What did you do for \(block.goalName)?")
                    .font(.subheadline)
                Text("\(block.start.formatted(date: .omitted, time: .shortened)) – \(block.end.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. Reviewed dynamic programming, did 3 problems", text: $whatIDid, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                Spacer()
            }
            .padding()
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { onDismiss(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            isSubmitting = true
                            await onSubmit(whatIDid.isEmpty ? "Nothing logged" : whatIDid)
                            isSubmitting = false
                            dismiss()
                        }
                    }
                    .disabled(whatIDid.isEmpty || isSubmitting)
                }
            }
        }
    }
}

// MARK: - CheckInResultSheet

struct CheckInResultSheet: View {
    let assessment: String
    let motivational: String
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assessment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(assessment)
                        .font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("Keep going", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(motivational)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("How you did")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDismiss(); dismiss() }
                }
            }
        }
    }
}

// MARK: - Timeline Block Row

struct TimelineBlockRow: View {
    let block: PlannedBlock
    var onLogTap: ((PlannedBlock) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(categoryColor.gradient)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.goalName)
                        .font(.subheadline.weight(.semibold))
                    Text(timeRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if block.isFixed {
                    Text("Fixed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5), in: Capsule())
                } else {
                    Image(systemName: block.category.iconName)
                        .font(.caption)
                        .foregroundStyle(categoryColor)
                }
            }

            if showLogButton {
                Button {
                    onLogTap?(block)
                } label: {
                    Label("Log what you did", systemImage: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var showLogButton: Bool {
        !block.isFixed && block.end < Date()
    }

    private var timeRange: String {
        "\(block.start.formatted(date: .omitted, time: .shortened)) – \(block.end.formatted(date: .omitted, time: .shortened))"
    }

    private var categoryColor: Color {
        switch block.category {
        case .study: return .blue
        case .fitness: return .green
        case .career: return .orange
        case .personal: return .purple
        case .project: return .cyan
        case .social: return .pink
        }
    }
}
