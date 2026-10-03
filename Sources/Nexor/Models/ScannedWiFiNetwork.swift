#if os(macOS)
import Foundation

public struct ScannedWiFiNetwork: Identifiable, Hashable, Sendable {
    public let id: String // BSSID or SSID+Channel
    public let ssid: String
    public let bssid: String
    public let rssi: Int // dBm (e.g. -45)
    public let noise: Int // dBm (e.g. -94)
    public var snr: Int { rssi - noise }
    public let channel: Int
    public let band: String // "2.4 GHz", "5 GHz", "6 GHz"
    public let channelWidth: String // "20 MHz", "40 MHz", "80 MHz", "160 MHz"
    public let phyMode: String // "802.11ax (Wi-Fi 6)", "802.11ac", etc.
    public let security: String // "WPA2 Personal", "WPA3", "Open"
    public let isCurrentNetwork: Bool
    public let vendor: String
    
    public init(
        ssid: String,
        bssid: String,
        rssi: Int,
        noise: Int = -94,
        channel: Int,
        band: String = "5 GHz",
        channelWidth: String = "80 MHz",
        phyMode: String = "802.11ax",
        security: String = "WPA2 Personal",
        isCurrentNetwork: Bool = false
    ) {
        self.ssid = ssid.isEmpty ? "<Hidden Network>" : ssid
        self.bssid = bssid.uppercased()
        self.id = bssid.isEmpty ? "\(ssid)-\(channel)" : bssid.uppercased()
        self.rssi = rssi
        self.noise = noise
        self.channel = channel
        self.band = band
        self.channelWidth = channelWidth
        self.phyMode = phyMode
        self.security = security
        self.isCurrentNetwork = isCurrentNetwork
        self.vendor = OUIDatabase.vendor(for: bssid)
    }
    
    /// Signal quality percentage from 0% to 100%
    public var signalQualityPercentage: Int {
        if rssi >= -50 { return 100 }
        if rssi <= -100 { return 0 }
        return 2 * (rssi + 100)
    }
    
    /// Signal quality bars (1 to 4)
    public var signalBars: Int {
        if rssi >= -60 { return 4 }
        if rssi >= -70 { return 3 }
        if rssi >= -80 { return 2 }
        return 1
    }
    
    /// Evaluates signal condition
    public var signalDescription: String {
        if rssi >= -60 { return "Excellent Signal" }
        if rssi >= -72 { return "Good Signal" }
        if rssi >= -82 { return "Fair / Weak Signal" }
        return "Poor Signal"
    }
}

#endif
