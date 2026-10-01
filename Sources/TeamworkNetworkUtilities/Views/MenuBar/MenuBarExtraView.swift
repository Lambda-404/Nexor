import SwiftUI

public struct MenuBarExtraView: View {
    @AppStorage("menuBarDisplayMode") private var mode: MenuBarDisplayMode = .speedAndGraph
    private var trafficManager = TrafficTelemetryManager.shared
    private var mediumDetector = NetworkMediumDetector.shared
    
    public init() {}
    
    public var body: some View {
        HStack(alignment: .center, spacing: 5) {
            switch mode {
            case .compactIcon:
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .medium))
                
            case .speedText:
                // Full speed horizontal display: ↑ 0 B/s  ↓ 0 B/s
                HStack(alignment: .center, spacing: 6) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(trafficManager.uploadSpeedFormatted)
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(trafficManager.downloadSpeedFormatted)
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                    }
                }
                
            case .speedAndGraph:
                // Compact rate horizontal display with Sparkline: ↑ 0B  ↓ 0B [∿]
                HStack(alignment: .center, spacing: 5) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(trafficManager.compactTxString)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                    }
                    
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(trafficManager.compactRxString)
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                    }
                    
                    MenuBarSparklineView(
                        downloadHistory: trafficManager.downloadHistory,
                        uploadHistory: trafficManager.uploadHistory,
                        width: 28,
                        height: 12
                    )
                }
            }
        }
    }
    
    private var iconName: String {
        if mediumDetector.isWiredEthernetActive {
            return "cable.connector"
        } else if mediumDetector.isWiFiActive {
            return "wifi"
        } else {
            return "network"
        }
    }
}
