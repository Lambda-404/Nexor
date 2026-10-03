#if os(macOS)
import Foundation
import SwiftUI

// MARK: - Bluetooth Device Category

public enum BluetoothDeviceCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case appleEcosystem = "Apple Ecosystem"
    case audio = "Audio & Headsets"
    case phone = "Phones & Tablets"
    case computer = "Computers"
    case wearable = "Wearables"
    case peripheral = "Input & Peripherals"
    case beacon = "Beacons & Proximity"
    case other = "Other BLE"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .appleEcosystem: return "apple.logo"
        case .audio: return "airpodspro"
        case .phone: return "iphone"
        case .computer: return "laptopcomputer"
        case .wearable: return "applewatch"
        case .peripheral: return "keyboard"
        case .beacon: return "dot.radiowaves.left.and.right"
        case .other: return "wave.3.right"
        }
    }
    
    public var color: Color {
        switch self {
        case .all: return .secondary
        case .appleEcosystem: return .indigo
        case .audio: return .cyan
        case .phone: return .blue
        case .computer: return .purple
        case .wearable: return .green
        case .peripheral: return .orange
        case .beacon: return .red
        case .other: return .gray
        }
    }
}

// MARK: - Bluetooth Protocol Type

public enum BluetoothProtocolType: String, Sendable {
    case ble = "BLE (Low Energy)"
    case classic = "Classic (BR/EDR)"
    case dualMode = "Dual Mode (BLE + Classic)"
    
    public var badgeColor: Color {
        switch self {
        case .ble: return .blue
        case .classic: return .orange
        case .dualMode: return .teal
        }
    }
}

// MARK: - Apple Beacon Subtypes

public enum AppleBeaconType: String, Sendable {
    case airDrop = "AirDrop"
    case airPods = "AirPods / Proximity"
    case airPlayTarget = "AirPlay Target"
    case airPlaySource = "AirPlay Source"
    case nearbyContinuity = "Nearby / Continuity"
    case findMyAirTag = "Find My / Offline Finding"
    case iBeacon = "iBeacon"
    case unknown = "Apple Proprietary"
}

// MARK: - Bluetooth Signal Quality

public enum BluetoothSignalQuality: String, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case weak = "Weak"
    
    public var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .cyan
        case .fair: return .orange
        case .weak: return .red
        }
    }
    
    public static func evaluate(rssi: Int) -> BluetoothSignalQuality {
        if rssi >= -55 { return .excellent }
        if rssi >= -68 { return .good }
        if rssi >= -80 { return .fair }
        return .weak
    }
    
    public static func percentage(rssi: Int) -> Int {
        // -100 dBm (0%) to -40 dBm (100%)
        if rssi <= -100 { return 0 }
        if rssi >= -40 { return 100 }
        return Int(Double(rssi + 100) / 60.0 * 100.0)
    }
}

// MARK: - Bluetooth Device Model

public struct BluetoothDevice: Identifiable, Hashable, Sendable {
    public let id: String // UUID or normalized MAC address string
    public var name: String
    public var category: BluetoothDeviceCategory
    public var protocolType: BluetoothProtocolType
    public var rssi: Int
    public var rssiHistory: [Int]
    public var txPower: Int?
    public var macAddress: String?
    public var manufacturerCode: UInt16?
    public var manufacturerName: String?
    public var appleBeaconType: AppleBeaconType?
    public var applePayloadSummary: String?
    public var serviceUUIDs: [String]
    public var serviceNames: [String]
    public var isConnectable: Bool
    public var isConnected: Bool
    public var rawManufacturerHex: String?
    public var rawAdvertisementDump: String?
    public var lastSeen: Date
    public var firstDiscovered: Date
    public var packetCount: Int
    public var primaryChannel: Int // 37, 38, 39 for BLE Adv, or Classic channel 0..78
    
    public init(
        id: String,
        name: String,
        category: BluetoothDeviceCategory,
        protocolType: BluetoothProtocolType,
        rssi: Int,
        rssiHistory: [Int] = [],
        txPower: Int? = nil,
        macAddress: String? = nil,
        manufacturerCode: UInt16? = nil,
        manufacturerName: String? = nil,
        appleBeaconType: AppleBeaconType? = nil,
        applePayloadSummary: String? = nil,
        serviceUUIDs: [String] = [],
        serviceNames: [String] = [],
        isConnectable: Bool = false,
        isConnected: Bool = false,
        rawManufacturerHex: String? = nil,
        rawAdvertisementDump: String? = nil,
        lastSeen: Date = Date(),
        firstDiscovered: Date = Date(),
        packetCount: Int = 1,
        primaryChannel: Int = 37
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.protocolType = protocolType
        self.rssi = rssi
        self.rssiHistory = rssiHistory.isEmpty ? [rssi] : rssiHistory
        self.txPower = txPower
        self.macAddress = macAddress
        self.manufacturerCode = manufacturerCode
        self.manufacturerName = manufacturerName
        self.appleBeaconType = appleBeaconType
        self.applePayloadSummary = applePayloadSummary
        self.serviceUUIDs = serviceUUIDs
        self.serviceNames = serviceNames
        self.isConnectable = isConnectable
        self.isConnected = isConnected
        self.rawManufacturerHex = rawManufacturerHex
        self.rawAdvertisementDump = rawAdvertisementDump
        self.lastSeen = lastSeen
        self.firstDiscovered = firstDiscovered
        self.packetCount = packetCount
        self.primaryChannel = primaryChannel
    }
    
    // MARK: - Computed Signal & Telemetry Properties
    
    public var signalQuality: BluetoothSignalQuality {
        BluetoothSignalQuality.evaluate(rssi: rssi)
    }
    
    public var signalPercentage: Int {
        BluetoothSignalQuality.percentage(rssi: rssi)
    }
    
    public var estimatedDistanceMeters: Double? {
        let referenceTx = Double(txPower ?? -59)
        let ratio = (referenceTx - Double(rssi)) / (10.0 * 2.2)
        let distance = pow(10.0, ratio)
        return max(0.1, min(distance, 50.0))
    }
    
    public var distanceString: String {
        guard let dist = estimatedDistanceMeters else { return "Unknown" }
        if dist < 0.8 {
            return "< 1 m (Immediate)"
        } else if dist < 2.5 {
            return String(format: "%.1f m (Near)", dist)
        } else if dist < 6.0 {
            return String(format: "%.1f m (Moderate)", dist)
        } else {
            return String(format: "%.1f m (Far)", dist)
        }
    }
    
    public var operatingFrequencyMHz: Int {
        if protocolType == .classic {
            return 2402 + max(0, min(primaryChannel, 78))
        } else {
            // BLE Advertising Channels: 37 -> 2402 MHz, 38 -> 2426 MHz, 39 -> 2480 MHz
            switch primaryChannel {
            case 37: return 2402
            case 38: return 2426
            case 39: return 2480
            default:
                if primaryChannel < 37 {
                    return 2404 + (primaryChannel * 2)
                }
                return 2402
            }
        }
    }
}

#endif
