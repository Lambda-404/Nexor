#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BIN="$SCRIPT_DIR/test_runner"

echo "======================================================="
echo " Compiling Teamwork_NetworkUtilities E2E Test Suite..."
echo "======================================================="

SWIFT_SOURCES=(
    "$SCRIPT_DIR/TestRunner.swift"
    "$SCRIPT_DIR/Tier1_FeatureTests.swift"
    "$SCRIPT_DIR/Tier2_BoundaryTests.swift"
    "$SCRIPT_DIR/Tier3_CombinationTests.swift"
    "$SCRIPT_DIR/Tier4_ScenarioTests.swift"
    "$SCRIPT_DIR/Fixtures/PacketFixtures.swift"
    "$SCRIPT_DIR/Fixtures/TestFixtures.swift"
)

swiftc -g -O "${SWIFT_SOURCES[@]}" \
    -o "$BIN" \
    -framework Foundation \
    -framework Network \
    -framework SystemConfiguration \
    -framework CoreWLAN

echo "Compilation successful. Executing E2E test suite..."
"$BIN" "$@"
EXIT_CODE=$?

exit $EXIT_CODE
