#if os(macOS)
import Foundation
import Darwin
import SystemConfiguration

public actor TrafficStatisticsEngine {
    public struct RawTrafficSample: Sendable {
        public let name: String
        public let ibytes: UInt64
        public let obytes: UInt64
        public let ipackets: UInt64
        public let opackets: UInt64
        public let baudrate: UInt64
        public let flags: UInt32
        public let mtu: UInt32
        public let timestamp: Date
    }

    private var previousSamples: [String: RawTrafficSample] = [:]
    private var sessionRxBytes: [String: UInt64] = [:]
    private var sessionTxBytes: [String: UInt64] = [:]
    private var isMonitoring: Bool = false

    public init() {}

    public func resetSession() {
        sessionRxBytes.removeAll()
        sessionTxBytes.removeAll()
    }

    public func sample() -> TrafficSnapshot {
        let currentRaw = Self.readKernelInterfaces()
        let now = Date()
        let primaryName = Self.resolvePrimaryInterface()
        let interfaceMeta = Self.fetchInterfaceMetadata()

        var statsList: [InterfaceTrafficStats] = []
        var aggRxRate: Double = 0
        var aggTxRate: Double = 0
        var aggSessionRx: UInt64 = 0
        var aggSessionTx: UInt64 = 0
        var activeCount: Int = 0

        for (name, raw) in currentRaw {
            let prev = previousSamples[name]
            let dt: Double
            let deltaRx: UInt64
            let deltaTx: UInt64

            if let prev = prev {
                dt = max(0.001, raw.timestamp.timeIntervalSince(prev.timestamp))
                deltaRx = raw.ibytes >= prev.ibytes ? (raw.ibytes - prev.ibytes) : 0
                deltaTx = raw.obytes >= prev.obytes ? (raw.obytes - prev.obytes) : 0
            } else {
                dt = 1.0
                deltaRx = 0
                deltaTx = 0
            }

            let rxRate = Double(deltaRx) / dt
            let txRate = Double(deltaTx) / dt

            // Monotonic delta accumulation for session counters (eliminates asymmetric resets and reconnect loss)
            sessionRxBytes[name, default: 0] += deltaRx
            sessionTxBytes[name, default: 0] += deltaTx
            let sessionRx = sessionRxBytes[name, default: 0]
            let sessionTx = sessionTxBytes[name, default: 0]

            let isPrimary = (name == primaryName)
            let isUp = (raw.flags & UInt32(IFF_UP)) != 0
            let isRunning = (raw.flags & UInt32(IFF_RUNNING)) != 0
            let isLoopback = (raw.flags & UInt32(IFF_LOOPBACK)) != 0 || name == "lo0"
            let meta = interfaceMeta[name]
            let medium = Self.classifyMedium(name: name, typeString: meta?.type, isLoopback: isLoopback)

            let stats = InterfaceTrafficStats(
                name: name,
                displayName: meta?.displayName ?? name,
                medium: medium,
                isPrimary: isPrimary,
                isUp: isUp,
                isRunning: isRunning,
                rxBytesPerSecond: rxRate,
                txBytesPerSecond: txRate,
                sessionRxBytes: sessionRx,
                sessionTxBytes: sessionTx,
                totalRxBytes: raw.ibytes,
                totalTxBytes: raw.obytes,
                baudrate: raw.baudrate,
                mtu: raw.mtu,
                timestamp: now
            )
            statsList.append(stats)

            // Aggregate non-loopback active physical adapters or primary routed interface
            if !isLoopback && (name.hasPrefix("en") || isPrimary) && isUp && isRunning {
                aggRxRate += rxRate
                aggTxRate += txRate
                aggSessionRx += sessionRx
                aggSessionTx += sessionTx
                activeCount += 1
            }
        }

        self.previousSamples = currentRaw

        let primaryStats = statsList.first(where: { $0.name == primaryName })
        let aggregate = AggregateTrafficStats(
            rxBytesPerSecond: aggRxRate,
            txBytesPerSecond: aggTxRate,
            sessionRxBytes: aggSessionRx,
            sessionTxBytes: aggSessionTx,
            activeInterfaceCount: activeCount
        )

        return TrafficSnapshot(
            timestamp: now,
            primaryInterfaceName: primaryName,
            primaryStats: primaryStats,
            aggregateStats: aggregate,
            perInterfaceStats: statsList.sorted(by: {
                if $0.isPrimary != $1.isPrimary { return $0.isPrimary && !$1.isPrimary }
                return $0.name < $1.name
            })
        )
    }

    public func startMonitoring(intervalNanoseconds: UInt64 = 1_000_000_000) -> AsyncStream<TrafficSnapshot> {
        AsyncStream { continuation in
            let task = Task {
                _ = self.sample()
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: intervalNanoseconds)
                    guard !Task.isCancelled else { break }
                    let snap = self.sample()
                    continuation.yield(snap)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - sysctl NET_RT_IFLIST2 Extraction (64-bit if_data64)

    public nonisolated static func readKernelInterfaces() -> [String: RawTrafficSample] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len = 0
        guard sysctl(&mib, 6, nil, &len, nil, 0) == 0 else { return [:] }
        var buf = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, 6, &buf, &len, nil, 0) == 0 else { return [:] }

        var result: [String: RawTrafficSample] = [:]
        let now = Date()

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
                    if !name.isEmpty {
                        result[name] = RawTrafficSample(
                            name: name,
                            ibytes: ifm2.ifm_data.ifi_ibytes,
                            obytes: ifm2.ifm_data.ifi_obytes,
                            ipackets: ifm2.ifm_data.ifi_ipackets,
                            opackets: ifm2.ifm_data.ifi_opackets,
                            baudrate: ifm2.ifm_data.ifi_baudrate,
                            flags: UInt32(ifm2.ifm_flags),
                            mtu: ifm2.ifm_data.ifi_mtu,
                            timestamp: now
                        )
                    }
                }
                offset += msgLen
            }
        }
        return result
    }

    public nonisolated static func resolvePrimaryInterface() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "RouteFinder" as CFString, nil, nil),
              let globalIPv4 = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any] else {
            return nil
        }
        return globalIPv4["PrimaryInterface"] as? String
    }

    public nonisolated static func fetchInterfaceMetadata() -> [String: (displayName: String, type: String)] {
        var map: [String: (displayName: String, type: String)] = [:]
        if let ifaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] {
            for iface in ifaces {
                if let bsdName = SCNetworkInterfaceGetBSDName(iface) as String?,
                   let disp = SCNetworkInterfaceGetLocalizedDisplayName(iface) as String?,
                   let type = SCNetworkInterfaceGetInterfaceType(iface) as String? {
                    map[bsdName] = (disp, type)
                }
            }
        }
        return map
    }

    public nonisolated static func classifyMedium(name: String, typeString: String?, isLoopback: Bool) -> InterfaceMedium {
        if isLoopback || name == "lo0" { return .loopback }
        if let type = typeString {
            if type == "IEEE80211" { return .wifi }
            if type == "Ethernet" { return .ethernet }
            if type == "Bridge" { return .bridge }
        }
        if name.hasPrefix("en") { return .ethernet }
        if name.hasPrefix("utun") || name.hasPrefix("gif") || name.hasPrefix("stf") { return .vpn }
        if name.hasPrefix("bridge") { return .bridge }
        return .other
    }
}

#endif
