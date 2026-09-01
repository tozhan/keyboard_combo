# Keyboard Combo

Keyboard Combo 是一款本地运行的 macOS 键盘使用统计应用。它常驻菜单栏，并通过独立窗口展示小时、天、周、月报表。

## 功能

- 全局统计标准键盘按键及左右修饰键
- 小时、天、周、月趋势图
- 键盘热力图
- 每个按键的次数和占全部按键的百分比
- 菜单栏展示今日总次数和 Top 5
- 暂停统计、自动重复开关、清空本地数据
- 支持 ANSI、ISO、JIS 键盘上的常见物理键

## 隐私设计

应用只保存“UTC 小时桶 + 物理 keyCode + 累计次数”，不会保存：

- 输入的文本或字符内容
- 单次按键的精确时间和先后顺序
- 组合键序列
- 当前使用的应用或窗口
- 鼠标事件

数据库只位于当前用户的：

```text
~/Library/Application Support/KeyboardCombo/keyboard-counts.sqlite
```

应用没有网络功能，也没有分析 SDK。

## 环境要求

- macOS 14 或更高版本
- Xcode 16 或更高版本
- Swift 6

项目使用 SwiftUI、Swift Charts、CoreGraphics Event Tap，以及通过 Swift Package Manager 引入的 GRDB。

## 运行

1. 用 Xcode 打开 `KeyboardCombo/KeyboardCombo.xcodeproj`。
2. 在 Signing & Capabilities 中选择本机开发 Team，保持固定的 Bundle ID。
3. 选择 `KeyboardCombo` scheme 并运行。
4. 首次启动时点击“请求输入监控权限”。
5. 在“系统设置 → 隐私与安全性 → 输入监控”中允许 Keyboard Combo。
6. 返回应用；应用激活后会自动刷新授权状态并开始统计。

为了避免 macOS 将每次构建识别成不同应用，请保持开发签名和 Bundle ID 稳定。如果授权后仍未采集，可在输入监控列表中移除旧条目，重新运行并授权。

也可以用 Swift Package Manager 编译并运行测试：

```bash
swift test
```

Swift Package 构建入口主要用于代码和单元测试校验；要获得正常的 `.app` Bundle 和可靠的输入监控授权，请从 Xcode 工程运行。

## 统计口径

- 普通键：每次 `keyDown` 计数一次。
- 修饰键：只在按下时计数，左右键分别统计。
- 长按：默认忽略系统产生的自动重复，可在设置中开启。
- 百分比：`该按键次数 / 所选时间桶内全部按键次数`。
- 周：从周一开始。
- 小时报表展示所选日的 24 小时；日报展示所选月；周报展示滚动 12 周；月报展示所选年。
- 报表和日期边界按系统本地时区显示，底层小时桶以 UTC 保存。

## 数据可靠性

- 事件监听使用只读 `CGEventTap`，不会拦截或修改按键。
- 计数先在内存中累加，每 10 秒、跨小时、暂停或正常退出时批量写入 SQLite。
- SQLite 使用 WAL 和原子 upsert。
- 权限缺失、系统安全输入、休眠或事件监听被系统暂停时，可能产生未采集区间；应用不会估算或补造数据。

## 已知限制

- 首版不统计媒体键等 `systemDefined` 事件。
- 不记录组合键、按应用分类，也不提供云同步。
- 直接强制结束进程时，最近最多约 10 秒的尚未落盘计数可能丢失。
- 当前目标是本机开发运行；Developer ID 公证与 Mac App Store 沙盒分发尚未配置。

## 项目结构

```text
KeyboardCombo/
├── KeyboardCombo.xcodeproj
├── KeyboardCombo/
│   ├── App/
│   ├── Features/
│   ├── Models/
│   ├── Persistence/
│   └── Services/
└── KeyboardComboTests/
```
