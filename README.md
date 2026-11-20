# CurrenSee

A small, notch-sized pill that floats on your macOS desktop and rotates through the exchange rates you choose —
fiat and crypto — with a split-flap "airport board" flip. Hover for change % and a sparkline, click for the full
list. Built for personal use on macOS 26 (ADR-0023): no account, no server, no telemetry.

## Requirements
- macOS 26 or newer
- Xcode 26 or newer (installed from the App Store and selected with `xcode-select`)
- XcodeGen: `brew install xcodegen`

## Install
```bash
./scripts/release.sh
```
This runs all tests, builds a Release copy, checks that it's sandboxed (network access only) with Hardened
Runtime, and installs it as `/Applications/CurrenSee.app`. Then open it from Applications or with
`open /Applications/CurrenSee.app`.

Options: `--open` launches it afterwards, `--dmg` also saves a backup DMG in `dist/`, `--yes` replaces an existing
copy without asking.

Because it's built on your own Mac, macOS doesn't show Gatekeeper warnings. A copy sent to another Mac would be
blocked until approved manually (right-click → Open, and System Settings › Privacy & Security) — sharing isn't a
supported scenario.

## Update
Pull or edit the code, then run `./scripts/release.sh` again. It quits the running copy and replaces it (it asks
first; add `--yes` to skip the question). Settings, watch list, alerts and history are kept.

## First run
- The pill appears at the top center of your main display, on every Space, just above the desktop icons
  (it sits under normal windows, like desktop widgets).
- Use the **$** icon in the menu bar (or right-click the pill) for: Show/Hide pill, Lock/Unlock position,
  Refresh now (⌘R), Settings… (⌘,), Quit.
- **Launch at login** is off until you switch it on in Settings → General. If macOS asks for approval, use the
  button there to open System Settings › Login Items.
- **Alerts**: macOS asks for notification permission when you create your first alert.
- **Language**: Hebrew by default; change it in Settings → General (the app restarts to switch).
- **Effects** (Ice, Fire, Israel themes) pause on battery while "Pause effects on battery" is on.

## Uninstall
1. Quit from the menu-bar icon, and switch off **Launch at login** first if you turned it on.
2. Delete `/Applications/CurrenSee.app`.
3. Optional — remove settings and cached rates/history (the folder keeps the app's original internal ID):
   ```bash
   rm -rf ~/Library/Containers/com.afik.CurrencyNotch
   ```

## Development
| Command | What it does |
|---|---|
| `./scripts/bootstrap.sh` | Check Xcode + XcodeGen, generate the Xcode project |
| `./scripts/test.sh` | Core tests (`swift test`) + app tests (`xcodebuild test`) |
| `./scripts/build.sh` | Debug build into `build/` |
| `./scripts/run.sh` | Debug build and launch (exports `.env` if present; see `.env.example`) |
| `./scripts/release.sh` | Tested, verified Release install to /Applications |

Logic lives in the `CurrencyCore` Swift package (`backend/`), the app in `frontend/`. Spec:
[`docs/SPEC.md`](docs/SPEC.md) · Architecture: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · Decisions:
[`docs/adr/`](docs/adr/) · Plan: [`docs/build-plan.md`](docs/build-plan.md).

Rates come from Coinbase (primary) and Frankfurter (fallback), both free and key-less, over HTTPS only.
