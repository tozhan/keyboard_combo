import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showingClearConfirmation = false
    @State private var showingKeyFilter = false
    @State private var draftExcludedKeyCodes: Set<UInt16> = []

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

            Section("按键过滤") {
                Text("被过滤的按键不会计入报表、总数或 Top 5；原始数据仍会保留。")
                    .foregroundStyle(.secondary)

                LabeledContent("已过滤") {
                    Text("\(model.excludedKeyCodes.count) 个按键")
                }

                HStack {
                    Button("选择按键…") {
                        draftExcludedKeyCodes = model.excludedKeyCodes
                        showingKeyFilter = true
                    }

                    if !model.excludedKeyCodes.isEmpty {
                        Button("全部恢复") {
                            model.setExcludedKeyCodes([])
                        }
                    }
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
        .sheet(isPresented: $showingKeyFilter) {
            KeyFilterSelectionView(
                selection: $draftExcludedKeyCodes,
                onCancel: {
                    showingKeyFilter = false
                },
                onSave: {
                    model.setExcludedKeyCodes(draftExcludedKeyCodes)
                    showingKeyFilter = false
                }
            )
        }
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

private struct KeyFilterSelectionView: View {
    private struct KeyGroup: Identifiable {
        let id: String
        let title: String
        let keys: [KeyboardKey]
    }

    private static let groups = [
        KeyGroup(
            id: "function",
            title: "顶部功能键",
            keys: KeyCatalog.functionKeyGroups.flatMap { $0 }
        ),
        KeyGroup(id: "main", title: "主键盘", keys: KeyCatalog.rows.flatMap { $0 }),
        KeyGroup(
            id: "navigation",
            title: "导航与方向键",
            keys: KeyCatalog.navigationRows.flatMap { $0 }
                + KeyCatalog.arrowRows.flatMap { $0 }
        ),
        KeyGroup(
            id: "keypad",
            title: "数字键盘",
            keys: KeyCatalog.numericKeypadTopRows.flatMap { $0 }
                + KeyCatalog.numericKeypadBottomRows.flatMap { $0 }
                + [KeyCatalog.numericKeypadEnter]
        )
    ]

    @Binding var selection: Set<UInt16>
    let onCancel: () -> Void
    let onSave: () -> Void
    @State private var searchText = ""

    private var filteredGroups: [KeyGroup] {
        guard !searchText.isEmpty else { return Self.groups }
        return Self.groups.compactMap { group in
            let keys = group.keys.filter {
                KeyCatalog.displayName(for: $0.keyCode)
                    .localizedCaseInsensitiveContains(searchText)
                    || String($0.keyCode).contains(searchText)
            }
            return keys.isEmpty
                ? nil
                : KeyGroup(id: group.id, title: group.title, keys: keys)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择要过滤的按键")
                        .font(.title2.bold())
                    Text("已选择 \(selection.count) 个；保存后会立即重新计算统计。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("清除选择") {
                    selection.removeAll()
                }
                .disabled(selection.isEmpty)
            }
            .padding()

            Divider()

            List {
                ForEach(filteredGroups) { group in
                    Section(group.title) {
                        ForEach(group.keys) { key in
                            Toggle(isOn: selectionBinding(for: key.keyCode)) {
                                HStack {
                                    Text(KeyCatalog.displayName(for: key.keyCode))
                                    Spacer()
                                    Text("#\(key.keyCode)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索按键名称或 keyCode")

            Divider()

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("保存", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 520, minHeight: 600)
        .interactiveDismissDisabled()
    }

    private func selectionBinding(for keyCode: UInt16) -> Binding<Bool> {
        Binding(
            get: { selection.contains(keyCode) },
            set: { isExcluded in
                if isExcluded {
                    selection.insert(keyCode)
                } else {
                    selection.remove(keyCode)
                }
            }
        )
    }
}
