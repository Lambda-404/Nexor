# Nexor

<p align="center">
  <strong>Modern, Elegant & High-Performance macOS & watchOS Network Utilities and Full-Spectrum Telemetry Suite</strong><br>
  <strong>现代、优雅、高性能的 macOS 与 watchOS 原生网络工具箱与全频谱遥测套件</strong>
</p>

<p align="center">
  <img src="Resources/Icons/AppIcon.iconset/icon_256x256@2x.png" width="128" height="128" alt="Nexor App Icon" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Release-v1.0.1-brightgreen.svg" alt="Release: v1.0.1" />
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B%20%7C%20watchOS%2010%2B-blue.svg" alt="macOS 14+ | watchOS 10+" />
  <img src="https://img.shields.io/badge/Language-Swift%206-orange.svg" alt="Swift 6" />
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2F%20Liquid%20Glass-purple.svg" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License: MIT" />
</p>

<p align="center">
  <a href="#english">English</a> • <a href="#-简体中文">简体中文</a>
</p>

---

<a name="english"></a>
## 🌐 English

### 📖 Overview
**Nexor** is a native macOS and watchOS network diagnostics and RF telemetry application designed for network engineers, system administrators, and security researchers. Built completely with pure Swift 6 and SwiftUI, Nexor combines low-level packet capture primitives, real-time wireless telemetry, passive zero-packet LAN discovery, Bluetooth RF radar, watchOS companion monitoring, and privileged execution into a cohesive Liquid Glass dashboard.

---

### 📂 Modular Project Structure

```text
Nexor/
├── Package.swift                             # Swift Package definition (macOS 14.0+, watchOS 10.0+)
├── build.sh                                  # Unified build, packaging and ad-hoc codesigning script
├── clean_launchpad_duplicates.sh             # Launch Services & Launchpad cache cleaner
├── README.md                                 # Bilingual documentation & architecture overview
├── LICENSE                                   # MIT License
├── .gitignore                                # Git ignore rules
├── Resources/
│   ├── Info.plist                            # App metadata & permission usage descriptions
│   ├── Icons/                                # Multi-resolution Retina AppIcon & Assets.car
│   │   ├── AppIcon.icns
│   │   ├── Assets.car
│   │   ├── AppIcon.iconset/
│   │   └── NU.icon/
│   └── LaunchDaemons/                        # Privileged helper daemon configuration
│       └── com.networkutilities.helper.plist
├── Scripts/
│   └── generate_icon.py                      # Algorithmic icon renderer (PIL / Math geometry)
├── Sources/
│   ├── Nexor/                                # Main client application source
│   │   ├── App/                              # Application lifecycle entry
│   │   ├── Models/                           # Data models (LANDevice, BluetoothDevice, Traffic, etc.)
│   │   ├── Services/                         # Core engines (Telemetric, Sniffer, OUI, BT, etc.)
│   │   ├── Views/                            # SwiftUI Liquid Glass views & MenuBar components
│   │   └── WatchOS/                          # Dedicated watchOS companion views & services
│   └── HelperDaemon/                         # Privileged root helper daemon (Mach XPC)
└── Tests/
    ├── E2E/                                  # Tier 1-4 End-to-End test suite (44/44 passing)
    ├── Stress/                               # Concurrency & memory stress benchmarks
    └── Verification/                         # Independent feature verification probes
```

---

### ✨ Key Features

#### 1. 📡 Real-Time Wi-Fi & RF Telemetry
- **Dynamic Interface Detection**: Automatically tracks active Wi-Fi and Ethernet interfaces without hardcoded identifiers.
- **RF Quality Rating**: Live retrieval of RSSI (dBm), Noise Floor (dBm), calculated Signal-to-Noise Ratio (`SNR = RSSI - Noise`), and visual quality rating.
- **Dynamic Gateway & IP Resolution**: Non-blocking default gateway resolution via `SCDynamicStore` and local IPv4/IPv6 monitoring.
- **Dual-Band Wi-Fi Radar**: Visual radar sweep charting 2.4 GHz and 5 GHz channel occupancy, channel widths, and BSSIDs.

