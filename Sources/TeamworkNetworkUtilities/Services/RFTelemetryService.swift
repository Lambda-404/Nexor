import Foundation
import CoreWLAN

public struct DetailedRFMetrics: Sendable {
    public let ssid: String
    public let bssid: String
    public let rssi: Int
    public let noise: Int
    public let snr: Int
    public let txRate: Double
    public let maxRate: Double?
    public let channel: String?
    public let channelWidthMHz: Int?
    public let mcsIndex: Int?
    public let opMode: String?
    
    public var signalRating: String {
        if snr >= 25 { return "Optimal (> 25 dB)" }
        if snr >= 15 { return "Fair (15 - 25 dB)" }
        return "Degraded / Unstable (< 15 dB)"
    }
}

public final class RFTelemetryService: @unchecked Sendable {
    public static let shared = RFTelemetryService()
    
    private var cachedProfilerMetrics: (timestamp: Date, metrics: [String: String])?
    private let lock = NSLock()
    
    public init() {}
    
    public func fetchMetrics() -> DetailedRFMetrics {
        let cwClient = CWWiFiClient.shared()
        let iface = cwClient.interface()
        
        let isPowered = iface?.powerOn() ?? false
        let ifaceName = iface?.interfaceName ?? "en0"
        let cwBSSID = iface?.bssid() ?? "--"
        let cwRSSI = isPowered ? (iface?.rssiValue() ?? 0) : 0
        let cwNoise = isPowered ? (iface?.noiseMeasurement() ?? 0) : 0
        let cwSNR = (cwRSSI != 0 && cwNoise != 0) ? (cwRSSI - cwNoise) : 0
        let cwTxRate = isPowered ? (iface?.transmitRate() ?? 0.0) : 0.0
        
        // 1. Instant Darwin ipconfig resolver (~9ms, no location permissions required)
        let ipconfigData = queryIpconfigSummary(interfaceName: ifaceName)
        
        // 2. Attempt private airport CLI interrogation
        let airportMetrics = queryAirportCLI()
        
        // 3. Fallback to networksetup if ipconfig did not return an SSID
        let networksetupSSID = (ipconfigData.ssid == nil || ipconfigData.ssid?.isEmpty == true) ? queryNetworksetup(interfaceName: ifaceName) : nil
        
        // 4. Auxiliary fallback via system_profiler when CoreWLAN or airport data is unavailable
        let needProfiler = cwRSSI == 0 && (ipconfigData.ssid == nil) && airportMetrics.isEmpty
        let profiler = needProfiler ? querySystemProfilerCurrentNetwork() : [:]
        
        // Resolve definitive SSID
        let initialSSID = iface?.ssid()
        let candidateSSID = (initialSSID != nil && !initialSSID!.isEmpty) ? initialSSID : (ipconfigData.ssid ?? (networksetupSSID ?? (airportMetrics["SSID"] ?? profiler["SSID"])))
        let finalSSID: String
        if let s = candidateSSID, !s.isEmpty {
            finalSSID = s
        } else {
            finalSSID = isPowered ? "Wi-Fi Active" : "Wi-Fi Inactive"
        }
        
        // Resolve definitive BSSID
        let initialBSSID = iface?.bssid()
        let candidateBSSID = (initialBSSID != nil && initialBSSID != "--" && !initialBSSID!.isEmpty) ? initialBSSID : (ipconfigData.bssid ?? (airportMetrics["BSSID"] ?? cwBSSID))
        let finalBSSID: String = (candidateBSSID?.isEmpty == false) ? candidateBSSID! : "--"
        let resolvedRSSI = airportMetrics["agrCtlRSSI"].flatMap { Int($0) } ?? (profiler["rssi"].flatMap { Int($0) } ?? cwRSSI)
        let resolvedNoise = airportMetrics["agrCtlNoise"].flatMap { Int($0) } ?? (profiler["noise"].flatMap { Int($0) } ?? cwNoise)
        let resolvedSNR = (resolvedRSSI != 0 && resolvedNoise != 0) ? (resolvedRSSI - resolvedNoise) : cwSNR
        let resolvedTxRate = airportMetrics["lastTxRate"].flatMap { Double($0) } ?? (profiler["txRate"].flatMap { Double($0) } ?? cwTxRate)
        let resolvedChannel = airportMetrics["channel"] ?? profiler["channel"]
        let resolvedMCS = airportMetrics["MCS"].flatMap { Int($0) } ?? profiler["mcs"].flatMap { Int($0) }
        let resolvedOpMode = airportMetrics["op mode"] ?? profiler["phyMode"]
        
        return DetailedRFMetrics(
            ssid: finalSSID,
            bssid: finalBSSID,
            rssi: resolvedRSSI,
            noise: resolvedNoise,
            snr: resolvedSNR,
            txRate: resolvedTxRate,
            maxRate: airportMetrics["maxRate"].flatMap { Double($0) },
            channel: resolvedChannel,
            channelWidthMHz: parseChannelWidth(from: resolvedChannel),
            mcsIndex: resolvedMCS,
            opMode: resolvedOpMode
        )
    }
    
