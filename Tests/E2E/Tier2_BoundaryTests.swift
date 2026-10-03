//
//  Tier2_BoundaryTests.swift
//  Nexor E2E Tests
//
//  Tier 2: Boundary & Corner Cases (Stress & Robustness)
//  Tests system resiliency against malformed, extreme, and adversarial inputs.
//

import Foundation

public struct Tier2_BoundaryTests {
    
    public static func register(in harness: TestHarness) {
        
        // B01: Subnet Math Extreme Boundaries (/0, /30, /31, /32)
        harness.register(test: TestCase(name: "B01_SubnetMathExtremeBoundaries", tier: 2) {
            // Test /0: entire IPv4 space
            let subnet0 = try SubnetCalculatorEngine.calculate(ip: "0.0.0.0", cidr: 0)
            try Assert.assertEqual(subnet0.networkAddress, "0.0.0.0")
            try Assert.assertEqual(subnet0.broadcastAddress, "255.255.255.255")
            try Assert.assertEqual(subnet0.netmask, "0.0.0.0")
            try Assert.assertEqual(subnet0.wildcardMask, "255.255.255.255")
            try Assert.assertEqual(subnet0.totalUsableHosts, 4294967294)
            
            // Test /30: small point-to-point subnet (2 usable hosts)
            let subnet30 = try SubnetCalculatorEngine.calculate(ip: "172.16.0.5", cidr: 30)
            try Assert.assertEqual(subnet30.networkAddress, "172.16.0.4")
            try Assert.assertEqual(subnet30.broadcastAddress, "172.16.0.7")
            try Assert.assertEqual(subnet30.totalUsableHosts, 2)
            try Assert.assertEqual(subnet30.usableHostRange.first, "172.16.0.5")
            try Assert.assertEqual(subnet30.usableHostRange.last, "172.16.0.6")
            
            // Test /31: RFC 3021 point-to-point link (2 usable hosts, no broadcast)
            let subnet31 = try SubnetCalculatorEngine.calculate(ip: "192.168.10.2", cidr: 31)
            try Assert.assertEqual(subnet31.networkAddress, "192.168.10.2")
            try Assert.assertEqual(subnet31.broadcastAddress, "192.168.10.3")
            try Assert.assertEqual(subnet31.totalUsableHosts, 2)
            try Assert.assertEqual(subnet31.usableHostRange.first, "192.168.10.2")
            try Assert.assertEqual(subnet31.usableHostRange.last, "192.168.10.3")
            
            // Test /32: single host route
            let subnet32 = try SubnetCalculatorEngine.calculate(ip: "10.0.0.1", cidr: 32)
            try Assert.assertEqual(subnet32.networkAddress, "10.0.0.1")
            try Assert.assertEqual(subnet32.broadcastAddress, "10.0.0.1")
            try Assert.assertEqual(subnet32.netmask, "255.255.255.255")
            try Assert.assertEqual(subnet32.wildcardMask, "0.0.0.0")
            try Assert.assertEqual(subnet32.totalUsableHosts, 1)
        })
        
        // B02: Invalid IP Addresses & Out-of-Range CIDRs
        harness.register(test: TestCase(name: "B02_InvalidIPAndOutOfRangeCIDR", tier: 2) {
            // Negative CIDR prefix
            try await Assert.assertThrows({
                _ = try SubnetCalculatorEngine.calculate(ip: "192.168.1.1", cidr: -1)
            }, "Negative CIDR must throw error")
            
            // CIDR > 32
            try await Assert.assertThrows({
                _ = try SubnetCalculatorEngine.calculate(ip: "192.168.1.1", cidr: 33)
            }, "CIDR > 32 must throw error")
            
            // Invalid IPs
            for invalidIP in TestFixtures.invalidIPv4Addresses {
                try await Assert.assertThrows({
                    _ = try SubnetCalculatorEngine.calculate(ip: invalidIP, cidr: 24)
                }, "Invalid IP '\(invalidIP)' must throw error")
            }
        })
        
        // B03: Command Injection & Empty Target Sanitization
        harness.register(test: TestCase(name: "B03_CommandInjectionAndEmptyInputSanitization", tier: 2) {
            func sanitizeInput(_ target: String) -> String? {
                let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return nil }
                // Disallow shell meta-characters
                let forbiddenChars = CharacterSet(charactersIn: ";|&`$><\n\r\"'")
                if trimmed.rangeOfCharacter(from: forbiddenChars) != nil {
                    return nil
                }
                return trimmed
            }
            
            // Empty / whitespace inputs must be rejected
            try Assert.assertNil(sanitizeInput(""), "Empty target must be rejected")
            try Assert.assertNil(sanitizeInput("   "), "Whitespace target must be rejected")
            try Assert.assertNil(sanitizeInput("\t\n"), "Newline target must be rejected")
            
            // Malicious commands must be rejected
            for mal in TestFixtures.maliciousInputs {
                let result = sanitizeInput(mal)
                try Assert.assertNil(result, "Malicious shell payload '\(mal)' must be rejected by input sanitizer")
            }
            
            // Legitimate targets must pass
            try Assert.assertEqual(sanitizeInput("127.0.0.1"), "127.0.0.1")
            try Assert.assertEqual(sanitizeInput("www.apple.com"), "www.apple.com")
        })
        
