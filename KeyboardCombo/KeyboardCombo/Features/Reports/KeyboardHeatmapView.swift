import SwiftUI

struct KeyboardHeatmapView: View {
    let statistics: [KeyStatistic]
    let excludedKeyCodes: Set<UInt16>

    private struct HeatmapData {
        let countByCode: [UInt16: Int64]
        let maximumCount: Int64

        init(statistics: [KeyStatistic]) {
            let counts = Dictionary(
                uniqueKeysWithValues: statistics.map { ($0.keyCode, $0.count) }
            )
            countByCode = counts
            maximumCount = max(
                KeyCatalog.allKeys.map { counts[$0.keyCode, default: 0] }.max() ?? 0,
                1
            )
        }
    }

    var body: some View {
        let data = HeatmapData(statistics: statistics)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("全键盘热力图")
                    .font(.headline)
                Spacer()
                Text("颜色越深，使用越频繁")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ForEach(
                            Array(KeyCatalog.functionKeyGroups.enumerated()),
                            id: \.offset
                        ) { _, group in
                            HStack(spacing: 6) {
                                ForEach(group) { key in
                                    keyCap(key, data: data)
                                }
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 18) {
                        keyboardSection(KeyCatalog.rows, data: data)
                        navigationSection(data: data)
                        numericKeypadSection(data: data)
                    }
                }
                .padding(14)
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary)
            }
        }
    }

    private func keyboardSection(_ rows: [[KeyboardKey]], data: HeatmapData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row) { key in
                        keyCap(key, data: data)
                    }
                }
            }
        }
    }

    private func navigationSection(data: HeatmapData) -> some View {
        VStack(spacing: 6) {
            keyboardSection(KeyCatalog.navigationRows, data: data)
            Color.clear.frame(height: 42)
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    keyPlaceholder
                    ForEach(KeyCatalog.arrowRows[0]) { key in
                        keyCap(key, data: data)
                    }
                    keyPlaceholder
                }
                HStack(spacing: 6) {
                    ForEach(KeyCatalog.arrowRows[1]) { key in
                        keyCap(key, data: data)
                    }
                }
            }
        }
    }

    private func numericKeypadSection(data: HeatmapData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            keyboardSection(KeyCatalog.numericKeypadTopRows, data: data)
            HStack(alignment: .top, spacing: 6) {
                keyboardSection(KeyCatalog.numericKeypadBottomRows, data: data)
                keyCap(KeyCatalog.numericKeypadEnter, data: data, height: 90)
            }
        }
    }

    private var keyPlaceholder: some View {
        Color.clear.frame(width: 42, height: 42)
    }

    private func keyCap(
        _ key: KeyboardKey,
        data: HeatmapData,
        height: Double = 42
    ) -> some View {
        let count = data.countByCode[key.keyCode, default: 0]
        let intensity = Double(count) / Double(data.maximumCount)
        let isExcluded = excludedKeyCodes.contains(key.keyCode)

        return VStack(spacing: 2) {
            Text(key.fallbackLabel)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            Text(isExcluded ? "已过滤" : count.formatted())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 42 * key.width, height: height)
        .background(
            isExcluded
                ? Color.secondary.opacity(0.08)
                : Color.accentColor.opacity(count == 0 ? 0.06 : 0.2 + intensity * 0.7),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.primary.opacity(0.08))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(KeyCatalog.displayName(for: key.keyCode))
        .accessibilityValue(isExcluded ? "已过滤" : "\(count) 次")
    }
}
