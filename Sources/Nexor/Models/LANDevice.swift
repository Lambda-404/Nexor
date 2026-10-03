#if os(macOS)
import Foundation

public enum DeviceCategory: String, CaseIterable, Sendable, Identifiable {
    case gateway = "Gateway & Routing"
    case apple = "Apple Devices"
    case smartIoT = "Smart Home & IoT"
    case computers = "Computers & Workstations"
    case gaming = "Gaming Consoles"
    case unknown = "Other Devices"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .gateway: return "wifi.router"
        case .apple: return "applelogo"
        case .smartIoT: return "homekit"
        case .computers: return "desktopcomputer"
        case .gaming: return "gamecontroller"
        case .unknown: return "network"
        }
    }
}

public struct LANDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public var ipAddress: String
    public var ipv6Address: String?
    public var macAddress: String
    public var hostname: String
    public var vendor: String
    public var protocolType: String // ARP, NDP, DHCP, mDNS, SSDP, NBNS, SWEEP
    public var modelName: String?
    public var appleModelID: String?
    public var netbiosWorkgroup: String?
    public var osInference: String?
    public var openPorts: [Int] = []
    public var services: [String] = []
    public var latencyMS: Double? = nil
    public var isOnline: Bool = true
    public var rawPacketDump: String?
    public var lastSeen: Date
    
    public init(
        ipAddress: String,
        ipv6Address: String? = nil,
        macAddress: String,
        hostname: String,
        vendor: String? = nil,
        protocolType: String = "ARP",
        modelName: String? = nil,
        appleModelID: String? = nil,
        netbiosWorkgroup: String? = nil,
        osInference: String? = nil,
        openPorts: [Int] = [],
        services: [String] = [],
        latencyMS: Double? = nil,
        isOnline: Bool = true,
        rawPacketDump: String? = nil,
        lastSeen: Date = Date()
    ) {
        let upperMAC = macAddress.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !upperMAC.isEmpty && upperMAC != "00:00:00:00:00:00" && upperMAC != "02:00:00:00:00:00" {
            self.id = upperMAC
        } else if !ipAddress.isEmpty {
            self.id = "IP-\(ipAddress)"
        } else if let v6 = ipv6Address, !v6.isEmpty {
            self.id = "IP6-\(v6)"
        } else {
            self.id = "DEV-\(UUID().uuidString)"
        }
        self.ipAddress = ipAddress
        self.ipv6Address = ipv6Address
        self.macAddress = upperMAC
        self.hostname = hostname
        self.protocolType = protocolType
        self.appleModelID = appleModelID
        self.netbiosWorkgroup = netbiosWorkgroup
        self.osInference = osInference
        self.openPorts = openPorts
        self.services = services
        self.latencyMS = latencyMS
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        
        let detectedVendor = vendor ?? OUIDatabase.vendor(for: macAddress)
        self.vendor = detectedVendor
        
        // If Apple Model ID is provided, look up commercial name
        if let modelID = appleModelID, let translated = AppleModelDatabase.lookup(modelID: modelID) {
            self.modelName = translated
        } else {
            self.modelName = modelName
        }
        
        self.rawPacketDump = rawPacketDump
    }
    
    /// Checks if the IEEE 802 Locally Administered bit is set (bit 1 of octet 0)
    public var isRandomizedMAC: Bool {
        let components = macAddress.split(separator: ":")
        guard let firstOctetStr = components.first,
              let firstOctet = UInt8(firstOctetStr, radix: 16) else { return false }
        return (firstOctet & 0b00000010) != 0
    }
    
    public var category: DeviceCategory {
        let hostLower = hostname.lowercased()
        let vendorLower = vendor.lowercased()
        
        if hostLower.contains("router") || hostLower.contains("gateway") || ipAddress.hasSuffix(".1") {
            return .gateway
        } else if vendorLower.contains("apple") || hostLower.contains("macbook") || hostLower.contains("iphone") || hostLower.contains("ipad") || appleModelID != nil {
            return .apple
        } else if vendorLower.contains("nintendo") || vendorLower.contains("playstation") || vendorLower.contains("xbox") || hostLower.contains("switch") {
            return .gaming
        } else if hostLower.contains("printer") || hostLower.contains("tv") || hostLower.contains("nas") || vendorLower.contains("xiaomi") || vendorLower.contains("tp-link") || vendorLower.contains("espressif") || vendorLower.contains("sonos") {
            return .smartIoT
        } else if vendorLower.contains("intel") || hostLower.contains("pc") || hostLower.contains("desktop") || hostLower.contains("server") || vendorLower.contains("dell") || vendorLower.contains("lenovo") || netbiosWorkgroup != nil {
            return .computers
        } else {
            return .unknown
        }
    }
}

#endif
