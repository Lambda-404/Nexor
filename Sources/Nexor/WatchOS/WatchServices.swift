import Foundation
import Network

#if os(watchOS)

class WatchNetworkHelper {
    
    static func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "pdp_ip0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
    
    static func pingHost(_ host: String, completion: @escaping (Double?) -> Void) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: 80)
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .wifi
        let connection = NWConnection(to: endpoint, using: parameters)
        let start = Date()
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let rtt = Date().timeIntervalSince(start)
                connection.cancel()
                completion(rtt)
            case .failed(_), .cancelled:
                completion(nil)
            default:
                break
            }
        }
        connection.start(queue: .global())
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            if connection.state != .ready && connection.state != .cancelled {
                connection.cancel()
                completion(nil)
            }
        }
    }
    
    static func resolveDNS(_ hostname: String) -> [String] {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        
        var result: UnsafeMutablePointer<addrinfo>?
        var ips = [String]()
        
        if getaddrinfo(hostname, nil, &hints, &result) == 0 {
            var ptr = result
            while let info = ptr {
                var hostnameBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(info.pointee.ai_addr, info.pointee.ai_addrlen,
                               &hostnameBuffer, socklen_t(hostnameBuffer.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    ips.append(String(cString: hostnameBuffer))
                }
                ptr = info.pointee.ai_next
            }
            freeaddrinfo(result)
        }
        return Array(Set(ips))
    }
    
    static func calculateSubnet(ip: String, mask: String) -> String {
        func ipToUInt32(_ ipStr: String) -> UInt32? {
            var sin = sockaddr_in()
            guard ipStr.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 else { return nil }
            return UInt32(bigEndian: sin.sin_addr.s_addr)
        }
        
        func uint32ToIP(_ val: UInt32) -> String {
            let byte1 = UInt8((val >> 24) & 0xFF)
            let byte2 = UInt8((val >> 16) & 0xFF)
            let byte3 = UInt8((val >> 8) & 0xFF)
            let byte4 = UInt8(val & 0xFF)
            return "\(byte1).\(byte2).\(byte3).\(byte4)"
        }
        
        guard let ipVal = ipToUInt32(ip), let maskVal = ipToUInt32(mask) else {
            return "Invalid IP or Mask"
        }
        
        let networkVal = ipVal & maskVal
        let broadcastVal = networkVal | ~maskVal
        
        return """
        Network: \(uint32ToIP(networkVal))
        Broadcast: \(uint32ToIP(broadcastVal))
        Host Min: \(uint32ToIP(networkVal + 1))
        Host Max: \(uint32ToIP(broadcastVal - 1))
        """
    }
    
    static func scanPorts(host: String, ports: [UInt16], completion: @escaping (String) -> Void) {
        let group = DispatchGroup()
        var results = [String]()
        let queue = DispatchQueue(label: "portScanQueue")
        
        for port in ports {
            group.enter()
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port))
            let connection = NWConnection(to: endpoint, using: .tcp)
            
            var didComplete = false
            
            connection.stateUpdateHandler = { state in
                if didComplete { return }
                switch state {
                case .ready:
                    didComplete = true
                    queue.async {
                        results.append("Port \(port): OPEN")
                    }
                    connection.cancel()
                    group.leave()
                case .failed(_), .cancelled:
                    didComplete = true
                    queue.async {
                        results.append("Port \(port): CLOSED")
                    }
                    connection.cancel()
                    group.leave()
                default:
                    break
                }
            }
            connection.start(queue: .global())
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                if !didComplete {
                    didComplete = true
                    queue.async {
                        results.append("Port \(port): TIMEOUT/CLOSED")
                    }
                    connection.cancel()
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(results.sorted().joined(separator: "\n"))
        }
    }
    
    static func sendWOL(mac: String, broadcastIP: String) -> Bool {
        var macBytes = [UInt8]()
        let components = mac.split(separator: ":")
        for comp in components {
            if let byte = UInt8(comp, radix: 16) {
                macBytes.append(byte)
            }
        }
        guard macBytes.count == 6 else { return false }
        
        var packet = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }
        
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return false }
        
        var broadcast: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout.size(ofValue: broadcast)))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(9).bigEndian
        inet_pton(AF_INET, broadcastIP, &addr.sin_addr)
        
        let sent = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(sock, packet, packet.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.stride))
            }
        }
        
        close(sock)
        return sent == packet.count
    }
}

#endif
