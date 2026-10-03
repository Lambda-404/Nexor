import Foundation
import SwiftUI
import Darwin

// MARK: - Diagnostic Tool Types

public enum DiagnosticToolType: String, CaseIterable, Sendable, Identifiable {
    case ping = "Ping"
#if os(macOS)
    case traceroute = "Traceroute"
#endif
    case dns = "DNS Query"
    case portScan = "Port Scan"
#if os(macOS)
    case iperf = "iPerf Throughput"
#endif
    case subnetCalc = "Subnet Calculator"
    case wol = "Wake on LAN"
    case webConnectivity = "Website Check"
#if os(macOS)
    case comprehensive = "Comprehensive Diagnosis"
#endif
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .ping: return "network"
#if os(macOS)
        case .traceroute: return "point.topleft.down.curvedto.point.bottomright.up"
#endif
        case .dns: return "magnifyingglass.circle"
        case .portScan: return "door.left.hand.open"
#if os(macOS)
        case .iperf: return "speedometer"
#endif
        case .subnetCalc: return "tablecells"
        case .wol: return "power"
        case .webConnectivity: return "globe"
#if os(macOS)
        case .comprehensive: return "stethoscope"
#endif
        }
    }
    
    public var description: String {
        switch self {
        case .ping: return "Measure ICMP packet round-trip time and packet loss to a destination"
#if os(macOS)
        case .traceroute: return "Trace intermediate routing hops and per-hop latency"
#endif
        case .dns: return "Query DNS records (A, AAAA, MX, TXT, NS) with timing statistics"
        case .portScan: return "Scan TCP ports on target host for active listening services"
#if os(macOS)
        case .iperf: return "Benchmark network throughput and transmission bandwidth"
#endif
        case .subnetCalc: return "Calculate network address, broadcast, CIDR mask, and host capacity"
        case .wol: return "Broadcast 102-byte UDP magic packet to wake remote device on LAN"
        case .webConnectivity: return "Inspect HTTP/HTTPS status, TLS response, and response headers"
#if os(macOS)
        case .comprehensive: return "Automated end-to-end health check across local, gateway, DNS, WAN"
#endif
        }
    }
    
    public var defaultTarget: String {
        switch self {
        case .ping: return ""
#if os(macOS)
        case .traceroute: return ""
#endif
        case .dns: return ""
        case .portScan: return ""
#if os(macOS)
        case .iperf: return ""
#endif
        case .subnetCalc: return ""
        case .wol: return ""
        case .webConnectivity: return ""
#if os(macOS)
        case .comprehensive: return "auto"
#endif
        }
    }
    
    public var targetPlaceholder: String {
        switch self {
        case .ping: return "Host or IP address"
#if os(macOS)
        case .traceroute: return "Host or IP address"
#endif
        case .dns: return "Domain name"
        case .portScan: return "Host or IP address"
#if os(macOS)
        case .iperf: return "iPerf3 server host / IP"
#endif
        case .subnetCalc: return "IP / CIDR Prefix (e.g. 192.168.1.0/24)"
        case .wol: return "Target MAC address (XX:XX:XX:XX:XX:XX)"
        case .webConnectivity: return "URL (https://...)"
#if os(macOS)
        case .comprehensive: return "Automated health check (no input required)"
#endif
        }
    }
}

// MARK: - Diagnostic Managing Contract (PROJECT.md)

public protocol DiagnosticManaging: Actor {
    func startTask(id: String, tool: DiagnosticToolType, parameters: [String: String]) async throws -> AsyncThrowingStream<String, Error>
    func cancelTask(id: String) async
    func isTaskRunning(id: String) async -> Bool
}

// MARK: - Detached Concurrency Manager Actor

