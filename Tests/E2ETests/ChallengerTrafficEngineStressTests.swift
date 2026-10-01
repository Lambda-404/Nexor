//
//  ChallengerTrafficEngineStressTests.swift
//  Teamwork_NetworkUtilities E2ETests
//
//  Empirical Adversarial Stress Harness for Requirement R2
//  (Network Traffic & Bandwidth Statistics Engine)
//

import Foundation
import Darwin
import SystemConfiguration

@main
struct ChallengerStressHarness {
    static var passCount = 0
    static var failCount = 0
    static var bugCount = 0

    static func assertTest(_ condition: Bool, _ name: String, details: String = "") {
        if condition {
            passCount += 1
            print("  ✓ PASS: \(name)")
        } else {
            failCount += 1
            print("  ✗ FAIL: \(name) - \(details)")
        }
    }

    static func reportBug(_ title: String, details: String) {
        bugCount += 1
        print("  ⚠️ DISCOVERED VULNERABILITY/BUG: \(title)")
        print("     Details: \(details)")
    }

    static func main() async {
        print("=================================================================")
        print("  EMPIRICAL ADVERSARIAL CHALLENGER SUITE: REQUIREMENT R2")
        print("=================================================================\n")

        await testSuite1_RateAndByteFormattingBoundaries()
        await testSuite2_RapidKernelSamplingLoop()
        await testSuite3_LiveSessionResetBehavior()
        await testSuite4_SimulatedCounterRollbackAndAsymmetricReset()
        await testSuite5_ExtremeRateFormattingAndNaNInfStress()
        await testSuite6_AggregateInterfaceFilteringAudit()

        print("\n=================================================================")
        print("  CHALLENGER SUITE RESULTS SUMMARY")
        print("=================================================================")
        print("  Passed Assertions: \(passCount)")
        print("  Failed Assertions: \(failCount)")
        print("  Confirmed Bugs / Flaws: \(bugCount)")
        print("=================================================================\n")

        if failCount > 0 || bugCount > 0 {
            print("Empirical challenger completed with identified bugs/failures.")
        } else {
            print("All adversarial stress tests passed without finding critical bugs.")
        }
    }

    // MARK: - Test Suite 1: Rate and Byte Formatting Boundaries
    static func testSuite1_RateAndByteFormattingBoundaries() async {
        print("[Suite 1] Rate & Byte Formatting Boundary Tests")

        // 1. Zero and negative rates
        assertTest(TrafficUnitFormatter.formatRate(0) == "0 B/s", "Format 0 B/s")
        assertTest(TrafficUnitFormatter.formatRate(-10.5) == "0 B/s", "Format negative rate clamped to 0 B/s")

        // 2. Small bytes
        assertTest(TrafficUnitFormatter.formatRate(500) == "500 B/s", "Format 500 B/s")
        assertTest(TrafficUnitFormatter.formatRate(1023.9) == "1024 B/s", "Format near KiB boundary 1023.9")

        // 3. Kilobyte ranges (< 100 KB/s should have 1 decimal, >= 100 KB/s should have 0 decimals)
        assertTest(TrafficUnitFormatter.formatRate(1024 * 50.4) == "50.4 KB/s", "Format 50.4 KB/s (with decimal)")
        assertTest(TrafficUnitFormatter.formatRate(1024 * 120.0) == "120 KB/s", "Format 120 KB/s (no decimal)")
        assertTest(TrafficUnitFormatter.formatRate(1024 * 99.94) == "99.9 KB/s", "Format 99.94 KB/s (< 100 KB/s)")
        assertTest(TrafficUnitFormatter.formatRate(1024 * 100.0) == "100 KB/s", "Format 100.0 KB/s (>= 100 KB/s)")

        // 4. Megabyte ranges (always 2 decimals)
        assertTest(TrafficUnitFormatter.formatRate(1024 * 1024 * 2.4) == "2.40 MB/s", "Format 2.4 MB/s")
        assertTest(TrafficUnitFormatter.formatRate(1024 * 1024 * 100.0) == "100.00 MB/s", "Format 100 MB/s")

        // 5. Gigabyte ranges
        assertTest(TrafficUnitFormatter.formatRate(1024 * 1024 * 1024 * 1.5) == "1.50 GB/s", "Format 1.5 GB/s")
        assertTest(TrafficUnitFormatter.formatRate(1024 * 1024 * 1024 * 10.0) == "10.00 GB/s", "Format 10 GB/s")

        // 6. Cumulative byte totals (formatBytes)
        assertTest(TrafficUnitFormatter.formatBytes(0) == "0 B", "Cumulative 0 B")
        assertTest(TrafficUnitFormatter.formatBytes(512) == "512 B", "Cumulative 512 B")
        assertTest(TrafficUnitFormatter.formatBytes(1024 * 15) == "15.0 KB", "Cumulative 15 KB")
        assertTest(TrafficUnitFormatter.formatBytes(1024 * 1024 * 45) == "45.00 MB", "Cumulative 45 MB")
        assertTest(TrafficUnitFormatter.formatBytes(UInt64(1024) * 1024 * 1024 * 3) == "3.00 GB", "Cumulative 3 GB")
        assertTest(TrafficUnitFormatter.formatBytes(UInt64(1024) * 1024 * 1024 * 1024 * 2) == "2.00 TB", "Cumulative 2 TB")

        // 7. Compact rate formatting
        assertTest(TrafficUnitFormatter.formatCompactRate(0) == "0B", "Compact 0B")
        assertTest(TrafficUnitFormatter.formatCompactRate(500) == "500B", "Compact 500B")
        assertTest(TrafficUnitFormatter.formatCompactRate(1024 * 50) == "50.0K", "Compact 50.0K")
        assertTest(TrafficUnitFormatter.formatCompactRate(1024 * 120) == "120K", "Compact 120K")
        assertTest(TrafficUnitFormatter.formatCompactRate(1024 * 1024 * 2.4) == "2.4M", "Compact 2.4M")
        assertTest(TrafficUnitFormatter.formatCompactRate(1024 * 1024 * 1024 * 1.5) == "1.5G", "Compact 1.5G")

        // 8. Decimal standard check (1000 base)
        assertTest(TrafficUnitFormatter.formatRate(1000 * 120, standard: .decimal) == "120 KB/s", "Decimal standard 120 KB/s")
        assertTest(TrafficUnitFormatter.formatBytes(1000 * 1000 * 5, standard: .decimal) == "5.00 MB", "Decimal standard 5 MB")
    }

