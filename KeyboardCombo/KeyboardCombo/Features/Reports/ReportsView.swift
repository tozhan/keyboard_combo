import Charts
import SwiftUI

struct ReportsView: View {
    @Environment(AppModel.self) private var model
    @State private var granularity: ReportGranularity = .hour
    @State private var anchor = Date.now
    @State private var selectedStart: Date?
    @State private var chartSelection: Date?
    @State private var snapshot: ReportSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if !model.permissionManager.isGranted {
                permissionBanner
                Divider()
            }

            if let snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        summary(snapshot)
                        timelineChart(snapshot)
                        KeyboardHeatmapView(statistics: snapshot.keyStatistics)
                        KeyStatisticsTable(statistics: snapshot.keyStatistics)
                    }
                    .padding(24)
                }
                .refreshable {
                    await load()
                }
            } else if isLoading {
                ProgressView("正在载入报表…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "无法载入报表",
                    systemImage: "chart.bar.xaxis",
                    description: Text(errorMessage ?? "请稍后重试")
                )
            }
        }
        .task {
            await load()
        }
        .onChange(of: granularity) {
            selectedStart = nil
            chartSelection = nil
            Task { await load() }
        }
        .onChange(of: anchor) {
            selectedStart = nil
            chartSelection = nil
            Task { await load() }
        }
        .onChange(of: chartSelection) {
            guard let chartSelection, let snapshot else { return }
            let closest = snapshot.timeline.min {
                abs($0.start.timeIntervalSince(chartSelection))
                    < abs($1.start.timeIntervalSince(chartSelection))
            }
            guard closest?.start != selectedStart else { return }
            selectedStart = closest?.start
            Task { await load() }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            Text("键盘统计")
                .font(.title2.bold())

            Picker("统计粒度", selection: $granularity) {
                ForEach(ReportGranularity.allCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            Spacer()

            Button {
                moveAnchor(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("上一个时间范围")

            DatePicker("日期", selection: $anchor, displayedComponents: .date)
                .labelsHidden()

            Button("今天") {
                anchor = .now
            }

            Button {
                moveAnchor(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("下一个时间范围")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("尚未授予输入监控权限")
                    .font(.callout.weight(.semibold))
                Text("报表仍可查看；授权前不会采集新的按键数据。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("打开系统设置") {
                model.permissionManager.openSystemSettings()
            }
            Button("请求权限") {
                model.requestPermission()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
    }

    private func summary(_ snapshot: ReportSnapshot) -> some View {
        HStack(spacing: 16) {
            metricCard(
                title: "所选区间",
                value: selectedIntervalTitle(snapshot.selectedInterval),
                systemImage: "calendar"
            )
            metricCard(
                title: "按键总数",
                value: snapshot.selectedTotal.formatted(),
                systemImage: "keyboard"
            )
            metricCard(
                title: "最常用按键",
                value: snapshot.keyStatistics.first(where: { $0.count > 0 })
                    .map { KeyCatalog.displayName(for: $0.keyCode) } ?? "—",
                systemImage: "star"
            )
        }
    }

    private func metricCard(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.bold())
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func timelineChart(_ snapshot: ReportSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("趋势")
                .font(.headline)

            Chart(snapshot.timeline) { point in
                BarMark(
                    x: .value("时间", point.start, unit: granularity.calendarComponent),
                    y: .value("次数", point.count)
                )
                .foregroundStyle(
                    point.start == snapshot.selectedInterval.start
                        ? Color.accentColor
                        : Color.accentColor.opacity(0.45)
                )
                .accessibilityLabel(axisLabel(for: point.start))
                .accessibilityValue(point.count.formatted())
            }
            .chartXSelection(value: $chartSelection)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 230)
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary)
            }
        }
    }

    private func moveAnchor(by direction: Int) {
        let component: Calendar.Component
        let amount: Int
        switch granularity {
        case .hour:
            component = .day
            amount = direction
        case .day:
            component = .month
            amount = direction
        case .week:
            component = .weekOfYear
            amount = direction * 12
        case .month:
            component = .year
            amount = direction
        }
        anchor = Calendar.autoupdatingCurrent.date(
            byAdding: component,
            value: amount,
            to: anchor
        ) ?? anchor
    }

    private func load() async {
        isLoading = snapshot == nil
        do {
            snapshot = try await model.loadReport(
                granularity: granularity,
                anchor: anchor,
                selectedStart: selectedStart
            )
            selectedStart = snapshot?.selectedInterval.start
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func selectedIntervalTitle(_ interval: DateInterval) -> String {
        switch granularity {
        case .hour:
            interval.start.formatted(date: .abbreviated, time: .shortened)
        case .day:
            interval.start.formatted(date: .long, time: .omitted)
        case .week:
            "\(interval.start.formatted(date: .abbreviated, time: .omitted)) – \(interval.end.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted))"
        case .month:
            interval.start.formatted(.dateTime.year().month(.wide))
        }
    }

    private func axisLabel(for date: Date) -> String {
        switch granularity {
        case .hour:
            date.formatted(.dateTime.hour())
        case .day:
            date.formatted(.dateTime.day())
        case .week:
            date.formatted(.dateTime.month(.abbreviated).day())
        case .month:
            date.formatted(.dateTime.month(.abbreviated))
        }
    }
}