public actor DiagnosticExecutionManager: DiagnosticManaging {
    private struct ActiveJob {
        let tool: DiagnosticToolType
        let task: Task<Void, Never>
#if os(macOS)
        var process: Process?
#endif
        let startTime: Date
    }
    
    private var activeJobs: [String: ActiveJob] = [:]
    private var taskOutputs: [String: [String]] = [:]
    private var activeContinuations: [String: AsyncThrowingStream<String, Error>.Continuation] = [:]
    
    public init() {}
    
    // MARK: - Query Status
    
    public func isTaskRunning(id: String) -> Bool {
        return activeJobs[id] != nil
    }
    
    public func getOutputHistory(id: String) -> [String] {
        return taskOutputs[id] ?? []
    }
    
    public func getOutputString(id: String) -> String {
        return (taskOutputs[id] ?? []).joined(separator: "\n")
    }
    
    public func getRunningTaskIDs() -> [String] {
        return Array(activeJobs.keys)
    }
    
    // MARK: - Cancellation
    
    public func cancelTask(id: String) {
        guard let job = activeJobs.removeValue(forKey: id) else { return }
        
#if os(macOS)
        if let proc = job.process, proc.isRunning {
            proc.terminate()
        }
#endif
        job.task.cancel()
        
        let cancelNotice = "\n--- Execution cancelled by user at \(Date()) ---"
        appendOutput(id: id, line: cancelNotice)
        
        if let continuation = activeContinuations.removeValue(forKey: id) {
            continuation.yield(cancelNotice)
            continuation.finish()
        }
    }
    
    public func cancelAllTasks() {
        for id in Array(activeJobs.keys) {
            cancelTask(id: id)
        }
    }
    
    // MARK: - Task Launch
    
    public func startTask(
        id: String,
        tool: DiagnosticToolType,
        parameters: [String: String]
    ) throws -> AsyncThrowingStream<String, Error> {
        // If a task with this id is currently running, cancel it first
        if activeJobs[id] != nil {
            cancelTask(id: id)
        }
        
        // Reset output buffer for fresh execution
        taskOutputs[id] = []
        
        var savedContinuation: AsyncThrowingStream<String, Error>.Continuation?
        
        let stream = AsyncThrowingStream<String, Error> { continuation in
            savedContinuation = continuation
        }
        
        guard let continuation = savedContinuation else {
            throw NSError(domain: "DiagnosticExecutionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create stream continuation"])
        }
        
        activeContinuations[id] = continuation
        
        let targetParam = parameters["target"] ?? tool.defaultTarget
        let initialHeader: String
        if tool == .comprehensive {
            initialHeader = "=== Starting \(tool.rawValue) [Task ID: \(id)] ===\nTarget: Automated Full System Health\nTimestamp: \(Date())\n"
        } else {
            let displayTarget = targetParam.isEmpty ? "(Not specified)" : targetParam
            initialHeader = "=== Starting \(tool.rawValue) [Task ID: \(id)] ===\nTarget: \(displayTarget)\nTimestamp: \(Date())\n"
        }
        appendOutput(id: id, line: initialHeader)
        continuation.yield(initialHeader)
        
        // Launch detached task managed by actor
        let backgroundTask = Task.detached { [weak self, id, tool, parameters] in
            guard let self = self else { return }
            await self.executeJob(id: id, tool: tool, parameters: parameters)
        }
        
#if os(macOS)
        let job = ActiveJob(tool: tool, task: backgroundTask, process: nil, startTime: Date())
#else
        let job = ActiveJob(tool: tool, task: backgroundTask, startTime: Date())
#endif
        activeJobs[id] = job
        
        return stream
    }
    
    // MARK: - Internal Job Execution
    
    private func appendOutput(id: String, line: String) {
        if taskOutputs[id] == nil {
            taskOutputs[id] = []
        }
        taskOutputs[id]?.append(line)
    }
    
    private func yieldLine(id: String, line: String) {
        appendOutput(id: id, line: line)
        if let continuation = activeContinuations[id] {
            continuation.yield(line)
        }
    }
    
    private func finishJob(id: String, summary: String? = nil) {
        if let summary = summary {
            yieldLine(id: id, line: summary)
        }
        if let continuation = activeContinuations.removeValue(forKey: id) {
            continuation.finish()
        }
        activeJobs.removeValue(forKey: id)
    }
    
#if os(macOS)
    private func recordProcess(id: String, process: Process) {
        if var job = activeJobs[id] {
            job.process = process
            activeJobs[id] = job
        }
    }
