import SwiftUI
import ServiceManagement
import AppKit

public struct SettingsView: View {
    @State private var helperDaemonStatus: String = "Checking..."
    @State private var devFallbackEnabled: Bool = true
    @State private var isCodeSigningError: Bool = false
    @State private var selectedInterface: String = "en0"
    @State private var autoRefreshTelemetry: Bool = true
    @State private var refreshIntervalSeconds: Double = 3.0
    @State private var copiedCommandToast: Bool = false
    
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra: Bool = true
    @AppStorage("menuBarDisplayMode") private var menuBarDisplayMode: MenuBarDisplayMode = .speedAndGraph
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section 1: Privilege Escalation & Helper Daemon (R5)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .bold))
                        Text("Privilege Escalation & Helper Daemon")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    
                    HStack(alignment: .top) {
                        Text("Daemon Status:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 120, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(helperDaemonStatus)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(statusColor)
                            
                            if isCodeSigningError {
                                Text("macOS 13+ requires an Apple Developer ID certificate to register daemons via SMAppService.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    
                    // Explanatory Banner for Code -67056
                    if isCodeSigningError {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("Development Fallback Mode Active")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                            }
                            
                            Text("Running in open-source development mode. All features (dual-stack ARP/NDP discovery, Wi-Fi RF telemetry, mDNS Apple Model ID extraction, and network tools) function smoothly in user-space!")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                Text("To launch with raw root privileges:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(copiedCommandToast ? "Copied!" : "Copy sudo Command") {
                                    copyRootCommand()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(12)
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(10)
                    }
                    
                    Toggle("Enable Development Fallback Mode", isOn: $devFallbackEnabled)
                        .font(.system(size: 12))
                    
                    HStack(spacing: 12) {
                        Button("Register Daemon (SMAppService)") {
                            registerHelperDaemon()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        
                        Button("Unregister Daemon") {
                            unregisterHelperDaemon()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(18)
                .liquidGlass(cornerRadius: 16, elevation: 1)
                
                // Section 2: macOS Menu Bar Extra & Popover Configuration (R3)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "menubar.dock.rectangle")
                            .foregroundColor(.indigo)
                            .font(.system(size: 16, weight: .bold))
                        Text("macOS Menu Bar Extra & Quick Access")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    
                    Toggle("Enable Status Item in Menu Bar", isOn: $showMenuBarExtra)
                        .font(.system(size: 12))
                    
                    if showMenuBarExtra {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Mode:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Picker("Display Mode", selection: $menuBarDisplayMode) {
                                ForEach(MenuBarDisplayMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            HStack {
                                Text("Preview: ")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(menuBarDisplayMode.previewSample)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(18)
                .liquidGlass(cornerRadius: 16, elevation: 1)
                
                // Section 3: Telemetry & Interface Configuration
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.purple)
                            .font(.system(size: 16, weight: .bold))
                        Text("Telemetry & Interface Configuration")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    
                    Picker("Primary Interface:", selection: $selectedInterface) {
                        Text("en0 (Built-in Wi-Fi)").tag("en0")
                        Text("en1 (Secondary Adapter)").tag("en1")
                        Text("Automatic Detection").tag("auto")
                    }
                    .font(.system(size: 12))
                    
                    Toggle("Auto-refresh Telemetry", isOn: $autoRefreshTelemetry)
                        .font(.system(size: 12))
                    
                    if autoRefreshTelemetry {
                        HStack {
                            Text("Interval:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Slider(value: $refreshIntervalSeconds, in: 1...10, step: 1)
                            Text("\(Int(refreshIntervalSeconds))s")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(width: 32)
                        }
                    }
                }
                .padding(18)
                .liquidGlass(cornerRadius: 16, elevation: 1)
                
                // Section 3: Hardware OUI Database
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.teal)
                            .font(.system(size: 16, weight: .bold))
                        Text("Hardware Fingerprinting & Database")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    
                    HStack {
                        Text("IEEE 802 Vendor Database:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Loaded (34,000+ OUIs)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Apple Hardware Identifiers:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Mac, iPhone, iPad, Apple Watch (M1-M4)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(18)
                .liquidGlass(cornerRadius: 16, elevation: 1)
                
                // Section 4: About Nexor
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .bold))
                        Text("About Nexor")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    
                    HStack {
                        Text("Version:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("1.0.0 (Native Swift 6 & macOS 14+)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Architecture:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Liquid Glass Native UI • Dual-Stack BPF / ARP / NDP")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(18)
                .liquidGlass(cornerRadius: 16, elevation: 1)
            }
            .padding(20)
        }
        .navigationTitle("Settings")
        .onAppear {
            checkDaemonStatus()
        }
    }
    
    private var statusColor: Color {
        if helperDaemonStatus == "Registered" { return .green }
        if isCodeSigningError { return .orange }
        return .secondary
    }
    
    private func checkDaemonStatus() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.networkutilities.helper.plist")
            switch service.status {
            case .enabled:
                helperDaemonStatus = "Registered"
                isCodeSigningError = false
            case .requiresApproval:
                helperDaemonStatus = "Requires System Approval"
                isCodeSigningError = false
            case .notRegistered:
                helperDaemonStatus = "Not Registered (Dev Fallback Active)"
                isCodeSigningError = false
            case .notFound:
                helperDaemonStatus = "Daemon Not Installed"
                isCodeSigningError = false
            @unknown default:
                helperDaemonStatus = "Status Unknown"
                isCodeSigningError = false
            }
        } else {
            helperDaemonStatus = "Legacy Daemon Mode"
        }
    }
    
    private func registerHelperDaemon() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.networkutilities.helper.plist")
            do {
                try service.register()
                checkDaemonStatus()
            } catch {
                let errStr = error.localizedDescription
                if errStr.contains("-67056") || errStr.contains("Codesigning failure") {
                    isCodeSigningError = true
                    helperDaemonStatus = "Requires Apple Developer Certificate (-67056)"
                } else {
                    helperDaemonStatus = "Registration Error: \(errStr)"
                }
            }
        }
    }
    
    private func unregisterHelperDaemon() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.networkutilities.helper.plist")
            service.unregister { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.helperDaemonStatus = "Unregister Error: \(error.localizedDescription)"
                    } else {
                        self.checkDaemonStatus()
                    }
                }
            }
        }
    }
    
    private func copyRootCommand() {
        let execPath = Bundle.main.executablePath ?? "/Applications/Nexor.app/Contents/MacOS/Nexor"
        let cmd = "sudo \"\(execPath)\""
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmd, forType: .string)
        copiedCommandToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.copiedCommandToast = false
        }
    }
}
