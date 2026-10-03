#if os(macOS)
import Foundation

public struct AppleModelDatabase {
    /// Comprehensive dictionary mapping Apple Model Identifiers to marketing product names
    private static let modelMapping: [String: String] = [
        // Mac Desktops & Laptops (Apple Silicon & Intel)
        "MacBookPro18,1": "16-inch MacBook Pro (M1 Pro, 2021)",
        "MacBookPro18,2": "16-inch MacBook Pro (M1 Max, 2021)",
        "MacBookPro18,3": "14-inch MacBook Pro (M1 Pro, 2021)",
        "MacBookPro18,4": "14-inch MacBook Pro (M1 Max, 2021)",
        "Mac14,5": "14-inch MacBook Pro (M2 Pro, 2023)",
        "Mac14,6": "16-inch MacBook Pro (M2 Max, 2023)",
        "Mac14,9": "14-inch MacBook Pro (M2 Pro, 2023)",
        "Mac14,10": "16-inch MacBook Pro (M2 Pro, 2023)",
        "Mac15,3": "14-inch MacBook Pro (M3 Pro, 2023)",
        "Mac15,6": "14-inch MacBook Pro (M3, 2023)",
        "Mac15,7": "16-inch MacBook Pro (M3 Pro, 2023)",
        "Mac15,8": "16-inch MacBook Pro (M3 Max, 2023)",
        "Mac15,9": "14-inch MacBook Pro (M3 Max, 2023)",
        "Mac16,1": "14-inch MacBook Pro (M4, 2024)",
        "Mac16,6": "14-inch MacBook Pro (M4 Pro, 2024)",
        "Mac16,7": "16-inch MacBook Pro (M4 Pro, 2024)",
        "Mac16,8": "16-inch MacBook Pro (M4 Max, 2024)",
        "MacBookAir10,1": "MacBook Air (M1, 2020)",
        "Mac14,2": "MacBook Air (13-inch, M2, 2022)",
        "Mac14,15": "MacBook Air (15-inch, M2, 2023)",
        "Mac15,12": "MacBook Air (13-inch, M3, 2024)",
        "Mac15,13": "MacBook Air (15-inch, M3, 2024)",
        "Mac16,12": "MacBook Air (13-inch, M4, 2025)",
        "Mac16,13": "MacBook Air (15-inch, M4, 2025)",
        "Macmini9,1": "Mac mini (M1, 2020)",
        "Mac14,3": "Mac mini (M2, 2023)",
        "Mac14,12": "Mac mini (M2 Pro, 2023)",
        "Mac16,10": "Mac mini (M4, 2024)",
        "Mac16,11": "Mac mini (M4 Pro, 2024)",
        "Mac13,1": "Mac Studio (M1 Max, 2022)",
        "Mac13,2": "Mac Studio (M1 Ultra, 2022)",
        "Mac14,13": "Mac Studio (M2 Max, 2023)",
        "Mac14,14": "Mac Studio (M2 Ultra, 2023)",
        "iMac21,1": "24-inch iMac (M1, 2021)",
        "iMac21,2": "24-inch iMac (M1, 2021)",
        "Mac15,4": "24-inch iMac (M3, 2023)",
        "Mac15,5": "24-inch iMac (M3, 2023)",
        "Mac16,2": "24-inch iMac (M4, 2024)",
        "Mac16,3": "24-inch iMac (M4, 2024)",

        // iPhones
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",

        // iPads
        "iPad13,4": "11-inch iPad Pro (3rd gen, M1)",
        "iPad13,8": "12.9-inch iPad Pro (5th gen, M1)",
        "iPad14,3": "11-inch iPad Pro (4th gen, M2)",
        "iPad14,5": "12.9-inch iPad Pro (6th gen, M2)",
        "iPad16,3": "11-inch iPad Pro (M4, 2024)",
        "iPad16,5": "13-inch iPad Pro (M4, 2024)",
        "iPad13,16": "iPad Air (5th gen, M1)",
        "iPad14,8": "11-inch iPad Air (M2, 2024)",
        "iPad14,10": "13-inch iPad Air (M2, 2024)",
        "iPad14,1": "iPad mini (6th gen)",
        "iPad16,1": "iPad mini (A17 Pro, 2024)",

        // Apple TV & HomePod
        "AppleTV6,2": "Apple TV 4K (2nd gen, 2021)",
        "AppleTV11,1": "Apple TV 4K (3rd gen, 2022)",
        "AudioAccessory1,1": "HomePod (1st gen)",
        "AudioAccessory5,1": "HomePod mini",
        "AudioAccessory6,1": "HomePod (2nd gen, 2023)"
    ]

    public static func lookup(modelID: String) -> String? {
        let clean = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = modelMapping[clean] {
            return match
        }
        // Try case-insensitive lookup
        if let match = modelMapping.first(where: { $0.key.caseInsensitiveCompare(clean) == .orderedSame })?.value {
            return match
        }
        return nil
    }
}

#endif