        // B04: Malformed & Truncated Packet Frames
        harness.register(test: TestCase(name: "B04_MalformedAndTruncatedPacketFrames", tier: 2) {
            // Truncated ARP
            let truncatedArp = PacketParserEngine.parseARP(frame: PacketFixtures.truncatedArpFrame)
            try Assert.assertNil(truncatedArp, "Truncated ARP frame must fail parsing gracefully without crashing")
            
            // Zero-length packet
            let emptyArp = PacketParserEngine.parseARP(frame: [])
            try Assert.assertNil(emptyArp, "Empty byte array must return nil")
            
            // Corrupted DHCP magic cookie
            let corruptedDhcp = PacketParserEngine.parseDHCP(packet: PacketFixtures.corruptedDhcpPacket)
            try Assert.assertNil(corruptedDhcp, "Corrupted DHCP magic cookie must be rejected")
            
            // Unterminated DHCP options: should safely parse available options without infinite loop
            let unterminatedDhcp = PacketParserEngine.parseDHCP(packet: PacketFixtures.unterminatedDhcpPacket)
            try Assert.assertNotNil(unterminatedDhcp, "Unterminated DHCP must terminate cleanly at buffer boundary")
            try Assert.assertEqual(unterminatedDhcp?.hostname, "ABCD")
            
            // Malformed SSDP datagram
            let invalidSSDP = PacketParserEngine.parseSSDP(datagram: "FOOBAR / INVALID")
            try Assert.assertNil(invalidSSDP, "Malformed SSDP missing HTTP/1.1 must return nil")
        })
        
        // B05: Extreme RF Telemetry & Negative SNR Math
        harness.register(test: TestCase(name: "B05_ExtremeRFTelemetryAndNegativeSNR", tier: 2) {
            // Extreme RSSI: 0 dBm (device right next to antenna)
            let snrMax = TelemetryAnalyzer.calculateSNR(rssi: 0, noise: -90)
            try Assert.assertEqual(snrMax, 90)
            try Assert.assertEqual(TelemetryAnalyzer.evaluateSignalRating(snr: snrMax), .excellent)
            
            // RSSI equal to Noise (SNR = 0 dB)
            let snrZero = TelemetryAnalyzer.calculateSNR(rssi: -90, noise: -90)
            try Assert.assertEqual(snrZero, 0)
            try Assert.assertEqual(TelemetryAnalyzer.evaluateSignalRating(snr: snrZero), .poor)
            
            // Noise higher than RSSI (Negative SNR: e.g. -10 dB)
            let snrNeg = TelemetryAnalyzer.calculateSNR(rssi: -95, noise: -85)
            try Assert.assertEqual(snrNeg, -10)
            try Assert.assertEqual(TelemetryAnalyzer.evaluateSignalRating(snr: snrNeg), .poor)
            
            // Extreme distance attenuation: -120 dBm
            let snrDeep = TelemetryAnalyzer.calculateSNR(rssi: -120, noise: -95)
            try Assert.assertEqual(snrDeep, -25)
            try Assert.assertEqual(TelemetryAnalyzer.evaluateSignalRating(snr: snrDeep), .poor)
        })
        
