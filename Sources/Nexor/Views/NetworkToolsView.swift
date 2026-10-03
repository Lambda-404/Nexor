#if os(macOS)
import SwiftUI

public struct NetworkToolsView: View {
    @Environment(\.diagnosticManager) private var diagnosticManager: DiagnosticExecutionManager
    @State private var selectedTool: DiagnosticToolType = .ping
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // Left Column: Tools List
            VStack(spacing: 0) {
                HStack {
                    Text("Diagnostic Tools")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    Text("9 Active")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                
                Divider().opacity(0.4)
                
                List(DiagnosticToolType.allCases, selection: $selectedTool) { tool in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(tool == selectedTool ? 0.25 : 0.12))
                            Image(systemName: tool.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                        .frame(width: 28, height: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tool.rawValue)
                                .font(.system(size: 12.5, weight: tool == selectedTool ? .semibold : .medium, design: .rounded))
                            Text(tool.description)
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 3)
                    .tag(tool)
                }
                .listStyle(.inset)
            }
            .frame(minWidth: 230, idealWidth: 260, maxWidth: 300)
            
            // Right Column: Execution Pane
            ToolExecutionPane(tool: selectedTool)
                .id(selectedTool.id)
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Tool Execution Pane

public struct ToolExecutionPane: View {
    public let tool: DiagnosticToolType
    @Environment(\.diagnosticManager) private var diagnosticManager: DiagnosticExecutionManager
    
    @State private var targetInput: String = ""
    @State private var outputText: String = ""
    @State private var isRunning: Bool = false
    @State private var activeStreamTask: Task<Void, Never>?
    
    public init(tool: DiagnosticToolType) {
        self.tool = tool
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header Glass Card
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                        }
                    Image(systemName: tool.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                .frame(width: 56, height: 56)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.rawValue)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(tool.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isRunning {
                    HStack(spacing: 6) {
                        PulsingBeacon(color: .orange, size: 6)
                        Text("EXECUTING")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlass(cornerRadius: 10, elevation: 1)
                }
            }
            .padding(16)
            .liquidGlass(cornerRadius: 16, elevation: 1.5)
            
            // Input controls
            if tool == .comprehensive {
                HStack(spacing: 12) {
                    Text("Automated end-to-end network health check across local interfaces, gateway, DNS, and WAN connectivity.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if isRunning {
                        Button(action: stopExecution) {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                Text("Stop")
                            }
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.red)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red.opacity(0.2))
                    } else {
                        Button(action: startExecution) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Run Health Check")
                            }
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    TextField(tool.targetPlaceholder, text: $targetInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .disabled(isRunning)
                    
                    if isRunning {
                        Button(action: stopExecution) {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                Text("Stop")
                            }
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.red)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red.opacity(0.2))
                    } else {
                        Button(action: startExecution) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Execute")
                            }
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    }
                }
            }
            
            // Console output display
            ConsoleOutputView(
                text: outputText,
                isRunning: isRunning,
                onClear: {
                    outputText = ""
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .navigationTitle(tool.rawValue)
        .onAppear {
            syncWithManager()
        }
    }
    
    private func syncWithManager() {
        Task {
            let running = await diagnosticManager.isTaskRunning(id: tool.id)
            let existingOutput = await diagnosticManager.getOutputString(id: tool.id)
            
            await MainActor.run {
                self.isRunning = running
                if !existingOutput.isEmpty {
                    self.outputText = existingOutput
                }
            }
        }
    }
    
    private func startExecution() {
        let trimmed = targetInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty && tool != .comprehensive {
            outputText = "Please enter a target to run \(tool.rawValue)."
            return
        }
        let target = (tool == .comprehensive) ? "auto" : trimmed
        isRunning = true
        
        activeStreamTask?.cancel()
        activeStreamTask = Task {
            do {
                let stream = try await diagnosticManager.startTask(
                    id: tool.id,
                    tool: tool,
                    parameters: ["target": target]
                )
                
                for try await line in stream {
                    if Task.isCancelled { break }
                    await MainActor.run {
                        self.outputText += (self.outputText.isEmpty ? "" : "\n") + line
                    }
                }
            } catch {
                await MainActor.run {
                    self.outputText += "\n[Error]: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                self.isRunning = false
            }
        }
    }
    
    private func stopExecution() {
        Task {
            await diagnosticManager.cancelTask(id: tool.id)
            await MainActor.run {
                self.isRunning = false
            }
        }
    }
}

#endif
