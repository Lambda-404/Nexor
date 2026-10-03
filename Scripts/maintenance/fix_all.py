import os

files_to_wrap = [
    "Sources/Nexor/Services/LANDiscoveryService.swift",
    "Sources/Nexor/Services/NetworkMediumDetector.swift",
    "Sources/Nexor/Services/TrafficStatisticsEngine.swift",
    "Sources/Nexor/Services/RFTelemetryService.swift",
    "Sources/Nexor/Services/WiFiScannerService.swift",
    "Sources/Nexor/Views/DashboardView.swift",
    "Sources/Nexor/Views/SettingsView.swift",
    "Sources/Nexor/Services/WiFiLocationAuthorizationHelper.swift",
    "Sources/Nexor/Views/BluetoothRadarView.swift",
    "Sources/Nexor/Views/Components/ConsoleOutputView.swift",
    "Sources/Nexor/Views/Components/LiquidGlassSystem.swift",
    "Sources/Nexor/Views/LANDevicesView.swift",
    "Sources/Nexor/Views/MenuBar/MenuBarPopoverView.swift",
    "Sources/Nexor/Services/BluetoothDiscoveryService.swift",
    "Sources/Nexor/Views/MenuBar/MenuBarExtraView.swift",
    "Sources/Nexor/Views/ContentView.swift",
    "Sources/Nexor/ViewModels/DashboardViewModel.swift",
    "Sources/Nexor/ViewModels/DiagnosticViewModel.swift",
    "Sources/Nexor/ViewModels/NetworkToolsViewModel.swift",
    "Sources/Nexor/Services/DiagnosticExecutionManager.swift",
    "Sources/Nexor/Views/DiagnosticsView.swift",
    "Sources/Nexor/Views/NetworkToolsView.swift",
    "Sources/Nexor/Views/SecurityScannerView.swift"
]

for file_path in files_to_wrap:
    if os.path.exists(file_path):
        with open(file_path, "r") as f:
            content = f.read()
        if not content.startswith("#if os(macOS)"):
            with open(file_path, "w") as f:
                f.write("#if os(macOS)\n" + content + "\n#endif\n")

app_path = "Sources/Nexor/App/NexorApp.swift"
app_content = """import SwiftUI
#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let window = sender.windows.first(where: { $0.canBecomeMain }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}
#endif

@main
struct NexorApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var executionManager = DiagnosticExecutionManager()
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra: Bool = true
#endif
    
    var body: some Scene {
        WindowGroup(id: "mainWindow") {
#if os(macOS)
            ContentView()
                .environment(\\.diagnosticManager, executionManager)
                .frame(minWidth: 1000, minHeight: 680)
#else
            Text("Network Utilities not supported on watchOS")
#endif
        }
#if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowResizability(.contentSize)
        .defaultSize(width: 1060, height: 720)
        
        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarPopoverView()
        } label: {
            MenuBarExtraView()
        }
        .menuBarExtraStyle(.window)
#endif
    }
}
"""
with open(app_path, "w") as f:
    f.write(app_content)
