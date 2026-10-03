import os
path = "Sources/Nexor/App/NexorApp.swift"
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
#if os(macOS)
        WindowGroup(id: "mainWindow") {
            ContentView()
                .environment(\\.diagnosticManager, executionManager)
                .frame(minWidth: 1000, minHeight: 680)
        }
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
#else
        WindowGroup(id: "mainWindow") {
            Text("Network Utilities not supported on watchOS")
        }
#endif
    }
}
"""
with open(path, "w") as f:
    f.write(app_content)
