import SwiftUI

struct KeyboardHeatmapView: View {
    let statistics: [KeyStatistic]

    private var countByCode: [UInt16: Int64] {
        Dictionary(uniqueKeysWithValues: statistics.map { ($0.keyCode, $0.count) })
    }

    private var maximumCount: Int64 {
        max(statistics.map(\.count).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("键盘热力图")
                    .font(.headline)
                Spacer()
                Text("颜色越深，使用越频繁")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(KeyCatalog.rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 6) {
                            ForEach(row) { key in
                                keyCap(key)
                            }
                        }
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

    private func keyCap(_ key: KeyboardKey) -> some View {
        let count = countByCode[key.keyCode, default: 0]
        let intensity = Double(count) / Double(maximumCount)

        return VStack(spacing: 2) {
            Text(key.fallbackLabel)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            Text(count.formatted())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(width: 42 * key.width, height: 42)
        .background(
            Color.accentColor.opacity(count == 0 ? 0.06 : 0.2 + intensity * 0.7),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.primary.opacity(0.08))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(KeyCatalog.displayName(for: key.keyCode))
        .accessibilityValue("\(count) 次")
    }
}