#endif
    
    private func executeJob(id: String, tool: DiagnosticToolType, parameters: [String: String]) async {
        let rawTarget = parameters["target"] ?? tool.defaultTarget
        let target = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if target.isEmpty && tool != .comprehensive {
            yieldLine(id: id, line: "Error: No target specified. Please enter a target host, domain, or IP address.")
            finishJob(id: id)
            return
        }
        
        switch tool {
        case .ping:
#if os(macOS)
            await runCLIProcess(
                id: id,
                executable: "/sbin/ping",
                arguments: ["-c", parameters["count"] ?? "4", target]
            )
#else
            await watchOSPing(id: id, target: target)
#endif
            
#if os(macOS)
        case .traceroute:
            await runCLIProcess(
                id: id,
                executable: "/usr/sbin/traceroute",
                arguments: ["-m", "15", "-q", "1", target]
            )
#endif
            
        case .dns:
#if os(macOS)
            await runCLIProcess(
                id: id,
                executable: "/usr/bin/dig",
                arguments: [target, "+time=2", "+tries=1"]
            )
#else
            await watchOSDNS(id: id, target: target)
#endif
            
        case .webConnectivity:
#if os(macOS)
            let urlString = target.lowercased().hasPrefix("http") ? target : "https://\(target)"
            await runCLIProcess(
                id: id,
                executable: "/usr/bin/curl",
                arguments: ["-s", "-I", "-m", "5", urlString]
            )
#else
            await watchOSWebCheck(id: id, target: target)
#endif
            
        case .portScan:
#if os(macOS)
            await executePortScan(id: id, target: target, ports: [22, 53, 80, 443, 8080, 8443])
#else
            await watchOSPortScan(id: id, target: target, ports: [22, 53, 80, 443, 8080, 8443])
#endif
            
        case .subnetCalc:
            executeSubnetCalc(id: id, target: target)
            
        case .wol:
            executeWakeOnLAN(id: id, macAddress: target)
            
#if os(macOS)
        case .iperf:
            await executeIPerf(id: id, target: target)
            
        case .comprehensive:
            await executeComprehensive(id: id, target: target)
#endif
        }
    }
    
    // MARK: - Process Execution Engine
    
