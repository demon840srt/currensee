# Currency Notch (app name: CurrenSee) — CLAUDE.md

Native macOS 26 floating notch-sized pill that rotates live exchange rates (fiat + crypto).
Full spec: `docs/SPEC.md` · Architecture: `docs/ARCHITECTURE.md` · Plan: `docs/build-plan.md`

## Stack
- Swift 6 (strict concurrency), SwiftUI + AppKit (`NSPanel`), Core Animation (`CAEmitterLayer`)
- Swift Testing (`import Testing`), XcodeGen (`frontend/project.yml`; `.xcodeproj` is generated, never committed)
- Deployment target macOS 26.0. No third-party dependencies without a new ADR.

## Folder structure
- `backend/CurrencyCore/` — Swift package, pure logic, no UI imports (models, providers, rotation, history, alerts)
- `frontend/CurrencyNotch/` — macOS app (`project.yml`, `Sources/`, `Resources/Localizable.xcstrings`)
- `scripts/` — `bootstrap.sh`, `test.sh`, `build.sh`, `run.sh`, `release.sh`
- `docs/` — `SPEC.md`, `ARCHITECTURE.md`, `build-plan.md`, `adr/`
- `references/` — API notes, theme specs, UI references (read-only input)

## Commands
- `./scripts/bootstrap.sh` — check tools (Xcode 26 or newer, xcodegen), generate project
- `./scripts/test.sh` — `swift test` in backend + `xcodebuild test` for the app
- `./scripts/build.sh` — Debug build · `./scripts/run.sh` — build + launch with `.env` exported
- `./scripts/release.sh` — Release build, verify, install to /Applications; `--dmg` for a backup DMG (asks first; ADR-0023)

## Working rules
- One phase per session: `/phase N`. Plan first, wait for approval, then implement.
- Every phase ends with `./scripts/test.sh` green and its checklist ticked in `docs/build-plan.md`.
- Never `git commit` or `git push` without explicit approval. Show the diff summary first.
- New decisions → new ADR in `docs/adr/` + one line in the SPEC decision log.
- Logic goes in `CurrencyCore` with tests; the app layer stays thin.
- Use `Decimal` for money values, never `Double`.
- All user-facing strings go through `Localizable.xcstrings`. Hebrew is default and RTL;
  use leading/trailing, never left/right. Code, comments, identifiers: English.
- Respect Reduce Motion; pause particles on battery when the setting is on.
- Tests never hit the network: use `MockRateProvider` / recorded JSON fixtures.

## Security
- Never read, print or edit `.env` (blocked in settings). Only `.env.example` holds dummy values.
- No secrets are needed (personal use, ADR-0023). If any are ever added: env vars / Keychain only — never in code,
  `project.yml`, Info.plist or the binary.
- HTTPS only, hosts allowlisted in `RateHostAllowlist`; no ATS exceptions.
- Decode API responses strictly; cap response size (1 MB); reject zero/negative/non-finite/absurd values.
- App Sandbox: `com.apple.security.network.client` only. Hardened Runtime on.
- No telemetry, no logging of full responses in Release builds.

## Out of scope
WidgetKit widget · Docker · server/DB · Mac App Store · iOS/Windows/Linux · accounts ·
converter/trading · paid or keyed APIs · analytics · CI.
