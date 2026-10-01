//
//  PacketFixtures.swift
//  Teamwork_NetworkUtilities E2ETests
//
//  Authoritative raw binary packet captures and frame fixtures for
//  ARP (RFC 826), DHCP (RFC 2131/2132), mDNS (RFC 6762), and SSDP (UPnP).
//

import Foundation

public struct PacketFixtures {
    
    // MARK: - ARP Frames (RFC 826)
    
    /// Standard Ethernet II ARP Request:
    /// Hardware Type: Ethernet (1), Protocol: IPv4 (0x0800)
    /// Opcode: Request (1)
    /// Sender MAC: 00:1A:2B:3C:4D:5E, Sender IP: 192.168.1.50
    /// Target MAC: 00:00:00:00:00:00, Target IP: 192.168.1.1
    public static let arpRequestFrame: [UInt8] = [
        // Ethernet Header (14 bytes)
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // Destination MAC: Broadcast
        0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E, // Source MAC
        0x08, 0x06,                         // EtherType: ARP (0x0806)
        
        // ARP Header (28 bytes)
        0x00, 0x01,                         // Hardware type: Ethernet (1)
        0x08, 0x00,                         // Protocol type: IPv4 (0x0800)
        0x06,                               // Hardware size: 6
        0x04,                               // Protocol size: 4
        0x00, 0x01,                         // Opcode: ARP Request (1)
        0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E, // Sender MAC: 00:1A:2B:3C:4D:5E
        192, 168, 1, 50,                    // Sender IP: 192.168.1.50
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Target MAC: 00:00:00:00:00:00
        192, 168, 1, 1                      // Target IP: 192.168.1.1
    ]
    
    /// Standard Ethernet II ARP Reply:
    /// Sender MAC: 00:11:22:33:44:55, Sender IP: 192.168.1.1 (Gateway)
    /// Target MAC: 00:1A:2B:3C:4D:5E, Target IP: 192.168.1.50
    public static let arpReplyFrame: [UInt8] = [
        // Ethernet Header (14 bytes)
        0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E, // Destination MAC
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55, // Source MAC (Gateway)
        0x08, 0x06,                         // EtherType: ARP (0x0806)
        
        // ARP Header (28 bytes)
        0x00, 0x01,                         // Hardware type: Ethernet (1)
        0x08, 0x00,                         // Protocol type: IPv4 (0x0800)
        0x06,                               // Hardware size: 6
        0x04,                               // Protocol size: 4
        0x00, 0x02,                         // Opcode: ARP Reply (2)
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55, // Sender MAC: 00:11:22:33:44:55
        192, 168, 1, 1,                     // Sender IP: 192.168.1.1
        0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E, // Target MAC: 00:1A:2B:3C:4D:5E
        192, 168, 1, 50                     // Target IP: 192.168.1.50
    ]
    
    // MARK: - DHCP Packets (RFC 2131 / RFC 2132)
    
    /// DHCP Request Packet (BOOTP header + DHCP Options)
    /// Client MAC: 3C:22:FB:12:34:56
    /// Magic Cookie: 0x63, 0x82, 0x53, 0x63
    /// Option 53: DHCP Request (3)
    /// Option 50: Requested IP: 192.168.1.150
    /// Option 12: Host Name: "MacBookPro-M3"
    /// Option 60: Vendor Class Identifier: "AppleTV6,2"
    public static var dhcpRequestPacket: [UInt8] {
        var packet = [UInt8](repeating: 0, count: 236)
        packet[0] = 0x01 // Opcode: BOOTREQUEST
        packet[1] = 0x01 // HType: Ethernet
        packet[2] = 0x06 // HLen: 6
        packet[3] = 0x00 // Hops: 0
        
        // Transaction ID (4 bytes)
        packet[4] = 0x39; packet[5] = 0x03; packet[6] = 0xF3; packet[7] = 0x26
        
        // Client MAC (offset 28)
        let mac: [UInt8] = [0x3C, 0x22, 0xFB, 0x12, 0x34, 0x56]
        for i in 0..<mac.count {
            packet[28 + i] = mac[i]
        }
        
        // Magic Cookie (offset 236)
        var options: [UInt8] = [0x63, 0x82, 0x53, 0x63]
        
        // Option 53: DHCP Message Type = Request (3)
        options += [53, 1, 3]
        
        // Option 50: Requested IP Address = 192.168.1.150
        options += [50, 4, 192, 168, 1, 150]
        
        // Option 12: Host Name = "MacBookPro-M3"
        let hostName = "MacBookPro-M3"
        let hostBytes = Array(hostName.utf8)
        options += [12, UInt8(hostBytes.count)] + hostBytes
        
        // Option 60: Vendor Class Identifier = "AppleTV6,2"
        let vendor = "AppleTV6,2"
        let vendorBytes = Array(vendor.utf8)
        options += [60, UInt8(vendorBytes.count)] + vendorBytes
        
        // End Option
        options.append(255)
        
        return packet + options
    }
    
