import SwiftUI

struct PlanView: View {
    @StateObject var viewModel: PlanViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateSelector
                Divider()
                dayDetail
            }
            .navigationTitle("2-Week Plan")
            .task { await viewModel.loadPlan() }
            .refreshable { await viewModel.loadPlan() }
            .overlay {
                if viewModel.isLoading && viewModel.plan == nil {
                    ProgressView("Generating plan...")
                }
            }
        }
    }

    // MARK: - Date Selector

    private var dateSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.dates, id: \.self) { date in
                        DatePill(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate))
                            .id(date)
                            .onTapGesture { viewModel.selectedDate = date }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .onAppear {
                proxy.scrollTo(viewModel.selectedDate, anchor: .center)
            }
        }
    }

    // MARK: - Day Detail

    private var dayDetail: some View {
        let blocks = viewModel.blocks(for: viewModel.selectedDate)
        let cap = viewModel.capacity(for: viewModel.selectedDate)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let cap {
                    HStack {
                        StatBadge(label: "Allocated", value: String(format: "%.1fh", cap.allocatedHours), color: .orange)
                        StatBadge(label: "Spare", value: String(format: "%.1fh", cap.spareHours), color: .green)
                        StatBadge(label: "Total", value: String(format: "%.1fh", cap.totalHours), color: .blue)
                    }
                }

                if blocks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No blocks scheduled")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(blocks) { block in
                        TimelineBlockRow(block: block)
                    }
                }

                if let unmet = viewModel.plan?.unmet, !unmet.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unmet Goals")
                            .font(.headline)
                            .foregroundStyle(.red)

                        ForEach(unmet) { item in
                            HStack {
                                Text(item.goalName)
                                    .font(.subheadline)
                                Spacer()
                                Text("-\(item.deficitHours, specifier: "%.1f")h")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }
}

// MARK: - Date Pill

struct DatePill: View {
    let date: Date
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2)
                .foregroundStyle(isSelected ? .white : .secondary)
            Text(date.formatted(.dateTime.day()))
                .font(.callout.weight(.bold))
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .frame(width: 48, height: 56)
        .background(
            isSelected ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(Color(.secondarySystemBackground)),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
