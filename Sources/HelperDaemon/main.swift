import Foundation

class HelperDaemonDelegate: NSObject, NSXPCListenerDelegate {
    let service = HelperDaemonService()
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}

let delegate = HelperDaemonDelegate()
let listener = NSXPCListener(machServiceName: "com.networkutilities.helper.xpc")
listener.delegate = delegate
listener.resume()

// Run loop keep alive for launchd daemon
RunLoop.main.run()
