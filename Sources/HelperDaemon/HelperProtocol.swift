import Foundation

@objc public protocol HelperProtocol {
    func startPassiveSniffing(interface: String, reply: @escaping (Bool, String?) -> Void)
    func stopPassiveSniffing(reply: @escaping (Bool) -> Void)
    func getDiscoveredPackets(reply: @escaping ([[String: Any]]) -> Void)
    func executePrivilegedCommand(command: String, arguments: [String], reply: @escaping (Int32, String) -> Void)
}
