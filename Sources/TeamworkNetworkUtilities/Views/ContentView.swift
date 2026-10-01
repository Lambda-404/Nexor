import SwiftUI

public enum SidebarItem: String, Identifiable, CaseIterable, Sendable {
    case dashboard = "Dashboard"
    case lanDevices = "LAN Devices"
    case wifiRadar = "Wi-Fi Radar"
    case bluetoothRadar = "Bluetooth Radar"
    case networkTools = "Network Tools"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .dashboard:
            return "gauge.with.dots.needle.33percent"
        case .lanDevices:
            return "network"
        case .wifiRadar:
            return "antenna.radiowaves.left.and.right"
        case .bluetoothRadar:
            return "dot.radiowaves.left.and.right"
        case .networkTools:
            return "wrench.and.screwdriver"
        case .settings:
            return "gearshape"
        }
    }
}

public struct ContentView: View {
    @State private var selection: SidebarItem? = .dashboard
    @State private var discoveryService = LANDiscoveryService.shared
    @State private var wifiScanner = WiFiScannerService.shared
    @State private var bluetoothService = BluetoothDiscoveryService.shared
    @Environment(\.diagnosticManager) private var diagnosticManager: DiagnosticExecutionManager
    
    @State private var runningTaskCount: Int = 0
    @State private var taskCheckTimer: Timer?
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                NavigationLink(value: item) {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(item == selection ? .accentColor : .secondary)
                            .frame(width: 22)
                        
                        Text(item.rawValue)
                            .font(.system(size: 13, weight: item == selection ? .semibold : .regular, design: .rounded))
                        
                        Spacer()
                        
                        // Dynamic liquid glass badges
                        switch item {
                        case .lanDevices:
                            HStack(spacing: 5) {
                                if discoveryService.isListening {
                                    PulsingBeacon(color: .green, size: 6)
                                }
                                Text("\(discoveryService.devices.count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(discoveryService.devices.isEmpty ? .secondary : .primary)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
                            )
                            
                        case .wifiRadar:
                            HStack(spacing: 5) {
                                if wifiScanner.isScanning {
                                    ProgressView()
                                        .scaleEffect(0.4)
                                }
                                Text("\(wifiScanner.networks.count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.blue.opacity(0.25), lineWidth: 0.8)
                            )
                            
                        case .bluetoothRadar:
                            HStack(spacing: 5) {
                                if bluetoothService.isScanning {
                                    PulsingBeacon(color: .teal, size: 6)
                                }
                                Text("\(bluetoothService.devices.count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.teal)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.teal.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.teal.opacity(0.25), lineWidth: 0.8)
                            )
                            
                        case .networkTools:
                            if runningTaskCount > 0 {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.45)
                                    Text("\(runningTaskCount) Active")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 0.8)
                                    )
                            } else {
                                Text("9")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                            
                        case .dashboard:
                            EmptyView()
                        case .settings:
                            EmptyView()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Nexor")
            .listStyle(.sidebar)
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 250)
        } detail: {
            ZStack {
                LiquidAmbientMesh()
                
                Group {
                    switch selection {
                    case .dashboard:
                        DashboardView()
                    case .lanDevices:
                        LANDevicesView()
                    case .wifiRadar:
                        WiFiRadarView()
                    case .bluetoothRadar:
                        BluetoothRadarView()
                    case .networkTools:
                        NetworkToolsView()
                    case .settings:
                        SettingsView()
                    case .none:
                        VStack(spacing: 16) {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 44, weight: .light))
                                .foregroundColor(.secondary.opacity(0.7))
                            Text("Select a section from the sidebar")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.99)))
                .animation(.easeInOut(duration: 0.2), value: selection)
            }
            .frame(minWidth: 760, minHeight: 620)
        }
        .frame(minWidth: 1000, minHeight: 680)
        .onAppear {
            startTaskStatusPolling()
        }
        .onDisappear {
            taskCheckTimer?.invalidate()
            taskCheckTimer = nil
        }
    }
    
    private func startTaskStatusPolling() {
        taskCheckTimer?.invalidate()
        taskCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task {
                let ids = await diagnosticManager.getRunningTaskIDs()
                await MainActor.run {
                    self.runningTaskCount = ids.count
                }
            }
        }
    }
}
