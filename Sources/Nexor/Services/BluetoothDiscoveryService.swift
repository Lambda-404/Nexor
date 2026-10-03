#if os(macOS)
import Foundation
import CoreBluetooth
import IOBluetooth
import SwiftUI

@Observable
@MainActor
public final class BluetoothDiscoveryService: NSObject, CBCentralManagerDelegate, IOBluetoothDeviceInquiryDelegate {
    public static let shared = BluetoothDiscoveryService()
    
    // MARK: - Published Observable State
    public private(set) var devices: [BluetoothDevice] = []
    public private(set) var isScanning: Bool = false
    public private(set) var bluetoothState: CBManagerState = .unknown
    public private(set) var totalPacketsCaptured: Int = 0
    public private(set) var lastUpdated: Date = Date()
    
    // Full spectrum channel activity distribution (0..78 for Classic, 37, 38, 39 for BLE Adv)
    public private(set) var channelActivity: [Int: Int] = [:]
    
    // MARK: - Internal Bluetooth Controllers
    private var centralManager: CBCentralManager?
    private var classicInquiry: IOBluetoothDeviceInquiry?
    private let discoveryQueue = DispatchQueue(label: "com.networkutilities.bluetooth", qos: .userInitiated)
    private var cyclicChannelCycle: Int = 37
    private var housekeepingTimer: Timer?
    
    public override init() {
        super.init()
        // Initialize channel activity buckets
        for ch in 0...78 { channelActivity[ch] = 0 }
        channelActivity[37] = 0
        channelActivity[38] = 0
        channelActivity[39] = 0
    }
    
    // MARK: - Scan Lifecycle
    
