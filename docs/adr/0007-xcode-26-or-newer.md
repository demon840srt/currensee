# ADR-0007: Build with Xcode 26 or newer

- Status: Accepted · Date: 2026-11-20

## Context
The kit assumed Xcode 26. When the project started, the Mac App Store only offered Xcode 27.2,
which is what is installed on the build machine.

## Decision
Accept any Xcode with major version ≥ 26 (`scripts/bootstrap.sh` checks `MIN_XCODE_MAJOR=26`).
The deployment target stays macOS 26.0 and the Swift language mode stays Swift 6.

## Consequences
- Newer SDKs may introduce warnings or deprecations; they are fixed, not silenced.
- APIs newer than macOS 26 must be guarded with `#available` or avoided.
- Debug builds are ad-hoc signed and Xcode omits the Hardened Runtime flag for them;
  Release builds carry it (`flags=0x10002(adhoc,runtime)` verified in Phase 1). Phase 11 verifies
  the Developer ID-signed build.
