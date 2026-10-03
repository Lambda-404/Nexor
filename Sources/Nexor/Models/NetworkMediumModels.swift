#if os(macOS)
import Foundation

public enum NetworkMedium: String, Sendable, CaseIterable, Identifiable {
    case wiredEthernet = "Wired Ethernet"
    case wifi = "Wireless Wi-Fi"
    case thunderboltBridge = "Thunderbolt Bridge"
    case cellular = "Cellular / Hotspot"
    case unknown = "Unknown Medium"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .wiredEthernet: return "cable.connector"
        case .wifi: return "wifi"
        case .thunderboltBridge: return "bolt.horizontal"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .unknown: return "network"
        }
    }
}

public enum NetworkConnectionState: String, Sendable {
    case active = "Active (Connected)"
    case linkUpNoIP = "Link Up (Configuring IP)"
    case cableDisconnected = "Cable Disconnected"
    case disabled = "Disabled / Inactive"
    case disconnected = "Disconnected"
}

public struct NetworkAdapterInfo: Identifiable, Sendable, Equatable {
    public var id: String { bsdName }
    public let bsdName: String              // e.g. "en6", "en0"
    public let displayName: String          // e.g. "USB 10/100/1000 LAN", "Wi-Fi"
    public let medium: NetworkMedium        // .wiredEthernet vs .wifi
    public let connectionState: NetworkConnectionState
    public let isPrimary: Bool              // true if default route interface
    public let macAddress: String           // e.g. "00:E0:4C:2E:0A:50"
    public let mtu: Int                     // e.g. 1500
    public let linkSpeedMbps: Double?       // e.g. 1000.0 (1 Gbps)
    public let linkSpeedDescription: String  // e.g. "1.0 Gbps (1000baseT) <Full-Duplex>"
    public let isFullDuplex: Bool
    public let ipv4Address: String?
    public let subnetMask: String?
    public let broadcastAddress: String?
    public let ipv6Address: String?
    public let gatewayAddress: String?
    
    // Wi-Fi specific fields (populated when medium == .wifi)
    public let wifiSSID: String?
    public let wifiBSSID: String?
    public let wifiRSSI: Int?
    public let wifiNoise: Int?
    public let wifiSNR: Int?
    public let wifiChannel: String?
    public let wifiTxRate: Double?
    
    public init(
        bsdName: String,
        displayName: String,
        medium: NetworkMedium,
        connectionState: NetworkConnectionState,
        isPrimary: Bool,
        macAddress: String,
        mtu: Int,
        linkSpeedMbps: Double?,
        linkSpeedDescription: String,
        isFullDuplex: Bool,
        ipv4Address: String?,
        subnetMask: String?,
        broadcastAddress: String?,
        ipv6Address: String?,
        gatewayAddress: String?,
        wifiSSID: String? = nil,
        wifiBSSID: String? = nil,
        wifiRSSI: Int? = nil,
        wifiNoise: Int? = nil,
        wifiSNR: Int? = nil,
        wifiChannel: String? = nil,
        wifiTxRate: Double? = nil
    ) {
        self.bsdName = bsdName
        self.displayName = displayName
        self.medium = medium
        self.connectionState = connectionState
        self.isPrimary = isPrimary
        self.macAddress = macAddress
        self.mtu = mtu
        self.linkSpeedMbps = linkSpeedMbps
        self.linkSpeedDescription = linkSpeedDescription
        self.isFullDuplex = isFullDuplex
        self.ipv4Address = ipv4Address
        self.subnetMask = subnetMask
        self.broadcastAddress = broadcastAddress
        self.ipv6Address = ipv6Address
        self.gatewayAddress = gatewayAddress
        self.wifiSSID = wifiSSID
        self.wifiBSSID = wifiBSSID
        self.wifiRSSI = wifiRSSI
        self.wifiNoise = wifiNoise
        self.wifiSNR = wifiSNR
        self.wifiChannel = wifiChannel
        self.wifiTxRate = wifiTxRate
    }
}

#endif
