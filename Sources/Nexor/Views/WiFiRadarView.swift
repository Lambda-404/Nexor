#if os(macOS)
import SwiftUI

public struct WiFiRadarView: View {
    @State private var scannerService = WiFiScannerService.shared
    @State private var locationHelper = WiFiLocationAuthorizationHelper.shared
    @State private var selectedNetwork: ScannedWiFiNetwork?
    @State private var selectedBand: String? = nil
    @State private var searchText: String = ""
    
    public init() {}
    
    public var filteredNetworks: [ScannedWiFiNetwork] {
        var list = scannerService.networks
        if let band = selectedBand {
            list = list.filter { $0.band == band }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.ssid.localizedCaseInsensitiveContains(searchText) ||
                $0.bssid.localizedCaseInsensitiveContains(searchText) ||
                $0.vendor.localizedCaseInsensitiveContains(searchText) ||
                "\($0.channel)".contains(searchText)
            }
        }
        return list
    }
    
    public var body: some View {
        HSplitView {
            // Left Column: Wi-Fi Networks List & Controls
            VStack(spacing: 0) {
                // Header status bar
                VStack(spacing: 8) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("\(scannerService.networks.count) Access Points")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                
                                if scannerService.isScanning {
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                        Text("SCANNING")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2.5)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.blue.opacity(0.25), lineWidth: 0.8)
                                    )
                                }
                            }
                            
                            Text("CoreWLAN RF channel scanner")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 8)
                        
                        Button(action: {
                            scannerService.scanNearbyNetworks()
                        }) {
                            HStack(spacing: 4) {
                                if scannerService.isScanning {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                Text(scannerService.isScanning ? "Scanning" : "Scan Wi-Fi")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.small)
                        .disabled(scannerService.isScanning)
                        .fixedSize()
                    }
                    
                    // Spectrum Recommendation Strip
                    let rec24 = scannerService.recommended24GHzChannel()
                    let rec5 = scannerService.recommended5GHzChannel()
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                            Text("Best 2.4G:")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                            Text("CH \(rec24.channel)")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .liquidGlass(cornerRadius: 6, elevation: 1)
                        
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 10))
                            Text("Best 5G:")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                            Text("CH \(rec5.channel)")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .liquidGlass(cornerRadius: 6, elevation: 1)
                        
                        Spacer()
                    }
                    
                    // Inline Glass Search Field
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        TextField("Search SSID, BSSID, Channel...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                
                Divider().opacity(0.4)
                
                // Location Services Status Notification Banner
                if !locationHelper.isAuthorized {
                    HStack(spacing: 8) {
                        Image(systemName: locationHelper.status == .notDetermined ? "location.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(locationHelper.status == .notDetermined ? .blue : .orange)
                            .font(.system(size: 13, weight: .semibold))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(locationHelper.status == .notDetermined ? "macOS Location Permission Required" : "Location Permission Denied")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(locationHelper.status == .notDetermined ? "Apple requires Location Services to reveal nearby Wi-Fi network names (SSIDs)." : "Open System Settings > Privacy & Security to enable SSID disclosure.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if locationHelper.status == .notDetermined {
                                locationHelper.requestAuthorizationIfNeeded()
                            } else {
                                locationHelper.openSystemSettings()
                            }
                        }) {
                            Text(locationHelper.status == .notDetermined ? "Authorize" : "Settings")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(locationHelper.status == .notDetermined ? .blue : .orange)
                        .controlSize(.mini)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        (locationHelper.status == .notDetermined ? Color.blue : Color.orange)
                            .opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                (locationHelper.status == .notDetermined ? Color.blue : Color.orange).opacity(0.25),
                                lineWidth: 0.8
                            )
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                
                // Band Filter Pills
                HStack(spacing: 6) {
                    BandPill(title: "All", isSelected: selectedBand == nil) {
                        selectedBand = nil
                    }
                    BandPill(title: "2.4 GHz", isSelected: selectedBand == "2.4 GHz") {
                        selectedBand = "2.4 GHz"
                    }
                    BandPill(title: "5 GHz", isSelected: selectedBand == "5 GHz") {
                        selectedBand = "5 GHz"
                    }
                    BandPill(title: "6 GHz", isSelected: selectedBand == "6 GHz") {
                        selectedBand = "6 GHz"
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial.opacity(0.6))
                
                Divider().opacity(0.4)
                
                // Networks List
                if filteredNetworks.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 64, height: 64)
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(spacing: 4) {
                            Text("No Wi-Fi Networks Found")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text("Click 'Scan Wi-Fi' to survey wireless channels.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Scan Nearby Networks") {
                            scannerService.scanNearbyNetworks()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.small)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(filteredNetworks, selection: $selectedNetwork) { net in
                        WiFiNetworkRow(network: net)
                            .tag(net)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 330, idealWidth: 370, maxWidth: 440)
            
            // Right Column: Detail Inspector
            Group {
                if let net = selectedNetwork {
                    WiFiDetailPane(network: net)
                        .id(net.id)
                } else {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 80, height: 80)
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 38, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        
                        Text("Select an Access Point")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Select any wireless network from the list to survey channel interference, RSSI signal levels, and security standards.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .frame(maxWidth: 320)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            scannerService.scanNearbyNetworks()
        }
    }
}

// MARK: - Band Pill

struct BandPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 4.5)
                .background(isSelected ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.06))
                .foregroundColor(isSelected ? .accentColor : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Wi-Fi Network Row

struct WiFiNetworkRow: View {
    let network: ScannedWiFiNetwork
    
    var body: some View {
        HStack(spacing: 12) {
            // Signal Strength Visual Icon & dBm in glass tile
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(signalColor(for: network.rssi).opacity(0.15))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(signalColor(for: network.rssi).opacity(0.35), lineWidth: 0.8)
                    }
                
                VStack(spacing: 2) {
                    Image(systemName: signalIcon(for: network.rssi))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(signalColor(for: network.rssi))
                    Text("\(network.rssi)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(signalColor(for: network.rssi))
                }
            }
            .frame(width: 38, height: 38)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(network.ssid)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(network.ssid.hasPrefix("<") ? .secondary : .primary)
                        .lineLimit(1)
                    
                    if network.ssid == "<Requires Location Permission>" {
                        Text("Location Needed")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.orange.opacity(0.18))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    } else if network.ssid == "<Hidden Network>" {
                        Text("Cloaked")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.gray.opacity(0.18))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                    }
                    
                    if network.isCurrentNetwork {
                        Text("Connected")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Color.green.opacity(0.18))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 6) {
                    Text(network.band)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("CH \(network.channel) (\(network.channelWidth))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(network.security)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Liquid Signal Quality Bar
                LiquidProgressBar(
                    value: Double(network.signalQualityPercentage) / 100.0,
                    height: 3,
                    gradientColors: [signalColor(for: network.rssi).opacity(0.7), signalColor(for: network.rssi)]
                )
                .padding(.top, 2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(network.signalQualityPercentage)%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(signalColor(for: network.rssi))
                
                Text(network.phyMode)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func signalColor(for rssi: Int) -> Color {
        if rssi >= -60 { return .green }
        if rssi >= -72 { return .blue }
        if rssi >= -82 { return .orange }
        return .red
    }
    
    private func signalIcon(for rssi: Int) -> String {
        if rssi >= -60 { return "wifi" }
        if rssi >= -72 { return "wifi" }
        if rssi >= -82 { return "wifi.exclamationmark" }
        return "wifi.slash"
    }
}

// MARK: - Detailed 3rd-Level Wi-Fi Detail Inspector

public struct WiFiDetailPane: View {
    public let network: ScannedWiFiNetwork
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header Glass Card
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.blue.opacity(0.18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.blue.opacity(0.35), lineWidth: 1)
                            }
                        Image(systemName: "wifi")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .frame(width: 60, height: 60)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(network.ssid)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            if network.isCurrentNetwork {
                                Text("Active Connection")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundColor(.green)
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(network.band) Wireless Access Point")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .liquidGlass(cornerRadius: 16, elevation: 1.5)
                
                // RF Signal Health Grid (Adaptive layout)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    MetricCard(
                        title: "Signal (RSSI)",
                        value: "\(network.rssi) dBm",
                        icon: "antenna.radiowaves.left.and.right",
                        color: .blue,
                        subtitle: "Quality: \(network.signalQualityPercentage)%"
                    )
                    
                    MetricCard(
                        title: "Noise Floor",
                        value: "\(network.noise) dBm",
                        icon: "waveform",
                        color: .gray,
                        subtitle: "Interference: \(network.noise < -90 ? "Low" : "Elevated")"
                    )
                    
                    MetricCard(
                        title: "Calculated SNR",
                        value: "\(network.snr) dB",
                        icon: "chart.bar.fill",
                        color: network.snr >= 25 ? .green : (network.snr >= 15 ? .yellow : .red),
                        subtitle: network.snr >= 25 ? "Optimal Link" : (network.snr >= 15 ? "Fair" : "Degraded")
                    )
                }
                
                // Technical Specifications Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Wireless Access Point Parameters")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    
                    DetailField(label: "SSID Network Name", value: network.ssid, copyable: true)
                    if !network.bssid.isEmpty {
                        DetailField(label: "BSSID (MAC Address)", value: network.bssid, copyable: true)
                        DetailField(label: "OUI Hardware Manufacturer", value: network.vendor)
                    }
                    DetailField(label: "Channel Number", value: "\(network.channel)")
                    DetailField(label: "Frequency Band", value: network.band)
                    DetailField(label: "Channel Bandwidth", value: network.channelWidth)
                    DetailField(label: "PHY Standard Mode", value: network.phyMode)
                    DetailField(label: "Security Protocol", value: network.security)
                }
                .padding(16)
                .liquidGlass(cornerRadius: 16, elevation: 1)
            }
            .padding(20)
        }
        .navigationTitle(network.ssid)
    }
}

#endif