#### 2. 🔵 Bluetooth Radar & Peripheral Discovery
- **Full-Spectrum BLE & Classic Radar**: Live radial visualization of nearby Bluetooth devices mapped by RSSI proximity.
- **Hardware Fingerprinting**: Instant manufacturer identification via official Bluetooth SIG Company Identifiers and Apple Model databases.

#### 3. 🛡️ Passive Zero-Packet LAN Device Discovery
- **Zero-Transmission Guarantee**: Pure passive packet sniffing via `libpcap` immediate mode with strict BPF filtering (`arp or (udp and (port 67 or 68 or 5353 or 1900))`).
- **Multi-Protocol Inspection**:
  - **ARP**: Real-time IP-to-MAC mapping without generating broadcast traffic.
  - **DHCP**: Extracts hostname (Option 12) and vendor class identifier (Option 60).
  - **mDNS / Bonjour**: Identifies Apple and smart home device names and broadcast services.
  - **SSDP / UPnP**: Discovers media servers and router device metadata.
- **IEEE 802 Randomized MAC Flagging**: Bitwise detection for privacy-randomized addresses.

#### 4. 🧰 9 Active Non-Blocking Diagnostic Tools
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

#### 5. ⌚ watchOS Companion & Menu Bar Extra
- **watchOS Companion**: Quick-glance network telemetry and wrist-based diagnostic tools.
- **Menu Bar Extra**: Compact Menu Bar HUD displaying live upload/download rates and network status with expandable sparkline popovers.

#### 6. 🔐 Privileged Root Helper Daemon
- Decoupled privileged helper registered via `SMAppService.daemon`.
- Secure Mach XPC protocol (`com.networkutilities.helper.xpc`) for elevated raw socket diagnostics and packet sniffing.
- Built-in unprivileged developer fallback for running in testing environments.

---

### 🛠️ Requirements & Building

- **macOS**: macOS 14.0 (Sonoma) or newer.
- **watchOS**: watchOS 10.0 or newer (for companion target).
- **Toolchain**: Xcode 15+ / Swift 6.0 toolchain.
- **Architecture**: Apple Silicon (`arm64`) & Intel (`x86_64`) supported.

```bash
# Clone the repository
git clone https://github.com/Lambda-404/Nexor.git
cd Nexor

# Build and ad-hoc sign the bundle
./build.sh

# Build and immediately launch the application
./build.sh --open
```

### 🧪 Running Tests
```bash
cd Tests/E2E
./run_tests.sh
```

---

### ⚖️ Legal & Security Disclaimer
> **IMPORTANT NOTICE**:
> 
> Nexor is developed and provided strictly for **authorized network diagnostic, troubleshooting, administrative self-audit, and educational purposes**.
> 
> - Users are solely responsible for ensuring that all packet sniffing, scanning, and diagnostic operations comply with local laws and regulations (including, but not limited to, the Computer Fraud and Abuse Act (CFAA) and relevant cybersecurity regulations).
> - **Do NOT** use port scanning or packet capturing against networks, systems, or devices without explicit, written authorization from the owner.
> - The developers and contributors of Nexor assume no liability and are not responsible for any misuse, damage, or legal consequences arising from the use of this software.

---

<a name="-简体中文"></a>
## 🇨🇳 简体中文

### 📖 项目简介
**Nexor** 是一款专为网络工程师、系统管理员和网络技术爱好者打造的原生 macOS 与 watchOS 网络诊断与全频谱射频遥测工具箱。纯 Swift 6 与 SwiftUI 打造，结合现代“液态玻璃（Liquid Glass）”设计美学，将底层数据包捕获、零发包局域网被动探测、蓝牙/Wi-Fi 射频雷达、Apple Watch 腕上监控与特权辅助服务融为一体。

