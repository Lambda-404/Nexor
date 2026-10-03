#if os(macOS)
import Foundation

public enum InterfaceMedium: String, Sendable, CaseIterable {
    case ethernet = "Ethernet"
    case wifi = "Wi-Fi"
    case bridge = "Bridge"
    case vpn = "VPN/Tunnel"
    case loopback = "Loopback"
    case other = "Other"
}

public struct InterfaceTrafficStats: Identifiable, Sendable, Equatable {
    public var id: String { name }
    public let name: String               // e.g. "en6"
    public let displayName: String        // e.g. "USB 10/100/1000 LAN"
    public let medium: InterfaceMedium
    public let isPrimary: Bool
    public let isUp: Bool
    public let isRunning: Bool
    public let rxBytesPerSecond: Double   // Instantaneous Rx rate
    public let txBytesPerSecond: Double   // Instantaneous Tx rate
    public let sessionRxBytes: UInt64     // Session cumulative downloaded
    public let sessionTxBytes: UInt64     // Session cumulative uploaded
    public let totalRxBytes: UInt64       // Total since system boot
    public let totalTxBytes: UInt64       // Total since system boot
    public let baudrate: UInt64           // Link speed in bps
    public let mtu: UInt32
    public let timestamp: Date

    public var formattedRxRate: String { TrafficUnitFormatter.formatRate(rxBytesPerSecond) }
    public var formattedTxRate: String { TrafficUnitFormatter.formatRate(txBytesPerSecond) }
    public var formattedSessionRx: String { TrafficUnitFormatter.formatBytes(sessionRxBytes) }
    public var formattedSessionTx: String { TrafficUnitFormatter.formatBytes(sessionTxBytes) }
    public var formattedTotalRx: String { TrafficUnitFormatter.formatBytes(totalRxBytes) }
    public var formattedTotalTx: String { TrafficUnitFormatter.formatBytes(totalTxBytes) }
    
    public init(
        name: String,
        displayName: String,
        medium: InterfaceMedium,
        isPrimary: Bool,
        isUp: Bool,
        isRunning: Bool,
        rxBytesPerSecond: Double,
        txBytesPerSecond: Double,
        sessionRxBytes: UInt64,
        sessionTxBytes: UInt64,
        totalRxBytes: UInt64,
        totalTxBytes: UInt64,
        baudrate: UInt64,
        mtu: UInt32,
        timestamp: Date
    ) {
        self.name = name
        self.displayName = displayName
        self.medium = medium
        self.isPrimary = isPrimary
        self.isUp = isUp
        self.isRunning = isRunning
        self.rxBytesPerSecond = rxBytesPerSecond
        self.txBytesPerSecond = txBytesPerSecond
        self.sessionRxBytes = sessionRxBytes
        self.sessionTxBytes = sessionTxBytes
        self.totalRxBytes = totalRxBytes
        self.totalTxBytes = totalTxBytes
        self.baudrate = baudrate
        self.mtu = mtu
        self.timestamp = timestamp
    }
}

public struct AggregateTrafficStats: Sendable, Equatable {
    public let rxBytesPerSecond: Double
    public let txBytesPerSecond: Double
    public let sessionRxBytes: UInt64
    public let sessionTxBytes: UInt64
    public let activeInterfaceCount: Int

    public var formattedRxRate: String { TrafficUnitFormatter.formatRate(rxBytesPerSecond) }
    public var formattedTxRate: String { TrafficUnitFormatter.formatRate(txBytesPerSecond) }
    public var formattedSessionRx: String { TrafficUnitFormatter.formatBytes(sessionRxBytes) }
    public var formattedSessionTx: String { TrafficUnitFormatter.formatBytes(sessionTxBytes) }
    public var formattedMenuString: String {
        "↑ \(formattedTxRate)  ↓ \(formattedRxRate)"
    }
    public var formattedMenuCompactString: String {
        "↑\(TrafficUnitFormatter.formatCompactRate(txBytesPerSecond)) ↓\(TrafficUnitFormatter.formatCompactRate(rxBytesPerSecond))"
    }
    
    public init(
        rxBytesPerSecond: Double,
        txBytesPerSecond: Double,
        sessionRxBytes: UInt64,
        sessionTxBytes: UInt64,
        activeInterfaceCount: Int
    ) {
        self.rxBytesPerSecond = rxBytesPerSecond
        self.txBytesPerSecond = txBytesPerSecond
        self.sessionRxBytes = sessionRxBytes
        self.sessionTxBytes = sessionTxBytes
        self.activeInterfaceCount = activeInterfaceCount
    }
}

public struct TrafficSnapshot: Sendable, Equatable {
    public let timestamp: Date
    public let primaryInterfaceName: String?
    public let primaryStats: InterfaceTrafficStats?
    public let aggregateStats: AggregateTrafficStats
    public let perInterfaceStats: [InterfaceTrafficStats]
    
    public init(
        timestamp: Date,
        primaryInterfaceName: String?,
        primaryStats: InterfaceTrafficStats?,
        aggregateStats: AggregateTrafficStats,
        perInterfaceStats: [InterfaceTrafficStats]
    ) {
        self.timestamp = timestamp
        self.primaryInterfaceName = primaryInterfaceName
        self.primaryStats = primaryStats
        self.aggregateStats = aggregateStats
        self.perInterfaceStats = perInterfaceStats
    }
}

#endif
