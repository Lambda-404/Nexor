import Foundation
import CoreBluetooth
import IOBluetooth

@main
@MainActor
struct BluetoothRadarVerificationProbes {
    static func main() async {
        print("=======================================================")
        print("  BLUETOOTH RADAR & FULL-SPECTRUM RF VERIFICATION")
        print("=======================================================")

        // Probe 1: Model & Signal Telemetry Math
        print("\n[Probe 1] Model & Signal Telemetry Math...")
        let dev1 = BluetoothDevice(
            id: "TEST-UUID-001",
            name: "Test AirPods Pro",
            category: .audio,
            protocolType: .ble,
            rssi: -45,
            txPower: -59,
            primaryChannel: 37
        )
        assert(dev1.signalQuality == .excellent, "RSSI -45 should be excellent")
        assert(dev1.signalPercentage >= 90, "Percentage should be high")
        assert(dev1.operatingFrequencyMHz == 2402, "Channel 37 should map to 2402 MHz")
        assert(dev1.distanceString.contains("< 1 m") || dev1.distanceString.contains("Near"), "Distance string should indicate immediate/near: \(dev1.distanceString)")
        print("✓ BluetoothDevice model and signal telemetry math verified")

        // Probe 2: SIG Company Identifiers
        print("\n[Probe 2] Bluetooth SIG Company Identifiers...")
        assert(BluetoothDiscoveryService.resolveCompanyIdentifier(0x004C) == "Apple Inc.")
        assert(BluetoothDiscoveryService.resolveCompanyIdentifier(0x0006) == "Microsoft Corporation")
        assert(BluetoothDiscoveryService.resolveCompanyIdentifier(0x00E0) == "Google LLC")
        assert(BluetoothDiscoveryService.resolveCompanyIdentifier(0x012D) == "Sony Corporation")
        assert(BluetoothDiscoveryService.resolveCompanyIdentifier(0x0075) == "Samsung Electronics")
        assert(BluetoothDiscoveryService.resolveCompanyIdentifier(0x027D) == "Huawei Technologies")
        assert(BluetoothDiscoveryService.resolveCompanyIdentifier(0x038F) == "Xiaomi Inc.")
        print("✓ Bluetooth SIG Company Identifiers resolved correctly")

        // Probe 3: SIG Standard Service UUIDs
        print("\n[Probe 3] Bluetooth SIG Standard Service UUIDs...")
        assert(BluetoothDiscoveryService.resolveServiceUUID("180F") == "Battery Service")
        assert(BluetoothDiscoveryService.resolveServiceUUID("1812") == "Human Interface Device")
        assert(BluetoothDiscoveryService.resolveServiceUUID("180D") == "Heart Rate Service")
        assert(BluetoothDiscoveryService.resolveServiceUUID("FE9F") == "Google Fast Pair")
        assert(BluetoothDiscoveryService.resolveServiceUUID("FD6F") == "Exposure Notification")
        print("✓ Standard GATT Service UUIDs translated properly")

        // Probe 4: Classic Bluetooth (IOBluetooth) Live Stack
        print("\n[Probe 4] Classic Bluetooth (IOBluetooth) Live Stack...")
        let paired = IOBluetoothDevice.pairedDevices() ?? []
        print("  Found \(paired.count) paired Classic Bluetooth device(s)")
        for item in paired {
            if let dev = item as? IOBluetoothDevice {
                let name = dev.nameOrAddress ?? "Unknown"
                let mac = dev.addressString ?? "None"
                print("   - Classic Device: '\(name)' [\(mac)], Connected: \(dev.isConnected())")
            }
        }
        assert(paired.count > 0, "Host system should have paired Classic devices")
        print("✓ IOBluetooth Classic device subsystem verified")

        // Probe 5: CoreBluetooth Central Manager Live Stack
        print("\n[Probe 5] CoreBluetooth Central Manager Live Stack...")
        class TestCentralDelegate: NSObject, CBCentralManagerDelegate {
            var stateUpdated = false
            func centralManagerDidUpdateState(_ central: CBCentralManager) {
                stateUpdated = true
            }
        }
        let del = TestCentralDelegate()
        let mgr = CBCentralManager(delegate: del, queue: nil)
        try? await Task.sleep(nanoseconds: 500_000_000)
        print("  CBCentralManager State: \(mgr.state.rawValue)")
        assert(mgr.state != .unsupported, "Bluetooth must be supported on host")
        print("✓ CBCentralManager initialized and verified on hardware")

        // Probe 6: Service Singleton & Export Validation
        print("\n[Probe 6] BluetoothDiscoveryService Singleton & Export Validation...")
        let service = BluetoothDiscoveryService.shared
        service.harvestPairedClassicDevices()
        let count = service.devices.count
        print("  Service devices count after paired harvest: \(count)")
        assert(count > 0, "Should have ingested paired devices")
        let jsonExport = service.exportAsJSON()
        assert(jsonExport.starts(with: "[") && jsonExport.contains("macAddress"), "JSON export format valid")
        let csvExport = service.exportAsCSV()
        assert(csvExport.starts(with: "Identifier,Device Name"), "CSV header format valid")
        print("✓ Service ingestion and JSON/CSV export validated")

        print("\n=======================================================")
        print("  ALL BLUETOOTH RADAR PROBES PASSED (100%)")
        print("=======================================================")
    }
}
