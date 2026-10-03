#if os(macOS)
import Foundation
import SystemConfiguration
import Darwin
import Network

@Observable
@MainActor
public final class NetworkMediumDetector {
    public static let shared = NetworkMediumDetector()
    
    public private(set) var primaryAdapter: NetworkAdapterInfo?
    public private(set) var allAdapters: [NetworkAdapterInfo] = []
    public private(set) var isDetecting: Bool = false
    
    public var primaryMedium: NetworkMedium {
        primaryAdapter?.medium ?? .unknown
    }
    
    public var primaryInterfaceName: String {
        primaryAdapter?.bsdName ?? "en0"
    }
    
    public var defaultGateway: String {
        primaryAdapter?.gatewayAddress ?? "--"
    }
    
    public var isWiredEthernetActive: Bool {
        primaryAdapter?.medium == .wiredEthernet && primaryAdapter?.connectionState == .active
    }
    
    public var isWiFiActive: Bool {
        allAdapters.contains { $0.medium == .wifi && $0.connectionState == .active }
    }
    
    public var coexistingWiFiAdapter: NetworkAdapterInfo? {
        allAdapters.first { $0.medium == .wifi && $0.connectionState == .active }
    }
    
    public var coexistingEthernetAdapter: NetworkAdapterInfo? {
        allAdapters.first { $0.medium == .wiredEthernet && $0.connectionState == .active }
    }
    
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.networkutilities.mediumdetector", qos: .utility)
    
    public init() {
        startPathMonitoring()
        refresh()
    }
    
    public func refresh() {
        isDetecting = true
        Task.detached {
            let adapters = Self.detectAllAdaptersSync()
            let primary = adapters.first(where: { $0.isPrimary }) ?? adapters.first
            
            await MainActor.run {
                self.allAdapters = adapters
                self.primaryAdapter = primary
                self.isDetecting = false
            }
        }
    }
    
