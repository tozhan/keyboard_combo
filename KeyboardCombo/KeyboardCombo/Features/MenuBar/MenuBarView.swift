import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(model.captureStatus.title, systemImage: model.captureStatus.systemImage)
                    .foregroundStyle(statusColor)
                Spacer()
                Text(model.todayTotal.formatted())
                    .font(.title2.bold().monospacedDigit())
            }

            Divider()

            Text("今日 Top 5")
                .font(.headline)
            if model.topKeys.isEmpty {
                Text("还没有统计数据")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                ForEach(model.topKeys) { statistic in
                    HStack {
                        Text(KeyCatalog.displayName(for: statistic.keyCode))
                        Spacer()
                        Text(statistic.count.formatted())
                            .monospacedDigit()
                        Text(statistic.percentage, format: .percent.precision(.fractionLength(1)))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 58, alignment: .trailing)
                    }
                }
            }

            if model.captureStatus == .permissionRequired {
                Button("授权输入监控…") {
                    model.permissionManager.openSystemSettings()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }

            Divider()

            HStack {
                Button(model.captureEnabled ? "暂停统计" : "继续统计") {
                    Task {
                        await model.setCaptureEnabled(!model.captureEnabled)
                    }
                }
                Button("打开报表") {
                    openWindow(id: "reports")
                    NSApplication.shared.activate()
                }
                .keyboardShortcut("o")
            }

            HStack {
                SettingsLink {
                    Text("设置…")
                }
                Spacer()
                Button("退出") {
                    Task {
                        await model.shutdown()
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 330)
        .task {
            await model.refreshSummary()
        }
    }

    private var statusColor: Color {
        switch model.captureStatus {
        case .active: .green
        case .paused: .secondary
        case .permissionRequired: .orange
        }
    }
}
