# ADR-0005: XcodeGen-generated project

- Status: Accepted · Date: 2026-11-20

## Context
Claude Code edits text files. Hand-editing `.pbxproj` is error-prone and causes merge conflicts.

## Decision
Define the app in `frontend/CurrencyNotch/project.yml` and generate the `.xcodeproj` with
`xcodegen generate` (via `scripts/bootstrap.sh`). The `.xcodeproj` is git-ignored.

## Consequences
- Requires `brew install xcodegen` once. The bootstrap script checks for it and explains how to install it.
- Signing settings in `project.yml` reference build settings filled from env vars at release time; no identities are committed.