    private func startPathMonitoring() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        pathMonitor?.start(queue: monitorQueue)
    }
    
    // MARK: - Core Detection Logic (Nonisolated for Thread Safety)
    
    public nonisolated static func detectAllAdaptersSync() -> [NetworkAdapterInfo] {
        let (primaryName, defaultRouter) = resolvePrimaryInterface()
        let ipAndMacMap = queryAllInterfacesState()
        let scMetaMap = querySystemConfigurationInterfaces()
        let rfMetrics = RFTelemetryService.shared.fetchMetrics()
        
        var result: [NetworkAdapterInfo] = []
        var processedBsdNames = Set<String>()
        
        // 1. First process all interfaces identified by SystemConfiguration (Hardware adapters)
        for (bsdName, meta) in scMetaMap {
            processedBsdNames.insert(bsdName)
            let isPrimary = (bsdName == primaryName)
            let state = ipAndMacMap[bsdName]
            
            let medium: NetworkMedium
            if meta.interfaceType == "IEEE80211" {
                medium = .wifi
            } else if meta.interfaceType == "Ethernet" {
                medium = .wiredEthernet
            } else if meta.interfaceType == "Bridge" {
                medium = .thunderboltBridge
            } else {
                medium = classifyByBSDName(bsdName)
            }
            
            let media = queryEthernetMedia(interfaceName: bsdName)
            let connState = evaluateConnectionState(
                isUp: state?.isUp ?? false,
                isRunning: state?.isRunning ?? false,
                hasIP: state?.ipv4 != nil,
                mediaActive: media.isActive,
                medium: medium
            )
            
            let speedMbps: Double?
            let speedDesc: String
            let isFDX: Bool
            
            if medium == .wifi {
                speedMbps = rfMetrics.txRate > 0 ? rfMetrics.txRate : nil
                speedDesc = speedMbps != nil ? "\(Int(speedMbps!)) Mbps (Wi-Fi PHY)" : "Wi-Fi Negotiating"
                isFDX = false
            } else if medium == .wiredEthernet {
                speedMbps = media.speedMbps
                speedDesc = media.description
                isFDX = media.isFullDuplex
            } else {
                speedMbps = media.speedMbps
                speedDesc = media.description
                isFDX = media.isFullDuplex
            }
            
            let adapter = NetworkAdapterInfo(
                bsdName: bsdName,
                displayName: meta.displayName,
                medium: medium,
                connectionState: connState,
                isPrimary: isPrimary,
                macAddress: state?.mac ?? "00:00:00:00:00:00",
                mtu: state?.mtu ?? 1500,
                linkSpeedMbps: speedMbps,
                linkSpeedDescription: speedDesc,
                isFullDuplex: isFDX,
                ipv4Address: state?.ipv4,
                subnetMask: state?.mask,
                broadcastAddress: state?.broadcast,
                ipv6Address: state?.ipv6,
                gatewayAddress: isPrimary ? defaultRouter : nil,
                wifiSSID: medium == .wifi ? rfMetrics.ssid : nil,
                wifiBSSID: medium == .wifi ? (rfMetrics.bssid != "--" ? rfMetrics.bssid : nil) : nil,
                wifiRSSI: medium == .wifi ? rfMetrics.rssi : nil,
                wifiNoise: medium == .wifi ? rfMetrics.noise : nil,
                wifiSNR: medium == .wifi ? rfMetrics.snr : nil,
                wifiChannel: medium == .wifi ? rfMetrics.channel : nil,
                wifiTxRate: medium == .wifi ? rfMetrics.txRate : nil
            )
            result.append(adapter)
        }
        
        // 2. Add any active en* interfaces discovered in getifaddrs but not in SCNetworkInterface
        for (bsdName, state) in ipAndMacMap {
            guard !processedBsdNames.contains(bsdName) else { continue }
            guard bsdName.hasPrefix("en") || bsdName.hasPrefix("bridge") else { continue }
            
            let isPrimary = (bsdName == primaryName)
            let medium = classifyByBSDName(bsdName)
            let media = queryEthernetMedia(interfaceName: bsdName)
            let connState = evaluateConnectionState(
                isUp: state.isUp,
                isRunning: state.isRunning,
                hasIP: state.ipv4 != nil,
                mediaActive: media.isActive,
                medium: medium
            )
            
            let adapter = NetworkAdapterInfo(
                bsdName: bsdName,
                displayName: "\(medium.rawValue) (\(bsdName))",
                medium: medium,
                connectionState: connState,
                isPrimary: isPrimary,
                macAddress: state.mac,
                mtu: state.mtu,
                linkSpeedMbps: media.speedMbps,
                linkSpeedDescription: media.description,
                isFullDuplex: media.isFullDuplex,
                ipv4Address: state.ipv4,
                subnetMask: state.mask,
                broadcastAddress: state.broadcast,
                ipv6Address: state.ipv6,
                gatewayAddress: isPrimary ? defaultRouter : nil
            )
            result.append(adapter)
        }
        
        // 3. Fallback: If no adapter in result is marked primary (which occurs when the active
        // default route is a VPN tunnel such as utun* or non-hardware virtual interface),
        // fall back to marking the active physical adapter providing underlying LAN/Internet connectivity
        // as isPrimary = true.
        if !result.contains(where: { $0.isPrimary }) {
            let primaryIndex = result.firstIndex(where: {
                $0.connectionState == .active &&
                $0.ipv4Address != nil &&
                !($0.ipv4Address?.hasPrefix("169.254.") ?? false)
            }) ?? result.firstIndex(where: {
                $0.connectionState == .active && $0.ipv4Address != nil
            }) ?? result.firstIndex(where: {
                $0.connectionState == .active
            }) ?? result.indices.first
            
            if let idx = primaryIndex {
                let old = result[idx]
                result[idx] = NetworkAdapterInfo(
                    bsdName: old.bsdName,
                    displayName: old.displayName,
                    medium: old.medium,
                    connectionState: old.connectionState,
                    isPrimary: true,
                    macAddress: old.macAddress,
                    mtu: old.mtu,
                    linkSpeedMbps: old.linkSpeedMbps,
                    linkSpeedDescription: old.linkSpeedDescription,
                    isFullDuplex: old.isFullDuplex,
                    ipv4Address: old.ipv4Address,
                    subnetMask: old.subnetMask,
                    broadcastAddress: old.broadcastAddress,
                    ipv6Address: old.ipv6Address,
                    gatewayAddress: defaultRouter ?? old.gatewayAddress,
                    wifiSSID: old.wifiSSID,
                    wifiBSSID: old.wifiBSSID,
                    wifiRSSI: old.wifiRSSI,
                    wifiNoise: old.wifiNoise,
                    wifiSNR: old.wifiSNR,
                    wifiChannel: old.wifiChannel,
                    wifiTxRate: old.wifiTxRate
                )
            }
        }
        
        // Sort: Primary first, then active interfaces, then alphabetically
        return result.sorted {
            if $0.isPrimary != $1.isPrimary { return $0.isPrimary && !$1.isPrimary }
            if ($0.connectionState == .active) != ($1.connectionState == .active) {
                return $0.connectionState == .active
            }
            return $0.bsdName < $1.bsdName
        }
    }
    
    // MARK: - SystemConfiguration Helpers
    
    public nonisolated static func resolvePrimaryInterface() -> (name: String, router: String?) {
        guard let store = SCDynamicStoreCreate(nil, "NetworkMediumDetector" as CFString, nil, nil),
              let ipv4Dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any] else {
            // Fallback via /sbin/route
            let (routeIface, routeGw) = fallbackResolveRoute()
            return (routeIface ?? "en0", routeGw)
        }
        
        let primaryIface = ipv4Dict["PrimaryInterface"] as? String ?? "en0"
        let router = ipv4Dict["Router"] as? String
        return (primaryIface, router)
    }
    
    private nonisolated static func fallbackResolveRoute() -> (interface: String?, gateway: String?) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/sbin/route")
        proc.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return (nil, nil) }
        
        var iface: String? = nil
        var gw: String? = nil
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("interface:") {
                let parts = trimmed.split(separator: ":")
                if parts.count >= 2 { iface = parts[1].trimmingCharacters(in: .whitespaces) }
            } else if trimmed.hasPrefix("gateway:") {
                let parts = trimmed.split(separator: ":")
                if parts.count >= 2 { gw = parts[1].trimmingCharacters(in: .whitespaces) }
            }
        }
        return (iface, gw)
    }
    
    private nonisolated static func querySystemConfigurationInterfaces() -> [String: (displayName: String, interfaceType: String)] {
        var map: [String: (displayName: String, interfaceType: String)] = [:]
        guard let ifaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return map }
        
        for iface in ifaces {
            guard let bsd = SCNetworkInterfaceGetBSDName(iface) as String? else { continue }
            let disp = (SCNetworkInterfaceGetLocalizedDisplayName(iface) as String?) ?? bsd
            let type = (SCNetworkInterfaceGetInterfaceType(iface) as String?) ?? "Unknown"
            map[bsd] = (disp, type)
        }
        return map
    }
    
    // MARK: - BSD ioctl SIOCGIFMEDIA (Link Speed, Duplex, Carrier State)
    
    public nonisolated static func queryEthernetMedia(interfaceName: String) -> (
        isActive: Bool,
        isEthernet: Bool,
        speedMbps: Double?,
        description: String,
        isFullDuplex: Bool
    ) {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else {
            return (false, false, nil, "Unable to query socket", false)
        }
        defer { close(sock) }
        
        var ifmr = ifmediareq()
        withUnsafeMutableBytes(of: &ifmr.ifm_name) { ptr in
            _ = strncpy(ptr.baseAddress!.assumingMemoryBound(to: CChar.self), interfaceName, Int(IFNAMSIZ))
        }
        
        // SIOCGIFMEDIA = 0xc0286938
        let result = ioctl(sock, 0xc0286938, &ifmr)
        guard result == 0 else {
            return (false, false, nil, "Media query unsupported", false)
        }
        
        let isActive = (ifmr.ifm_status & 0x02) != 0 // IFM_ACTIVE
        let isEthernet = (ifmr.ifm_active & 0xe0) == 0x20 // IFM_ETHER
        let isFullDuplex = (ifmr.ifm_active & 0x00100000) != 0 // IFM_FDX
        
        guard isActive else {
            return (false, isEthernet, nil, "Cable Disconnected / Link Down", false)
        }
        
        let (speed, speedLabel) = decodeEthernetSpeed(activeMedia: UInt32(bitPattern: ifmr.ifm_active))
        let duplexStr = isFullDuplex ? "<Full-Duplex>" : "<Half-Duplex>"
        let fullDesc = "\(speedLabel) \(duplexStr)"
        
        return (true, isEthernet, speed, fullDesc, isFullDuplex)
    }

    public nonisolated static func decodeEthernetSpeed(activeMedia: UInt32) -> (speedMbps: Double?, label: String) {
        // In Darwin <net/if_media.h>, IFM_TMASK_COMPAT = 0x0000001f, IFM_TMASK_EXT = 0x000f0000 (shifted by 11)
        let subtype = Int((activeMedia & 0x1f) | ((activeMedia & 0x000f0000) >> 11))
        let speed: Double?
        let speedLabel: String
        
        switch subtype {
        case 3, 4, 5:
            speed = 10.0
            speedLabel = "10 Mbps"
        case 6, 7, 8, 9, 10, 24:
            speed = 100.0
            speedLabel = "100 Mbps (100baseTX)"
        case 11, 13, 14, 16, 25:
            speed = 1000.0
            speedLabel = "1.0 Gbps (1000baseT)"
        case 22, 26:
            speed = 2500.0
            speedLabel = "2.5 Gbps (2.5GbaseT)"
        case 23, 27:
            speed = 5000.0
            speedLabel = "5.0 Gbps (5GbaseT)"
        case 18, 19, 20, 21, 28:
            speed = 10000.0
            speedLabel = "10 Gbps (10GbaseT)"
        case 29, 30:
            speed = 25000.0
            speedLabel = "25 Gbps"
        case 31, 32, 33, 37, 38, 44, 45, 72, 73, 74:
            speed = 40000.0
            speedLabel = "40 Gbps"
        case 34, 35, 36, 47, 48, 49, 50, 89, 90, 91, 92:
            speed = 100000.0
            speedLabel = "100 Gbps"
        default:
            speed = nil
            speedLabel = "Auto-negotiated Link"
        }
        return (speed, speedLabel)
    }
    
    // MARK: - getifaddrs Parser (MAC, MTU, IPv4, Subnet, IPv6)
    
    private struct InterfaceState {
        var mac: String = "00:00:00:00:00:00"
        var mtu: Int = 1500
        var isUp: Bool = false
        var isRunning: Bool = false
        var ipv4: String? = nil
        var mask: String? = nil
        var broadcast: String? = nil
        var ipv6: String? = nil
    }
    
    private nonisolated static func queryAllInterfacesState() -> [String: InterfaceState] {
        var map: [String: InterfaceState] = [:]
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return map }
        defer { freeifaddrs(firstAddr) }
        
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ifa = ptr?.pointee {
            defer { ptr = ifa.ifa_next }
            let name = String(cString: ifa.ifa_name)
            guard !name.isEmpty, let addr = ifa.ifa_addr else { continue }
            
            var state = map[name] ?? InterfaceState()
            state.isUp = (ifa.ifa_flags & UInt32(IFF_UP)) != 0
            state.isRunning = (ifa.ifa_flags & UInt32(IFF_RUNNING)) != 0
            
            let family = addr.pointee.sa_family
            
            if family == UInt8(AF_LINK) {
                let sdl = addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
                let nlen = Int(sdl.sdl_nlen)
                let alen = Int(sdl.sdl_alen)
                if alen == 6 {
                    var macBytes = [UInt8](repeating: 0, count: 6)
                    withUnsafePointer(to: sdl.sdl_data) { rawPtr in
                        let p = UnsafeRawPointer(rawPtr).advanced(by: nlen)
                        for i in 0..<6 {
                            macBytes[i] = p.load(fromByteOffset: i, as: UInt8.self)
                        }
                    }
                    state.mac = macBytes.map { String(format: "%02X", $0) }.joined(separator: ":")
                }
                if let dataPtr = ifa.ifa_data {
                    state.mtu = Int(dataPtr.assumingMemoryBound(to: if_data.self).pointee.ifi_mtu)
                }
            } else if family == UInt8(AF_INET) {
                var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ipStr = String(cString: hostBuf)
                    if ipStr != "127.0.0.1" {
                        state.ipv4 = ipStr
                    }
                }
                if let netmask = ifa.ifa_netmask {
                    var maskBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(netmask, socklen_t(netmask.pointee.sa_len), &maskBuf, socklen_t(maskBuf.count), nil, 0, NI_NUMERICHOST) == 0 {
                        state.mask = String(cString: maskBuf)
                    }
                }
                if let dstaddr = ifa.ifa_dstaddr {
                    var bcastBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(dstaddr, socklen_t(dstaddr.pointee.sa_len), &bcastBuf, socklen_t(bcastBuf.count), nil, 0, NI_NUMERICHOST) == 0 {
                        state.broadcast = String(cString: bcastBuf)
                    }
                }
            } else if family == UInt8(AF_INET6) {
                var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip6Str = String(cString: hostBuf)
                    if !ip6Str.hasPrefix("fe80") || state.ipv6 == nil {
                        state.ipv6 = ip6Str
                    }
                }
            }
            
            map[name] = state
        }
        
        return map
    }
    
    // MARK: - Evaluation Helpers
    
    private nonisolated static func evaluateConnectionState(
        isUp: Bool,
        isRunning: Bool,
        hasIP: Bool,
        mediaActive: Bool,
        medium: NetworkMedium
    ) -> NetworkConnectionState {
        if !isUp {
            return .disabled
        }
        if medium == .wiredEthernet && !mediaActive {
            return .cableDisconnected
        }
        if isRunning && hasIP {
            return .active
        }
        if isRunning && !hasIP {
            return .linkUpNoIP
        }
        return .disconnected
    }
    
    private nonisolated static func classifyByBSDName(_ name: String) -> NetworkMedium {
        if name.hasPrefix("bridge") { return .thunderboltBridge }
        if name.hasPrefix("pdp_ip") { return .cellular }
        if name.hasPrefix("en") { return .wiredEthernet }
        return .unknown
    }
}

// Typealias for architecture consistency
public typealias NetworkMonitor = NetworkMediumDetector

#endif