    public func startScanning() {
        guard !isScanning else { return }
        isScanning = true
        
        // 1. Ingest known/paired Classic Bluetooth devices first
        harvestPairedClassicDevices()
        
        // 2. Initialize and start CoreBluetooth BLE central manager
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: discoveryQueue)
        } else if centralManager?.state == .poweredOn {
            centralManager?.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        }
        
        // 3. Start Classic Bluetooth RF Inquiry
        startClassicInquiry()
        
        // 4. Housekeeping timer (decay dead devices / prune stale entries if offline > 120s)
        housekeepingTimer?.invalidate()
        housekeepingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.decayChannelActivity()
            }
        }
    }
    
    public func stopScanning() {
        isScanning = false
        centralManager?.stopScan()
        classicInquiry?.stop()
        housekeepingTimer?.invalidate()
        housekeepingTimer = nil
    }
    
    public func clearAllDevices() {
        // Stop all scanning first so callbacks don't re-add devices immediately
        stopScanning()
        
        devices.removeAll()
        totalPacketsCaptured = 0
        for k in channelActivity.keys { channelActivity[k] = 0 }
        lastUpdated = Date()
    }
    
    // MARK: - Classic Bluetooth (IOBluetooth) Harvester
    
    public func harvestPairedClassicDevices() {
        guard let paired = IOBluetoothDevice.pairedDevices() else { return }
        
        for item in paired {
            guard let dev = item as? IOBluetoothDevice else { continue }
            // Only ingest actively connected physical devices; never pre-populate offline/disconnected paired devices
            guard dev.isConnected() else { continue }
            
            let name = dev.nameOrAddress ?? dev.name ?? "Classic BT Device"
            let mac = (dev.addressString ?? "").uppercased().replacingOccurrences(of: "-", with: ":")
            guard !mac.isEmpty else { continue }
            
            let rawRSSI = Int(dev.rawRSSI())
            let rssi = rawRSSI != 0 ? rawRSSI : -45
            
            let category = classifyClassicDevice(device: dev, name: name)
            let mfg = OUIDatabase.vendor(for: mac)
            let resolvedMfg = mfg != "Unknown Vendor" ? mfg : resolveClassicVendor(name: name, mac: mac)
            
            let classicDevice = BluetoothDevice(
                id: mac,
                name: name,
                category: category,
                protocolType: .classic,
                rssi: rssi,
                rssiHistory: [rssi],
                txPower: 4,
                macAddress: mac,
                manufacturerCode: nil,
                manufacturerName: resolvedMfg,
                appleBeaconType: category == .appleEcosystem || name.contains("AirPods") ? .airPods : nil,
                applePayloadSummary: "Active Link (Connected)",
                serviceUUIDs: [],
                serviceNames: ["Classic BR/EDR Baseband"],
                isConnectable: true,
                isConnected: true,
                rawManufacturerHex: nil,
                rawAdvertisementDump: "Classic Bluetooth BR/EDR [MAC: \(mac)] CoD: 0x\(String(format: "%06X", dev.classOfDevice))",
                lastSeen: Date(),
                firstDiscovered: Date(),
                packetCount: 1,
                primaryChannel: abs(mac.hashValue % 79)
            )
            
            upsertDevice(classicDevice)
        }
    }
    
    private func startClassicInquiry() {
        if classicInquiry == nil {
            classicInquiry = IOBluetoothDeviceInquiry(delegate: self)
        }
        classicInquiry?.inquiryLength = 4
        classicInquiry?.updateNewDeviceNames = true
        _ = classicInquiry?.start()
    }
    
    // MARK: - IOBluetoothDeviceInquiryDelegate
    
    public nonisolated func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        guard let device = device else { return }
        let name = device.nameOrAddress ?? device.name ?? "Classic Device"
        let mac = (device.addressString ?? "").uppercased().replacingOccurrences(of: "-", with: ":")
        guard !mac.isEmpty else { return }
        
        let rawRSSI = Int(device.rawRSSI())
        let rssi = rawRSSI != 0 ? rawRSSI : -68
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let category = self.classifyClassicDevice(device: device, name: name)
            let mfg = OUIDatabase.vendor(for: mac)
            let resolvedMfg = mfg != "Unknown Vendor" ? mfg : self.resolveClassicVendor(name: name, mac: mac)
            
            let dev = BluetoothDevice(
                id: mac,
                name: name,
                category: category,
                protocolType: .classic,
                rssi: rssi,
                rssiHistory: [rssi],
                txPower: 4,
                macAddress: mac,
                manufacturerName: resolvedMfg,
                appleBeaconType: category == .appleEcosystem ? .nearbyContinuity : nil,
                applePayloadSummary: "Inquiry Discovered (BR/EDR)",
                serviceUUIDs: [],
                serviceNames: ["Classic RFCOMM / L2CAP"],
                isConnectable: true,
                isConnected: device.isConnected(),
                rawAdvertisementDump: "IOBluetooth Classic Inquiry Response\nMAC: \(mac)\nClass of Device: 0x\(String(format: "%06X", device.classOfDevice))",
                lastSeen: Date(),
                packetCount: 1,
                primaryChannel: abs(mac.hashValue % 79)
            )
            self.upsertDevice(dev)
            self.totalPacketsCaptured += 1
            self.incrementChannelActivity(channel: abs(mac.hashValue % 79))
        }
    }
    
    public nonisolated func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool) {
        if !aborted {
            Task { @MainActor [weak self] in
                guard let self = self, self.isScanning else { return }
                self.discoveryQueue.asyncAfter(deadline: .now() + 6.0) { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self = self, self.isScanning else { return }
                        _ = self.classicInquiry?.start()
                    }
                }
            }
        }
    }
    
    // MARK: - CoreBluetooth CBCentralManagerDelegate
    
    public nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.bluetoothState = central.state
            if central.state == .poweredOn && self.isScanning {
                central.scanForPeripherals(
                    withServices: nil,
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
                )
            }
        }
    }
    
    public nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rawRSSI = RSSI.intValue
        guard rawRSSI < 0 && rawRSSI > -110 else { return }
        
        let peripheralId = peripheral.identifier.uuidString
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let peripheralName = peripheral.name
        let discoveredName = localName ?? peripheralName ?? ""
        
        let txPower = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? Int
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
        
        let serviceUUIDObjs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let serviceUUIDStrings = serviceUUIDObjs.map { $0.uuidString }
        
        let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.processDiscoveredBLEPeripheral(
                id: peripheralId,
                name: discoveredName,
                rssi: rawRSSI,
                txPower: txPower,
                isConnectable: isConnectable,
                serviceUUIDs: serviceUUIDStrings,
                manufacturerData: mfgData,
                advertisementData: advertisementData
            )
        }
    }
    
    // MARK: - BLE Packet Dissection Engine
    
    private func processDiscoveredBLEPeripheral(
        id: String,
        name: String,
        rssi: Int,
        txPower: Int?,
        isConnectable: Bool,
        serviceUUIDs: [String],
        manufacturerData: Data?,
        advertisementData: [String: Any]
    ) {
        totalPacketsCaptured += 1
        
        // Cyclic primary advertising channel simulation (37, 38, 39)
        cyclicChannelCycle = (cyclicChannelCycle == 37) ? 38 : (cyclicChannelCycle == 38 ? 39 : 37)
        let primaryChannel = cyclicChannelCycle
        incrementChannelActivity(channel: primaryChannel)
        
        var mfgCode: UInt16? = nil
        var mfgName: String? = nil
        var appleBeaconType: AppleBeaconType? = nil
        var appleSummary: String? = nil
        var rawHex: String? = nil
        
        if let data = manufacturerData, data.count >= 2 {
            rawHex = data.map { String(format: "%02X", $0) }.joined()
            let code = UInt16(data[0]) | (UInt16(data[1]) << 8)
            mfgCode = code
            mfgName = Self.resolveCompanyIdentifier(code)
            
            if code == 0x004C { // Apple Inc.
                (appleBeaconType, appleSummary) = dissectApplePayload(data: data)
            } else if code == 0x0006 { // Microsoft
                appleSummary = "Microsoft Swift Pair / Device Telemetry"
            } else if code == 0x00E0 { // Google
                appleSummary = "Google Fast Pair / Nearby"
            } else if code == 0x012D { // Sony
                appleSummary = "Sony Audio LDAC / Headset Link"
            } else if code == 0x0075 { // Samsung
                appleSummary = "Samsung SmartThings / Galaxy Buds"
            } else if code == 0x027D { // Huawei
                appleSummary = "Huawei Share / Audio Proximity"
            } else if code == 0x038F { // Xiaomi
                appleSummary = "Xiaomi HyperOS Interconnect"
            }
        }
        
        // Service names translation
        let serviceNames = serviceUUIDs.map { Self.resolveServiceUUID($0) }
        
        // Fallback name calculation
        var finalName = name
        if finalName.isEmpty {
            if let appleType = appleBeaconType {
                finalName = "Apple \(appleType.rawValue)"
            } else if let comp = mfgName {
                finalName = "\(comp) BLE Beacon"
            } else if !serviceNames.isEmpty {
                finalName = serviceNames.first ?? "BLE Peripheral"
            } else {
                finalName = "Nearby BLE Device (\(id.prefix(6)))"
            }
        }
        
        let category = classifyBLEDevice(
            name: finalName,
            mfgCode: mfgCode,
            appleType: appleBeaconType,
            serviceUUIDs: serviceUUIDs
        )
        
        // Build detailed formatted advertisement dump
        var dump = "=== BLE Advertising Frame ===\n"
        dump += "UUID: \(id)\n"
        dump += "Name: \(finalName)\n"
        dump += "RSSI: \(rssi) dBm\n"
        if let tx = txPower { dump += "Tx Power Level: \(tx) dBm\n" }
        dump += "Connectable: \(isConnectable ? "YES" : "NO")\n"
        if let code = mfgCode, let comp = mfgName {
            dump += "Company ID: 0x\(String(format: "%04X", code)) (\(comp))\n"
        }
        if let hex = rawHex {
            dump += "Manufacturer Hex Payload:\n\(formatHexWithSpaces(hex))\n"
        }
        if !serviceUUIDs.isEmpty {
            dump += "Service UUIDs:\n"
            for (idx, uuid) in serviceUUIDs.enumerated() {
                let sName = idx < serviceNames.count ? serviceNames[idx] : "Unknown"
                dump += " - \(uuid) [\(sName)]\n"
            }
        }
        if let summary = appleSummary {
            dump += "Dissected Payload: \(summary)\n"
        }
        
        let device = BluetoothDevice(
            id: id,
            name: finalName,
            category: category,
            protocolType: .ble,
            rssi: rssi,
            txPower: txPower,
            macAddress: nil,
            manufacturerCode: mfgCode,
            manufacturerName: mfgName,
            appleBeaconType: appleBeaconType,
            applePayloadSummary: appleSummary,
            serviceUUIDs: serviceUUIDs,
            serviceNames: serviceNames,
            isConnectable: isConnectable,
            isConnected: false,
            rawManufacturerHex: rawHex,
            rawAdvertisementDump: dump,
            lastSeen: Date(),
            firstDiscovered: Date(),
            packetCount: 1,
            primaryChannel: primaryChannel
        )
        
        upsertDevice(device)
    }
    
    // MARK: - Apple Ecosystem Dissector (0x004C)
    
    private func dissectApplePayload(data: Data) -> (AppleBeaconType, String) {
        guard data.count >= 3 else {
            return (.unknown, "Apple Payload (Truncated)")
        }
        
        let subType = data[2]
        switch subType {
        case 0x05: // AirDrop
            return (.airDrop, "AirDrop Discoverable Broadcast")
            
        case 0x07: // AirPods / Proximity Pairing
            var summary = "AirPods Proximity Beacon"
            if data.count >= 8 {
                let batteryCase = Int(data[5])
                summary = "AirPods Proximity [Battery Telemetry: \(batteryCase)%]"
            }
            return (.airPods, summary)
            
        case 0x09: // AirPlay Target
            return (.airPlayTarget, "AirPlay Receiver / Screen Mirroring")
            
        case 0x0A: // AirPlay Source
            return (.airPlaySource, "AirPlay Audio / Video Transmitter")
            
        case 0x10: // Nearby Action / Continuity / Handoff
            var dev = "Apple Device"
            if data.count >= 5 {
                let actionType = data[3]
                if actionType == 0x05 || actionType == 0x06 {
                    dev = "Apple Watch (Nearby Action)"
                } else if actionType == 0x09 {
                    dev = "Apple MacBook / Mac (Continuity)"
                } else {
                    dev = "iPhone / iPad (Continuity Link)"
                }
            }
            return (.nearbyContinuity, "\(dev) Handoff & Nearby Frame")
            
        case 0x12: // Find My / Offline Finding
            return (.findMyAirTag, "Apple Find My Offline Locating Key")
            
        case 0x02: // iBeacon
            return (.iBeacon, "Apple iBeacon Proximity Frame")
            
        default:
            return (.unknown, "Apple Proprietary Subtype 0x\(String(format: "%02X", subType))")
        }
    }
    
    // MARK: - Device Classification
    
    private func classifyClassicDevice(device: IOBluetoothDevice, name: String) -> BluetoothDeviceCategory {
        let lowName = name.lowercased()
        if lowName.contains("airpods") || lowName.contains("headphone") || lowName.contains("earbuds") || lowName.contains("audio") || lowName.contains("speaker") || lowName.contains("buds") {
            return .audio
        }
        if lowName.contains("iphone") || lowName.contains("ipad") || lowName.contains("galaxy") || lowName.contains("pixel") {
            return .phone
        }
        if lowName.contains("macbook") || lowName.contains("imac") || lowName.contains("laptop") || lowName.contains("pc") {
            return .computer
        }
        if lowName.contains("watch") || lowName.contains("band") || lowName.contains("fitbit") {
            return .wearable
        }
        if lowName.contains("keyboard") || lowName.contains("mouse") || lowName.contains("trackpad") || lowName.contains("pen") || lowName.contains("stylus") {
            return .peripheral
        }
        if lowName.contains("apple") || lowName.contains("airtag") {
            return .appleEcosystem
        }
        
        let major = device.deviceClassMajor
        switch major {
        case 0x01: return .computer
        case 0x02: return .phone
        case 0x04: return .audio
        case 0x05: return .peripheral
        case 0x07: return .wearable
        default: return .other
        }
    }
    
    private func classifyBLEDevice(
        name: String,
        mfgCode: UInt16?,
        appleType: AppleBeaconType?,
        serviceUUIDs: [String]
    ) -> BluetoothDeviceCategory {
        let lowName = name.lowercased()
        
        if appleType != nil || mfgCode == 0x004C || lowName.contains("apple") {
            if appleType == .airPods || lowName.contains("airpods") {
                return .audio
            }
            if lowName.contains("watch") {
                return .wearable
            }
            if lowName.contains("iphone") || lowName.contains("ipad") {
                return .phone
            }
            if appleType == .findMyAirTag || appleType == .airDrop || appleType == .iBeacon {
                return .beacon
            }
            return .appleEcosystem
        }
        
        if lowName.contains("headphone") || lowName.contains("earphone") || lowName.contains("buds") || lowName.contains("audio") || lowName.contains("speaker") || lowName.contains("sony") || lowName.contains("bose") {
            return .audio
        }
        if lowName.contains("mouse") || lowName.contains("keyboard") || lowName.contains("trackpad") || lowName.contains("k380") || lowName.contains("mx") {
            return .peripheral
        }
        if lowName.contains("watch") || lowName.contains("band") {
            return .wearable
        }
        if lowName.contains("phone") || lowName.contains("pad") || lowName.contains("tab") {
            return .phone
        }
        if serviceUUIDs.contains("1812") { // HID Service
            return .peripheral
        }
        if serviceUUIDs.contains("180D") { // Heart Rate
            return .wearable
        }
        
        return .other
    }
    
    private func resolveClassicVendor(name: String, mac: String) -> String {
        let low = name.lowercased()
        if low.contains("apple") || low.contains("airpods") || low.contains("iphone") || low.contains("ipad") {
            return "Apple Inc."
        }
        if low.contains("huawei") { return "Huawei Technologies" }
        if low.contains("nothing") { return "Nothing Technology" }
        if low.contains("k380") || low.contains("logitech") { return "Logitech" }
        if low.contains("sony") { return "Sony Corporation" }
        if low.contains("samsung") { return "Samsung Electronics" }
        return "Bluetooth SIG Device"
    }
    
    // MARK: - Internal Upsert & Merging
    
    private func upsertDevice(_ device: BluetoothDevice) {
        if let idx = devices.firstIndex(where: {
            $0.id == device.id ||
            ($0.macAddress != nil && $0.macAddress == device.macAddress) ||
            (!device.name.isEmpty && $0.name == device.name && $0.protocolType == device.protocolType)
        }) {
            // Merge & update existing device
            devices[idx].rssi = device.rssi
            devices[idx].rssiHistory.append(device.rssi)
            if devices[idx].rssiHistory.count > 25 {
                devices[idx].rssiHistory.removeFirst()
            }
            devices[idx].packetCount += 1
            devices[idx].lastSeen = device.lastSeen
            devices[idx].primaryChannel = device.primaryChannel
            
            if devices[idx].name.starts(with: "Nearby BLE") && !device.name.starts(with: "Nearby BLE") {
                devices[idx].name = device.name
            }
            if devices[idx].manufacturerName == nil && device.manufacturerName != nil {
                devices[idx].manufacturerName = device.manufacturerName
            }
            if devices[idx].appleBeaconType == nil && device.appleBeaconType != nil {
                devices[idx].appleBeaconType = device.appleBeaconType
                devices[idx].applePayloadSummary = device.applePayloadSummary
            }
            if devices[idx].rawAdvertisementDump == nil || device.protocolType == .ble {
                devices[idx].rawAdvertisementDump = device.rawAdvertisementDump
            }
        } else {
            devices.append(device)
        }
        lastUpdated = Date()
    }
    
    private func incrementChannelActivity(channel: Int) {
        channelActivity[channel, default: 0] += 1
    }
    
    private func decayChannelActivity() {
        for (k, v) in channelActivity where v > 0 {
            channelActivity[k] = max(0, Int(Double(v) * 0.85))
        }
    }
    
    private func formatHexWithSpaces(_ hex: String) -> String {
        var result = ""
        for (index, char) in hex.enumerated() {
            if index > 0 && index % 2 == 0 {
                result += " "
            }
            result.append(char)
        }
        return result
    }
    
    // MARK: - Export Utilities
    
    public func exportAsJSON() -> String {
        let exportable = devices.map { [
            "id": $0.id,
            "name": $0.name,
            "category": $0.category.rawValue,
            "protocol": $0.protocolType.rawValue,
            "rssi": "\($0.rssi) dBm",
            "signalQuality": $0.signalQuality.rawValue,
            "macAddress": $0.macAddress ?? "",
            "manufacturer": $0.manufacturerName ?? "",
            "appleBeaconType": $0.appleBeaconType?.rawValue ?? "",
            "applePayload": $0.applePayloadSummary ?? "",
            "services": $0.serviceNames.joined(separator: ", "),
            "packetCount": $0.packetCount,
            "lastSeen": $0.lastSeen.ISO8601Format()
        ] }
        if let data = try? JSONSerialization.data(withJSONObject: exportable, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }
    
    public func exportAsCSV() -> String {
        var csv = "Identifier,Device Name,Category,Protocol,RSSI,Quality,MAC Address,Manufacturer,Beacon Type,Payload Summary,Services,Packets,Last Seen\n"
        for d in devices {
            csv += "\"\(d.id)\",\"\(d.name)\",\"\(d.category.rawValue)\",\"\(d.protocolType.rawValue)\",\(d.rssi),\"\(d.signalQuality.rawValue)\",\"\(d.macAddress ?? "")\",\"\(d.manufacturerName ?? "")\",\"\(d.appleBeaconType?.rawValue ?? "")\",\"\(d.applePayloadSummary ?? "")\",\"\(d.serviceNames.joined(separator: "; "))\",\(d.packetCount),\"\(d.lastSeen.ISO8601Format())\"\n"
        }
        return csv
    }
    
    // MARK: - Bluetooth SIG Dictionaries
    
    public static func resolveCompanyIdentifier(_ code: UInt16) -> String {
        switch code {
        case 0x004C: return "Apple Inc."
        case 0x0006: return "Microsoft Corporation"
        case 0x00E0: return "Google LLC"
        case 0x012D: return "Sony Corporation"
        case 0x0075: return "Samsung Electronics"
        case 0x027D: return "Huawei Technologies"
        case 0x038F: return "Xiaomi Inc."
        case 0x000F: return "Broadcom Corporation"
        case 0x000A: return "Qualcomm Technologies"
        case 0x0046: return "MediaTek Inc."
        case 0x0059: return "Nordic Semiconductor"
        case 0x0002: return "Intel Corporation"
        case 0x0157: return "Anker Innovations"
        case 0x0822: return "DJI Technology"
        case 0x0087: return "Garmin International"
        case 0x0171: return "Amazon.com Services"
        case 0x00D2: return "Bose Corporation"
        case 0x0030: return "STMicroelectronics"
        case 0x000D: return "Texas Instruments"
        case 0x0060: return "Cypress Semiconductor"
        default: return "Company (0x\(String(format: "%04X", code)))"
        }
    }
    
    public static func resolveServiceUUID(_ uuidStr: String) -> String {
        let clean = uuidStr.uppercased().trimmingCharacters(in: .whitespaces)
        switch clean {
        case "180F": return "Battery Service"
        case "180A": return "Device Information"
        case "1812": return "Human Interface Device"
        case "180D": return "Heart Rate Service"
        case "1800": return "Generic Access"
        case "1801": return "Generic Attribute"
        case "1802": return "Immediate Alert"
        case "1803": return "Link Loss"
        case "1804": return "Tx Power Service"
        case "1805": return "Current Time Service"
        case "180E": return "Phone Alert Status"
        case "1816": return "Cycling Speed & Cadence"
        case "181A": return "Environmental Sensing"
        case "FE9F": return "Google Fast Pair"
        case "FD6F": return "Exposure Notification"
        case "D061": return "Apple Nearby Framework"
        case "9FA480E0-4967-4542-9390-D343DC5D04AE": return "Apple Continuity / AirDrop"
        default:
            return "SIG UUID \(clean)"
        }
    }
}

#endif
