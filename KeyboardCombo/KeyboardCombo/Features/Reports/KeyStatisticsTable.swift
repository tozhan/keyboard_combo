import SwiftUI

struct KeyStatisticsTable: View {
    private enum SortField {
        case key
        case count
        case percentage
    }

    let statistics: [KeyStatistic]
    @State private var searchText = ""
    @State private var showZeroValues = true
    @State private var sortField: SortField = .count
    @State private var ascending = false

    private var displayedStatistics: [KeyStatistic] {
        statistics
            .filter {
                (showZeroValues || $0.count > 0)
                    && (searchText.isEmpty
                        || KeyCatalog.displayName(for: $0.keyCode)
                            .localizedCaseInsensitiveContains(searchText))
            }
            .sorted { lhs, rhs in
                let comparison: ComparisonResult
                switch sortField {
                case .key:
                    let nameComparison = KeyCatalog.displayName(for: lhs.keyCode)
                        .localizedStandardCompare(KeyCatalog.displayName(for: rhs.keyCode))
                    comparison = nameComparison == .orderedSame
                        ? compare(lhs.keyCode, rhs.keyCode)
                        : nameComparison
                case .count:
                    comparison = lhs.count == rhs.count
                        ? compare(lhs.keyCode, rhs.keyCode)
                        : compare(lhs.count, rhs.count)
                case .percentage:
                    comparison = lhs.percentage == rhs.percentage
                        ? compare(lhs.keyCode, rhs.keyCode)
                        : compare(lhs.percentage, rhs.percentage)
                }
                return comparison == (ascending ? .orderedAscending : .orderedDescending)
            }
    }

    private var usageRankByKeyCode: [UInt16: Int] {
        let rankedStatistics = statistics
            .filter { $0.count > 0 }
            .sorted {
                $0.count == $1.count
                    ? $0.keyCode < $1.keyCode
                    : $0.count > $1.count
            }
        return Dictionary(
            uniqueKeysWithValues: rankedStatistics.enumerated().map {
                ($0.element.keyCode, $0.offset + 1)
            }
        )
    }

    var body: some View {
        let usageRanks = usageRankByKeyCode

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("按键明细")
                    .font(.headline)
                Spacer()
                Toggle("显示零值", isOn: $showZeroValues)
                    .toggleStyle(.checkbox)
                TextField("搜索按键", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("排名")
                        .frame(width: 56, alignment: .trailing)
                        .help("按使用次数从高到低的整体排名")
                    headerButton("按键", field: .key)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    headerButton("次数", field: .count)
                        .frame(width: 150, alignment: .trailing)
                    headerButton("占比", field: .percentage)
                        .frame(width: 180, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider()

                LazyVStack(spacing: 0) {
                    ForEach(displayedStatistics) { statistic in
                        HStack(spacing: 12) {
                            Text(
                                usageRanks[statistic.keyCode]
                                    .map(String.init) ?? "—"
                            )
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)

                            HStack {
                                Text(KeyCatalog.displayName(for: statistic.keyCode))
                                Text("#\(statistic.keyCode)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(statistic.count.formatted())
                                .monospacedDigit()
                                .frame(width: 150, alignment: .trailing)

                            HStack(spacing: 8) {
                                ProgressView(value: statistic.percentage)
                                    .frame(width: 90)
                                Text(
                                    statistic.percentage,
                                    format: .percent.precision(.fractionLength(2))
                                )
                                .monospacedDigit()
                                .frame(width: 66, alignment: .trailing)
                            }
                            .frame(width: 180, alignment: .trailing)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)

                        Divider()
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary)
            }
        }
    }

    private func headerButton(_ title: String, field: SortField) -> some View {
        Button {
            if sortField == field {
                ascending.toggle()
            } else {
                sortField = field
                ascending = field == .key
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if sortField == field {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }
}
