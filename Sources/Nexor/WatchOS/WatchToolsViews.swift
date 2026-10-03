import SwiftUI
import Network
import Foundation

#if os(watchOS)

// MARK: - Dashboard
struct WatchDashboardView: View {
    @State private var connectionType: String = "Unknown"
    @State private var localIP: String = "Fetching..."
    private let monitor = NWPathMonitor()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "wifi")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Connection Status")
                        .font(.headline)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type: \(connectionType)")
                    Text("Local IP: \(localIP)")
                }
                .font(.footnote)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("Status")
        .onAppear {
            startMonitoring()
            fetchIP()
        }
        .onDisappear {
            monitor.cancel()
        }
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = "Wi-Fi"
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = "Cellular"
                } else if path.status == .satisfied {
                    self.connectionType = "Connected"
                } else {
                    self.connectionType = "No Connection"
                }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    private func fetchIP() {
        self.localIP = WatchNetworkHelper.getLocalIPAddress() ?? "Unavailable"
    }
}

// MARK: - Ping
struct WatchPingView: View {
    @State private var host = ""
    @State private var result = ""
    @State private var isPinging = false

    var body: some View {
        ScrollView {
            VStack {
                TextField("Host or IP", text: $host)
                Button(action: ping) {
                    Text(isPinging ? "Pinging..." : "Start Ping")
                }
                .disabled(isPinging || host.isEmpty)
                
                Text(result)
                    .font(.caption2)
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Ping")
    }
    
    private func ping() {
        isPinging = true
        result = "Pinging \(host)...\n"
        WatchNetworkHelper.pingHost(host) { rtt in
            DispatchQueue.main.async {
                isPinging = false
                if let rtt = rtt {
                    result += "Success! RTT: \(String(format: "%.1f", rtt * 1000)) ms"
                } else {
                    result += "Failed to ping \(host)."
                }
            }
        }
    }
}

// MARK: - DNS Lookup
struct WatchDNSLookupView: View {
    @State private var hostname = ""
    @State private var result = ""
    @State private var isResolving = false

    var body: some View {
        ScrollView {
            VStack {
                TextField("Domain name", text: $hostname)
                Button(action: resolve) {
                    Text(isResolving ? "Resolving..." : "Resolve")
                }
                .disabled(isResolving || hostname.isEmpty)
                
                Text(result)
                    .font(.caption2)
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("DNS")
    }
    
    private func resolve() {
        isResolving = true
        result = "Resolving \(hostname)...\n"
        DispatchQueue.global(qos: .userInitiated).async {
            let ips = WatchNetworkHelper.resolveDNS(hostname)
            DispatchQueue.main.async {
                isResolving = false
                if ips.isEmpty {
                    result += "No IPs found."
                } else {
                    result += ips.joined(separator: "\n")
                }
            }
        }
    }
}

// MARK: - Website Check
struct WatchWebsiteCheckView: View {
    @State private var urlString = ""
    @State private var result = ""
    @State private var isChecking = false

    var body: some View {
        ScrollView {
            VStack {
                TextField("URL", text: $urlString)
                Button(action: check) {
                    Text(isChecking ? "Checking..." : "Check")
                }
                .disabled(isChecking || urlString.isEmpty)
                
                Text(result)
                    .font(.caption2)
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Website")
    }
    
    private func check() {
        guard let url = URL(string: urlString) else {
            result = "Invalid URL"
            return
        }
        isChecking = true
        result = "Checking...\n"
        
        let start = Date()
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            let duration = Date().timeIntervalSince(start)
            DispatchQueue.main.async {
                isChecking = false
                if let error = error {
                    result += "Error: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse {
                    result += "Status: \(httpResponse.statusCode)\nLatency: \(String(format: "%.0f", duration * 1000)) ms"
                }
            }
        }.resume()
    }
}

// MARK: - Subnet Calculator
struct WatchSubnetCalculatorView: View {
    @State private var ip = "192.168.1.1"
    @State private var mask = "255.255.255.0"
    @State private var result = ""

    var body: some View {
        ScrollView {
            VStack {
                TextField("IP Address", text: $ip)
                TextField("Subnet Mask", text: $mask)
                Button("Calculate") {
                    calculate()
                }
                
                Text(result)
                    .font(.caption2)
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Subnet")
    }
    
    private func calculate() {
        result = WatchNetworkHelper.calculateSubnet(ip: ip, mask: mask)
    }
}

// MARK: - Port Scanner
struct WatchPortScannerView: View {
    @State private var host = "192.168.1.1"
    @State private var portsText = "80, 443"
    @State private var result = ""
    @State private var isScanning = false

    var body: some View {
        ScrollView {
            VStack {
                TextField("Host", text: $host)
                TextField("Ports (comma separated)", text: $portsText)
                Button(action: scan) {
                    Text(isScanning ? "Scanning..." : "Scan")
                }
                .disabled(isScanning || host.isEmpty || portsText.isEmpty)
                
                Text(result)
                    .font(.caption2)
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("Port Scan")
    }
    
    private func scan() {
        let ports = portsText.split(separator: ",").compactMap { UInt16($0.trimmingCharacters(in: .whitespaces)) }
        if ports.isEmpty {
            result = "Invalid ports"
            return
        }
        isScanning = true
        result = "Scanning...\n"
        
        WatchNetworkHelper.scanPorts(host: host, ports: ports) { scanResults in
            DispatchQueue.main.async {
                isScanning = false
                self.result = scanResults
            }
        }
    }
}

// MARK: - Wake on LAN
struct WatchWakeOnLANView: View {
    @State private var macAddress = "00:11:22:33:44:55"
    @State private var ipAddress = "255.255.255.255"
    @State private var result = ""

    var body: some View {
        ScrollView {
            VStack {
                TextField("MAC Address", text: $macAddress)
                TextField("Broadcast IP", text: $ipAddress)
                Button("Wake") {
                    wake()
                }
                
                Text(result)
                    .font(.caption2)
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("WOL")
    }
    
    private func wake() {
        let success = WatchNetworkHelper.sendWOL(mac: macAddress, broadcastIP: ipAddress)
        result = success ? "Magic packet sent." : "Failed to send packet."
    }
}

#endif