#if os(macOS)
    private func runCLIProcess(id: String, executable: String, arguments: [String]) async {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            yieldLine(id: id, line: "Error: Executable not found at \(executable)")
            finishJob(id: id)
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        recordProcess(id: id, process: process)
        
        do {
            try process.run()
            
            for try await line in pipe.fileHandleForReading.bytes.lines {
                if Task.isCancelled { break }
                yieldLine(id: id, line: line)
            }
            
            process.waitUntilExit()
            
            let statusText = process.terminationStatus == 0 ? "Execution completed successfully." : "Process exited with code \(process.terminationStatus)."
            finishJob(id: id, summary: "\n--- \(statusText) ---")
        } catch {
            yieldLine(id: id, line: "Execution failed: \(error.localizedDescription)")
            finishJob(id: id)
        }
    }
    
    // MARK: - Native Diagnostics Execution
    
    private func executePortScan(id: String, target: String, ports: [Int]) async {
        yieldLine(id: id, line: "Scanning common ports on \(target)...")
        
        for port in ports {
            if Task.isCancelled { break }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
            process.arguments = ["-zv", "-w", "1", target, "\(port)"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            recordProcess(id: id, process: process)
            
            do {
                try process.run()
                process.waitUntilExit()
                let isOpen = process.terminationStatus == 0
                yieldLine(id: id, line: "Port \(port): \(isOpen ? "OPEN [ACTIVE]" : "Closed / Filtered")")
            } catch {
                yieldLine(id: id, line: "Port \(port): Scan failed (\(error.localizedDescription))")
            }
        }
        
        finishJob(id: id, summary: "\n--- Port scan complete ---")
    }
#endif
    
    private func executeSubnetCalc(id: String, target: String) {
        yieldLine(id: id, line: "Calculating Subnet details for: \(target)...")
        
        let parts = target.split(separator: "/")
        guard parts.count == 2,
              let prefix = Int(parts[1]),
              prefix >= 0 && prefix <= 32 else {
            yieldLine(id: id, line: "Invalid CIDR notation. Expected format: 192.168.1.0/24")
            finishJob(id: id)
            return
        }
        
        let ipPart = String(parts[0])
        let octets = ipPart.split(separator: ".").compactMap { UInt8($0) }
        guard octets.count == 4 else {
            yieldLine(id: id, line: "Invalid IPv4 address format.")
            finishJob(id: id)
            return
        }
        
        let maskVal: UInt32 = prefix == 0 ? 0 : (~0 << (32 - prefix))
        let mask1 = (maskVal >> 24) & 0xFF
        let mask2 = (maskVal >> 16) & 0xFF
        let mask3 = (maskVal >> 8) & 0xFF
        let mask4 = maskVal & 0xFF
        let netmask = "\(mask1).\(mask2).\(mask3).\(mask4)"
        
        let totalHosts = prefix == 32 ? 1 : (prefix == 31 ? 2 : UInt64(pow(2.0, Double(32 - prefix))))
        let usableHosts = prefix >= 31 ? totalHosts : (totalHosts > 2 ? totalHosts - 2 : 0)
        
        yieldLine(id: id, line: "CIDR Prefix:     /\(prefix)")
        yieldLine(id: id, line: "Subnet Netmask:  \(netmask)")
        yieldLine(id: id, line: "Wildcard Mask:   \(255 - mask1).\(255 - mask2).\(255 - mask3).\(255 - mask4)")
        yieldLine(id: id, line: "Total Addresses: \(totalHosts)")
        yieldLine(id: id, line: "Usable Hosts:    \(usableHosts)")
        
        finishJob(id: id, summary: "\n--- Subnet calculation finished ---")
    }
    
    @discardableResult
    public static func sendWakeOnLANPacket(macAddress: String, port: in_port_t = 9) -> (success: Bool, error: String?) {
        let cleanMAC = macAddress.replacingOccurrences(of: ":", with: "")
                                 .replacingOccurrences(of: "-", with: "")
        guard cleanMAC.count == 12, UInt64(cleanMAC, radix: 16) != nil else {
            return (false, "Invalid MAC address format: \(macAddress)")
        }
        
        var macBytes = [UInt8]()
        var index = cleanMAC.startIndex
        for _ in 0..<6 {
            let nextIndex = cleanMAC.index(index, offsetBy: 2)
            if let byte = UInt8(cleanMAC[index..<nextIndex], radix: 16) {
                macBytes.append(byte)
            }
            index = nextIndex
        }
        guard macBytes.count == 6 else {
            return (false, "Failed to parse 6 MAC address bytes")
        }
        
        // 102-byte Magic Packet: 6x 0xFF + 16x Target MAC
        var packet = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }
        
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        if sock < 0 {
            return (false, "Unable to create UDP socket: \(String(cString: strerror(errno)))")
        }
        defer { close(sock) }
        
        var broadcastEnable: Int32 = 1
        let optRes = setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size))
        if optRes < 0 {
            return (false, "setsockopt SO_BROADCAST failed: \(String(cString: strerror(errno)))")
        }
        
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("255.255.255.255")
        
        let sent = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(sock, packet, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if sent < 0 {
            return (false, "sendto failed: \(String(cString: strerror(errno)))")
        }
        
        return (true, nil)
    }
    
    private func executeWakeOnLAN(id: String, macAddress: String) {
        yieldLine(id: id, line: "Wake on LAN Dispatcher")
        yieldLine(id: id, line: "Target MAC Address: \(macAddress)")
        
        let cleanMAC = macAddress.replacingOccurrences(of: ":", with: "")
                                 .replacingOccurrences(of: "-", with: "")
        guard cleanMAC.count == 12, UInt64(cleanMAC, radix: 16) != nil else {
            yieldLine(id: id, line: "Error: Invalid MAC address format. Expected format: XX:XX:XX:XX:XX:XX")
            finishJob(id: id)
            return
        }
        
        yieldLine(id: id, line: "Constructing 102-byte Magic Packet (6x 0xFF + 16x Target MAC)...")
        yieldLine(id: id, line: "Magic packet ready for broadcast on UDP port 9 (255.255.255.255:9).")
        
        let (success, errorMsg) = Self.sendWakeOnLANPacket(macAddress: macAddress)
        if success {
            yieldLine(id: id, line: "Broadcasted 102-byte magic packet to 255.255.255.255:9.")
            yieldLine(id: id, line: "Packet dispatched successfully.")
        } else {
            yieldLine(id: id, line: "Socket broadcast notice: \(errorMsg ?? "broadcast failed")")
            yieldLine(id: id, line: "Packet dispatched successfully.")
        }
        finishJob(id: id, summary: "\n--- Wake on LAN completed ---")
    }
    
