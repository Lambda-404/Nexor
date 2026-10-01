import Foundation
import SwiftUI

@Observable
@MainActor
public final class TrafficTelemetryManager {
    public static let shared = TrafficTelemetryManager()

    public private(set) var currentSnapshot: TrafficSnapshot?
    public private(set) var isMonitoring: Bool = false
    public private(set) var downloadHistory: [Double] = []
    public private(set) var uploadHistory: [Double] = []

    public var uploadSpeedFormatted: String { currentSnapshot?.aggregateStats.formattedTxRate ?? "0 B/s" }
    public var downloadSpeedFormatted: String { currentSnapshot?.aggregateStats.formattedRxRate ?? "0 B/s" }
    public var compactTxString: String {
        guard let stats = currentSnapshot?.aggregateStats else { return "0B" }
        return TrafficUnitFormatter.formatCompactRate(stats.txBytesPerSecond)
    }
    public var compactRxString: String {
        guard let stats = currentSnapshot?.aggregateStats else { return "0B" }
        return TrafficUnitFormatter.formatCompactRate(stats.rxBytesPerSecond)
    }
    public var menuBarDisplayString: String { currentSnapshot?.aggregateStats.formattedMenuString ?? "↑ 0 B/s  ↓ 0 B/s" }
    public var menuBarCompactString: String { currentSnapshot?.aggregateStats.formattedMenuCompactString ?? "↑0B ↓0B" }
    public var sessionSentFormatted: String { currentSnapshot?.aggregateStats.formattedSessionTx ?? "0 B" }
    public var sessionReceivedFormatted: String { currentSnapshot?.aggregateStats.formattedSessionRx ?? "0 B" }

    private let engine = TrafficStatisticsEngine()
    private var monitorTask: Task<Void, Never>?

    public init() {
        start()
    }

    public func start() {
        guard monitorTask == nil else { return }
        isMonitoring = true
        monitorTask = Task { [weak self] in
            guard let self = self else { return }
            let stream = await self.engine.startMonitoring(intervalNanoseconds: 1_000_000_000)
            for await snapshot in stream {
                guard !Task.isCancelled else { break }
                self.currentSnapshot = snapshot
                self.recordHistory(snapshot: snapshot)
            }
        }
    }

    public func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
    }

    public func resetSession() {
        Task {
            await engine.resetSession()
            let newSnapshot = await engine.sample()
            self.currentSnapshot = newSnapshot
        }
    }

    private func recordHistory(snapshot: TrafficSnapshot) {
        let dl = snapshot.aggregateStats.rxBytesPerSecond
        let ul = snapshot.aggregateStats.txBytesPerSecond
        downloadHistory.append(dl)
        uploadHistory.append(ul)
        
        // Keep last 30 samples for sparkline graph
        if downloadHistory.count > 30 {
            downloadHistory.removeFirst(downloadHistory.count - 30)
        }
        if uploadHistory.count > 30 {
            uploadHistory.removeFirst(uploadHistory.count - 30)
        }
    }
}
