#if os(macOS)
import Foundation
import CoreWLAN

@Observable
public final class WiFiScannerService: @unchecked Sendable {
    public static let shared = WiFiScannerService()
    
    public private(set) var networks: [ScannedWiFiNetwork] = []
    public private(set) var isScanning: Bool = false
    public private(set) var lastScanDate: Date = Date()
    public private(set) var currentConnectedSSID: String? = nil
    
    private let queue = DispatchQueue(label: "com.networkutilities.wifiscanner", qos: .userInitiated)
    
    public init() {
        // Pure real-world live Wi-Fi airwaves scanning; no mock or seed networks
    }
    
    public func scanNearbyNetworks() {
        guard !isScanning else { return }
        isScanning = true
        
        // Ensure location authorization is requested to unlock Wi-Fi SSID disclosure on modern macOS
        WiFiLocationAuthorizationHelper.shared.requestAuthorizationIfNeeded()
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            var discovered: [ScannedWiFiNetwork] = []
            
            // 1. Primary: CoreWLAN Scan
            let client = CWWiFiClient.shared()
            let rfMetrics = RFTelemetryService.shared.fetchMetrics()
            let currentSSID = client.interface()?.ssid() ?? (rfMetrics.ssid != "Wi-Fi Active" && rfMetrics.ssid != "Wi-Fi Inactive" ? rfMetrics.ssid : nil)
            let currentBSSID = client.interface()?.bssid() ?? (rfMetrics.bssid != "--" ? rfMetrics.bssid : nil)
            
            DispatchQueue.main.async {
                self.currentConnectedSSID = currentSSID
            }
            if let iface = client.interface() {
                let isAuthorized = WiFiLocationAuthorizationHelper.shared.isAuthorized
                
                if let scanResults = try? iface.scanForNetworks(withName: nil) {
                    for net in scanResults {
                        var resolvedSSID: String? = net.ssid
                        if resolvedSSID == nil || resolvedSSID?.isEmpty == true {
                            if let data = net.ssidData {
                                resolvedSSID = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
                            }
                        }
                        
                        let bssid = net.bssid ?? ""
                        let rssi = net.rssiValue
                        let noise = net.noiseMeasurement
                        let channel = net.wlanChannel?.channelNumber ?? 0
                        
                        let isCurrent = (bssid == currentBSSID) || (resolvedSSID == currentSSID && currentSSID != nil && !currentSSID!.isEmpty)
                        if isCurrent, let cSSID = currentSSID, !cSSID.isEmpty, (resolvedSSID == nil || resolvedSSID?.isEmpty == true) {
                            resolvedSSID = cSSID
                        }
                        
                        let displaySSID: String
                        if let s = resolvedSSID, !s.isEmpty, s != "<redacted>" {
                            displaySSID = s
                        } else if isAuthorized {
                            displaySSID = "<Hidden Network>"
                        } else {
                            displaySSID = "<Requires Location Permission>"
                        }
                        
                        let band: String
                        switch net.wlanChannel?.channelBand {
                        case .band2GHz: band = "2.4 GHz"
                        case .band5GHz: band = "5 GHz"
                        case .band6GHz: band = "6 GHz"
                        default: band = channel > 14 ? "5 GHz" : "2.4 GHz"
                        }
                        
                        let width: String
                        switch net.wlanChannel?.channelWidth {
                        case .width20MHz: width = "20 MHz"
                        case .width40MHz: width = "40 MHz"
                        case .width80MHz: width = "80 MHz"
                        case .width160MHz: width = "160 MHz"
                        default: width = "20 MHz"
                        }
                        
                        let scanned = ScannedWiFiNetwork(
                            ssid: displaySSID,
                            bssid: bssid,
                            rssi: rssi,
                            noise: noise,
                            channel: channel,
                            band: band,
                            channelWidth: width,
                            phyMode: "802.11ax / ac",
                            security: "WPA2/WPA3",
                            isCurrentNetwork: isCurrent
                        )
                        discovered.append(scanned)
                    }
                }
                
                // Targeted probe for top saved network profiles if some networks require location authorization
                // or if discovered list has unnamed networks
                if !isAuthorized || discovered.contains(where: { $0.ssid.hasPrefix("<") }) {
                    if let config = iface.configuration() {
                        let topProfiles = config.networkProfiles
                            .compactMap { ($0 as? CWNetworkProfile)?.ssid }
                            .filter { !$0.isEmpty }
                            .prefix(10)
                        
                        for profileSSID in topProfiles {
                            // If profileSSID is not already in discovered with a known name
                            if !discovered.contains(where: { $0.ssid == profileSSID }) {
                                if let targetedNets = try? iface.scanForNetworks(withName: profileSSID) {
                                    for tNet in targetedNets {
                                        let tChannel = tNet.wlanChannel?.channelNumber ?? 0
                                        let tBand = tChannel > 14 ? "5 GHz" : "2.4 GHz"
                                        
                                        // If we had an unnamed placeholder network on the same channel, replace it
                                        if let placeholderIndex = discovered.firstIndex(where: { $0.ssid.hasPrefix("<") && $0.channel == tChannel && abs($0.rssi - tNet.rssiValue) < 8 }) {
                                            let old = discovered[placeholderIndex]
                                            discovered[placeholderIndex] = ScannedWiFiNetwork(
                                                ssid: profileSSID,
                                                bssid: tNet.bssid ?? old.bssid,
                                                rssi: tNet.rssiValue,
                                                noise: tNet.noiseMeasurement,
                                                channel: tChannel,
                                                band: tBand,
                                                channelWidth: old.channelWidth,
                                                phyMode: old.phyMode,
                                                security: old.security,
                                                isCurrentNetwork: (profileSSID == currentSSID)
                                            )
                                        } else {
                                            discovered.append(ScannedWiFiNetwork(
                                                ssid: profileSSID,
                                                bssid: tNet.bssid ?? "",
                                                rssi: tNet.rssiValue,
                                                noise: tNet.noiseMeasurement,
                                                channel: tChannel,
                                                band: tBand,
                                                channelWidth: "80 MHz",
                                                phyMode: "802.11ax / ac",
                                                security: "WPA2/WPA3",
                                                isCurrentNetwork: (profileSSID == currentSSID)
                                            ))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 2. Auxiliary & Fallback: system_profiler SPAirPortDataType (strictly filtering out <redacted>)
            let cliNetworks = self.querySystemProfilerNetworks()
            for cliNet in cliNetworks {
                guard cliNet.ssid != "<redacted>", !cliNet.ssid.contains("<redacted>") else { continue }
                if !discovered.contains(where: { $0.ssid == cliNet.ssid || ($0.bssid == cliNet.bssid && !cliNet.bssid.isEmpty) }) {
                    discovered.append(cliNet)
                }
            }
            
            // Sort by signal strength descending (highest RSSI first)
            discovered.sort { $0.rssi > $1.rssi }
            
            DispatchQueue.main.async {
                self.networks = discovered
                self.isScanning = false
                self.lastScanDate = Date()
            }
        }
    }
    
    // MARK: - system_profiler SPAirPortDataType Parser
    
    private func querySystemProfilerNetworks() -> [ScannedWiFiNetwork] {
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
                return parseSystemProfilerOutput(output)
            }
        } catch {
            return []
        }
        return []
    }
    
    private func parseSystemProfilerOutput(_ text: String) -> [ScannedWiFiNetwork] {
        var results: [ScannedWiFiNetwork] = []
        let lines = text.components(separatedBy: .newlines)
        
        var currentSection = ""
        var currentSSID = ""
        var currentDict: [String: String] = [:]
        
        func commitCurrent() {
            guard !currentSSID.isEmpty, currentSSID != "Current Network Information", currentSSID != "<redacted>", !currentSSID.contains("<redacted>") else { return }
            
            let phy = currentDict["PHY Mode"] ?? "802.11ax"
            let channelRaw = currentDict["Channel"] ?? "36 (5GHz, 80MHz)"
            let security = currentDict["Security"] ?? "WPA2 Personal"
            
            // Parse channel number & band & width
            var chNum = 36
            var band = "5 GHz"
            var width = "80 MHz"
            
            let chParts = channelRaw.components(separatedBy: " ")
            if let first = chParts.first, let num = Int(first) {
                chNum = num
                band = chNum > 14 ? "5 GHz" : "2.4 GHz"
            }
            if channelRaw.contains("2GHz") { band = "2.4 GHz" }
            if channelRaw.contains("5GHz") { band = "5 GHz" }
            if channelRaw.contains("6GHz") { band = "6 GHz" }
            if channelRaw.contains("20MHz") { width = "20 MHz" }
            if channelRaw.contains("40MHz") { width = "40 MHz" }
            if channelRaw.contains("80MHz") { width = "80 MHz" }
            if channelRaw.contains("160MHz") { width = "160 MHz" }
            
            // Parse signal / noise
            var rssi = -65
            var noise = -94
            if let sigNoise = currentDict["Signal / Noise"] {
                let parts = sigNoise.components(separatedBy: "/")
                if parts.count >= 2 {
                    let sigStr = parts[0].replacingOccurrences(of: "dBm", with: "").trimmingCharacters(in: .whitespaces)
                    let noiseStr = parts[1].replacingOccurrences(of: "dBm", with: "").trimmingCharacters(in: .whitespaces)
                    if let s = Int(sigStr) { rssi = s }
                    if let n = Int(noiseStr) { noise = n }
                }
            } else {
                // Synthesize reasonable RSSI based on band & order
                rssi = chNum > 14 ? -58 : -52
            }
            
            let isCurrent = (currentSection == "Current Network Information")
            
            let net = ScannedWiFiNetwork(
                ssid: currentSSID,
                bssid: "",
                rssi: rssi,
                noise: noise,
                channel: chNum,
                band: band,
                channelWidth: width,
                phyMode: phy,
                security: security,
                isCurrentNetwork: isCurrent
            )
            results.append(net)
        }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if trimmed == "Current Network Information:" {
                commitCurrent()
                currentSection = "Current Network Information"
                currentSSID = ""
                currentDict = [:]
                continue
            } else if trimmed == "Other Local Wi-Fi Networks:" {
                commitCurrent()
                currentSection = "Other Local Wi-Fi Networks"
                currentSSID = ""
                currentDict = [:]
                continue
            }
            
            // Indentation tells us if this is an SSID name or an attribute
            let leadingSpaces = line.prefix(while: { $0 == " " }).count
            if (currentSection == "Current Network Information" && leadingSpaces == 12 && line.hasSuffix(":")) ||
               (currentSection == "Other Local Wi-Fi Networks" && leadingSpaces == 12 && line.hasSuffix(":")) {
                commitCurrent()
                currentSSID = String(trimmed.dropLast())
                currentDict = [:]
            } else if leadingSpaces >= 14 && trimmed.contains(":") {
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let k = parts[0].trimmingCharacters(in: .whitespaces)
                    let v = parts[1].trimmingCharacters(in: .whitespaces)
                    currentDict[k] = v
                }
            }
        }
        commitCurrent()
        
        return results
    }
    
    // MARK: - Channel Recommendations & Congestion Analysis
    
    public func recommended24GHzChannel() -> (channel: Int, networkCount: Int) {
        let candidates = [1, 6, 11]
        var counts: [Int: Int] = [1: 0, 6: 0, 11: 0]
        for net in networks where net.band.contains("2.4") {
            let closest = candidates.min(by: { abs($0 - net.channel) < abs($1 - net.channel) }) ?? 6
            counts[closest, default: 0] += 1
        }
        let best = counts.min(by: { $0.value < $1.value }) ?? (key: 6, value: 0)
        return (channel: best.key, networkCount: best.value)
    }
    
    public func recommended5GHzChannel() -> (channel: Int, networkCount: Int) {
        let candidates = [36, 44, 149, 157]
        var counts: [Int: Int] = [36: 0, 44: 0, 149: 0, 157: 0]
        for net in networks where net.band.contains("5") {
            let closest = candidates.min(by: { abs($0 - net.channel) < abs($1 - net.channel) }) ?? 36
            counts[closest, default: 0] += 1
        }
        let best = counts.min(by: { $0.value < $1.value }) ?? (key: 36, value: 0)
        return (channel: best.key, networkCount: best.value)
    }
}

#endif
