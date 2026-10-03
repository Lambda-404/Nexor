#if os(macOS)
import SwiftUI

public enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Sendable {
    case speedText = "speedText"
    case compactIcon = "compactIcon"
    case speedAndGraph = "speedAndGraph"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .speedText: return "Live Speed Text"
        case .compactIcon: return "Compact Icon"
        case .speedAndGraph: return "Speed + Mini Sparkline Graph"
        }
    }
    
    public var previewSample: String {
        switch self {
        case .speedText: return "↑ 120 KB/s  ↓ 2.4 MB/s"
        case .compactIcon: return "􀤆"
        case .speedAndGraph: return "↑120K ↓2.4M [∿]"
        }
    }
}

public struct MenuBarSparklineView: View {
    public let downloadHistory: [Double]
    public let uploadHistory: [Double]
    public var width: CGFloat?
    public var height: CGFloat
    
    public init(downloadHistory: [Double], uploadHistory: [Double], width: CGFloat? = 34, height: CGFloat = 14) {
        self.downloadHistory = downloadHistory
        self.uploadHistory = uploadHistory
        self.width = width
        self.height = height
    }
    
    public var body: some View {
        Group {
            if let w = width {
                sparklineCanvas
                    .frame(width: w, height: height)
            } else {
                sparklineCanvas
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            }
        }
    }
    
    private var sparklineCanvas: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let hasDl = downloadHistory.count > 1
            let hasUl = uploadHistory.count > 1
            guard hasDl || hasUl else {
                // Subtle baseline when no history
                var baseLine = Path()
                baseLine.move(to: CGPoint(x: 0, y: h - 1))
                baseLine.addLine(to: CGPoint(x: w, y: h - 1))
                context.stroke(baseLine, with: .color(.secondary.opacity(0.3)), lineWidth: 1)
                return
            }
            
            let maxDl = downloadHistory.max() ?? 1024
            let maxUl = uploadHistory.max() ?? 1024
            let maxVal = max(maxDl, maxUl, 50 * 1024) // 50 KB/s minimum ceiling
            let dlStep = w / CGFloat(max(1, downloadHistory.count - 1))
            let ulStep = w / CGFloat(max(1, uploadHistory.count - 1))
            
            // Download curve (Cyan)
            if hasDl {
                var dlPath = Path()
                for (i, val) in downloadHistory.enumerated() {
                    let x = CGFloat(i) * dlStep
                    let y = h - (CGFloat(val) / CGFloat(maxVal) * (h - 2)) - 1
                    if i == 0 { dlPath.move(to: CGPoint(x: x, y: y)) }
                    else { dlPath.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(dlPath, with: .color(.cyan), lineWidth: 1.2)
            }
            
            // Upload curve (Orange)
            if hasUl {
                var ulPath = Path()
                for (i, val) in uploadHistory.enumerated() {
                    let x = CGFloat(i) * ulStep
                    let y = h - (CGFloat(val) / CGFloat(maxVal) * (h - 2)) - 1
                    if i == 0 { ulPath.move(to: CGPoint(x: x, y: y)) }
                    else { ulPath.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(ulPath, with: .color(.orange.opacity(0.85)), lineWidth: 1.0)
            }
        }
    }
}

#endif
