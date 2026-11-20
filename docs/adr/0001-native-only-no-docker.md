# ADR-0001: Native Swift app only — Docker rule waived

- Status: Accepted · Date: 2026-11-20

## Context
The workshop requires everything to run in Docker. The product is a macOS floating window using
AppKit/SwiftUI, which cannot run in a Linux container. A split where a Swift core builds in Docker
was offered and declined by the owner.

## Decision
Build a native macOS app only. No Docker, no server. Builds and tests run on the Mac with Xcode 26
via `scripts/`.

## Consequences
- No container reproducibility; `scripts/bootstrap.sh` checks tool versions instead.
- Contributors need a Mac with Xcode 26 and XcodeGen.