---

### 📂 规范化工程目录结构

```text
Nexor/
├── Package.swift                             # Swift Package 规范定义 (支持 macOS 14+, watchOS 10+)
├── build.sh                                  # 自动化编译、打包与 Ad-hoc 签名脚本
├── clean_launchpad_duplicates.sh             # Launch Services 与启动台缓存重置工具
├── README.md                                 # 中英双语项目文档与架构说明
├── LICENSE                                   # MIT 开源协议
├── .gitignore                                # Git 忽略规则
├── Resources/
│   ├── Info.plist                            # App 元数据与系统隐私权限声明
│   ├── Icons/                                # 高分辨率 Retina AppIcon 与 Assets.car
│   │   ├── AppIcon.icns
│   │   ├── Assets.car
│   │   ├── AppIcon.iconset/
│   │   └── NU.icon/
│   └── LaunchDaemons/                        # 特权守护进程配置文件
│       └── com.networkutilities.helper.plist
├── Scripts/
│   └── generate_icon.py                      # 纯算法图标渲染脚本 (PIL / 数学几何矢量)
├── Sources/
│   ├── Nexor/                                # 客户端主源码
│   │   ├── App/                              # App 生命周期入口
│   │   ├── Models/                           # 核心数据模型 (LANDevice, BluetoothDevice, Traffic 等)
│   │   ├── Services/                         # 底层服务引擎 (RF 遥测, 嗅探器, OUI, 蓝牙等)
│   │   ├── Views/                            # SwiftUI 液态玻璃视图与状态栏组件
│   │   └── WatchOS/                          # 独立 watchOS 腕上视图与服务
│   └── HelperDaemon/                         # Root 特权辅助守护进程 (Mach XPC)
└── Tests/
    ├── E2E/                                  # 4 层分级 E2E 测试套件 (44/44 全部通过)
    ├── Stress/                               # 高并发与内存压力测试
    └── Verification/                         # 独立新特性验证探针
```

---

### ✨ 核心功能特性

#### 1. 📡 实时 Wi-Fi 与射频环境遥测
- **动态网络接口检测**：自动监听当前主活跃网卡（Wi-Fi 或以太网），无需硬编码指定。
- **射频质量量化**：毫秒级采集 RSSI 接收电平（dBm）、环境底噪（Noise Floor）并实时推导信噪比（`SNR = RSSI - Noise`），提供直观的连接品质评级。
- **非阻塞网关与 IP 解析**：基于 `SCDynamicStore` 异步获取默认网关，实时展示本端 IPv4 / IPv6 分配状态。
- **双频 Wi-Fi 拓扑雷达**：以动态雷达波束可视化呈现 2.4 GHz 与 5 GHz 频段上的信道占用、频宽及 BSSID 热点分布。

#### 2. 🔵 蓝牙雷达与外设深度指纹
- **全频谱 BLE 与传统蓝牙雷达**：以天线接收灵敏度为距离权重，动态绘制周边蓝牙设备的空间分布图。
- **硬件指纹精准识别**：集成完整的 Bluetooth SIG 官方厂商数据库与 Apple 硬件型号映射库，即时辨识外设厂商与硬件代际。

#### 3. 🛡️ 被动零发包（Zero-Packet）局域网拓扑探测
- **严格零发包承诺**：采用 `libpcap` 混杂抓包模式结合严密的 BPF 过滤器（`arp or (udp and (port 67 or 68 or 5353 or 1900))`），仅被动监听网络现有广播/组播，**绝不向网内主动注入任何数据帧**，杜绝网络告警。
- **多协议被动深度解包**：
  - **ARP 帧**：自动构建 IP 与 MAC 地址映射。
  - **DHCP 数据包**：无感提取主机名称（Option 12）与厂商类型（Option 60）。
  - **mDNS / Bonjour**：自动捕获并解析 Apple 生态设备及智能家居主机的服务通告。
  - **SSDP / UPnP**：自动提取局域网路由器与流媒体设备元数据。
