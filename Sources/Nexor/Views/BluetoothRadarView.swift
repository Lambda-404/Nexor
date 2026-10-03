#if os(macOS)
import SwiftUI
import AppKit

public struct BluetoothRadarView: View {
    @State private var bluetoothService = BluetoothDiscoveryService.shared
    @State private var selectedDevice: BluetoothDevice?
    @State private var searchText: String = ""
    @State private var selectedCategory: BluetoothDeviceCategory = .all
    @State private var exportToast: String? = nil
    
    public init() {}
    
    public var filteredDevices: [BluetoothDevice] {
        var list = bluetoothService.devices
        if selectedCategory != .all {
            list = list.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.manufacturerName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.macAddress?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.id.localizedCaseInsensitiveContains(searchText) ||
                ($0.applePayloadSummary?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.serviceNames.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
        return list.sorted { $0.rssi > $1.rssi } // Strongest signal first
    }
    
    public var body: some View {
        HSplitView {
            // Left Column: Devices List & Spectrum Controls
            VStack(spacing: 0) {
                // Header status bar
                VStack(spacing: 8) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("\(bluetoothService.devices.count) Devices")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                
                                if bluetoothService.isScanning {
                                    HStack(spacing: 4) {
                                        PulsingBeacon(color: .teal, size: 6)
                                        Text("RF SCANNING")
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .foregroundColor(.teal)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2.5)
                                    .background(Color.teal.opacity(0.12))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.teal.opacity(0.25), lineWidth: 0.8)
                                    )
                                } else {
                                    Text("PAUSED")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2.5)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Text("2.4 GHz Full-Spectrum BLE & Classic RF Domain (\(bluetoothService.totalPacketsCaptured) frames)")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Control Buttons
                        HStack(spacing: 6) {
                            Button(action: {
                                if bluetoothService.isScanning {
                                    bluetoothService.stopScanning()
                                } else {
                                    bluetoothService.startScanning()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: bluetoothService.isScanning ? "pause.fill" : "play.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text(bluetoothService.isScanning ? "Pause" : "Scan")
                                        .font(.system(size: 11, weight: .medium))
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(bluetoothService.isScanning ? .orange : .teal)
                            
                            Menu {
                                Button("Export as JSON...") {
                                    copyToClipboard(bluetoothService.exportAsJSON(), label: "JSON copied to clipboard")
                                }
                                Button("Export as CSV...") {
                                    copyToClipboard(bluetoothService.exportAsCSV(), label: "CSV copied to clipboard")
                                }
                                Divider()
                                Button("Clear List", role: .destructive) {
                                    bluetoothService.clearAllDevices()
                                    selectedDevice = nil
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    // Search Bar
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        TextField("Search device name, vendor, MAC or services...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.8))
                
                Divider().opacity(0.4)
                
                // Full-Spectrum 2.4 GHz Visualizer
                BluetoothSpectrumCanvas(
                    devices: bluetoothService.devices,
                    channelActivity: bluetoothService.channelActivity,
                    isScanning: bluetoothService.isScanning
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.4))
                
                Divider().opacity(0.4)
                
                // Category Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(BluetoothDeviceCategory.allCases) { cat in
                            let count = cat == .all ? bluetoothService.devices.count : bluetoothService.devices.filter { $0.category == cat }.count
                            if count > 0 || cat == .all {
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
                
                Divider().opacity(0.4)
                
                // Device List
                if filteredDevices.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.teal.opacity(0.1))
                                .frame(width: 64, height: 64)
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 28))
                                .foregroundColor(.teal)
                        }
                        
                        VStack(spacing: 4) {
                            Text("No Bluetooth Devices in Range")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text("Listening across 2.4 GHz BLE and Classic radio channels...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        if !bluetoothService.isScanning {
                            Button("Resume Full-Spectrum Scan") {
                                bluetoothService.startScanning()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                            .controlSize(.small)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(selection: $selectedDevice) {
                        ForEach(filteredDevices) { device in
                            BluetoothDeviceRowView(device: device)
                                .tag(device)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 340, idealWidth: 380, maxWidth: 460)
            
            // Right Column: 3rd-Level Detailed Inspector
            Group {
                if let device = selectedDevice {
                    BluetoothDeviceDetailPane(device: device)
                        .id(device.id)
                } else {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.teal.opacity(0.12))
                                .frame(width: 80, height: 80)
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 38, weight: .medium))
                                .foregroundColor(.teal)
                        }
                        
                        Text("Select a Bluetooth Device")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Select any detected peripheral or classic host to inspect radio telemetry, Apple beacon flags, service UUIDs, and raw packet frames.")
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
        .overlay(alignment: .bottom) {
            if let toast = exportToast {
                Text(toast)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            bluetoothService.startScanning()
        }
    }
    
    private func copyToClipboard(_ text: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation { exportToast = label }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { exportToast = nil }
        }
    }
}

// MARK: - Full Spectrum 2.4 GHz Canvas Component

struct BluetoothSpectrumCanvas: View {
    let devices: [BluetoothDevice]
    let channelActivity: [Int: Int]
    let isScanning: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.teal)
                    Text("2.4 GHz Spectrum Activity")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                Spacer()
                Text("2402 MHz — 2480 MHz (79 Ch)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // Visual frequency bars
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                
                ZStack(alignment: .bottom) {
                    // Spectrum baseline
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .offset(y: -14)
                    
                    // Channel Bars across 79 channels
                    HStack(alignment: .bottom, spacing: 1) {
                        ForEach(0..<79, id: \.self) { ch in
                            let count = channelActivity[ch] ?? 0
                            let isAdv = (ch == 0 || ch == 24 || ch == 78) // Maps roughly to 2402, 2426, 2480
                            let barHeight = min(CGFloat(count * 4) + (isAdv ? 6 : 2), height - 16)
                            
                            RoundedRectangle(cornerRadius: 1)
                                .fill(isAdv ? Color.teal.opacity(0.85) : Color.blue.opacity(0.45))
                                .frame(maxWidth: .infinity)
                                .frame(height: max(2, barHeight))
                        }
                    }
                    .frame(height: height - 16, alignment: .bottom)
                    .offset(y: -14)
                    
                    // Device Blip Pins along the frequency line
                    ForEach(devices.prefix(15)) { dev in
                        let freqNorm = CGFloat(dev.operatingFrequencyMHz - 2402) / 78.0
                        let xPos = max(6, min(width - 6, freqNorm * width))
                        
                        Circle()
                            .fill(dev.category.color)
                            .frame(width: 6, height: 6)
                            .shadow(color: dev.category.color.opacity(0.8), radius: 3)
                            .position(x: xPos, y: height - 14)
                    }
                    
                    // Frequency labels
                    HStack {
                        Text("Ch 37 (2402)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.teal)
                        Spacer()
                        Text("Ch 38 (2426)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.teal)
                        Spacer()
                        Text("Ch 39 (2480)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.teal)
                    }
                    .frame(height: 12)
                }
            }
            .frame(height: 48)
        }
        .padding(10)
        .liquidGlass(cornerRadius: 10, elevation: 1)
    }
}

// MARK: - Bluetooth Device Row View

struct BluetoothDeviceRowView: View {
    let device: BluetoothDevice
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(device.category.color.opacity(0.18))
                    .frame(width: 36, height: 36)
                
                Image(systemName: device.category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(device.category.color)
            }
            
            // Name and Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(device.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    
                    if device.isConnected {
                        Text("CONNECTED")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 6) {
                    Text(device.manufacturerName ?? "BLE Peripheral")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text("•")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text(device.protocolType == .ble ? "BLE" : "Classic")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(device.protocolType.badgeColor)
                    
                    if let appleType = device.appleBeaconType {
                        Text(appleType.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.indigo)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.indigo.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
            
            // Signal RSSI & Distance
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    Text("\(device.rssi) dBm")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(device.signalQuality.color)
                    
                    SignalBarsView(quality: device.signalQuality)
                }
                
                Text(device.distanceString)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Mini Signal Bars Component

struct SignalBarsView: View {
    let quality: BluetoothSignalQuality
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 2.5, height: 4)
            RoundedRectangle(cornerRadius: 0.5)
                .fill(quality != .weak ? quality.color : Color.secondary.opacity(0.3))
                .frame(width: 2.5, height: 7)
            RoundedRectangle(cornerRadius: 0.5)
                .fill(quality == .good || quality == .excellent ? quality.color : Color.secondary.opacity(0.3))
                .frame(width: 2.5, height: 10)
            RoundedRectangle(cornerRadius: 0.5)
                .fill(quality == .excellent ? quality.color : Color.secondary.opacity(0.3))
                .frame(width: 2.5, height: 13)
        }
    }
}

// MARK: - 3rd-Level Detailed Inspector Pane

struct BluetoothDeviceDetailPane: View {
    let device: BluetoothDevice
    @State private var copiedNotice: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header Card
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(device.category.color.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: device.category.icon)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(device.category.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .lineLimit(nil)
                        
                        HStack(spacing: 6) {
                            Text(device.manufacturerName ?? "Bluetooth SIG Device")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            Text(device.protocolType.rawValue)
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(device.protocolType.badgeColor)
                        }
                    }
                    
                    Spacer()
                    
                    if device.isConnected {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text("Connected")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(16)
                .liquidGlass(cornerRadius: 14, elevation: 1.5)
                
                // Telemetry Metric Grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    MetricCard(
                        title: "Signal RSSI",
                        value: "\(device.rssi) dBm",
                        icon: "antenna.radiowaves.left.and.right",
                        color: device.signalQuality.color,
                        subtitle: "Quality: \(device.signalQuality.rawValue) (\(device.signalPercentage)%)"
                    )
                    
                    MetricCard(
                        title: "Proximity Distance",
                        value: device.estimatedDistanceMeters != nil ? String(format: "%.1f m", device.estimatedDistanceMeters!) : "--",
                        icon: "figure.walk",
                        color: .blue,
                        subtitle: device.distanceString
                    )
                    
                    MetricCard(
                        title: "RF Channel",
                        value: "Ch \(device.primaryChannel)",
                        icon: "waveform.path",
                        color: .teal,
                        subtitle: "\(device.operatingFrequencyMHz) MHz (2.4 GHz)"
                    )
                    
                    MetricCard(
                        title: "Tx Power Level",
                        value: device.txPower != nil ? "\(device.txPower!) dBm" : "--",
                        icon: "bolt.fill",
                        color: .orange,
                        subtitle: device.isConnectable ? "Connectable: YES" : "Broadcaster Only"
                    )
                }
                
                // Apple Ecosystem Deep Dissection Card
                if let appleType = device.appleBeaconType {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.indigo)
                            Text("Apple Ecosystem Beacon Dissection")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Spacer()
                            Text(appleType.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.indigo)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.indigo.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        
                        Divider().opacity(0.3)
                        
                        if let summary = device.applePayloadSummary {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.indigo)
                                    .font(.system(size: 12))
                                    .padding(.top, 1)
                                Text(summary)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(14)
                    .liquidGlass(cornerRadius: 12, elevation: 1)
                }
                
                // Hardware Identifiers
                VStack(alignment: .leading, spacing: 10) {
                    Text("Hardware & Radio Identifiers")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 6) {
                        DetailField(label: "Peripheral UUID", value: device.id, copyable: true)
                        if let mac = device.macAddress {
                            DetailField(label: "MAC Address (IEEE)", value: mac, copyable: true)
                        }
                        if let code = device.manufacturerCode {
                            DetailField(label: "Company Identifier", value: String(format: "0x%04X (%@)", code, device.manufacturerName ?? "SIG Member"))
                        }
                        DetailField(label: "First Discovered", value: device.firstDiscovered.formatted(date: .omitted, time: .standard))
                        DetailField(label: "Last Frame Received", value: device.lastSeen.formatted(date: .omitted, time: .standard))
                        DetailField(label: "Frames Captured", value: "\(device.packetCount)")
                    }
                    .padding(12)
                    .liquidGlass(cornerRadius: 12, elevation: 1)
                }
                
                // Advertised Services List
                if !device.serviceNames.isEmpty || !device.serviceUUIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Advertised Services (GATT)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(device.serviceNames.enumerated()), id: \.offset) { idx, name in
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundColor(.teal)
                                        .font(.system(size: 11))
                                    Text(name)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    if idx < device.serviceUUIDs.count {
                                        Text(device.serviceUUIDs[idx])
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                                if idx < device.serviceNames.count - 1 {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                        .padding(12)
                        .liquidGlass(cornerRadius: 12, elevation: 1)
                    }
                }
                
                // Raw Packet Frame Dump
                if let dump = device.rawAdvertisementDump {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Raw Advertisement Frame Dump")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Copy Raw Hex") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(dump, forType: .string)
                                withAnimation { copiedNotice = "Frame dump copied" }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { copiedNotice = nil }
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(dump)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(Color.black.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding(18)
        }
        .overlay(alignment: .bottom) {
            if let notice = copiedNotice {
                Text(notice)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
        }
    }
}

#endif
