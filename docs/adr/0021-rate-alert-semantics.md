# ADR-0021: Rate alert semantics

- Status: Accepted · Date: 2026-11-21

## Decision
- **Crossing** (`AlertEvaluator`): an armed *above* alert fires when the rate is strictly above the threshold
  (*below*: strictly below), then disarms and records `lastTriggeredAt`. It re-arms when the rate is back at or on
  the other side of the threshold. Exactly at the threshold never fires but re-arms — no repeated firing while
  hovering at the line.
- **Fresh data only**: only quotes fetched after the previous evaluation (initially app launch) are evaluated,
  so the launch cache or a value held by the 50 % jump guard can't trigger a notification.
- **New or edited alert already past its threshold** starts disarmed and notifies on the next real crossing;
  the Alerts tab says "Already above/below — will notify on the next crossing".
- **Inactive alerts**: an alert whose base differs from the current base, or whose currency left the watch list,
  is kept but never evaluated; the tab shows why. Switching back reactivates it. Alerts can only be created for
  watch-list currencies (only those are fetched).
- **Notifications**: one `UNNotificationRequest` per firing; permission is requested when an alert is created
  (macOS prompts only the first time). Banners also show while the app is frontmost. If permission is denied
  the tab shows a warning and a button to System Settings › Notifications.
- **Text**: "USD rose above 3.8000 ₪" — threshold formatted with the display precision rule (ADR-0016) and the
  base symbol. The two notification sentences are translated in all five languages now (positional `%1$@ %2$@`);
  the rest of the UI gets es/ru/zh-Hans in Phase 10.
