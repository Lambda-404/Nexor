#if os(macOS)
import SwiftUI
import AppKit

public struct MenuBarPopoverView: View {
    @Environment(\.openWindow) private var openWindow
    
    private var mediumDetector = NetworkMediumDetector.shared
    private var trafficManager = TrafficTelemetryManager.shared
    @State private var lanDiscovery = LANDiscoveryService.shared
    
    @State private var isPerformingSweep: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            // Header: App Title, Real-Time Status Pill
            HStack(alignment: .center) {
                HStack(spacing: 7) {
                    Image(systemName: "network")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.cyan)
                        .frame(width: 16, height: 16, alignment: .center)
                    Text("Nexor")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                Spacer()
                
                let isConnected = (mediumDetector.primaryAdapter?.connectionState == .active)
                LiquidGlassPill(
                    text: isConnected ? "Connected" : "Offline",
                    icon: isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    color: isConnected ? .green : .orange,
                    isFilled: true
                )
            }
            .padding(.horizontal, 2)
            
            Divider().opacity(0.15)
            
            // Section 1: Active Medium (Wired Ethernet vs. Wireless Wi-Fi)
            let primary = mediumDetector.primaryAdapter
            let isWired = (primary?.medium == .wiredEthernet)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 7) {
                    Image(systemName: isWired ? "cable.connector" : "wifi")
                        .foregroundColor(isWired ? .green : .cyan)
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 16, height: 16, alignment: .center)
                    Text(isWired ? "Wired Ethernet" : (primary?.medium == .wifi ? "Wireless Wi-Fi" : "Active Medium"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Spacer()
                    Text(primary?.bsdName ?? "en0")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    if isWired {
                        PopoverKVRow(label: "Adapter", value: primary?.displayName ?? "Ethernet Adapter")
                        PopoverKVRow(label: "Link Speed", value: primary?.linkSpeedDescription ?? "Auto-negotiating")
                        PopoverKVRow(label: "MAC", value: primary?.macAddress ?? "--", isMonospaced: true)
                    } else {
                        let ssid = primary?.wifiSSID ?? (RFTelemetryService.shared.fetchMetrics().ssid)
                        let bssid = primary?.wifiBSSID ?? (RFTelemetryService.shared.fetchMetrics().bssid)
                        let rssi = primary?.wifiRSSI ?? (RFTelemetryService.shared.fetchMetrics().rssi)
                        let noise = primary?.wifiNoise ?? (RFTelemetryService.shared.fetchMetrics().noise)
                        let snr = primary?.wifiSNR ?? (RFTelemetryService.shared.fetchMetrics().snr)
                        
                        PopoverKVRow(label: "SSID", value: bssid != "--" ? "\(ssid) (\(bssid))" : ssid)
                        PopoverKVRow(label: "Signal", value: rssi != 0 ? "\(rssi) dBm / \(noise) dBm (\(snr) dB)" : "Wi-Fi Active", isMonospaced: true)
                        if let mac = primary?.macAddress {
                            PopoverKVRow(label: "MAC", value: mac, isMonospaced: true)
                        }
                    }
                }
            }
            .padding(11)
            .liquidGlass(cornerRadius: 12, elevation: 1)
            
            // Section 2: Real-Time Bandwidth & Session Volume
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 7) {
                    Image(systemName: "arrow.up.and.down.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 16, height: 16, alignment: .center)
                    Text("Bandwidth & Session Volume")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Spacer()
                    Button(action: {
                        trafficManager.resetSession()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 9))
                            Text("Reset")
                                .font(.system(size: 9, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                
                HStack(alignment: .center, spacing: 0) {
                    // Upload Column
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up")
                                .foregroundColor(.orange)
                                .font(.system(size: 8.5, weight: .bold))
                            Text("Upload").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        Text(trafficManager.uploadSpeedFormatted)
                            .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .lineLimit(1)
                        Text("Sent: \(trafficManager.sessionSentFormatted)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .frame(height: 36)
                        .opacity(0.25)
                        .padding(.horizontal, 8)
                    
                    // Download Column
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down")
                                .foregroundColor(.cyan)
                                .font(.system(size: 8.5, weight: .bold))
                            Text("Download").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        Text(trafficManager.downloadSpeedFormatted)
                            .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .lineLimit(1)
                        Text("Rcvd: \(trafficManager.sessionReceivedFormatted)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Real-time sparkline graph (fills card width automatically)
                MenuBarSparklineView(
                    downloadHistory: trafficManager.downloadHistory,
                    uploadHistory: trafficManager.uploadHistory,
                    width: nil,
                    height: 28
                )
                .frame(height: 28)
                .frame(maxWidth: .infinity)
            }
            .padding(11)
            .liquidGlass(cornerRadius: 12, elevation: 1)
            
            // Section 3: Addressing & Gateway
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 7) {
                    Image(systemName: "point.filled.topleft.down.curvedto.point.bottomright.up")
                        .foregroundColor(.indigo)
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 16, height: 16, alignment: .center)
                    Text("Addressing & Gateway")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Spacer()
                }
                
                let localIP = primary?.ipv4Address ?? "Resolving..."
                let mask = primary?.subnetMask ?? "--"
                let localIPv6 = primary?.ipv6Address ?? ""
                let gateway = primary?.gatewayAddress ?? mediumDetector.defaultGateway
                
                VStack(alignment: .leading, spacing: 5) {
                    PopoverKVRow(label: "Local IPv4", value: mask != "--" ? "\(localIP) / \(mask)" : localIP, isMonospaced: true)
                    if !localIPv6.isEmpty {
                        PopoverKVRow(label: "Local IPv6", value: localIPv6, isMonospaced: true)
                    }
                    PopoverKVRow(label: "Gateway", value: gateway, isMonospaced: true)
                }
            }
            .padding(11)
            .liquidGlass(cornerRadius: 12, elevation: 1)
            
            Divider().opacity(0.15)
            
            // Section 4: Quick Action Buttons (Uniform height & vertical alignment)
            HStack(spacing: 8) {
                Button(action: openMainWindow) {
                    HStack(spacing: 5) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 11, weight: .medium))
                        Text("Main Window")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Button(action: performQuickSubnetSweep) {
                    HStack(spacing: 5) {
                        if isPerformingSweep || lanDiscovery.isSweeping {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 11, weight: .medium))
                                .frame(width: 12, height: 12)
                        }
                        Text(lanDiscovery.isSweeping ? "Sweeping..." : "Subnet Sweep")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isPerformingSweep || lanDiscovery.isSweeping)
                
                Button(action: quitApp) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red.opacity(0.85))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Quit Nexor")
            }
        }
        .padding(14)
        .frame(width: 350)
        .background {
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                Circle()
                    .fill(Color.cyan.opacity(0.06))
                    .frame(width: 250, height: 250)
                    .position(x: 40, y: 30)
                    .blur(radius: 40)
            }
        }
    }
    
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "mainWindow")
        }
    }
    
    private func performQuickSubnetSweep() {
        isPerformingSweep = true
        lanDiscovery.triggerSubnetSweep()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.isPerformingSweep = false
        }
    }
    
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Popover Key-Value Row Component

struct PopoverKVRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 66, alignment: .leading)
            
            Text(value)
                .font(isMonospaced ? .system(size: 10.5, weight: .medium, design: .monospaced) : .system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(1)
            
            Spacer()
        }
    }
}


#endif
