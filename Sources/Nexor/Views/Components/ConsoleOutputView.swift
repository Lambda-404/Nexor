#if os(macOS)
import SwiftUI
import AppKit

public struct ConsoleOutputView: View {
    public let text: String
    public var isRunning: Bool
    public var onClear: (() -> Void)?
    public var onCopy: (() -> Void)?
    
    @State private var copiedToast: Bool = false
    
    public init(
        text: String,
        isRunning: Bool = false,
        onClear: (() -> Void)? = nil,
        onCopy: (() -> Void)? = nil
    ) {
        self.text = text
        self.isRunning = isRunning
        self.onClear = onClear
        self.onCopy = onCopy
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack(spacing: 8) {
                if isRunning {
                    PulsingBeacon(color: .green, size: 6)
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                }
                
                Text(isRunning ? "STREAMING ACTIVE" : "CONSOLE OUTPUT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isRunning ? .green : .secondary)
                
                Spacer()
                
                if copiedToast {
                    Text("Copied to Clipboard")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
                
                Button(action: handleCopy) {
                    Label(copiedToast ? "Copied" : "Copy", systemImage: copiedToast ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                if let onClear = onClear {
                    Button(action: onClear) {
                        Label("Clear", systemImage: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial)
            
            Divider()
                .opacity(0.4)
            
            // Console output area
            ScrollViewReader { proxy in
                ScrollView {
                    Text(text.isEmpty ? "Ready. Select a tool and execute to stream live telemetry output..." : text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(text.isEmpty ? .secondary.opacity(0.6) : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(14)
                        .id("bottom_anchor")
                }
                .onChange(of: text) { _, _ in
                    proxy.scrollTo("bottom_anchor", anchor: .bottom)
                }
            }
            .background(Color.black.opacity(0.25))
        }
        .liquidGlass(cornerRadius: 14, elevation: 2)
    }
    
    private func handleCopy() {
        if let onCopy = onCopy {
            onCopy()
        } else {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
        withAnimation {
            copiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                self.copiedToast = false
            }
        }
    }
}

#endif
