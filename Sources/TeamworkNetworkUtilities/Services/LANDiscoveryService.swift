import Foundation
import Network
import SystemConfiguration

@Observable
public final class LANDiscoveryService: @unchecked Sendable {
    public static let shared = LANDiscoveryService()
    
    public private(set) var devices: [LANDevice] = []
    public private(set) var isListening: Bool = false
    public private(set) var isSweeping: Bool = false
    public private(set) var sweepProgress: Double = 0.0
    public private(set) var capturedPacketCount: Int = 0
    public private(set) var lastUpdated: Date = Date()
    
    private var timer: Timer?
    private var browsers: [NWBrowser] = []
    private let discoveryQueue = DispatchQueue(label: "com.networkutilities.discovery", qos: .userInitiated)
    private var activeResolvingConnections: [NWConnection] = []
    
    public init() {
        // Pure real-world live LAN discovery; no mock or seed devices
    }
    
    public func startListening() {
        guard !isListening else { return }
        isListening = true
        
        harvestLocalDevice()
        harvestSystemNDPCache()
        harvestSystemARPCache()
        startAppleAndBonjourDiscovery()
        
        if devices.count <= 1 && !isSweeping {
            triggerSubnetSweep()
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.harvestLocalDevice()
                self?.harvestSystemNDPCache()
                self?.harvestSystemARPCache()
            }
        }
    }
    
    public func stopListening() {
        isListening = false
        timer?.invalidate()
        timer = nil
        for browser in browsers {
            browser.cancel()
        }
        browsers.removeAll()
        for conn in activeResolvingConnections {
            conn.cancel()
        }
        activeResolvingConnections.removeAll()
    }
    
    // MARK: - Multi-Subnet Detection
    
    public struct ActiveSubnet: Sendable {
        public let interface: String
        public let localIP: String
        public let broadcast: String
        public let subnetPrefix: String
    }
    
    public func resolveAllActiveSubnets() -> [ActiveSubnet] {
        var subnets: [ActiveSubnet] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return subnets }
        defer { freeifaddrs(first) }
        
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = ptr?.pointee {
            defer { ptr = ifa.ifa_next }
            guard let addr = ifa.ifa_addr else { continue }
            if addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: ifa.ifa_name)
                let flags = ifa.ifa_flags
                // Must be UP and RUNNING, and NOT loopback
                if (flags & UInt32(IFF_UP | IFF_RUNNING)) == UInt32(IFF_UP | IFF_RUNNING) &&
                   (flags & UInt32(IFF_LOOPBACK)) == 0 {
                    var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NUMERICHOST)
                    let ip = String(cString: hostBuf)
                    if !ip.isEmpty && ip != "127.0.0.1" && !ip.starts(with: "169.254") {
                        var bcast = ""
                        if let dst = ifa.ifa_dstaddr {
                            var bcastBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            getnameinfo(dst, socklen_t(dst.pointee.sa_len), &bcastBuf, socklen_t(bcastBuf.count), nil, 0, NI_NUMERICHOST)
                            bcast = String(cString: bcastBuf)
                        }
                        let parts = ip.split(separator: ".")
                        if parts.count == 4 {
                            let prefix = "\(parts[0]).\(parts[1]).\(parts[2])."
                            if bcast.isEmpty { bcast = "\(prefix)255" }
                            subnets.append(ActiveSubnet(interface: name, localIP: ip, broadcast: bcast, subnetPrefix: prefix))
                        }
                    }
                }
            }
        }
        return subnets
    }
    
    public func resolveLocalPhysicalNetwork() -> (interface: String, ip: String, broadcast: String, subnetPrefix: String) {
        let allSubnets = resolveAllActiveSubnets()
        let (primaryIface, _) = NetworkMediumDetector.resolvePrimaryInterface()
        if let primary = allSubnets.first(where: { $0.interface == primaryIface }) {
            return (primary.interface, primary.localIP, primary.broadcast, primary.subnetPrefix)
        }
        if let first = allSubnets.first {
            return (first.interface, first.localIP, first.broadcast, first.subnetPrefix)
        }
        return ("en0", "192.168.1.100", "192.168.1.255", "192.168.1.")
    }
    
    // MARK: - Fast High-Concurrency Subnet Sweep
    
    public func triggerSubnetSweep() {
        guard !isSweeping else { return }
        isSweeping = true
        sweepProgress = 0.0
        
        let allSubnets = resolveAllActiveSubnets()
        guard !allSubnets.isEmpty else {
            isSweeping = false
            return
        }
        
        let defaultGateway = resolveDefaultGateway()
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let totalSubnets = allSubnets.count
            var completedSubnets = 0
            
            for subnet in allSubnets {
                // Phase 1: Fast broadcast burst to awaken idle neighbors
                let bcastProcess = Process()
                bcastProcess.executableURL = URL(fileURLWithPath: "/sbin/ping")
                bcastProcess.arguments = ["-c", "2", "-t", "1", subnet.broadcast]
                try? bcastProcess.run()
                bcastProcess.waitUntilExit()
                
                // Immediate harvest of NDP / ARP caches
                self.harvestSystemNDPCache()
                self.harvestSystemARPCache()
                
                // Phase 2: High-concurrency sweep across all 1..254 hosts
                let totalHosts = 254
                var completedHosts = 0
                let maxConcurrent = 48
                var currentHost = 1
                
                await withTaskGroup(of: (String, Double?).self) { group in
                    // Initial batch of probes
                    while currentHost <= min(maxConcurrent, totalHosts) {
                        let targetIP = "\(subnet.subnetPrefix)\(currentHost)"
                        group.addTask {
                            let process = Process()
                            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
                            process.arguments = ["-c", "1", "-W", "250", "-t", "1", targetIP]
                            let pipe = Pipe()
                            process.standardOutput = pipe
                            try? process.run()
                            let data = pipe.fileHandleForReading.readDataToEndOfFile()
                            process.waitUntilExit()
                            
                            var latency: Double? = nil
                            if process.terminationStatus == 0 {
                                if let outStr = String(data: data, encoding: .utf8),
                                   let timeRange = outStr.range(of: "time=") {
                                    let sub = outStr[timeRange.upperBound...]
                                    if let endRange = sub.range(of: " ms") {
                                        latency = Double(sub[..<endRange.lowerBound].trimmingCharacters(in: .whitespaces))
                                    }
                                }
                                if latency == nil { latency = 1.0 }
                            }
                            return (targetIP, latency)
                        }
                        currentHost += 1
                    }
                    
                    // Replenish group as probes complete
                    for await (ip, latency) in group {
                        completedHosts += 1
                        let subnetFraction = Double(completedHosts) / Double(totalHosts)
                        let overallProgress = (Double(completedSubnets) + subnetFraction) / Double(totalSubnets)
                        
                        await MainActor.run {
                            self.sweepProgress = overallProgress
                        }
                        
                        if let lat = latency {
                            await MainActor.run {
                                self.handleDiscoveredHost(
                                    ip: ip,
                                    latency: lat,
                                    interface: subnet.interface,
                                    defaultGateway: defaultGateway
                                )
                            }
                        }
                        
                        if currentHost <= totalHosts {
                            let targetIP = "\(subnet.subnetPrefix)\(currentHost)"
                            group.addTask {
                                let process = Process()
                                process.executableURL = URL(fileURLWithPath: "/sbin/ping")
                                process.arguments = ["-c", "1", "-W", "250", "-t", "1", targetIP]
                                let pipe = Pipe()
                                process.standardOutput = pipe
                                try? process.run()
                                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                                process.waitUntilExit()
                                
                                var latency: Double? = nil
                                if process.terminationStatus == 0 {
                                    if let outStr = String(data: data, encoding: .utf8),
                                       let timeRange = outStr.range(of: "time=") {
                                        let sub = outStr[timeRange.upperBound...]
                                        if let endRange = sub.range(of: " ms") {
                                            latency = Double(sub[..<endRange.lowerBound].trimmingCharacters(in: .whitespaces))
                                        }
                                    }
                                    if latency == nil { latency = 1.0 }
                                }
                                return (targetIP, latency)
                            }
                            currentHost += 1
                        }
                    }
                }
                
                completedSubnets += 1
            }
            
            // Immediate dual-stack harvest after all sweeps complete
            self.harvestSystemNDPCache()
            self.harvestSystemARPCache()
            
            let allIPs = await MainActor.run {
                self.devices.map { $0.ipAddress }.filter { !$0.isEmpty }
            }
            self.resolveHostnamesAsync(for: allIPs)
            
            await MainActor.run {
                self.isSweeping = false
                self.sweepProgress = 1.0
                self.lastUpdated = Date()
            }
        }
    }
    
    @MainActor
    private func handleDiscoveredHost(ip: String, latency: Double, interface: String, defaultGateway: String?) {
        let isLocal = (ip == resolveLocalIP())
        let isGateway = (defaultGateway != nil && ip == defaultGateway) || (defaultGateway == nil && ip.hasSuffix(".1"))
        
        // Find existing device by IP or MAC
        if let idx = devices.firstIndex(where: { $0.ipAddress == ip }) {
            devices[idx].latencyMS = latency
            devices[idx].isOnline = true
            devices[idx].lastSeen = Date()
        } else {
            // New discovered host on the LAN!
            let hostname = isGateway ? "Gateway Router" : "Host-\(ip.replacingOccurrences(of: ".", with: "-"))"
            let modelName = isGateway ? "Primary Network Gateway" : nil
            let vendor = isGateway ? "Gateway / Router" : "Network Device"
            
            let newDev = LANDevice(
                ipAddress: ip,
                macAddress: "00:00:00:00:00:00",
                hostname: hostname,
                vendor: vendor,
                protocolType: isLocal ? "LOCAL" : "ICMP",
                modelName: modelName,
                latencyMS: latency,
                isOnline: true,
                lastSeen: Date()
            )
            upsertDevice(newDev)
            capturedPacketCount += 1
            lastUpdated = Date()
            
            // Immediately kick off reverse DNS resolution
            resolveHostnamesAsync(for: [ip])
        }
    }
    
    // MARK: - NDP (Neighbor Discovery Protocol) Harvester (IPv6 & Real MACs)
    
    public func harvestSystemNDPCache() {
        discoveryQueue.async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/ndp")
            process.arguments = ["-an"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                if let output = String(data: data, encoding: .utf8) {
                    self.parseNDPOutput(output)
                }
            } catch {}
        }
    }
    
    private func parseNDPOutput(_ output: String) {
        // Sample line: fe80::1%en0 24:46:e4:c2:87:d8 en0 23h59m50s S R
        let lines = output.components(separatedBy: .newlines)
        var harvestedNDP: [(ipv6: String, mac: String, iface: String)] = []
        
        for line in lines {
            let parts = line.split(separator: " ").filter { !$0.isEmpty }
            guard parts.count >= 3 else { continue }
            
            let ipv6Raw = String(parts[0])
            guard ipv6Raw.contains(":") else { continue }
            let ipv6 = ipv6Raw.components(separatedBy: "%").first ?? ipv6Raw
            
            let rawMAC = String(parts[1])
            guard rawMAC.contains(":") && !rawMAC.contains("(incomplete)") else { continue }
            
            let iface = String(parts[2])
            
            let formattedMAC = rawMAC.split(separator: ":").map { part in
                part.count == 1 ? "0" + part : String(part)
            }.joined(separator: ":").uppercased()
            
            guard formattedMAC != "FF:FF:FF:FF:FF:FF" && formattedMAC != "00:00:00:00:00:00" &&
                  !formattedMAC.starts(with: "01:00:5E") && !formattedMAC.starts(with: "33:33:") else { continue }
            
            harvestedNDP.append((ipv6, formattedMAC, iface))
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for item in harvestedNDP {
                // If device with this MAC already exists, associate IPv6
                if let idx = self.devices.firstIndex(where: { $0.macAddress == item.mac }) {
                    if self.devices[idx].ipv6Address == nil {
                        self.devices[idx].ipv6Address = item.ipv6
                    }
                    self.devices[idx].isOnline = true
                } else {
                    // Check if an existing host has matching IPv6
                    if let idx = self.devices.firstIndex(where: { $0.ipv6Address == item.ipv6 }) {
                        self.devices[idx].macAddress = item.mac
                        self.devices[idx].vendor = OUIDatabase.vendor(for: item.mac)
                    } else {
                        // Create new device discovered via IPv6 Neighbor Discovery
                        let vendor = OUIDatabase.vendor(for: item.mac)
                        let isGateway = item.ipv6.hasPrefix("fe80::1") || item.ipv6 == "fe80::1"
                        let hostname = isGateway ? "Gateway Router" : "Host-\(item.mac.replacingOccurrences(of: ":", with: "-"))"
                        
                        let dev = LANDevice(
                            ipAddress: "",
                            ipv6Address: item.ipv6,
                            macAddress: item.mac,
                            hostname: hostname,
                            vendor: vendor != "Unknown Vendor" ? vendor : "Network Device",
                            protocolType: "NDP",
                            modelName: isGateway ? "Network Gateway" : nil,
                            isOnline: true,
                            lastSeen: Date()
                        )
                        self.upsertDevice(dev)
                    }
                }
            }
            self.lastUpdated = Date()
        }
    }
    
    // MARK: - ARP Cache Harvester (IPv4)
    
    public func harvestSystemARPCache() {
        discoveryQueue.async { [weak self] in
            guard let self = self else { return }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
            process.arguments = ["-an"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    self.parseARPOutput(output)
                }
            } catch {}
        }
    }
    
    private func parseARPOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        var newHarvested: [LANDevice] = []
        let defaultGateway = resolveDefaultGateway()
        
        for line in lines {
            guard line.contains(" at ") && line.contains(" on ") else { continue }
            
            guard let ipStart = line.firstIndex(of: "("),
                  let ipEnd = line.firstIndex(of: ")"),
                  ipStart < ipEnd else { continue }
            let ip = String(line[line.index(after: ipStart)..<ipEnd])
            
            // Filter broadcast / multicast / link-local addresses
            guard !ip.hasSuffix(".255") && !ip.starts(with: "224.") && !ip.starts(with: "239.") && !ip.starts(with: "169.254.") else { continue }
            
            let components = line.components(separatedBy: " at ")
            guard components.count >= 2 else { continue }
            let rightPart = components[1]
            let macParts = rightPart.components(separatedBy: " on ")
            guard let rawMAC = macParts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawMAC.contains("(incomplete)"),
                  rawMAC.contains(":") else { continue }
            
            let formattedMAC = rawMAC.split(separator: ":").map { part in
                part.count == 1 ? "0" + part : String(part)
            }.joined(separator: ":").uppercased()
            
            guard formattedMAC != "FF:FF:FF:FF:FF:FF" && formattedMAC != "00:00:00:00:00:00" &&
                  !formattedMAC.starts(with: "01:00:5E") && !formattedMAC.starts(with: "33:33:") else { continue }
            
            let isGateway = (defaultGateway != nil && ip == defaultGateway) || (defaultGateway == nil && ip.hasSuffix(".1"))
            let vendor = OUIDatabase.vendor(for: formattedMAC)
            let hostname = isGateway ? "Gateway Router" : "Host-\(ip.replacingOccurrences(of: ".", with: "-"))"
            let modelName = isGateway ? "Primary Network Gateway" : nil
            
            let device = LANDevice(
                ipAddress: ip,
                macAddress: formattedMAC,
                hostname: hostname,
                vendor: vendor,
                protocolType: "ARP",
                modelName: modelName,
                isOnline: true,
                lastSeen: Date()
            )
            newHarvested.append(device)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for dev in newHarvested {
                self.upsertDevice(dev)
            }
            self.capturedPacketCount += newHarvested.count
            self.lastUpdated = Date()
            
            let ips = newHarvested.map { $0.ipAddress }
            if !ips.isEmpty {
                self.resolveHostnamesAsync(for: ips)
            }
        }
    }
    
    // MARK: - Apple Ecosystem & Multi-Service Bonjour Discovery
    
    private func startAppleAndBonjourDiscovery() {
        let serviceTypes = [
            "_companion-link._tcp",  // Apple Continuity, Sidecar, AirDrop Link
            "_airdrop._tcp",         // Apple AirDrop
            "_airplay._tcp",         // Apple AirPlay Video
            "_raop._tcp",            // Apple AirPlay Audio
            "_sleep-proxy._udp",     // Apple Bonjour Sleep Proxy
            "_http._tcp",            // Web Services / Router UI
            "_smb._tcp",             // SMB File sharing (Windows / NAS)
            "_printer._tcp",         // Network Printers
            "_googlecast._tcp",      // Google Cast / Nest
            "_ssh._tcp"              // SSH Terminal Servers
        ]
        
        for st in serviceTypes {
            let descriptor = NWBrowser.Descriptor.bonjour(type: st, domain: nil)
            let parameters = NWParameters()
            let browser = NWBrowser(for: descriptor, using: parameters)
            
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                guard let self = self else { return }
                for result in results {
                    if case let .service(name, type, _, _) = result.endpoint {
                        self.resolveBonjourEndpoint(endpoint: result.endpoint, name: name, type: type)
                    }
                }
            }
            
            browser.start(queue: discoveryQueue)
            browsers.append(browser)
        }
    }
    
    private func resolveBonjourEndpoint(endpoint: NWEndpoint, name: String, type: String) {
        let conn = NWConnection(to: endpoint, using: .tcp)
        
        discoveryQueue.async { [weak self] in
            guard let self = self else { return }
            self.activeResolvingConnections.append(conn)
        }
        
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self = self, let conn = conn else { return }
            if case .ready = state {
                var resolvedIP: String? = nil
                if let remote = conn.currentPath?.remoteEndpoint,
                   case let .hostPort(host, _) = remote {
                    switch host {
                    case .ipv4(let v4):
                        resolvedIP = "\(v4)"
                    case .ipv6(let v6):
                        resolvedIP = "\(v6)"
                    default:
                        break
                    }
                }
                
                DispatchQueue.main.async {
                    self.associateBonjourService(name: name, type: type, remoteIP: resolvedIP)
                }
                conn.cancel()
            } else if case .failed = state {
                DispatchQueue.main.async {
                    self.associateBonjourService(name: name, type: type, remoteIP: nil)
                }
                conn.cancel()
            }
        }
        conn.start(queue: discoveryQueue)
    }
    
    private func associateBonjourService(name: String, type: String, remoteIP: String?) {
        let cleanType = type.replacingOccurrences(of: "._tcp", with: "").replacingOccurrences(of: "._udp", with: "").replacingOccurrences(of: "_", with: "").uppercased()
        let localHostName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        let isLocalMac = name.localizedCaseInsensitiveContains(localHostName)
        
        // Match existing device by resolved remote IP or exact hostname
        let matchedIdx = devices.firstIndex(where: {
            if let ip = remoteIP, !ip.isEmpty && ($0.ipAddress == ip || $0.ipv6Address == ip) {
                return true
            }
            return $0.hostname.localizedCaseInsensitiveCompare(name) == .orderedSame ||
                   (!name.isEmpty && $0.hostname.localizedCaseInsensitiveContains(name))
        })
        
        if let idx = matchedIdx {
            if devices[idx].hostname.starts(with: "Host-") {
                devices[idx].hostname = name
            }
            if !devices[idx].services.contains(cleanType) {
                devices[idx].services.append(cleanType)
            }
            devices[idx].protocolType = "mDNS"
            applyAppleModelRecognition(name: name, idx: idx)
        } else if !isLocalMac {
            // Distinct new network host discovered via Bonjour
            let isApple = name.contains("MacBook") || name.contains("iPhone") || name.contains("iPad") || name.contains("Apple") || name.contains("HomePod") || name.contains("AirPort")
            var modelName: String? = nil
            var appleModelID: String? = nil
            for id in ["MacBookPro", "MacBookAir", "MacBook", "iPhone", "iPad", "AppleTV", "AudioAccessory"] {
                if name.contains(id) {
                    appleModelID = id
                    modelName = AppleModelDatabase.lookup(modelID: id) ?? "Apple Device"
                    break
                }
            }
            
            let dev = LANDevice(
                ipAddress: remoteIP ?? "",
                macAddress: "00:00:00:00:00:00",
                hostname: name,
                vendor: isApple ? "Apple Inc." : "Bonjour Device",
                protocolType: "mDNS",
                modelName: modelName,
                appleModelID: appleModelID,
                services: [cleanType],
                isOnline: true,
                lastSeen: Date()
            )
            upsertDevice(dev)
        }
    }
    
    private func applyAppleModelRecognition(name: String, idx: Int) {
        for modelID in ["MacBookPro18,1", "Mac14,2", "Mac15,3", "iPhone15,2", "iPhone16,1", "iPad13,8", "AudioAccessory5,1"] {
            if name.contains(modelID) || devices[idx].rawPacketDump?.contains(modelID) ?? false {
                devices[idx].appleModelID = modelID
                if let trans = AppleModelDatabase.lookup(modelID: modelID) {
                    devices[idx].modelName = trans
                }
            }
        }
    }
    
    // MARK: - NetBIOS / SMB Name Probe
    
    public func probeNetBIOS(ip: String) async -> (server: String?, workgroup: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/smbutil")
        process.arguments = ["status", ip]
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if let output = String(data: data, encoding: .utf8) {
                var server: String?
                var workgroup: String?
                for line in output.components(separatedBy: .newlines) {
                    if line.contains("Server:") {
                        server = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if line.contains("Workgroup:") {
                        workgroup = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                return (server, workgroup)
            }
        } catch {
            return (nil, nil)
        }
        return (nil, nil)
    }
    
    // MARK: - Single Device Latency & OS Inference via TTL
    
    public func probeDeviceLatency(ip: String) async -> (latency: Double?, os: String?) {
        guard !ip.isEmpty else { return (nil, nil) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "-W", "1000", ip]
        let pipe = Pipe()
        process.standardOutput = pipe
        
        var latency: Double?
        var os: String?
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            if let output = String(data: data, encoding: .utf8) {
                if let ttlLine = output.components(separatedBy: .newlines).first(where: { $0.contains("ttl=") || $0.contains("TTL=") }) {
                    if let ttlStr = ttlLine.components(separatedBy: "ttl=").last?.components(separatedBy: " ").first,
                       let ttl = Int(ttlStr) {
                        if ttl <= 64 {
                            os = "macOS / iOS / Linux (TTL \(ttl))"
                        } else if ttl <= 128 {
                            os = "Microsoft Windows (TTL \(ttl))"
                        } else {
                            os = "Cisco / Network Appliance (TTL \(ttl))"
                        }
                    }
                }
                
                if let rttLine = output.components(separatedBy: .newlines).first(where: { $0.contains("round-trip") || $0.contains("rtt") }) {
                    let parts = rttLine.split(separator: "=")
                    if parts.count >= 2 {
                        let values = parts[1].split(separator: "/")
                        if values.count >= 2, let avg = Double(values[1].trimmingCharacters(in: .whitespaces)) {
                            latency = avg
                        }
                    }
                }
            }
        } catch {
            return (nil, nil)
        }
        return (latency, os)
    }
    
    public func probeOpenPorts(ip: String, ports: [Int] = [22, 53, 80, 443, 445, 8080, 9100]) async -> [Int] {
        guard !ip.isEmpty else { return [] }
        var open: [Int] = []
        for port in ports {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
            process.arguments = ["-zv", "-G", "1", ip, "\(port)"]
            let pipe = Pipe()
            process.standardOutput = pipe
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    open.append(port)
                }
            } catch {
                continue
            }
        }
        return open
    }
    
    // MARK: - Export Utilities
    
    public func exportAsJSON() -> String {
        let exportable = devices.map { [
            "ip": $0.ipAddress,
            "ipv6": $0.ipv6Address ?? "",
            "mac": $0.macAddress,
            "hostname": $0.hostname,
            "vendor": $0.vendor,
            "category": $0.category.rawValue,
            "model": $0.modelName ?? "",
            "appleModelID": $0.appleModelID ?? "",
            "osInference": $0.osInference ?? "",
            "workgroup": $0.netbiosWorkgroup ?? "",
            "isRandomizedMAC": $0.isRandomizedMAC,
            "protocol": $0.protocolType,
            "services": $0.services.joined(separator: ", "),
            "lastSeen": $0.lastSeen.ISO8601Format()
        ] }
        if let data = try? JSONSerialization.data(withJSONObject: exportable, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }
    
    public func exportAsCSV() -> String {
        var csv = "IPv4 Address,IPv6 Address,MAC Address,Hostname,Vendor,Category,Model,Apple Model ID,OS Inference,NetBIOS Workgroup,Randomized MAC,Protocol,Services\n"
        for d in devices {
            csv += "\"\(d.ipAddress)\",\"\(d.ipv6Address ?? "")\",\"\(d.macAddress)\",\"\(d.hostname)\",\"\(d.vendor)\",\"\(d.category.rawValue)\",\"\(d.modelName ?? "")\",\"\(d.appleModelID ?? "")\",\"\(d.osInference ?? "")\",\"\(d.netbiosWorkgroup ?? "")\",\"\(d.isRandomizedMAC)\",\"\(d.protocolType)\",\"\(d.services.joined(separator: "; "))\"\n"
        }
        return csv
    }
    
    // MARK: - Internal Helpers
    
    private func upsertDevice(_ device: LANDevice) {
        let upperMAC = device.macAddress.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let hasValidMAC = !upperMAC.isEmpty && upperMAC != "00:00:00:00:00:00" && upperMAC != "02:00:00:00:00:00"
        
        let idx = devices.firstIndex(where: {
            if hasValidMAC && $0.macAddress == upperMAC {
                return true
            }
            if !device.ipAddress.isEmpty && $0.ipAddress == device.ipAddress {
                return true
            }
            if let v6 = device.ipv6Address, !v6.isEmpty && $0.ipv6Address == v6 {
                return true
            }
            if !device.hostname.starts(with: "Host-") && !device.hostname.isEmpty &&
               $0.hostname.localizedCaseInsensitiveCompare(device.hostname) == .orderedSame {
                return true
            }
            return false
        })
        
        if let i = idx {
            devices[i].lastSeen = device.lastSeen
            devices[i].isOnline = true
            
            if !device.ipAddress.isEmpty && devices[i].ipAddress.isEmpty {
                devices[i].ipAddress = device.ipAddress
            }
            if let v6 = device.ipv6Address, devices[i].ipv6Address == nil {
                devices[i].ipv6Address = v6
            }
            if hasValidMAC && (devices[i].macAddress == "00:00:00:00:00:00" || devices[i].macAddress.isEmpty || devices[i].macAddress == "02:00:00:00:00:00") {
                devices[i].macAddress = upperMAC
                devices[i].vendor = device.vendor
            }
            if let lat = device.latencyMS {
                devices[i].latencyMS = lat
            }
            if devices[i].hostname.starts(with: "Host-") && !device.hostname.starts(with: "Host-") {
                devices[i].hostname = device.hostname
            }
            if devices[i].modelName == nil && device.modelName != nil {
                devices[i].modelName = device.modelName
            }
            if devices[i].appleModelID == nil && device.appleModelID != nil {
                devices[i].appleModelID = device.appleModelID
            }
            for s in device.services {
                if !devices[i].services.contains(s) {
                    devices[i].services.append(s)
                }
            }
        } else {
            devices.append(device)
        }
    }
    
    private func resolveLocalIP() -> String {
        return resolveLocalPhysicalNetwork().ip
    }
    
    public func resolveHostnamesAsync(for ips: [String]) {
        discoveryQueue.async { [weak self] in
            guard let self = self else { return }
            for ip in ips {
                guard !ip.isEmpty else { continue }
                var hints = addrinfo()
                hints.ai_family = AF_INET
                var res: UnsafeMutablePointer<addrinfo>?
                if getaddrinfo(ip, nil, &hints, &res) == 0, let info = res {
                    defer { freeaddrinfo(res) }
                    var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(info.pointee.ai_addr, socklen_t(info.pointee.ai_addrlen),
                                   &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NAMEREQD) == 0 {
                        let rawName = String(cString: hostBuf)
                        let cleanName = rawName.replacingOccurrences(of: ".local", with: "").replacingOccurrences(of: ".lan", with: "")
                        if !cleanName.isEmpty && cleanName != ip {
                            DispatchQueue.main.async {
                                if let idx = self.devices.firstIndex(where: { $0.ipAddress == ip }) {
                                    if self.devices[idx].hostname.starts(with: "Host-") {
                                        self.devices[idx].hostname = cleanName
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func harvestLocalDevice() {
        discoveryQueue.async { [weak self] in
            guard let self = self else { return }
            let (primaryIface, _) = NetworkMediumDetector.resolvePrimaryInterface()
            let localIP = self.resolveLocalIP()
            guard localIP != "127.0.0.1" && !localIP.isEmpty else { return }
            
            var primaryMAC = ""
            var fallbackMAC = ""
            
            var ifaddr: UnsafeMutablePointer<ifaddrs>?
            if getifaddrs(&ifaddr) == 0 {
                var ptr = ifaddr
                while ptr != nil {
                    defer { ptr = ptr?.pointee.ifa_next }
                    guard let ifa = ptr?.pointee, let addr = ifa.ifa_addr else { continue }
                    if addr.pointee.sa_family == UInt8(AF_LINK) {
                        let name = String(cString: ifa.ifa_name)
                        if name.starts(with: "en") || name.starts(with: "bridge") {
                            addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { sdl in
                                let nlen = Int(sdl.pointee.sdl_nlen)
                                let alen = Int(sdl.pointee.sdl_alen)
                                if alen == 6 {
                                    let base = withUnsafePointer(to: &sdl.pointee.sdl_data) {
                                        UnsafeRawPointer($0).advanced(by: nlen)
                                    }
                                    let bytes = base.assumingMemoryBound(to: UInt8.self)
                                    let mac = String(format: "%02X:%02X:%02X:%02X:%02X:%02X",
                                                     bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5])
                                    if mac != "00:00:00:00:00:00" && !mac.isEmpty {
                                        if name == primaryIface {
                                            primaryMAC = mac
                                        } else if fallbackMAC.isEmpty {
                                            fallbackMAC = mac
                                        }
                                    }
                                }
                            }
                            if !primaryMAC.isEmpty { break }
                        }
                    }
                }
                freeifaddrs(ifaddr)
            }
            
            let localMAC = !primaryMAC.isEmpty ? primaryMAC : fallbackMAC
            guard !localMAC.isEmpty else { return }
            
            var size: size_t = 0
            sysctlbyname("hw.model", nil, &size, nil, 0)
            var modelBuffer = [CChar](repeating: 0, count: max(size, 1))
            sysctlbyname("hw.model", &modelBuffer, &size, nil, 0)
            let rawModelID = String(cString: modelBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
            let appleModelID = rawModelID.isEmpty ? nil : rawModelID
            
            let hostName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
            let vendor = OUIDatabase.vendor(for: localMAC)
            let modelName = appleModelID != nil ? (AppleModelDatabase.lookup(modelID: appleModelID!) ?? "Apple Mac") : "Apple Mac"
            
            let adapters = NetworkMediumDetector.detectAllAdaptersSync()
            let primaryAdapter = adapters.first(where: { $0.isPrimary }) ?? adapters.first
            let mediumType = primaryAdapter?.medium == .wiredEthernet ? "Ethernet" : "Wi-Fi"
            let mediumBadge = "LOCAL [\(mediumType) \(primaryIface)]"
            
            let localDev = LANDevice(
                ipAddress: localIP,
                macAddress: localMAC,
                hostname: "\(hostName) (This Mac)",
                vendor: vendor != "Unknown Vendor" ? vendor : "Apple Inc.",
                protocolType: mediumBadge,
                modelName: modelName,
                appleModelID: appleModelID,
                osInference: "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
                latencyMS: 0.1,
                lastSeen: Date()
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.upsertDevice(localDev)
                self?.lastUpdated = Date()
            }
        }
    }
    
    public func resolveDefaultGateway() -> String? {
        // Fast path 1: SystemConfiguration SCDynamicStore router
        let (_, router) = NetworkMediumDetector.resolvePrimaryInterface()
        if let r = router, !r.isEmpty {
            return r
        }
        
        // Fallback 2: /sbin/route query
        let routeProc = Process()
        routeProc.executableURL = URL(fileURLWithPath: "/sbin/route")
        routeProc.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        routeProc.standardOutput = pipe
        
        do {
            try routeProc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            routeProc.waitUntilExit()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("gateway:") {
                        let parts = trimmed.split(separator: ":")
                        if parts.count >= 2 {
                            return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
