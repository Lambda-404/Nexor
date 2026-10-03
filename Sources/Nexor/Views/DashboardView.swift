#if os(macOS)
import SwiftUI
import CoreWLAN
import SystemConfiguration

public struct DashboardView: View {
    @State private var ssid: String = "Detecting..."
    @State private var bssid: String = "--"
    @State private var localIP: String = "Resolving..."
    @State private var subnetMask: String = "--"
    @State private var gateway: String = "Resolving..."
    @State private var rssi: Int = 0
    @State private var noise: Int = 0
    @State private var snr: Int = 0
    @State private var txRate: Double = 0.0
    @State private var channelInfo: String = "Detecting..."
    @State private var mcsIndex: Int = 0
    @State private var interfaceName: String = "en0"
    @State private var isRefreshing: Bool = false
    @State private var refreshTimer: Timer?
    
    private var mediumDetector = NetworkMediumDetector.shared
    private var trafficManager = TrafficTelemetryManager.shared
    @State private var discoveryService = LANDiscoveryService.shared
    @State private var wifiScanner = WiFiScannerService.shared
    @State private var bluetoothService = BluetoothDiscoveryService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header with live refresh button & status
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Network Overview")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("Real-time dual-medium telemetry, physical layer negotiation, and bandwidth statistics")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            PulsingBeacon(color: .green, size: 7)
                            let badgeText: String = {
                                if mediumDetector.isWiredEthernetActive && mediumDetector.isWiFiActive {
                                    return "DUAL-MEDIUM (ETHERNET & WI-FI)"
                                } else if mediumDetector.isWiredEthernetActive {
                                    return "WIRED ETHERNET ACTIVE"
                                } else {
                                    return "COREWLAN & BPF ACTIVE"
                                }
                            }()
                            Text(badgeText)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .liquidGlass(cornerRadius: 10, elevation: 1)
                        
