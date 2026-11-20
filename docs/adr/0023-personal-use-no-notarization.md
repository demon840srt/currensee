# ADR-0023: Personal use — no Developer ID, no notarization

- Status: Accepted · Date: 2026-11-21 · Supersedes the distribution parts of SPEC §2, §6, §8 and decision log #8

## Context
The brief planned a Developer ID–signed, notarized DMG for friends. The owner decided (2026-11-21) not to join the
Apple Developer Program: the app is for personal use on the owner's Mac.

## Decision
- **Users**: the owner only.
- **Signing**: local ad-hoc signature (`codesign -s -`), as in every build so far. **App Sandbox
  (`network.client` only) and Hardened Runtime stay on.** No Developer ID, no notarization, no stapling.
- **`scripts/release.sh`**: builds Release, verifies signature / entitlements / Hardened Runtime / no ATS keys,
  installs to `/Applications/CurrencyNotch.app` (asks before replacing), and with `--dmg` also writes a plain DMG
  to `dist/` as a backup copy. No secrets or environment variables are needed.

- **Security review fix**: with local signing, Xcode injected `com.apple.security.get-task-allow` (debugger
  attach) into Release too. `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO` for Release removes it; Debug keeps it.
  `release.sh` refuses to install unless the entitlements are exactly sandbox + network client.

## Consequences
- Apps built on the same Mac carry no quarantine attribute, so Gatekeeper doesn't block them.
- A copy downloaded or AirDropped to another Mac **would** be quarantined and blocked by Gatekeeper until approved
  manually (right-click → Open, and on recent macOS, System Settings › Privacy & Security). Sharing is therefore
  not a supported scenario.
- `.env` is no longer needed for releases; `.env.example` now only documents Debug-only measurement switches.
