# ADR-0024: The app is named CurrenSee

- Status: Accepted · Date: 2026-11-21

## Decision
- User-visible name **CurrenSee**: `CFBundleDisplayName`, product/executable (`/Applications/CurrenSee.app`), the
  five UI strings that mention the name (all languages), the network User-Agent (`CurrenSee/<version>`), the DMG
  (`dist/CurrenSee-<version>.dmg`, volume "CurrenSee"), scripts and README.
- **Kept on purpose**: bundle ID `com.afik.CurrencyNotch` (settings, watch list, alerts, placements and
  notification permission live under it; changing it would reset everything — ADR-0008), the data folder
  `Application Support/CurrencyNotch` (rate cache and history), and internal names (repo folder, Xcode
  project/target/scheme `CurrencyNotch`, code module `CurrencyNotch` via `PRODUCT_MODULE_NAME`, package `CurrencyCore`).
- `release.sh` replaces a pre-rename `/Applications/CurrencyNotch.app` when it installs CurrenSee.
- XcodeGen derives the unit-test host from the target name, so `TEST_HOST` points at `CurrenSee.app` explicitly.