- **IEEE 802 随机化 MAC 标靶**：自动通过最高有效字节的局部管理位检测是否为隐私随机 MAC。

#### 4. 🧰 9 大非阻塞原生网络诊断工具
内置 Actor 隔离的后台任务协同引擎，诊断过程绝不阻塞主 UI 线程：
1. **Ping（连通性测试）**：流式回显 ICMP 响应、实时抖动与丢包率，支持毫秒级中断。
2. **Traceroute（路由追踪）**：异步逐跳路由探测，展示经过的路由器节点与逐段时延。
3. **DNS 查询**：支持 A、AAAA、CNAME、MX、TXT、NS 记录查询及上游解析服务器响应耗时。
4. **网站连通性分析**：分段测量 TCP 握手、TLS 协商与首字节时延（TTFB），校验证书及状态码。
5. **并发端口扫描**：基于原生 `NWConnection` 的高并发有界 `TaskGroup` 扫描器。
6. **纯 Swift 子网计算器**：即时运算 CIDR、掩码、通配符、广播地址及可用主机区间。
7. **Wake on LAN（远程网络唤醒）**：向目标 MAC 地址广播标准 102 字节魔术数据包（Port 9）。
8. **iPerf 吞吐量测速**：深度整合 iperf3 CLI 并提供路径自适应探测。
9. **网络综合体检**：多阶段自动化检查本地环回、默认网关、DNS 解析及广域网外网联通性。

#### 5. ⌚ watchOS 腕上监控与菜单栏 HUD
- **watchOS 协同端**：腕上快速查阅实时网络遥测指标，支持常用轻量诊断工具。
- **状态栏菜单（Menu Bar Extra）**：常驻 macOS 顶栏的小巧监控胶囊，实时显示上行/下行速率，支持动态流量折线图。

#### 6. 🔐 Root 提权辅助守护进程（Privileged Helper Daemon）
- 遵循 Apple 现代化 `SMAppService.daemon` 规范的独立守护服务。
- 基于安全的 Mach XPC 通信协议，保障普通权限 UI 安全调用底层嗅探和原始套接字操作。
- 内置非特权开发回退模式，方便单元测试与调试。

---

### 🛠️ 环境要求与本地编译
- **系统要求**：macOS 14.0 (Sonoma) 或更高版本；watchOS 10.0+（用于 Apple Watch 端）。
- **编译工具**：Xcode 15+ / Swift 6.0 工具链。
- **架构支持**：通用架构（Apple Silicon `arm64` 与 Intel `x86_64`）。

```bash
# 克隆代码仓库
git clone https://github.com/Lambda-404/Nexor.git
cd Nexor

# 编译并生成带 Ad-hoc 签名的应用程序
./build.sh

# 编译并立即启动 Nexor
./build.sh --open
```

### 🧪 运行自动化测试
```bash
cd Tests/E2E
./run_tests.sh
```

---

### ⚖️ 安全合规与法律免责声明
> **重要合规提示**：
> 
> Nexor 仅用于**合法的网络运维、故障诊断、自主网络拓扑排查及教学学术研究**。
> 
> - 使用者有责任确保本工具的所有嗅探、扫描及诊断行为符合所在国家或地区的相关网络安全法律法规（如《中华人民共和国网络安全法》第27条等）。
> - **严禁**在未经网络所有者明确书面授权的情况下对他人网络、服务器或终端发起端口扫描、网络嗅探或未授权探测。
> - 本项目的开发者及贡献者不对任何人因违规使用本工具所导致的任何直接或间接法律责任及损失承担任何责任。

---

## 📄 License
This project is open-sourced under the [MIT License](LICENSE).  
本项目基于 [MIT 许可证](LICENSE) 开源。