    // MARK: - mDNS Packet (RFC 6762)
    
    /// mDNS Response announcement for "Office-Printer._workstation._tcp.local"
    /// IP: 192.168.1.120
    public static var mdnsResponsePacket: [UInt8] {
        var data = [UInt8]()
        // Header: Transaction ID 0, Flags 0x8400 (Standard query response, Authoritative), Questions 0, Answers 1
        data += [0x00, 0x00, 0x84, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]
        
        // Name: "Office-Printer", "local", 0
        let service = "Office-Printer"
        data.append(UInt8(service.utf8.count))
        data += Array(service.utf8)
        let domain = "local"
        data.append(UInt8(domain.utf8.count))
        data += Array(domain.utf8)
        data.append(0) // Null terminator
        
        // Type: A (1), Class: IN (1), TTL: 120, Data Length: 4
        data += [0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78, 0x00, 0x04]
        // Address: 192.168.1.120
        data += [192, 168, 1, 120]
        
        return data
    }
    
    // MARK: - SSDP HTTP Datagram (UPnP Architecture)
    
    public static let ssdpNotifyDatagram: String =
        "NOTIFY * HTTP/1.1\r\n" +
        "HOST: 239.255.255.250:1900\r\n" +
        "CACHE-CONTROL: max-age=1800\r\n" +
        "LOCATION: http://192.168.1.80:1400/xml/device_description.xml\r\n" +
        "NT: urn:schemas-upnp-org:device:ZonePlayer:1\r\n" +
        "NTS: ssdp:alive\r\n" +
        "SERVER: Linux/4.14 UPnP/1.0 Sonos/15.2 (PLAY:1)\r\n" +
        "USN: uuid:RINCON_000E58F1234501400::urn:schemas-upnp-org:device:ZonePlayer:1\r\n\r\n"
        
    // MARK: - Malformed Frames for Boundary Testing
    
    /// Truncated ARP frame (20 bytes, shorter than 42 bytes required for Ethernet+ARP)
    public static let truncatedArpFrame: [UInt8] = [
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E,
        0x08, 0x06,
        0x00, 0x01, 0x08, 0x00, 0x06, 0x04
    ]
    
    /// DHCP packet with corrupted magic cookie
    public static var corruptedDhcpPacket: [UInt8] {
        var packet = [UInt8](repeating: 0, count: 240)
        packet[0] = 0x01
        packet[236] = 0xAA; packet[237] = 0xBB; packet[238] = 0xCC; packet[239] = 0xDD
        return packet
    }
    
    /// Unterminated DHCP options (missing option 255)
    public static var unterminatedDhcpPacket: [UInt8] {
        var packet = [UInt8](repeating: 0, count: 236)
        packet[0] = 0x01
        var options: [UInt8] = [0x63, 0x82, 0x53, 0x63] // Valid magic cookie
        options += [12, 4, 0x41, 0x42, 0x43, 0x44] // Option 12: "ABCD"
        // Intentionally no 255 end marker
        return packet + options
    }
}