        // B06: MAC Address Variations & Invalid String Parsing
        harness.register(test: TestCase(name: "B06_MACAddressVariationsAndInvalidStrings", tier: 2) {
            // Colon-separated
            let colonBytes = IEEE802Analyzer.parseOctets(mac: "00:1A:2B:3C:4D:5E")
            try Assert.assertNotNil(colonBytes)
            try Assert.assertEqual(colonBytes?.count, 6)
            
            // Hyphen-separated
            let hyphenBytes = IEEE802Analyzer.parseOctets(mac: "00-1A-2B-3C-4D-5E")
            try Assert.assertNotNil(hyphenBytes)
            try Assert.assertEqual(hyphenBytes?.count, 6)
            
            // Unseparated
            let unsepBytes = IEEE802Analyzer.parseOctets(mac: "001A2B3C4D5E")
            try Assert.assertNotNil(unsepBytes)
            try Assert.assertEqual(unsepBytes?.count, 6)
            
            // Lowercase
            let lowerBytes = IEEE802Analyzer.parseOctets(mac: "00:1a:2b:3c:4d:5e")
            try Assert.assertNotNil(lowerBytes)
            try Assert.assertEqual(lowerBytes, colonBytes)
            
            // Invalid MAC strings must return nil
            for inv in TestFixtures.invalidMACs {
                let res = IEEE802Analyzer.parseOctets(mac: inv)
                try Assert.assertNil(res, "Invalid MAC '\(inv)' must return nil")
            }
        })
        
        // B07: Port Range Boundaries (0, 1, 65535, invalid ports)
        harness.register(test: TestCase(name: "B07_PortRangeBoundaries", tier: 2) {
            func validatePort(_ port: Int) -> Bool {
                return port >= 0 && port <= 65535
            }
            
            try Assert.assertTrue(validatePort(0), "Port 0 is a valid reserved boundary")
            try Assert.assertTrue(validatePort(1), "Port 1 is valid")
            try Assert.assertTrue(validatePort(80), "Port 80 is valid")
            try Assert.assertTrue(validatePort(65535), "Port 65535 is maximum valid 16-bit port")
            
            try Assert.assertFalse(validatePort(-1), "Port -1 must be rejected")
            try Assert.assertFalse(validatePort(65536), "Port 65536 exceeds 16-bit range")
            try Assert.assertFalse(validatePort(100000), "Port 100000 must be rejected")
        })
        
        // B08: Wake On LAN Payload Boundary Validation
        harness.register(test: TestCase(name: "B08_WOLPayloadBoundaryValidation", tier: 2) {
            // Reject invalid MAC for WOL
            try await Assert.assertThrows({
                _ = try WakeOnLANEngine.createMagicPacket(mac: "invalid-mac")
            }, "Creating WOL packet with invalid MAC must throw")
            
            // Reject short packet for validation
            let shortPacket: [UInt8] = [0xFF, 0xFF, 0xFF]
            let isShortValid = WakeOnLANEngine.validateMagicPacket(packet: shortPacket, expectedMAC: "00:1A:2B:3C:4D:5E")
            try Assert.assertFalse(isShortValid, "Packet shorter than 102 bytes must be invalid")
            
            // Reject packet with corrupted preamble (e.g. byte 0 is 0xFE instead of 0xFF)
            var valid = try WakeOnLANEngine.createMagicPacket(mac: "00:1A:2B:3C:4D:5E").bytes
            valid[0] = 0xFE
            let isCorruptValid = WakeOnLANEngine.validateMagicPacket(packet: valid, expectedMAC: "00:1A:2B:3C:4D:5E")
            try Assert.assertFalse(isCorruptValid, "Packet with corrupted preamble must be invalid")
        })
    }
}
