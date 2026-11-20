# ADR-0022: Localization, language override and RTL

- Status: Accepted · Date: 2026-11-21

## Decision
- **Languages**: every user-facing string is in `Localizable.xcstrings` with he (source), en, es, ru, zh-Hans.
  Sentences with two arguments use positional placeholders (`%1$@ %2$@`). An app test checks the built
  `.lproj` tables: every key present in all five languages, non-empty, same placeholders as the key, and not an
  English fallback (allow-list: Spanish "Fiat", "General", "Israel", and the `%lld min` / `%lld s` units).
- **Default stays Hebrew** (SPEC §4, CLAUDE.md); "System" is the option to follow macOS (SPEC F30).
- **Override = per-app `AppleLanguages`**, written from the saved setting in the app's `init` before any string
  loads, and again when the setting changes. macOS fixes an app's localization at launch (menus, notifications,
  AppKit), so a change shows "Restart Currency Notch to switch language" with a **Restart Now** button
  (launches a new instance, then quits). "System" removes the app's value, falling back to the macOS list.
- **RTL** (SPEC F31): the pill, expanded view, dropdown rows and Settings mirror with the layout direction.
  Codes and numbers are wrapped in Unicode LTR isolates (U+2066…U+2069), including the notification arguments.
  The collapsed board mirrors as `[•] [3.3429 ₪] [USD]`, with value + symbol kept as one LTR group. The threshold
  input field and sparklines stay LTR (time runs left → right, as in financial charts).
- **Number formats** follow the selected language's locale (tested for all five), e.g. Spanish `194.557,83` but
  `5311,62` (CLDR: no grouping for 4-digit numbers), Russian `194 557,83`.
- Translations are mine, not native-speaker reviewed.