                        Button(action: refreshMetrics) {
                            HStack(spacing: 6) {
                                if isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.55)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                Text("Refresh")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRefreshing)
                    }
                }
                
                // Topology Glass Bar: This Device -> Active Link -> Gateway -> WAN
                let primary = mediumDetector.primaryAdapter
                let isWired = (primary?.medium == .wiredEthernet)
                
                HStack(spacing: 12) {
                    // Node 1: Local Device
                    HStack(spacing: 8) {
                        Image(systemName: "laptopcomputer")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("This Device")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(localIP)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .liquidGlass(cornerRadius: 10, elevation: 1)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    // Node 2: Active Medium (Wired vs. Wireless)
                    HStack(spacing: 8) {
                        Image(systemName: isWired ? "cable.connector" : "wifi")
                            .foregroundColor(isWired ? .green : .cyan)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isWired ? "Wired Ethernet" : "Wi-Fi SSID")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(isWired ? (primary?.displayName ?? primary?.bsdName ?? "Ethernet") : ssid)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .liquidGlass(cornerRadius: 10, elevation: 1)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    // Node 3: Default Gateway
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.router")
                            .foregroundColor(.orange)
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Default Router")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(gateway)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .liquidGlass(cornerRadius: 10, elevation: 1)
                    
                    Spacer()
                    
                    // Live Status Pill
                    HStack(spacing: 6) {
                        if isWired {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Wired Link Active")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        } else {
                            Circle()
                                .fill(snr >= 15 ? Color.green : (snr > 0 ? Color.orange : Color.gray))
                                .frame(width: 8, height: 8)
                            Text(snr >= 25 ? "Optimal Link" : (snr >= 15 ? "Good Link" : (snr > 0 ? "Degraded" : "Connecting")))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(snr >= 15 ? .green : (snr > 0 ? .orange : .secondary))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .liquidGlass(cornerRadius: 10, elevation: 1)
                }
                
                // Degraded Wi-Fi Alert (only if Wi-Fi is active and SNR < 15)
                if !isWired && snr < 15 && snr > 0 && rssi != 0 {
                    HStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Degraded Wi-Fi Link Quality (SNR < 15 dB)")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text("The current Signal-to-Noise Ratio is \(snr) dB. Packet jitter or latency spikes may occur due to environmental RF noise.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .liquidGlass(cornerRadius: 12, elevation: 1)
                }
                
                // Section 1: Core Connection & Hardware Identity Cards (R1)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connection & Medium Identity")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    
                    HStack(spacing: 14) {
                        MetricCard(
                            title: isWired ? "Primary Medium" : "Wi-Fi SSID",
                            value: isWired ? "Wired Ethernet" : ssid,
                            icon: isWired ? "cable.connector" : "wifi",
                            color: isWired ? .green : .blue,
                            subtitle: isWired ? "\(primary?.displayName ?? "Adapter") (\(primary?.bsdName ?? interfaceName))" : (bssid != "--" ? "BSSID: \(bssid)" : "Active Wi-Fi Link")
                        )
                        
                        MetricCard(
                            title: isWired ? "Negotiated Link Rate" : "Local IPv4",
                            value: isWired ? (primary?.linkSpeedMbps != nil ? (primary!.linkSpeedMbps! >= 1000 ? "\(String(format: "%.1f", primary!.linkSpeedMbps! / 1000)) Gbps" : "\(Int(primary!.linkSpeedMbps!)) Mbps") : "Link Up") : localIP,
                            icon: isWired ? "speedometer" : "network",
                            color: isWired ? .teal : .teal,
                            subtitle: isWired ? "\(primary?.isFullDuplex == true ? "Full-Duplex" : "Half-Duplex") • MTU \(primary?.mtu ?? 1500)" : (subnetMask != "--" ? "Mask: \(subnetMask)" : "Interface: \(interfaceName)")
                        )
                        
                        MetricCard(
                            title: "Hardware MAC & Router",
                            value: primary?.macAddress ?? "--",
                            icon: "cpu",
                            color: .orange,
                            subtitle: "Gateway: \(gateway)"
                        )
                    }
                }
                
                // Section 2: Real-time Bandwidth & Traffic Statistics (R2)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Live Bandwidth & Session Traffic")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Spacer()
                        Button(action: {
                            trafficManager.resetSession()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10))
                                Text("Reset Session")
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    HStack(spacing: 14) {
                        MetricCard(
                            title: "Upload Speed (Tx)",
                            value: trafficManager.uploadSpeedFormatted,
                            icon: "arrow.up.circle.fill",
                            color: .orange,
                            subtitle: "Session Sent: \(trafficManager.sessionSentFormatted)"
                        )
                        
                        MetricCard(
                            title: "Download Speed (Rx)",
                            value: trafficManager.downloadSpeedFormatted,
                            icon: "arrow.down.circle.fill",
                            color: .cyan,
                            subtitle: "Session Received: \(trafficManager.sessionReceivedFormatted)"
                        )
                        
                        // Mini throughput graph card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Throughput History")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(trafficManager.downloadHistory.count)s trend")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            MenuBarSparklineView(
                                downloadHistory: trafficManager.downloadHistory,
                                uploadHistory: trafficManager.uploadHistory,
                                width: 220,
                                height: 32
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                            
                            HStack {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.cyan).frame(width: 6, height: 6)
                                    Text("Download").font(.system(size: 9)).foregroundColor(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 4) {
                                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                                    Text("Upload").font(.system(size: 9)).foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlass(cornerRadius: 14, elevation: 1)
                    }
                }
                
                // Section 3: Physical Layer Telemetry (Wired vs Wireless)
                if isWired {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Wired Physical Layer & Adapter Specifications")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Spacer()
                            Text("BSD ioctl & SystemConfiguration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 14) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.green.opacity(0.15))
                                    Image(systemName: "cable.connector")
                                        .foregroundColor(.green)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .frame(width: 32, height: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("PHY Negotiation & Duplex")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(primary?.linkSpeedDescription ?? "Auto-negotiated Link")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .liquidGlass(cornerRadius: 12, elevation: 1)
                            
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.15))
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .frame(width: 32, height: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Frame MTU & State")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text("MTU \(primary?.mtu ?? 1500) bytes • \(primary?.connectionState.rawValue ?? "Active")")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .liquidGlass(cornerRadius: 12, elevation: 1)
                        }
                        
                        // If Wi-Fi is also active as a co-existing adapter, show its link overview
                        if let wifi = mediumDetector.coexistingWiFiAdapter, wifi.bsdName != primary?.bsdName {
                            HStack(spacing: 12) {
                                Image(systemName: "wifi")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Co-existing Wi-Fi Link (\(wifi.bsdName))")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                    Text("SSID: \(ssid) • RSSI: \(rssi != 0 ? "\(rssi) dBm" : "--") • SNR: \(snr > 0 ? "\(snr) dB" : "--")")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(wifi.ipv4Address != nil ? wifi.ipv4Address! : "Configured")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .padding(10)
                            .liquidGlass(cornerRadius: 10, elevation: 0.5)
                        }
                    }
                } else {
                    // Wi-Fi RF Signal Health Cards (Physical Layer)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Wireless RF Health (Physical Layer)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                            Spacer()
                            Text("CoreWLAN Hardware Telemetry")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 14) {
                            MetricCard(
                                title: "Signal (RSSI)",
                                value: rssi != 0 ? "\(rssi) dBm" : "--",
                                icon: "antenna.radiowaves.left.and.right",
                                color: .purple,
                                subtitle: rssi >= -60 && rssi != 0 ? "Excellent (-40 to -60 dBm)" : (rssi >= -75 && rssi != 0 ? "Good (-61 to -75 dBm)" : (rssi != 0 ? "Weak (< -75 dBm)" : "Offline"))
                            )
                            
                            MetricCard(
                                title: "Noise Floor",
                                value: noise != 0 ? "\(noise) dBm" : "--",
                                icon: "waveform",
                                color: .gray,
                                subtitle: "Ambient Electro-Magnetic Noise"
                            )
                            
                            MetricCard(
                                title: "Signal-to-Noise (SNR)",
                                value: snr > 0 ? "\(snr) dB" : "--",
                                icon: "chart.bar.fill",
                                color: snr >= 25 ? .green : (snr >= 15 ? .yellow : .red),
                                subtitle: snr >= 25 ? "Optimal (> 25 dB)" : (snr >= 15 ? "Fair (15-25 dB)" : (snr > 0 ? "Degraded (< 15 dB)" : "No RF Signal"))
                            )
                        }
                        
                        // Hardware PHY Detail Bar
                        HStack(spacing: 14) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.15))
                                    Image(systemName: "wave.3.forward")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .frame(width: 32, height: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Physical Channel & Bandwidth")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(channelInfo)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .liquidGlass(cornerRadius: 12, elevation: 1)
                            
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.green.opacity(0.15))
                                    Image(systemName: "speedometer")
                                        .foregroundColor(.green)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .frame(width: 32, height: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("PHY Negotiated Rate")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(txRate > 0 ? "\(String(format: "%.0f", txRate)) Mbps (MCS \(mcsIndex))" : "--")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .liquidGlass(cornerRadius: 12, elevation: 1)
                        }
                    }
                }
                
                // Section 4: Workspace Navigation Tiles
                VStack(alignment: .leading, spacing: 12) {
                    Text("Workspace Quick Access")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        // LAN Scanner Card
                        NavigationLink(value: SidebarItem.lanDevices) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.blue.opacity(0.18))
                                    Image(systemName: "network")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                .frame(width: 44, height: 44)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("LAN Devices Scanner")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(discoveryService.devices.count)")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.2))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                    }
                                    Text("Zero-packet passive BPF, Dual-stack ARP/NDP, and Apple TXT extraction")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .liquidGlass(cornerRadius: 14, elevation: 1.5)
                        }
                        .buttonStyle(.plain)
                        
                        // Wi-Fi Radar Card
                        NavigationLink(value: SidebarItem.wifiRadar) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.purple.opacity(0.18))
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.title2)
                                        .foregroundColor(.purple)
                                }
                                .frame(width: 44, height: 44)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("Wi-Fi Radar")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(wifiScanner.networks.count)")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Color.purple.opacity(0.2))
                                            .foregroundColor(.purple)
                                            .clipShape(Capsule())
                                    }
                                    Text("Survey nearby APs, signal strength, channel spectrum & interference")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .liquidGlass(cornerRadius: 14, elevation: 1.5)
                        }
                        .buttonStyle(.plain)
                        
                        // Bluetooth Radar Card
                        NavigationLink(value: SidebarItem.bluetoothRadar) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.teal.opacity(0.18))
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .font(.title2)
                                        .foregroundColor(.teal)
                                }
                                .frame(width: 44, height: 44)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("Bluetooth Radar")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(bluetoothService.devices.count)")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Color.teal.opacity(0.2))
                                            .foregroundColor(.teal)
                                            .clipShape(Capsule())
                                    }
                                    Text("Full-spectrum 2.4 GHz BLE & Classic RF, Apple Beacon dissection, RSSI tracking")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .liquidGlass(cornerRadius: 14, elevation: 1.5)
                        }
                        .buttonStyle(.plain)
                        
                        // Network Tools Card
                        NavigationLink(value: SidebarItem.networkTools) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.orange.opacity(0.18))
                                    Image(systemName: "wrench.and.screwdriver")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                }
                                .frame(width: 44, height: 44)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("Network Diagnostics")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("9 Tools")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .clipShape(Capsule())
                                    }
                                    Text("Ping, Traceroute, Port Scan, iPerf, Subnet, WOL")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .liquidGlass(cornerRadius: 14, elevation: 1.5)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .onAppear {
            refreshMetrics()
            refreshTimer?.invalidate()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                refreshMetrics()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
    
    private func refreshMetrics() {
        Task.detached {
            let metrics = RFTelemetryService.shared.fetchMetrics()
            let adapters = NetworkMediumDetector.detectAllAdaptersSync()
            let primary = adapters.first(where: { $0.isPrimary }) ?? adapters.first
            
            let localAddress = primary?.ipv4Address ?? "--"
            let mask = primary?.subnetMask ?? "--"
            let activeIface = primary?.bsdName ?? "en0"
            let defaultGateway = primary?.gatewayAddress ?? self.resolveDefaultGateway()
            
            let channelText: String
            if let ch = metrics.channel, !ch.isEmpty {
                if let width = metrics.channelWidthMHz {
                    channelText = "Channel \(ch) (\(width) MHz)"
                } else {
                    channelText = "Channel \(ch)"
                }
            } else {
                channelText = "--"
            }
            
            await MainActor.run {
                self.ssid = metrics.ssid
                self.bssid = metrics.bssid
                self.rssi = metrics.rssi
                self.noise = metrics.noise
                self.snr = metrics.snr
                self.txRate = metrics.txRate
                self.channelInfo = channelText
                self.mcsIndex = metrics.mcsIndex ?? 0
                self.localIP = localAddress
                self.subnetMask = mask
                self.gateway = defaultGateway
                self.interfaceName = activeIface
                self.mediumDetector.refresh()
            }
        }
    }
    
    private nonisolated func resolveDefaultGateway() -> String {
        let (_, gw) = NetworkMediumDetector.resolvePrimaryInterface()
        if let gw = gw, !gw.isEmpty {
            return gw
        }
        return "--"
    }
}

#endif
