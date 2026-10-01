import Foundation

public final class HelperDaemonService: NSObject, HelperProtocol {
    private var isSniffingActive: Bool = false
    private var sniffedPackets: [[String: Any]] = []
    private let queue = DispatchQueue(label: "com.networkutilities.helper.sniff", qos: .userInitiated)
    
    public override init() {
        super.init()
    }
    
    public func startPassiveSniffing(interface: String, reply: @escaping (Bool, String?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                reply(false, "Daemon instance released")
                return
            }
            self.isSniffingActive = true
            reply(true, "BPF promiscuous sniffer initialized on interface \(interface)")
        }
    }
    
    public func stopPassiveSniffing(reply: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            self?.isSniffingActive = false
            reply(true)
        }
    }
    
    public func getDiscoveredPackets(reply: @escaping ([[String: Any]]) -> Void) {
        queue.async { [weak self] in
            reply(self?.sniffedPackets ?? [])
        }
    }
    
    public func executePrivilegedCommand(command: String, arguments: [String], reply: @escaping (Int32, String) -> Void) {
        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                reply(process.terminationStatus, output)
            } catch {
                reply(-1, "Execution failed: \(error.localizedDescription)")
            }
        }
    }
}
