import SwiftUI
import AppKit

public struct LANDevicesView: View {
    @State private var discoveryService = LANDiscoveryService.shared
    @State private var selectedDevice: LANDevice?
    @State private var searchText: String = ""
    @State private var selectedCategory: DeviceCategory? = nil
    @State private var exportToast: String? = nil
    
    public init() {}
    
    public var filteredDevices: [LANDevice] {
        var result = discoveryService.devices
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.hostname.localizedCaseInsensitiveContains(searchText) ||
                $0.ipAddress.contains(searchText) ||
                ($0.ipv6Address?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.macAddress.localizedCaseInsensitiveContains(searchText) ||
                $0.vendor.localizedCaseInsensitiveContains(searchText) ||
                ($0.modelName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.appleModelID?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.netbiosWorkgroup?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.services.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
        return result
    }
    
    public var body: some View {
        HSplitView {
            // Left Column: Devices List & Filters
            VStack(spacing: 0) {
                // Header status bar
                VStack(spacing: 8) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("\(discoveryService.devices.count) Devices")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                
                                if discoveryService.isListening {
                                    HStack(spacing: 4) {
                                        PulsingBeacon(color: .green, size: 6)
                                        Text("LIVE")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .foregroundColor(.green)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2.5)
                                    .background(Color.green.opacity(0.12))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.green.opacity(0.25), lineWidth: 0.8)
                                    )
                                }
                            }
                            
                            Text(discoveryService.isSweeping ? "Sweeping 254 subnet hosts..." : "ARP, IPv6 NDP & mDNS")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 8)
                        
                        HStack(spacing: 6) {
                            // Subnet Sweep Button
                            Button(action: {
                                discoveryService.triggerSubnetSweep()
                            }) {
                                HStack(spacing: 4) {
                                    if discoveryService.isSweeping {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                    } else {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    Text(discoveryService.isSweeping ? "Sweeping" : "Sweep")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .controlSize(.small)
                            .disabled(discoveryService.isSweeping)
                            .fixedSize()
                            .help("Concurrently ping and wake all 254 subnet hosts to harvest active devices")
                            
                            // Export Menu
                            Menu {
                                Button("Copy as JSON") {
                                    copyToClipboard(discoveryService.exportAsJSON(), label: "JSON copied")
                                }
                                Button("Copy as CSV") {
                                    copyToClipboard(discoveryService.exportAsCSV(), label: "CSV copied")
                                }
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .fixedSize()
                        }
                    }
                    
                    // Liquid Sweep progress bar if sweeping
                    if discoveryService.isSweeping {
                        VStack(spacing: 3) {
                            LiquidProgressBar(value: discoveryService.sweepProgress, height: 3, gradientColors: [.blue, .cyan])
                            HStack {
                                Text("Probing 254 subnet addresses")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(discoveryService.sweepProgress * 100))%")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    // Inline Glass Search Field
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        TextField("Search Hostname, IP, MAC, Model...", text: $searchText)
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
                
                Divider()
                    .opacity(0.4)
                
                // Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterPill(title: "All", count: discoveryService.devices.count, isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        
                        ForEach(DeviceCategory.allCases) { cat in
                            let count = discoveryService.devices.filter { $0.category == cat }.count
                            if count > 0 {
                                FilterPill(title: cat.rawValue, count: count, isSelected: selectedCategory == cat) {
                                    selectedCategory = cat
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .background(.ultraThinMaterial.opacity(0.6))
                
                Divider()
                    .opacity(0.4)
                
                // Device List
                if filteredDevices.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 64, height: 64)
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(spacing: 4) {
                            Text("No Devices Discovered")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text("Click 'Sweep' to probe the local subnet.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Start Subnet Sweep") {
                            discoveryService.triggerSubnetSweep()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.small)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(selection: $selectedDevice) {
                        ForEach(DeviceCategory.allCases) { cat in
                            let catDevices = filteredDevices.filter { $0.category == cat }
                            if !catDevices.isEmpty {
                                Section(header: Label(cat.rawValue, systemImage: cat.icon).font(.system(size: 10.5, weight: .semibold, design: .rounded)).foregroundColor(.secondary)) {
                                    ForEach(catDevices) { device in
                                        DeviceRowView(device: device)
                                            .tag(device)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 330, idealWidth: 370, maxWidth: 440)
            
            // Right Column: Device Detail Inspector
            Group {
                if let device = selectedDevice {
                    DeviceDetailPane(device: device)
                        .id(device.id)
                } else {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 80, height: 80)
                            Image(systemName: "network")
                                .font(.system(size: 38, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        
                        Text("Select a Device")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Select any host from the list to inspect hardware models, IPv6 NDP addresses, open ports, and live packet frames.")
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
            discoveryService.startListening()
            if discoveryService.devices.count <= 1 && !discoveryService.isSweeping {
                discoveryService.triggerSubnetSweep()
            }
        }
        .onDisappear {
            discoveryService.stopListening()
        }
    }
    
    private func copyToClipboard(_ text: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Filter Pill Component

struct FilterPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
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

// MARK: - Device Row View

struct DeviceRowView: View {
    let device: LANDevice
    
    private var categoryColor: Color {
        switch device.category {
        case .gateway: return .orange
        case .apple: return .purple
        case .computers: return .blue
        case .smartIoT: return .teal
        case .gaming: return .pink
        case .unknown: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon with liquid glass tile
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(categoryColor.opacity(0.18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(categoryColor.opacity(0.35), lineWidth: 0.8)
                    }
                
                Image(systemName: device.category.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(categoryColor)
            }
            .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.hostname)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    
                    if device.isRandomizedMAC {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                            .help("Private MAC Address (IEEE 802 Locally Administered)")
                    }
                    
                    if let rtt = device.latencyMS {
                        Text(String(format: "%.1f ms", rtt))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 6) {
                    Text(device.modelName ?? device.vendor)
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.8))
                        .lineLimit(1)
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(device.ipAddress.isEmpty ? (device.ipv6Address ?? "No IP") : device.ipAddress)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                // Badges row: Apple Model ID, Services, or Open Ports
                HStack(spacing: 4) {
                    if let modelID = device.appleModelID {
                        Text(modelID)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                    }
                    
                    if let workgroup = device.netbiosWorkgroup {
                        Text("SMB:\(workgroup)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.teal.opacity(0.15))
                            .foregroundColor(.teal)
                            .clipShape(Capsule())
                    }
                    
                    ForEach(device.services.prefix(2), id: \.self) { svc in
                        Text(svc)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text(device.protocolType)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                
                Text(device.lastSeen.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detailed 3rd-Level Device Pane with Live Interactive Tools

public struct DeviceDetailPane: View {
    public let device: LANDevice
    @State private var liveLatency: Double? = nil
    @State private var inferredOS: String? = nil
    @State private var isPinging: Bool = false
    @State private var probedPorts: [Int] = []
    @State private var isPortScanning: Bool = false
    @State private var wolStatus: String? = nil
    @State private var smbStatus: String? = nil
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header Glass Card
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentColor.opacity(0.18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                            }
                        Image(systemName: device.category.icon)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    .frame(width: 60, height: 60)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.hostname)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(device.modelName ?? device.vendor)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if device.isRandomizedMAC {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.orange)
                            Text("Private MAC")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .liquidGlass(cornerRadius: 10, elevation: 1)
                    }
                }
                .padding(16)
                .liquidGlass(cornerRadius: 16, elevation: 1.5)
                
                // Action Buttons Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button(action: pingTarget) {
                            HStack(spacing: 5) {
                                if isPinging {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                } else {
                                    Image(systemName: "waveform.path.ecg")
                                }
                                Text(liveLatency != nil ? String(format: "%.1f ms", liveLatency!) : "Ping Host")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isPinging)
                        
                        Button(action: scanTargetPorts) {
                            HStack(spacing: 5) {
                                if isPortScanning {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                } else {
                                    Image(systemName: "door.left.hand.open")
                                }
                                Text("Scan Ports")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isPortScanning)
                        
                        Button(action: probeSMB) {
                            HStack(spacing: 5) {
                                Image(systemName: "server.rack")
                                Text("NetBIOS/SMB")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: sendWakeOnLAN) {
                            HStack(spacing: 5) {
                                Image(systemName: "power")
                                Text("WOL")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        if probedPorts.contains(80) || probedPorts.contains(443) || device.openPorts.contains(80) || device.openPorts.contains(443) {
                            Button(action: openWebUI) {
                                HStack(spacing: 5) {
                                    Image(systemName: "safari")
                                    Text("Web UI")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                if let status = wolStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                if let smb = smbStatus {
                    Text(smb)
                        .font(.caption)
                        .foregroundColor(.teal)
                }
                
                // Hardware & Network Attributes (Dual-Stack IPv4 / IPv6)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Device Specification & Protocol Fingerprints")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    
                    if !device.ipAddress.isEmpty {
                        DetailField(label: "IPv4 Address", value: device.ipAddress, copyable: true)
                    }
                    if let ipv6 = device.ipv6Address {
                        DetailField(label: "IPv6 Neighbor (NDP)", value: ipv6, copyable: true)
                    }
                    DetailField(label: "MAC Address", value: device.macAddress, copyable: true)
                    DetailField(label: "Manufacturer / OUI", value: device.vendor)
                    
                    if let model = device.modelName {
                        DetailField(label: "Hardware Model", value: model)
                    }
                    if let appleID = device.appleModelID {
                        DetailField(label: "Apple Model Identifier", value: "\(appleID) (Bonjour TXT Record)")
                    }
                    if let os = inferredOS ?? device.osInference {
                        DetailField(label: "OS Fingerprint", value: os)
                    }
                    if let wg = device.netbiosWorkgroup {
                        DetailField(label: "NetBIOS Workgroup", value: wg)
                    }
                    if device.protocolType.hasPrefix("LOCAL") {
                        let primary = NetworkMediumDetector.shared.primaryAdapter
                        DetailField(label: "Connection Medium", value: primary?.medium.rawValue ?? "Active Medium")
                        DetailField(label: "Link Negotiation", value: primary?.linkSpeedDescription ?? "Active Link")
                        DetailField(label: "Network Interface", value: "\(primary?.displayName ?? "Adapter") (\(primary?.bsdName ?? "en0"))")
                        DetailField(label: "Frame MTU", value: "\(primary?.mtu ?? 1500) bytes")
                        DetailField(label: "Connection State", value: primary?.connectionState.rawValue ?? "Active")
                    }
                    DetailField(label: "Discovery Vector", value: "\(device.protocolType) Network Broadcast")
                    DetailField(label: "Category", value: device.category.rawValue)
                    DetailField(label: "Last Seen", value: device.lastSeen.formatted(date: .abbreviated, time: .standard))
                }
                .padding(16)
                .liquidGlass(cornerRadius: 16, elevation: 1)
                
                // Active Services & Open Ports Pane
                let allPorts = Array(Set(device.openPorts + probedPorts)).sorted()
                if !allPorts.isEmpty || !device.services.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Active Services & Open Ports")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        
                        if !device.services.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(device.services, id: \.self) { svc in
                                    Text(svc)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        
                        if !allPorts.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                                ForEach(allPorts, id: \.self) { port in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text("Port \(port)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text(serviceName(for: port))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .liquidGlass(cornerRadius: 16, elevation: 1)
                }
                
                // Anti-MAC Randomization Banner
                if device.isRandomizedMAC {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.title3)
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Anti-MAC Randomization Notice")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("The second least significant bit of the first MAC octet is set (\(device.macAddress.prefix(2))), indicating an IEEE 802 Locally Administered Address (Private MAC used by iOS, iPadOS, Android, and Windows 11).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .liquidGlass(cornerRadius: 14, elevation: 1)
                }
                
                // Raw Captured Packet Frame
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Raw Packet Frame Capture", systemImage: "curlybraces")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Text("Promiscuous BPF Dump")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let dump = device.rawPacketDump {
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(dump)
                                .font(.system(.caption, design: .monospaced))
                                .padding(12)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.35))
                        .cornerRadius(8)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("Host discovered via system ARP/NDP routing tables. Promiscuous BPF frame capture displays live frames as packets arrive on the interface.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
                .padding(16)
                .liquidGlass(cornerRadius: 16, elevation: 1)
            }
            .padding(20)
        }
        .navigationTitle(device.hostname)
    }
    
    private func serviceName(for port: Int) -> String {
        switch port {
        case 22: return "SSH"
        case 53: return "DNS"
        case 80: return "HTTP"
        case 443: return "HTTPS"
        case 445: return "SMB"
        case 631: return "IPP"
        case 3389: return "RDP"
        case 5000: return "AirPlay"
        case 8080: return "HTTP-Alt"
        case 9100: return "Raw Print"
        default: return ""
        }
    }
    
    private var activeHostAddress: String {
        if !device.ipAddress.isEmpty {
            return device.ipAddress
        }
        return device.ipv6Address ?? ""
    }
    
    private func pingTarget() {
        guard !isPinging else { return }
        let targetHost = activeHostAddress
        guard !targetHost.isEmpty else { return }
        
        isPinging = true
        Task.detached {
            let isV6 = targetHost.contains(":")
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: isV6 ? "/sbin/ping6" : "/sbin/ping")
            proc.arguments = isV6 ? ["-c", "2", targetHost] : ["-c", "2", "-t", "2", targetHost]
            let pipe = Pipe()
            proc.standardOutput = pipe
            try? proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var foundRTT: Double? = nil
                for line in output.components(separatedBy: .newlines) {
                    if line.contains("time=") {
                        let parts = line.components(separatedBy: "time=")
                        if parts.count >= 2 {
                            let rttStr = parts[1].components(separatedBy: " ")[0]
                            if let d = Double(rttStr) {
                                foundRTT = d
                            }
                        }
                    }
                }
                let finalRTT = foundRTT
                await MainActor.run {
                    self.liveLatency = finalRTT
                    self.isPinging = false
                }
            } else {
                await MainActor.run {
                    self.isPinging = false
                }
            }
        }
    }
    
    private func scanTargetPorts() {
        guard !isPortScanning else { return }
        let targetIP = activeHostAddress
        guard !targetIP.isEmpty else { return }
        isPortScanning = true
        let portsToScan = [22, 53, 80, 443, 445, 631, 3389, 5000, 8080]
        
        Task.detached {
            var open: [Int] = []
            await withTaskGroup(of: Int?.self) { group in
                for p in portsToScan {
                    group.addTask {
                        let proc = Process()
                        proc.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
                        proc.arguments = ["-zv", "-G", "1", targetIP, "\(p)"]
                        try? proc.run()
                        proc.waitUntilExit()
                        if proc.terminationStatus == 0 {
                            return p
                        }
                        return nil
                    }
                }
                for await p in group {
                    if let port = p {
                        open.append(port)
                    }
                }
            }
            let finalOpen = open
            await MainActor.run {
                self.probedPorts = finalOpen
                self.isPortScanning = false
            }
        }
    }
    
    private func probeSMB() {
        let targetIP = activeHostAddress
        guard !targetIP.isEmpty else { return }
        smbStatus = "Probing NetBIOS..."
        Task.detached {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
            proc.arguments = ["-zv", "-G", "1", targetIP, "445"]
            try? proc.run()
            proc.waitUntilExit()
            await MainActor.run {
                if proc.terminationStatus == 0 {
                    self.smbStatus = "SMB / Windows File Sharing is open on port 445"
                } else {
                    self.smbStatus = "SMB port 445 closed / filtered"
                }
            }
        }
    }
    
    private func sendWakeOnLAN() {
        wolStatus = "Broadcasting magic packet to \(device.macAddress)..."
        Task.detached {
            let (success, errorMsg) = DiagnosticExecutionManager.sendWakeOnLANPacket(macAddress: device.macAddress)
            await MainActor.run {
                if success {
                    self.wolStatus = "Magic Packet dispatched to \(device.macAddress) on UDP port 9"
                } else {
                    self.wolStatus = "Failed to dispatch WOL: \(errorMsg ?? "Unknown socket error")"
                }
            }
        }
    }
    
    private func openWebUI() {
        let host = activeHostAddress
        let urlString = host.contains(":") ? "http://[\(host)]" : "http://\(host)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Detail Field Component

struct DetailField: View {
    let label: String
    let value: String
    var copyable: Bool = false
    @State private var copied: Bool = false
    
    var body: some View {
        ViewThatFits(in: .horizontal) {
            // Standard horizontal arrangement
            HStack(alignment: .top, spacing: 10) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 160, alignment: .leading)
                
                Text(value)
                    .font(.system(size: 12, weight: .medium, design: (label.contains("IP") || label.contains("MAC")) ? .monospaced : .rounded))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                
                Spacer(minLength: 4)
                
                if copyable {
                    copyButton
                }
            }
            
            // Compact vertical reflow layout for narrower pane widths
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                HStack(alignment: .top, spacing: 6) {
                    Text(value)
                        .font(.system(size: 12, weight: .medium, design: (label.contains("IP") || label.contains("MAC")) ? .monospaced : .rounded))
                        .textSelection(.enabled)
                        .lineLimit(nil)
                    
                    Spacer(minLength: 4)
                    
                    if copyable {
                        copyButton
                    }
                }
            }
        }
        .padding(.vertical, 3.5)
    }
    
    private var copyButton: some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        }) {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11))
                .foregroundColor(copied ? .green : .secondary)
        }
        .buttonStyle(.plain)
    }
}
