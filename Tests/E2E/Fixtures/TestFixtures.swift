//
//  TestFixtures.swift
//  Nexor E2E Tests
//
//  Standard dataset fixtures for network models, IEEE 802 MAC addresses,
//  IP addresses, CIDR subnets, and RF telemetry values.
//

import Foundation

public struct TestFixtures {
    
    // MARK: - MAC Addresses (IEEE 802 Standard)
    
    /// Burned-in / Universal MAC addresses: (firstOctet & 0x02) == 0
    public static let universalMACs: [String] = [
        "00:1A:2B:3C:4D:5E", // Apple Inc.
        "AC:DE:48:00:11:22", // Apple Inc.
        "3C:22:FB:12:34:56", // Apple Inc.
        "B8:27:EB:AA:BB:CC", // Raspberry Pi Foundation
        "00:50:56:C0:00:08", // VMware Inc.
        "54:B7:E5:99:88:77"  // Intel Corporate
    ]
    
    /// Locally Administered / Randomized MAC addresses: (firstOctet & 0x02) != 0
    /// Examples include iOS / macOS Private Wi-Fi Addresses, Android MAC randomization
    public static let randomizedMACs: [String] = [
        "DA:A1:19:12:34:56", // 0xDA & 0x02 == 0x02 (set)
        "02:00:00:00:00:01", // 0x02 & 0x02 == 0x02 (set)
        "AE:01:23:45:67:89", // 0xAE & 0x02 == 0x02 (set)
        "7A:12:34:56:78:90", // 0x7A & 0x02 == 0x02 (set)
        "F6:9A:C3:44:55:66", // 0xF6 & 0x02 == 0x02 (set)
        "12:34:56:78:9A:BC"  // 0x12 & 0x02 == 0x02 (set)
    ]
    
    /// Invalid MAC strings for boundary validation
    public static let invalidMACs: [String] = [
        "",
        "invalid-mac-address",
        "00:11:22:33:44",        // 5 octets
        "00:11:22:33:44:55:66",  // 7 octets
        "ZZ:YY:XX:WW:VV:UU",     // Non-hex characters
        "00-11-22-33-44",        // 5 octets hyphen
        "192.168.1.1"            // IP string
    ]
    
    // MARK: - IP Address Datasets
    
    public static let validIPv4Addresses: [String] = [
        "192.168.1.1",
        "10.0.0.1",
        "172.16.254.1",
        "127.0.0.1",
        "8.8.8.8",
        "255.255.255.255",
        "0.0.0.0"
    ]
    
    public static let invalidIPv4Addresses: [String] = [
        "",
        "   ",
        "256.0.0.1",
        "192.168.1",
        "192.168.1.1.1",
        "-1.0.0.1",
        "abc.def.ghi.jkl",
        "192.168.1.256"
    ]
    
    // MARK: - Subnet Math Test Cases
    
    public struct SubnetTestCase {
        public let ip: String
        public let cidr: Int
        public let expectedNetwork: String
        public let expectedBroadcast: String
        public let expectedNetmask: String
        public let expectedWildcard: String
        public let expectedFirstHost: String
        public let expectedLastHost: String
        public let expectedUsableHosts: UInt64
    }
    
    public static let standardSubnetCases: [SubnetTestCase] = [
        // Standard /24
        SubnetTestCase(
            ip: "192.168.1.50",
            cidr: 24,
            expectedNetwork: "192.168.1.0",
            expectedBroadcast: "192.168.1.255",
            expectedNetmask: "255.255.255.0",
            expectedWildcard: "0.0.0.255",
            expectedFirstHost: "192.168.1.1",
            expectedLastHost: "192.168.1.254",
            expectedUsableHosts: 254
        ),
        // Class A /8
        SubnetTestCase(
            ip: "10.15.20.25",
            cidr: 8,
            expectedNetwork: "10.0.0.0",
            expectedBroadcast: "10.255.255.255",
            expectedNetmask: "255.0.0.0",
            expectedWildcard: "0.255.255.255",
            expectedFirstHost: "10.0.0.1",
            expectedLastHost: "10.255.255.254",
            expectedUsableHosts: 16777214
        ),
        // Small /30 (Point to Point subnet)
        SubnetTestCase(
            ip: "172.16.0.5",
            cidr: 30,
            expectedNetwork: "172.16.0.4",
            expectedBroadcast: "172.16.0.7",
            expectedNetmask: "255.255.255.252",
            expectedWildcard: "0.0.0.3",
            expectedFirstHost: "172.16.0.5",
            expectedLastHost: "172.16.0.6",
            expectedUsableHosts: 2
        ),
        // RFC 3021 /31 (Point-to-point links)
        SubnetTestCase(
            ip: "192.168.10.2",
            cidr: 31,
            expectedNetwork: "192.168.10.2",
            expectedBroadcast: "192.168.10.3",
            expectedNetmask: "255.255.255.254",
            expectedWildcard: "0.0.0.1",
            expectedFirstHost: "192.168.10.2",
            expectedLastHost: "192.168.10.3",
            expectedUsableHosts: 2
        ),
        // /32 Host route
        SubnetTestCase(
            ip: "192.168.1.10",
            cidr: 32,
            expectedNetwork: "192.168.1.10",
            expectedBroadcast: "192.168.1.10",
            expectedNetmask: "255.255.255.255",
            expectedWildcard: "0.0.0.0",
            expectedFirstHost: "192.168.1.10",
            expectedLastHost: "192.168.1.10",
            expectedUsableHosts: 1
        )
    ]
    
    // MARK: - RF Wi-Fi Telemetry & SNR Test Cases
    
    public struct TelemetryTestCase {
        public let rssi: Int
        public let noise: Int
        public let expectedSNR: Int
        public let expectedRating: String // "Excellent", "Good", "Fair", "Poor"
    }
    
    public static let telemetryCases: [TelemetryTestCase] = [
        TelemetryTestCase(rssi: -45, noise: -95, expectedSNR: 50, expectedRating: "Excellent"),
        TelemetryTestCase(rssi: -60, noise: -92, expectedSNR: 32, expectedRating: "Good"),
        TelemetryTestCase(rssi: -75, noise: -95, expectedSNR: 20, expectedRating: "Fair"),
        TelemetryTestCase(rssi: -85, noise: -90, expectedSNR: 5, expectedRating: "Poor"),
        // Extreme / Edge case: noise equals RSSI
        TelemetryTestCase(rssi: -90, noise: -90, expectedSNR: 0, expectedRating: "Poor"),
        // Extreme / Edge case: noise exceeds RSSI (negative SNR)
        TelemetryTestCase(rssi: -95, noise: -90, expectedSNR: -5, expectedRating: "Poor")
    ]
    
    // MARK: - Command Injection / Adversarial Strings
    
    public static let maliciousInputs: [String] = [
        "127.0.0.1; rm -rf /",
        "127.0.0.1 | cat /etc/passwd",
        "127.0.0.1 && touch /tmp/pwned",
        "127.0.0.1 `id`",
        "127.0.0.1 $(whoami)",
        "\" && echo hacked || \"",
        "127.0.0.1\n/bin/ls"
    ]
}
