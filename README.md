# Nexor

<p align="center">
  <strong>Modern, Elegant & High-Performance macOS Network Utilities and Full-Spectrum Telemetry Suite</strong>
</p>

<p align="center">
  <img src="Resources/AppIcon.iconset/icon_256x256@2x.png" width="128" height="128" alt="Nexor App Icon" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue.svg" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Language-Swift%206-orange.svg" alt="Swift 6" />
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2F%20Liquid%20Glass-purple.svg" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT" />
</p>

---

## 📖 Overview

**Nexor** is a native macOS network diagnostics and RF telemetry application designed for network engineers, system administrators, and developers. Built from scratch with pure Swift 6 and SwiftUI, Nexor combines low-level networking primitives, real-time wireless telemetry, passive zero-packet LAN discovery, Bluetooth RF radar, and privileged execution into a cohesive, Liquid Glass-themed dashboard.

---

## ✨ Key Features

### 1. 📡 Real-Time Wi-Fi & RF Telemetry
- **Dynamic Interface Detection**: Automatically tracks active Wi-Fi and Ethernet interfaces without hardcoded identifiers.
- **RF Metrics**: Live retrieval of RSSI (dBm), Noise Floor (dBm), calculated Signal-to-Noise Ratio (`SNR = RSSI - Noise`), and signal quality index.
- **Dynamic Gateway & IP Resolution**: Non-blocking default gateway resolution via `SCDynamicStore` and IPv4/IPv6 address monitoring.
- **Dual-Band Wi-Fi Radar**: Visual radar sweep charting 2.4 GHz and 5 GHz channel occupancy, channel widths, and BSSIDs.

### 2. 🔵 Bluetooth Radar & Peripheral Discovery
- **Full-Spectrum BLE & Classic Radar**: Live radial visualization of nearby Bluetooth devices mapped by RSSI proximity.
- **Device Fingerprinting**: Instant manufacturer identification via official Bluetooth SIG Company Identifiers and Apple Model databases.

### 3. 🛡️ Passive Zero-Packet LAN Device Discovery
- **Zero-Transmission Guarantee**: Pure passive packet sniffing via `libpcap` immediate mode with strict BPF filtering (`arp or (udp and (port 67 or 68 or 5353 or 1900))`).
- **Multi-Protocol Inspection**:
  - **ARP**: Real-time IP-to-MAC mapping without generating broadcast traffic.
  - **DHCP**: Extracts hostname (Option 12) and vendor class identifier (Option 60).
  - **mDNS / Bonjour**: Identifies Apple and smart home device names and broadcast services.
  - **SSDP / UPnP**: Discovers media servers and router device metadata.
- **IEEE 802 Randomized MAC Flagging**: Bitwise detection for privacy-randomized addresses.

### 4. 🧰 9 Active Non-Blocking Diagnostic Tools
Managed by an actor-isolated detached concurrency manager that ensures UI responsiveness regardless of diagnostic duration:
1. **Ping**: Streaming ICMP ping with round-trip statistics and instant cancellation.
2. **Traceroute**: Asynchronous hop-by-hop route path analysis.
3. **DNS Query**: Query A, AAAA, CNAME, MX, TXT, and NS records with nameserver latency timings.
4. **Website Check**: End-to-end HTTP/HTTPS latency breakdown, status codes, and TLS validation.
5. **Port Scanner**: Bounded concurrent `TaskGroup` scanner leveraging native `NWConnection`.
6. **Subnet Calculator**: Instant calculation of CIDR, network mask, wildcard, broadcast address, and usable host ranges.
7. **Wake on LAN (WoL)**: UDP broadcast generator for standard 102-byte magic packets (Port 9).
8. **iPerf Throughput Benchmark**: Native throughput test runner with custom binary path detection.
9. **Comprehensive Health Diagnosis**: Multi-stage composite check spanning local loopback, gateway, DNS, and WAN connectivity.

### 5. 📊 Menu Bar Extra & Traffic Monitor
- Compact Menu Bar HUD displaying live upload/download rates and network status.
- Expandable popover with real-time transfer graphs and interface telemetry.

### 6. 🔐 Privileged Root Helper Daemon
- Decoupled privileged helper registered via `SMAppService.daemon`.
- Secure Mach XPC protocol (`com.networkutilities.helper.xpc`) for elevated raw socket diagnostics and packet sniffing.
- Built-in unprivileged developer fallback for running in testing environments.

---

## 🛠️ Requirements & Building

- **macOS**: macOS 14.0 (Sonoma) or newer.
- **Toolchain**: Xcode 15+ / Swift 6.0 toolchain.
- **Architecture**: Apple Silicon (`arm64`) & Intel (`x86_64`) supported.

### Build Application Bundle (.app)
Run the self-contained build script:
```bash
# Clone the repository
git clone https://github.com/Lambda-404/Nexor.git
cd Nexor

# Build and ad-hoc sign the bundle
./build.sh

# Build and immediately launch the application
./build.sh --open
```

### Running Tests
Execute the end-to-end test suite:
```bash
cd Tests/E2ETests
./run_tests.sh
```

---

## ⚖️ Legal & Security Disclaimer

> **IMPORTANT NOTICE**:
> 
> Nexor is developed and provided strictly for **authorized network diagnostic, troubleshooting, administrative self-audit, and educational purposes**.
> 
> - Users are solely responsible for ensuring that all packet sniffing, scanning, and diagnostic operations comply with local laws and regulations (including, but not limited to, the Computer Fraud and Abuse Act (CFAA) and relevant cybersecurity regulations).
> - **Do NOT** use port scanning or packet capturing against networks, systems, or devices without explicit, written authorization from the owner.
> - The developers and contributors of Nexor assume no liability and are not responsible for any misuse, damage, or legal consequences arising from the use of this software.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
