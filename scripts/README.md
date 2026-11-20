# scripts/

Created during the build (Phase 1 and Phase 11):

| Script | Purpose |
|---|---|
| `bootstrap.sh` | Check Xcode 26+ + xcodegen, run `xcodegen generate` |
| `test.sh` | `swift test` in `backend/CurrencyCore` + `xcodebuild test` for the app; exits non-zero on failure |
| `build.sh` | Debug build |
| `lib.sh` | Shared paths and helpers (sourced by the others) |
| `run.sh` | Build and launch with `.env` exported (never prints values) |
| `release.sh` | Archive → Developer ID sign → notarize → staple → DMG (uses env vars only) |
