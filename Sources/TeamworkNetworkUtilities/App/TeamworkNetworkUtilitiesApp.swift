import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // App stays alive in macOS Menu Bar when main window is closed
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

@main
struct NexorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var executionManager = DiagnosticExecutionManager()
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra: Bool = true
    
    var body: some Scene {
        WindowGroup(id: "mainWindow") {
            ContentView()
                .environment(\.diagnosticManager, executionManager)
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
    }
}