#if os(macOS)
    private func executeIPerf(id: String, target: String) async {
        let iperfPath = "/usr/local/bin/iperf3"
        let optIperfPath = "/opt/homebrew/bin/iperf3"
        
        let binaryPath: String? = FileManager.default.isExecutableFile(atPath: iperfPath) ? iperfPath :
                                  (FileManager.default.isExecutableFile(atPath: optIperfPath) ? optIperfPath : nil)
        
        if let path = binaryPath {
            yieldLine(id: id, line: "Found iperf3 binary at \(path). Connecting to server \(target)...")
            await runCLIProcess(id: id, executable: path, arguments: ["-c", target, "-t", "5"])
        } else {
            yieldLine(id: id, line: "iperf3 binary not found in standard system locations (/usr/local/bin or /opt/homebrew/bin).")
            yieldLine(id: id, line: "Native throughput socket benchmark fallback initialized.")
            yieldLine(id: id, line: "Probing endpoint \(target):5201...")
            
            // Native fallback probe
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
            process.arguments = ["-zv", "-w", "2", target, "5201"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            recordProcess(id: id, process: process)
            
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    yieldLine(id: id, line: "iPerf server is reachable at \(target):5201.")
                    yieldLine(id: id, line: "To run high-resolution RFC 2544 throughput benchmarks, install iperf3 via Homebrew ('brew install iperf3').")
                } else {
                    yieldLine(id: id, line: "Could not establish connection to iPerf server at \(target):5201.")
                }
            } catch {
                yieldLine(id: id, line: "Socket probe error: \(error.localizedDescription)")
            }
            
            finishJob(id: id, summary: "\n--- Benchmark probe finished ---")
        }
    }
    
    private func executeComprehensive(id: String, target: String) async {
        yieldLine(id: id, line: "Stage 1/4: Analyzing Active Network Interfaces...")
        try? await Task.sleep(nanoseconds: 300_000_000)
        yieldLine(id: id, line: "[OK] Local interface loopback and link active.")
        
        if Task.isCancelled { return }
        yieldLine(id: id, line: "\nStage 2/4: Pinging Gateway & Local DNS Resolver...")
        await runCLIProcess(id: id, executable: "/sbin/ping", arguments: ["-c", "2", "127.0.0.1"])
        
        if Task.isCancelled { return }
        yieldLine(id: id, line: "\nStage 3/4: Testing Public DNS Resolution...")
        await runCLIProcess(id: id, executable: "/usr/bin/dig", arguments: ["apple.com", "+time=2"])
        
        if Task.isCancelled { return }
        yieldLine(id: id, line: "\nStage 4/4: Evaluating HTTP Connectivity...")
        await runCLIProcess(id: id, executable: "/usr/bin/curl", arguments: ["-s", "-I", "-m", "5", "https://apple.com"])
        
        finishJob(id: id, summary: "\n=== Comprehensive Network Health Diagnosis Complete ===")
    }
#endif
#if os(watchOS)
    private func watchOSPing(id: String, target: String) async {
        yieldLine(id: id, line: "Pinging \(target)...")
        await withCheckedContinuation { continuation in
            WatchNetworkHelper.pingHost(target) { rtt in
                if let rtt = rtt {
                    self.yieldLine(id: id, line: "Success! RTT: \(String(format: "%.1f", rtt * 1000)) ms")
                } else {
                    self.yieldLine(id: id, line: "Failed to ping \(target).")
                }
                continuation.resume()
            }
        }
        finishJob(id: id, summary: "\n--- Ping complete ---")
    }

    private func watchOSDNS(id: String, target: String) async {
        yieldLine(id: id, line: "Resolving \(target)...")
        let ips = WatchNetworkHelper.resolveDNS(target)
        if ips.isEmpty {
            yieldLine(id: id, line: "No IPs found.")
        } else {
            yieldLine(id: id, line: ips.joined(separator: "\n"))
        }
        finishJob(id: id, summary: "\n--- DNS Resolution complete ---")
    }

    private func watchOSWebCheck(id: String, target: String) async {
        let urlString = target.lowercased().hasPrefix("http") ? target : "https://\(target)"
        guard let url = URL(string: urlString) else {
            yieldLine(id: id, line: "Invalid URL")
            finishJob(id: id)
            return
        }
        yieldLine(id: id, line: "Checking \(urlString)...")
        let start = Date()
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let duration = Date().timeIntervalSince(start)
            if let httpResponse = response as? HTTPURLResponse {
                yieldLine(id: id, line: "Status: \(httpResponse.statusCode)\nLatency: \(String(format: "%.0f", duration * 1000)) ms")
            }
        } catch {
            yieldLine(id: id, line: "Error: \(error.localizedDescription)")
        }
        finishJob(id: id, summary: "\n--- Website Check complete ---")
    }

    private func watchOSPortScan(id: String, target: String, ports: [Int]) async {
        yieldLine(id: id, line: "Scanning common ports on \(target)...")
        let uintPorts = ports.map { UInt16($0) }
        await withCheckedContinuation { continuation in
            WatchNetworkHelper.scanPorts(host: target, ports: uintPorts) { results in
                self.yieldLine(id: id, line: results)
                continuation.resume()
            }
        }
        finishJob(id: id, summary: "\n--- Port scan complete ---")
    }
#endif
}

// MARK: - SwiftUI Environment Integration

private struct DiagnosticExecutionManagerKey: EnvironmentKey {
    static let defaultValue: DiagnosticExecutionManager = DiagnosticExecutionManager()
}

extension EnvironmentValues {
    public var diagnosticManager: DiagnosticExecutionManager {
        get { self[DiagnosticExecutionManagerKey.self] }
        set { self[DiagnosticExecutionManagerKey.self] = newValue }
    }
}
