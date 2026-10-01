import Foundation

public enum UnitStandard: Sendable {
    case binary   // 1024 (KiB/s, MiB/s)
    case decimal  // 1000 (KB/s, MB/s)
}

public struct TrafficUnitFormatter: Sendable {
    public static func formatRate(_ bytesPerSecond: Double, standard: UnitStandard = .binary) -> String {
        guard !bytesPerSecond.isNaN && !bytesPerSecond.isInfinite && bytesPerSecond > 0 else {
            return "0 B/s"
        }
        let base: Double = (standard == .binary) ? 1024.0 : 1000.0
        if bytesPerSecond < base {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < base * base {
            let val = bytesPerSecond / base
            return val >= 100 ? String(format: "%.0f KB/s", val) : String(format: "%.1f KB/s", val)
        } else if bytesPerSecond < base * base * base {
            let val = bytesPerSecond / (base * base)
            return String(format: "%.2f MB/s", val)
        } else {
            let val = bytesPerSecond / (base * base * base)
            return String(format: "%.2f GB/s", val)
        }
    }

    public static func formatBytes(_ bytes: UInt64, standard: UnitStandard = .binary) -> String {
        let base: Double = (standard == .binary) ? 1024.0 : 1000.0
        let b = Double(bytes)
        if b < base {
            return "\(bytes) B"
        } else if b < base * base {
            return String(format: "%.1f KB", b / base)
        } else if b < base * base * base {
            return String(format: "%.2f MB", b / (base * base))
        } else if b < base * base * base * base {
            return String(format: "%.2f GB", b / (base * base * base))
        } else {
            return String(format: "%.2f TB", b / (base * base * base * base))
        }
    }
    
    public static func formatCompactRate(_ bytesPerSecond: Double) -> String {
        guard !bytesPerSecond.isNaN && !bytesPerSecond.isInfinite && bytesPerSecond > 0 else {
            return "0B"
        }
        let base: Double = 1024.0
        if bytesPerSecond < base {
            return String(format: "%.0fB", bytesPerSecond)
        } else if bytesPerSecond < base * base {
            let val = bytesPerSecond / base
            return val >= 100 ? String(format: "%.0fK", val) : String(format: "%.1fK", val)
        } else if bytesPerSecond < base * base * base {
            let val = bytesPerSecond / (base * base)
            return String(format: "%.1fM", val)
        } else {
            let val = bytesPerSecond / (base * base * base)
            return String(format: "%.1fG", val)
        }
    }
}
