import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 54))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("开始统计键盘使用情况")
                    .font(.largeTitle.bold())
                Text("Keyboard Combo 需要“输入监控”权限，才能在其他应用处于前台时统计按键。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("只记录每小时各按键的累计次数", systemImage: "checkmark.shield")
                Label("不记录输入内容、按键顺序或前台应用", systemImage: "eye.slash")
                Label("所有数据仅保存在这台 Mac 上", systemImage: "internaldrive")
            }
            .padding(20)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))

            HStack {
                Button("打开系统设置") {
                    model.permissionManager.openSystemSettings()
                }
                Button("请求输入监控权限") {
                    model.requestPermission()
                }
                .buttonStyle(.borderedProminent)
            }

            Text("授权后返回此窗口，应用会自动开始统计。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(48)
    }
}
