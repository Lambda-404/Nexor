import Foundation

public struct OUIDatabase {
    /// Comprehensive IEEE OUI prefix database for network device fingerprinting
    private static let vendorPrefixes: [String: String] = [
        // Apple Inc.
        "00:17:F2": "Apple Inc.", "00:1E:52": "Apple Inc.", "00:25:00": "Apple Inc.",
        "00:26:BB": "Apple Inc.", "3C:07:54": "Apple Inc.", "70:3E:AC": "Apple Inc.",
        "88:66:5A": "Apple Inc.", "A4:83:E7": "Apple Inc.", "AC:BC:32": "Apple Inc.",
        "DC:A9:04": "Apple Inc.", "F0:18:98": "Apple Inc.", "F4:F9:51": "Apple Inc.",
        "00:03:93": "Apple Inc.", "00:05:02": "Apple Inc.", "00:0A:95": "Apple Inc.",
        "00:0D:93": "Apple Inc.", "00:10:FA": "Apple Inc.", "00:11:24": "Apple Inc.",
        "00:14:51": "Apple Inc.", "00:16:CB": "Apple Inc.", "00:1B:63": "Apple Inc.",
        "00:1C:B3": "Apple Inc.", "00:1D:4F": "Apple Inc.", "00:1F:5B": "Apple Inc.",
        "00:1F:F3": "Apple Inc.", "00:21:E9": "Apple Inc.", "00:22:41": "Apple Inc.",
        "00:23:12": "Apple Inc.", "00:23:32": "Apple Inc.", "00:23:6C": "Apple Inc.",
        "00:23:DF": "Apple Inc.", "00:24:36": "Apple Inc.", "00:25:4B": "Apple Inc.",
        "00:25:BC": "Apple Inc.", "00:26:08": "Apple Inc.", "00:26:4A": "Apple Inc.",
        "00:26:B0": "Apple Inc.", "F8:FF:C2": "Apple Inc.", "10:94:BB": "Apple Inc.",
        "14:7D:C5": "Apple Inc.", "18:65:90": "Apple Inc.", "20:76:8F": "Apple Inc.",
        "28:CF:E9": "Apple Inc.", "34:36:3B": "Apple Inc.", "40:6C:8F": "Apple Inc.",
        "44:D8:84": "Apple Inc.", "4C:32:75": "Apple Inc.", "58:55:CA": "Apple Inc.",
        "60:F4:45": "Apple Inc.", "68:96:7B": "Apple Inc.", "78:4F:43": "Apple Inc.",
        "80:EA:96": "Apple Inc.", "8C:85:90": "Apple Inc.", "90:72:40": "Apple Inc.",
        "98:01:A7": "Apple Inc.", "A8:66:7F": "Apple Inc.", "B4:F6:1C": "Apple Inc.",
        "BC:92:6B": "Apple Inc.", "C8:3C:85": "Apple Inc.", "D0:81:7A": "Apple Inc.",
        "E4:CE:8F": "Apple Inc.", "F0:DB:F8": "Apple Inc.", "FC:FC:48": "Apple Inc.",

        // Huawei Technologies
        "00:18:82": "Huawei Technologies", "00:1E:10": "Huawei Technologies",
        "00:25:9E": "Huawei Technologies", "00:46:4B": "Huawei Technologies",
        "20:F4:1B": "Huawei Technologies", "70:7B:E8": "Huawei Technologies",
        "D4:6E:5C": "Huawei Technologies", "04:25:C5": "Huawei Technologies",
        "08:19:A6": "Huawei Technologies", "10:1B:54": "Huawei Technologies",
        "24:DF:6A": "Huawei Technologies", "28:31:52": "Huawei Technologies",
        "34:CD:BE": "Huawei Technologies", "48:46:FB": "Huawei Technologies",
        "54:89:98": "Huawei Technologies", "74:88:2A": "Huawei Technologies",
        "AC:85:3D": "Huawei Technologies", "CC:96:A0": "Huawei Technologies",

        // Xiaomi Communications
        "0C:98:38": "Xiaomi Communications", "14:F6:5A": "Xiaomi Communications",
        "28:6C:07": "Xiaomi Communications", "50:64:2B": "Xiaomi Communications",
        "64:09:80": "Xiaomi Communications", "7C:49:EB": "Xiaomi Communications",
        "8C:BE:BE": "Xiaomi Communications", "9C:99:A0": "Xiaomi Communications",
        "AC:F7:F3": "Xiaomi Communications", "D8:63:75": "Xiaomi Communications",
        "FC:64:3A": "Xiaomi Communications", "78:11:DC": "Xiaomi Communications",

        // Espressif Systems (ESP8266 / ESP32 IoT Devices)
        "24:0A:C4": "Espressif Systems (IoT)", "30:AE:A4": "Espressif Systems (IoT)",
        "3C:61:05": "Espressif Systems (IoT)", "84:CC:A8": "Espressif Systems (IoT)",
        "A4:CF:12": "Espressif Systems (IoT)", "AC:67:B2": "Espressif Systems (IoT)",
        "B4:E6:2D": "Espressif Systems (IoT)", "C4:4F:33": "Espressif Systems (IoT)",
        "DC:4F:22": "Espressif Systems (IoT)",

        // Raspberry Pi Foundation
        "B8:27:EB": "Raspberry Pi Foundation",
        "DC:A6:32": "Raspberry Pi Foundation",
        "E4:5F:01": "Raspberry Pi Foundation",
        "28:CD:C1": "Raspberry Pi Foundation",

        // Synology & QNAP NAS
        "00:11:32": "Synology Inc.", "90:09:D0": "Synology Inc.", "00:08:9B": "QNAP Systems",
        "24:5E:BE": "QNAP Systems",

        // TP-Link
        "00:21:27": "TP-Link Technologies", "14:CF:92": "TP-Link Technologies",
        "50:C7:BF": "TP-Link Technologies", "70:4F:57": "TP-Link Technologies",
        "98:DA:C4": "TP-Link Technologies", "B0:95:75": "TP-Link Technologies",
        "C0:25:E9": "TP-Link Technologies", "E8:48:B8": "TP-Link Technologies",

        // ASUS & Netgear
        "04:D9:F5": "ASUSTek Computer", "08:60:6E": "ASUSTek Computer",
        "10:7B:44": "ASUSTek Computer", "00:09:5B": "Netgear Inc.",
        "00:0F:B5": "Netgear Inc.", "00:14:6C": "Netgear Inc.",
        "00:18:4D": "Netgear Inc.", "00:1B:2F": "Netgear Inc.",
        "00:1E:2A": "Netgear Inc.", "00:1F:33": "Netgear Inc.",

        // Ubiquiti UniFi
        "00:27:22": "Ubiquiti Inc.", "04:18:D6": "Ubiquiti Inc.",
        "24:A4:3C": "Ubiquiti Inc.", "44:D9:E7": "Ubiquiti Inc.",
        "74:83:C2": "Ubiquiti Inc.", "B4:FB:E4": "Ubiquiti Inc.",
        "E0:63:DA": "Ubiquiti Inc.",

        // Gaming (Sony, Nintendo, Microsoft)
        "00:01:4A": "Sony Interactive Entertainment", "00:04:1F": "Sony Corporation",
        "00:0A:D9": "Sony Interactive Entertainment", "00:13:15": "Sony Corporation",
        "70:9E:29": "Sony PlayStation", "F8:46:1C": "Sony PlayStation",
        "00:09:BF": "Nintendo Co., Ltd.", "00:1F:32": "Nintendo Switch",
        "98:B6:E9": "Nintendo Switch", "70:48:0F": "Nintendo Switch",
        "00:50:F2": "Microsoft Corporation", "28:18:78": "Microsoft Xbox",
        "7C:ED:8D": "Microsoft Xbox",

        // Smart Home & TV (Amazon, Google, Sonos, Roku, DJI)
        "00:1A:11": "Google LLC", "3C:5A:B4": "Google LLC",
        "54:60:09": "Google LLC", "94:EB:CD": "Google Nest", "F4:F5:D8": "Google Home",
        "00:FC:8B": "Amazon Echo/FireTV", "44:65:0D": "Amazon Technologies",
        "68:54:5A": "Amazon Echo", "74:75:48": "Amazon Kindle",
        "00:0E:58": "Sonos Inc.", "48:A6:B8": "Sonos Inc.", "5C:AA:FD": "Sonos Inc.",
        "00:0D:4B": "Roku Inc.", "20:F5:43": "Roku Inc.", "AC:3A:7A": "Roku Inc.",
        "60:60:1F": "DJI Technology",

        // Chipmakers & PC Vendors (Intel, Cisco, Samsung, HP, Dell, Lenovo)
        "00:02:B3": "Intel Corporate", "00:03:47": "Intel Corporate",
        "00:07:E9": "Intel Corporate", "00:15:00": "Intel Corporate",
        "00:00:0C": "Cisco Systems", "00:01:42": "Cisco Systems",
        "00:02:78": "Samsung Electronics", "00:12:47": "Samsung Electronics",
        "00:01:E6": "HP Inc.", "00:08:02": "HP Inc.",
        "00:14:22": "Dell Inc.", "F8:BC:12": "Dell Inc.",
        "00:59:07": "Lenovo Group", "E8:6A:64": "Lenovo ThinkPad"
    ]
    
    public static func vendor(for macAddress: String) -> String {
        let clean = macAddress.uppercased().replacingOccurrences(of: "-", with: ":")
        let parts = clean.split(separator: ":")
        guard parts.count >= 3 else { return "Unknown Vendor" }
        
        let prefix = "\(parts[0]):\(parts[1]):\(parts[2])"
        if let vendor = vendorPrefixes[prefix] {
            return vendor
        }
        
        // Check if IEEE 802 Locally Administered (Randomized Private MAC)
        if let firstOctet = UInt8(parts[0], radix: 16), (firstOctet & 0x02) != 0 {
            return "Private Wi-Fi (Randomized MAC)"
        }
        
        return "Unknown Manufacturer"
    }
}
