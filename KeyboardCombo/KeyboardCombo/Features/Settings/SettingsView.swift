import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showingClearConfirmation = false

    var body: some View {
        Form {
            Section("统计") {
                Toggle(
                    "启用键盘统计",
                    isOn: Binding(
                        get: { model.captureEnabled },
                        set: { enabled in
                            Task {
                                await model.setCaptureEnabled(enabled)
                            }
                        }
                    )
                )

                Toggle(
                    "统计长按产生的自动重复",
                    isOn: Binding(
                        get: { model.includeAutoRepeat },
                        set: { model.setIncludeAutoRepeat($0) }
                    )
                )

                LabeledContent("状态") {
                    Label(model.captureStatus.title, systemImage: model.captureStatus.systemImage)
                }
            }

            Section("隐私") {
                Text("应用只保存每小时、每个物理按键的累计次数。不会保存输入内容、按键顺序、前台应用或任何网络数据。")
                    .foregroundStyle(.secondary)

                if !model.permissionManager.isGranted {
                    Button("打开输入监控设置…") {
                        model.permissionManager.openSystemSettings()
                    }
                }
            }

            Section("本地数据") {
                Button("清空全部统计数据…", role: .destructive) {
                    showingClearConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 12)
        .alert("清空全部统计数据？", isPresented: $showingClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                Task {
                    await model.clearAllData()
                }
            }
        } message: {
            Text("此操作会永久删除这台 Mac 上的所有键盘统计，且无法撤销。")
        }
    }
}