    private func queryIpconfigSummary(interfaceName: String?) -> (ssid: String?, bssid: String?) {
        let iface = interfaceName ?? "en0"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ipconfig")
        process.arguments = ["getsummary", iface]
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return (nil, nil) }
            var foundSSID: String?
            var foundBSSID: String?
            for line in output.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("SSID :") {
                    foundSSID = trimmed.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("BSSID :") {
                    foundBSSID = trimmed.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces)
                }
            }
            return (foundSSID, foundBSSID)
        } catch {
            return (nil, nil)
        }
    }
    
    private func queryNetworksetup(interfaceName: String?) -> String? {
        let iface = interfaceName ?? "en0"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-getairportnetwork", iface]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.contains("Current Wi-Fi Network:") {
                    return trimmed.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces)
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func queryAirportCLI() -> [String: String] {
        let airportPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        guard FileManager.default.isExecutableFile(atPath: airportPath) else {
            return [:]
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: airportPath)
        process.arguments = ["-I"]
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var dict: [String: String] = [:]
                for line in output.components(separatedBy: .newlines) {
                    let parts = line.split(separator: ":", maxSplits: 1)
                    if parts.count == 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let val = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        dict[key] = val
                    }
                }
                return dict
            }
        } catch {
            return [:]
        }
        return [:]
    }
    
    private func querySystemProfilerCurrentNetwork() -> [String: String] {
        lock.lock()
        if let cached = cachedProfilerMetrics, Date().timeIntervalSince(cached.timestamp) < 3.0 {
            let res = cached.metrics
            lock.unlock()
            return res
        }
        lock.unlock()
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPAirPortDataType"]
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let parsed = parseCurrentNetworkFromProfiler(output)
                lock.lock()
                cachedProfilerMetrics = (Date(), parsed)
                lock.unlock()
                return parsed
            }
        } catch {
            return [:]
        }
        return [:]
    }
    
    private func parseCurrentNetworkFromProfiler(_ output: String) -> [String: String] {
        var dict: [String: String] = [:]
        let lines = output.components(separatedBy: .newlines)
        var inCurrentSection = false
        var currentSSID: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "Current Network Information:" {
                inCurrentSection = true
                continue
            } else if trimmed == "Other Local Wi-Fi Networks:" {
                break
            }
            
            guard inCurrentSection else { continue }
            let leadingSpaces = line.prefix(while: { $0 == " " }).count
            
            if leadingSpaces == 12 && line.hasSuffix(":") && currentSSID == nil {
                currentSSID = String(trimmed.dropLast())
                dict["SSID"] = currentSSID
            } else if leadingSpaces >= 14 && trimmed.contains(":") {
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let k = parts[0].trimmingCharacters(in: .whitespaces)
                    let v = parts[1].trimmingCharacters(in: .whitespaces)
                    if k == "Signal / Noise" {
                        let sn = v.components(separatedBy: "/")
                        if sn.count >= 2 {
                            let s = sn[0].replacingOccurrences(of: "dBm", with: "").trimmingCharacters(in: .whitespaces)
                            let n = sn[1].replacingOccurrences(of: "dBm", with: "").trimmingCharacters(in: .whitespaces)
                            dict["rssi"] = s
                            dict["noise"] = n
                        }
                    } else if k == "Transmit Rate" {
                        dict["txRate"] = v
                    } else if k == "MCS Index" {
                        dict["mcs"] = v
                    } else if k == "Channel" {
                        dict["channel"] = v
                    } else if k == "PHY Mode" {
                        dict["phyMode"] = v
                    }
                }
            }
        }
        return dict
    }
    
    private func parseChannelWidth(from channelStr: String?) -> Int? {
        guard let str = channelStr else { return nil }
        // channel string often looks like: "36,80" or "149 (5GHz, 80MHz)"
        if str.contains(",") {
            let parts = str.split(separator: ",")
            if parts.count >= 2, let width = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                return width
            }
        }
        if str.contains("80MHz") || str.contains("80") { return 80 }
        if str.contains("160MHz") || str.contains("160") { return 160 }
        if str.contains("40MHz") || str.contains("40") { return 40 }
        if str.contains("20MHz") || str.contains("20") { return 20 }
        return nil
    }
}
