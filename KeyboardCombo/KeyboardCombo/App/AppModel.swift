import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private static let excludedKeyCodesDefaultsKey = "excludedKeyCodes"

    enum CaptureStatus {
        case active
        case paused
        case permissionRequired

        var title: String {
            switch self {
            case .active: "正在统计"
            case .paused: "已暂停"
            case .permissionRequired: "需要输入监控权限"
            }
        }

        var systemImage: String {
            switch self {
            case .active: "circle.fill"
            case .paused: "pause.circle.fill"
            case .permissionRequired: "exclamationmark.triangle.fill"
            }
        }
    }

    let permissionManager: InputPermissionManager
    private(set) var todayTotal: Int64 = 0
    private(set) var topKeys: [KeyStatistic] = []
    private(set) var lastError: String?
    private(set) var isStarted = false
    var captureEnabled: Bool
    var includeAutoRepeat: Bool
    private(set) var excludedKeyCodes: Set<UInt16>

    @ObservationIgnored private let repository: StatisticsRepository
    @ObservationIgnored private let aggregator: KeyAggregationActor
    @ObservationIgnored private let keyboardMonitor: KeyboardMonitor
    @ObservationIgnored private let eventStream: AsyncStream<KeyPress>
    @ObservationIgnored private let eventContinuation: AsyncStream<KeyPress>.Continuation
    @ObservationIgnored private var consumerTask: Task<Void, Never>?
    @ObservationIgnored private var summaryTask: Task<Void, Never>?
    @ObservationIgnored private var permissionPollingTask: Task<Void, Never>?

    var captureStatus: CaptureStatus {
        if !permissionManager.isGranted {
            return .permissionRequired
        }
        return captureEnabled ? .active : .paused
    }

    init(database: AppDatabase? = nil) {
        do {
            let resolvedDatabase = try database ?? AppDatabase()
            repository = StatisticsRepository(database: resolvedDatabase)
            aggregator = KeyAggregationActor(database: resolvedDatabase)
        } catch {
            fatalError("Unable to open Keyboard Combo database: \(error)")
        }

        permissionManager = InputPermissionManager()
        captureEnabled = UserDefaults.standard.object(forKey: "captureEnabled") as? Bool ?? true
        includeAutoRepeat = UserDefaults.standard.bool(forKey: "includeAutoRepeat")
        excludedKeyCodes = Set(
            UserDefaults.standard
                .array(forKey: Self.excludedKeyCodesDefaultsKey)?
                .compactMap { value in
                    guard let number = value as? NSNumber else { return nil }
                    return UInt16(exactly: number.intValue)
                } ?? []
        )

        let (stream, continuation) = AsyncStream<KeyPress>.makeStream(
            bufferingPolicy: .bufferingNewest(4_096)
        )
        eventStream = stream
        eventContinuation = continuation
        keyboardMonitor = KeyboardMonitor { press in
            continuation.yield(press)
        }
    }

    func start() async {
        guard !isStarted else {
            refreshPermissionAndCapture()
            return
        }
        isStarted = true

        await aggregator.start()
        consumerTask = Task { [weak self, eventStream] in
            for await press in eventStream {
                guard let self else { break }
                let includeRepeat = self.includeAutoRepeat
                await self.aggregator.record(press, includeAutoRepeat: includeRepeat)
            }
        }
        summaryTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshSummary()
                try? await Task.sleep(for: .seconds(10))
            }
        }
        refreshPermissionAndCapture()
    }

    func refreshPermissionAndCapture() {
        permissionManager.refresh()
        if captureEnabled && permissionManager.isGranted {
            keyboardMonitor.start()
        } else {
            keyboardMonitor.stop()
        }
    }

    func requestPermission() {
        permissionPollingTask?.cancel()
        let wasGranted = permissionManager.request()
        refreshPermissionAndCapture()
        guard !wasGranted else { return }

        permissionPollingTask = Task { [weak self] in
            for _ in 0..<120 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.permissionManager.refresh()
                if self.permissionManager.isGranted {
                    self.refreshPermissionAndCapture()
                    return
                }
            }
        }
    }

    func setCaptureEnabled(_ enabled: Bool) async {
        captureEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "captureEnabled")
        if enabled {
            refreshPermissionAndCapture()
        } else {
            keyboardMonitor.stop()
            await aggregator.flush()
            await refreshSummary()
        }
    }

    func setIncludeAutoRepeat(_ enabled: Bool) {
        includeAutoRepeat = enabled
        UserDefaults.standard.set(enabled, forKey: "includeAutoRepeat")
    }

    func setExcludedKeyCodes(_ keyCodes: Set<UInt16>) {
        excludedKeyCodes = keyCodes
        UserDefaults.standard.set(
            keyCodes.sorted().map(Int.init),
            forKey: Self.excludedKeyCodesDefaultsKey
        )
        Task {
            await refreshSummary()
        }
    }

    func refreshSummary() async {
        await aggregator.flush()
        let interval = repository.todayInterval()
        let excludedKeyCodes = excludedKeyCodes

        do {
            let result = try await Task.detached { [repository] in
                try repository.totalAndTopKeys(
                    in: interval,
                    excluding: excludedKeyCodes
                )
            }.value
            todayTotal = result.0
            topKeys = result.1
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadReport(
        granularity: ReportGranularity,
        anchor: Date,
        selectedStart: Date?
    ) async throws -> ReportSnapshot {
        await aggregator.flush()
        let excludedKeyCodes = excludedKeyCodes
        return try await Task.detached { [repository] in
            try repository.snapshot(
                granularity: granularity,
                anchor: anchor,
                selectedStart: selectedStart,
                excluding: excludedKeyCodes
            )
        }.value
    }

    func clearAllData() async {
        let shouldResume = captureEnabled && permissionManager.isGranted
        keyboardMonitor.stop()
        await aggregator.clear()

        do {
            try await Task.detached { [repository] in
                try repository.deleteAll()
            }.value
            todayTotal = 0
            topKeys = []
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        if shouldResume {
            keyboardMonitor.start()
        }
    }

    func shutdown() async {
        keyboardMonitor.stop()
        summaryTask?.cancel()
        consumerTask?.cancel()
        permissionPollingTask?.cancel()
        await aggregator.stop()
        eventContinuation.finish()
    }
}
