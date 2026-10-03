#!/bin/bash
for f in \
"Sources/Nexor/Services/LANDiscoveryService.swift" \
"Sources/Nexor/Services/NetworkMediumDetector.swift" \
"Sources/Nexor/Services/TrafficStatisticsEngine.swift" \
"Sources/Nexor/Services/RFTelemetryService.swift" \
"Sources/Nexor/Services/WiFiScannerService.swift" \
"Sources/Nexor/Views/DashboardView.swift" \
"Sources/Nexor/Views/SettingsView.swift" \
"Sources/Nexor/Services/WiFiLocationAuthorizationHelper.swift" \
"Sources/Nexor/Views/BluetoothRadarView.swift" \
"Sources/Nexor/Views/Components/ConsoleOutputView.swift" \
"Sources/Nexor/Views/Components/LiquidGlassSystem.swift" \
"Sources/Nexor/Views/LANDevicesView.swift" \
"Sources/Nexor/Views/MenuBar/MenuBarPopoverView.swift" \
"Sources/Nexor/Services/BluetoothDiscoveryService.swift" \
"Sources/Nexor/Views/MenuBar/MenuBarExtraView.swift" \
"Sources/Nexor/Views/ContentView.swift" \
"Sources/Nexor/ViewModels/DashboardViewModel.swift" \
"Sources/Nexor/ViewModels/DiagnosticViewModel.swift" \
"Sources/Nexor/ViewModels/NetworkToolsViewModel.swift" \
"Sources/Nexor/Services/DiagnosticExecutionManager.swift" \
"Sources/Nexor/Views/DiagnosticsView.swift" \
"Sources/Nexor/Views/NetworkToolsView.swift" \
"Sources/Nexor/Views/SecurityScannerView.swift"
do
  if [ -f "$f" ]; then
    echo -e "#if os(macOS)\n$(cat "$f")\n#endif" > "$f"
  fi
done