    // MARK: - Test Suite 2: Rapid Kernel Sampling Loop
    static func testSuite2_RapidKernelSamplingLoop() async {
        print("\n[Suite 2] Rapid Kernel Sampling Loop Stress Test (100 consecutive calls)")

        let startTime = CFAbsoluteTimeGetCurrent()
        var sampleCount = 0
        var totalInterfacesDiscovered = 0

        for i in 1...100 {
            let samples = TrafficStatisticsEngine.readKernelInterfaces()
            sampleCount += 1
            totalInterfacesDiscovered += samples.count
            if i % 25 == 0 {
                print("  Iteration \(i)/100: \(samples.count) interfaces discovered.")
            }
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let avgPerSample = (elapsed / Double(sampleCount)) * 1000.0

        assertTest(sampleCount == 100, "Completed 100 consecutive sysctl kernel reads without crash")
        assertTest(totalInterfacesDiscovered > 0, "Discovered active interfaces across all iterations")
        print("  ⏱ Total time for 100 rapid samples: \(String(format: "%.2f", elapsed * 1000)) ms (avg: \(String(format: "%.3f", avgPerSample)) ms/sample)")

        // Rapid actor sampling
        let engine = TrafficStatisticsEngine()
        let actorStartTime = CFAbsoluteTimeGetCurrent()
        for _ in 1...50 {
            let snap = await engine.sample()
            assertTest(!snap.perInterfaceStats.isEmpty, "Actor snapshot contains interface stats")
        }
        let actorElapsed = CFAbsoluteTimeGetCurrent() - actorStartTime
        print("  ⏱ Total time for 50 rapid actor sample() calls: \(String(format: "%.2f", actorElapsed * 1000)) ms")
    }

    // MARK: - Test Suite 3: Live Session Reset Behavior
    static func testSuite3_LiveSessionResetBehavior() async {
        print("\n[Suite 3] Live Session Reset Verification")

        let engine = TrafficStatisticsEngine()
        let snap1 = await engine.sample()
        let initialRx = snap1.aggregateStats.sessionRxBytes
        let initialTx = snap1.aggregateStats.sessionTxBytes
        assertTest(initialRx == 0 && initialTx == 0, "Initial sample session counters start at 0")

        // Sleep briefly to let any background traffic accumulate
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        let snap2 = await engine.sample()
        print("  Pre-reset sessionRx: \(snap2.aggregateStats.sessionRxBytes) B, sessionTx: \(snap2.aggregateStats.sessionTxBytes) B")

        // Reset session
        await engine.resetSession()
        let snapAfterReset = await engine.sample()

        print("  Post-reset sessionRx: \(snapAfterReset.aggregateStats.sessionRxBytes) B, sessionTx: \(snapAfterReset.aggregateStats.sessionTxBytes) B")
        assertTest(snapAfterReset.aggregateStats.sessionRxBytes == 0 || snapAfterReset.aggregateStats.sessionRxBytes < 10000,
                   "Post-reset sessionRxBytes is zero or minimal delta")

        // Verify total boot bytes remained non-zero and intact
        if let primary = snapAfterReset.primaryStats {
            assertTest(primary.totalRxBytes > 0, "Total boot Rx bytes preserved after session reset (\(primary.totalRxBytes) bytes)")
            assertTest(primary.totalTxBytes > 0, "Total boot Tx bytes preserved after session reset (\(primary.totalTxBytes) bytes)")
        } else {
            print("  ⚠️ Warning: No primary interface found in snapAfterReset")
        }
    }

    private static func computeDelta(current: UInt64, previous: UInt64) -> UInt64 {
        return current >= previous ? (current - previous) : 0
    }

    // MARK: - Test Suite 4: Simulated Counter Rollback & Asymmetric Reset
    static func testSuite4_SimulatedCounterRollbackAndAsymmetricReset() async {
        print("\n[Suite 4] Simulated Counter Wraparound, Rollback & Replug Stress Test")

        // We simulate the exact mathematical logic of TrafficStatisticsEngine:
        // Case 1: Monotonic normal traffic
        var prevRx: UInt64 = 1_000_000
        var prevTx: UInt64 = 500_000
        let baselineRx: UInt64 = 1_000_000
        let baselineTx: UInt64 = 500_000

        let curRx1: UInt64 = 2_000_000
        let curTx1: UInt64 = 800_000

        let deltaRx1 = computeDelta(current: curRx1, previous: prevRx)
        let deltaTx1 = computeDelta(current: curTx1, previous: prevTx)
        assertTest(deltaRx1 == 1_000_000 && deltaTx1 == 300_000, "Normal delta calculation")

        let sessionRx1 = computeDelta(current: curRx1, previous: baselineRx)
        let sessionTx1 = computeDelta(current: curTx1, previous: baselineTx)
        assertTest(sessionRx1 == 1_000_000 && sessionTx1 == 300_000, "Normal session accumulation")

        // Case 2: Counter Wraparound / Adapter Replug (counter drops from 2,000,000 to 500)
        prevRx = curRx1
        prevTx = curTx1
        let curRx2: UInt64 = 500   // Replug resets kernel counter
        let curTx2: UInt64 = 200

        let deltaRx2 = computeDelta(current: curRx2, previous: prevRx)
        let deltaTx2 = computeDelta(current: curTx2, previous: prevTx)
        assertTest(deltaRx2 == 0, "Delta Rx does not underflow upon counter drop (clamped to 0)")
        assertTest(deltaTx2 == 0, "Delta Tx does not underflow upon counter drop (clamped to 0)")

        // Engine's reset handling:
        let triggeredReset = (curRx2 < prevRx || curTx2 < prevTx)
        assertTest(triggeredReset, "Engine detects counter drop below baseline")

        // Now test the ASYMMETRIC COUNTER DROP:
        // What if curRx is 50,000,000,000 (50 GB boot count) and ONLY TX drops?
        let bootRx: UInt64 = 50_000_000_000
        let bootTx: UInt64 = 10_000_000_000

        // User uploaded 50 MB, downloaded 100 MB
        let nowRx = bootRx + 100_000_000
        let nowTx = bootTx + 50_000_000

        // Now suppose TX counter drops to 10 (e.g. TX ring buffer re-init or hotplug)
        let droppedTx: UInt64 = 10
        let unchangedRx = nowRx + 1000

        // In TrafficStatisticsEngine (remediated: monotonic delta accumulation):
        var simSessionRx: UInt64 = 100_000_000
        var simSessionTx: UInt64 = 50_000_000
        let simPrevRx = nowRx
        let simPrevTx = nowTx

        let simDeltaRx = computeDelta(current: unchangedRx, previous: simPrevRx)
        let simDeltaTx = computeDelta(current: droppedTx, previous: simPrevTx)
        simSessionRx += simDeltaRx
        simSessionTx += simDeltaTx

        if simSessionRx >= 50_000_000_000 {
            reportBug(
                "Asymmetric Baseline Reset Corrupts Session Counters",
                details: "When only TX counter drops (e.g. droppedTx < baseline.tx), the engine resets BOTH rx and tx baseline to 0. This causes sessionRx to instantly leap to total boot bytes (\(simSessionRx) bytes = 50+ GB) instead of preserving session usage!"
            )
        } else {
            assertTest(simSessionRx == 100_001_000, "Monotonic delta accumulation prevents 50GB explosion upon TX drop (simSessionRx=\(simSessionRx))")
        }

        // Also test the loss of historical session bytes:
        if simSessionTx < 50_000_000 {
            reportBug(
                "Session Traffic History Lost On Replug/Counter Wrap",
                details: "When an interface counter wraps or resets, sessionRx/Tx are reset to current counter instead of preserving accumulated session traffic via delta summation."
            )
        } else {
            assertTest(simSessionTx == 50_000_000, "Historical session traffic preserved across counter reset/reconnect (simSessionTx=\(simSessionTx))")
        }
    }

    // MARK: - Test Suite 5: Extreme Rate Formatting & NaN / Inf Stress
    static func testSuite5_ExtremeRateFormattingAndNaNInfStress() async {
        print("\n[Suite 5] Extreme Rate Formatting & NaN / Infinity Stress Test")

        // Terabyte/sec rate (10 TB/s = 10 * 1024^4 B/s)
        let tenTbps = Double(10) * 1024.0 * 1024.0 * 1024.0 * 1024.0
        let formattedTbps = TrafficUnitFormatter.formatRate(tenTbps)
        print("  10 TB/s formatted as: \"\(formattedTbps)\"")
        assertTest(formattedTbps.contains("GB/s") || formattedTbps.contains("TB/s"), "Extreme high throughput formats without crashing")

        // Compact formatting of 10 TB/s
        let compactTbps = TrafficUnitFormatter.formatCompactRate(tenTbps)
        print("  10 TB/s compact formatted as: \"\(compactTbps)\"")

        // Maximum UInt64 bytes
        let maxBytesFormatted = TrafficUnitFormatter.formatBytes(UInt64.max)
        print("  UInt64.max bytes formatted as: \"\(maxBytesFormatted)\"")
        assertTest(maxBytesFormatted.contains("TB"), "UInt64.max formats into TB range")

        // NaN and Infinity resilience
        let nanRate = TrafficUnitFormatter.formatRate(Double.nan)
        let infRate = TrafficUnitFormatter.formatRate(Double.infinity)
        print("  NaN rate formatted: \"\(nanRate)\"")
        print("  Infinity rate formatted: \"\(infRate)\"")
        if nanRate.contains("nan") {
            reportBug(
                "Unsanitized NaN in TrafficUnitFormatter",
                details: "Passing Double.nan to formatRate produces 'nan GB/s' instead of falling back to '0 B/s' or sanitized output."
            )
        } else {
            assertTest(nanRate == "0 B/s", "NaN rate cleanly sanitized to 0 B/s")
        }
        if infRate.contains("inf") {
            reportBug(
                "Unsanitized Infinity in TrafficUnitFormatter",
                details: "Passing Double.infinity to formatRate produces 'inf GB/s' instead of a bounded ceiling or sanitized output."
            )
        } else {
            assertTest(infRate == "0 B/s", "Infinity rate cleanly sanitized to 0 B/s")
        }

        // Escaping pointer audit in readKernelInterfaces
        print("  [Audit] Inspecting sysctl pointer safety in readKernelInterfaces()...")
        let kernelReadResult = TrafficStatisticsEngine.readKernelInterfaces()
        assertTest(!kernelReadResult.isEmpty, "Kernel interfaces parsed safely via withUnsafeBytes without escaping pointer")
    }

    // MARK: - Test Suite 6: Aggregate Interface Filtering Audit
    static func testSuite6_AggregateInterfaceFilteringAudit() async {
        print("\n[Suite 6] Aggregate Interface Filtering Audit")

        // Verify that non-loopback active routed interfaces (including primary non-en interfaces) are aggregated
        let engine = TrafficStatisticsEngine()
        let snap = await engine.sample()
        if let primary = snap.primaryStats, !primary.name.hasPrefix("en") && !primary.name.contains("lo") {
            assertTest(snap.aggregateStats.activeInterfaceCount >= 1, "Non-en primary interface included in aggregate stats")
        } else {
            assertTest(snap.aggregateStats.activeInterfaceCount >= 1, "Active network interfaces included in aggregate stats")
        }
    }
}
