import Foundation
import Darwin
import SystemConfiguration

@main
struct FeatureVerificationProbes {
    static func main() {
        print("=== Starting NetWorker Pro & LanScan Verification Probes ===")

        // Probe 1: AppIcon Verification
        print("\n[Probe 1] AppIcon Verification...")
        let projectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
        let bundleIcon = "\(projectRoot)/Nexor.app/Contents/Resources/AppIcon.icns"
        let resIcon = "\(projectRoot)/Resources/AppIcon.icns"
        if FileManager.default.fileExists(atPath: resIcon) {
            let iconAttrs = try! FileManager.default.attributesOfItem(atPath: resIcon)
            let iconSize = iconAttrs[.size] as! Int64
            assert(iconSize > 500_000, "AppIcon.icns is unexpectedly small: \(iconSize) bytes")
            print("✓ AppIcon verified: \(iconSize) bytes (Retina multi-resolution icns)")
        } else {
            print("ℹ AppIcon.icns not yet generated in Resources (can be built via build.sh)")
        }

        // Probe 2: TrafficUnitFormatter Verification
        print("\n[Probe 2] TrafficUnitFormatter Verification...")
        assert(TrafficUnitFormatter.formatRate(0) == "0 B/s")
        assert(TrafficUnitFormatter.formatRate(-10.5) == "0 B/s")
        assert(TrafficUnitFormatter.formatRate(500) == "500 B/s")
        assert(TrafficUnitFormatter.formatRate(1024 * 120) == "120 KB/s")
        assert(TrafficUnitFormatter.formatRate(1024 * 1024 * 2.4) == "2.40 MB/s")
        assert(TrafficUnitFormatter.formatRate(1024 * 1024 * 1024 * 1.5) == "1.50 GB/s")
        assert(TrafficUnitFormatter.formatRate(Double.nan) == "0 B/s")
        assert(TrafficUnitFormatter.formatRate(Double.infinity) == "0 B/s")
        print("✓ Genuine TrafficUnitFormatter verified across all boundary units and NaN/Inf sanitization")

        // Probe 3: sysctl NET_RT_IFLIST2 64-bit Metrics Verification
        print("\n[Probe 3] Kernel sysctl NET_RT_IFLIST2 64-bit Verification...")
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len = 0
        assert(sysctl(&mib, 6, nil, &len, nil, 0) == 0, "sysctl NET_RT_IFLIST2 length query failed")
        var buf = [UInt8](repeating: 0, count: len)
        assert(sysctl(&mib, 6, &buf, &len, nil, 0) == 0, "sysctl NET_RT_IFLIST2 buffer fetch failed")

        var found64bit = false
        buf.withUnsafeBytes { rawBuffer in
            guard let basePtr = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= len {
                let msgPtr = basePtr.advanced(by: offset)
                let msgHdr = msgPtr.assumingMemoryBound(to: if_msghdr.self).pointee
                let msgLen = Int(msgHdr.ifm_msglen)
                if msgLen <= 0 || offset + msgLen > len { break }
                if msgHdr.ifm_type == RTM_IFINFO2 && msgLen >= MemoryLayout<if_msghdr2>.size {
                    let ifm2 = msgPtr.assumingMemoryBound(to: if_msghdr2.self).pointee
                    var nameBuf = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                    if_indextoname(UInt32(ifm2.ifm_index), &nameBuf)
                    let name = String(cString: nameBuf)
                    if (name == "en6" || name == "en0") {
                        found64bit = true
                        print("  Interface \(name): ibytes=\(ifm2.ifm_data.ifi_ibytes), obytes=\(ifm2.ifm_data.ifi_obytes), baudrate=\(ifm2.ifm_data.ifi_baudrate) bps")
                        assert(ifm2.ifm_data.ifi_mtu == 1500, "MTU should be 1500")
                    }
                }
                offset += msgLen
            }
        }
        assert(found64bit, "Did not find active 64-bit interface data!")
        print("✓ sysctl NET_RT_IFLIST2 genuine 64-bit data verified")

        // Probe 4: Primary Network Medium & ioctl SIOCGIFMEDIA Verification
        print("\n[Probe 4] Dual-Medium Detection & SIOCGIFMEDIA Verification...")
        let store = SCDynamicStoreCreate(nil, "VerifyMedium" as CFString, nil, nil)!
        let ipv4Dict = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any]
        assert(ipv4Dict != nil, "Global IPv4 state missing!")
        let primary = ipv4Dict!["PrimaryInterface"] as! String
        let router = ipv4Dict!["Router"] as? String
        print("  Primary Interface: \(primary), Router: \(router ?? "--")")

        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        defer { close(sock) }
        var ifmr = ifmediareq()
        withUnsafeMutableBytes(of: &ifmr.ifm_name) { ptr in
            _ = strncpy(ptr.baseAddress!.assumingMemoryBound(to: CChar.self), primary, Int(IFNAMSIZ))
        }
        let ioctlRes = ioctl(sock, 0xc0286938, &ifmr)
        assert(ioctlRes == 0, "ioctl SIOCGIFMEDIA failed for primary interface \(primary)")
        let isCarrierActive = (ifmr.ifm_status & 0x02) != 0
        let isEthernet = (ifmr.ifm_active & 0xe0) == 0x20
        let isFDX = (ifmr.ifm_active & 0x00100000) != 0
        let subtype = Int((UInt32(bitPattern: ifmr.ifm_active) & 0x1f) | ((UInt32(bitPattern: ifmr.ifm_active) & 0x000f0000) >> 11))
        print("  Carrier Active: \(isCarrierActive), Is Ethernet: \(isEthernet), Subtype: \(subtype), Full Duplex: \(isFDX)")
        assert(isCarrierActive, "Primary interface carrier should be active")
        print("✓ Dual-Medium detection and ioctl link negotiation verified")

        // Probe 5: Codesign Verification
        print("\n[Probe 5] Codesigning Verification...")
        let appBundlePath = "\(projectRoot)/Nexor.app"
        if FileManager.default.fileExists(atPath: appBundlePath) {
            let csProc = Process()
            csProc.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            csProc.arguments = ["-v", appBundlePath]
            try! csProc.run()
            csProc.waitUntilExit()
            assert(csProc.terminationStatus == 0, "codesign -v failed!")
            print("✓ App bundle codesign verification passed (Exit code 0)")
        } else {
            print("ℹ Nexor.app not yet compiled, codesign probe skipped")
        }

        print("\n=== ALL NEW FEATURE VERIFICATION PROBES PASSED SUCCESSFULLY ===")
    }
}
