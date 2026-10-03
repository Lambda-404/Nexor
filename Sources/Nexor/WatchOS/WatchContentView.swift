import SwiftUI
import Network

#if os(watchOS)
struct WatchContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Dashboard") {
                    NavigationLink(destination: WatchDashboardView()) {
                        Label("Network Status", systemImage: "network")
                    }
                }
                
                Section("Tools") {
                    NavigationLink(destination: WatchPingView()) {
                        Label("Ping", systemImage: "waveform.path.ecg")
                    }
                    NavigationLink(destination: WatchDNSLookupView()) {
                        Label("DNS Lookup", systemImage: "magnifyingglass.circle")
                    }
                    NavigationLink(destination: WatchWebsiteCheckView()) {
                        Label("Website Check", systemImage: "globe")
                    }
                    NavigationLink(destination: WatchSubnetCalculatorView()) {
                        Label("Subnet Calc", systemImage: "tablecells")
                    }
                    NavigationLink(destination: WatchPortScannerView()) {
                        Label("Port Scan", systemImage: "door.left.hand.open")
                    }
                    NavigationLink(destination: WatchWakeOnLANView()) {
                        Label("Wake on LAN", systemImage: "power")
                    }
                }
            }
            .navigationTitle("Nexor")
        }
    }
}
#endif
