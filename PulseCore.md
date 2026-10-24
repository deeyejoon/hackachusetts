# PulseCore

The physiological-response engine: syncs heart-rate data to the phone and correlates
**extraordinary** physiological changes with the content a user was exposed to.

This is a plain Swift Package so the core logic is buildable and testable from the command
line (`swift test`) with **no WHOOP band, no simulator, and no Apple entitlements**. It gets
imported into the iOS app target later for ReplayKit / notifications / UI.

## What this does (and what it deliberately does not)

- **Detects "extraordinary" changes**, not "harmful" ones. The engine flags heart-rate
  readings that are statistically unusual *for that specific user* (z-score vs. their own
  rolling baseline). It makes **no claim** about healthy vs. harmful — meaning comes from
  the correlated content keywords and from the user's own labeling.
- It is **source-agnostic**: the same engine runs on a fake stream today and a real WHOOP
  band tomorrow.

## Architecture

```
HeartRateSource (protocol)            ContentEvent sources (iOS layer, added next)
 ├─ MockHeartRateSource   ← now        ├─ DeviceActivity   (app usage, automatic)
 ├─ WhoopBLESource        ← later      ├─ ReplayKit + OCR  (real keywords, consented session)
 └─ WhoopAPISource        ← later      └─ Share Extension  (flagged post)
         │                                      │
         └──────── HRSample ────┐   ┌─ ContentEvent ───────┘
                                ▼   ▼
                        CorrelationEngine
                        • BaselineTracker (rolling mean/SD, per-user z-score)
                        • spike detection (z >= threshold) + refractory debounce
                        • time-join content to each spike
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
              onSpike callback         WeeklyReport
              (→ live local notif)     (ranked trigger keywords)
```

## Files

| File | Role |
|------|------|
| `Models/HRSample.swift` | one physiological reading (bpm, R-R, time) |
| `Models/ContentEvent.swift` | one content exposure (keywords, app, source, time) |
| `Models/SpikeEvent.swift` | a detected unusual reading + correlated content |
| `Sources/HeartRateSource.swift` | the swappable source protocol |
| `Sources/MockHeartRateSource.swift` | synthetic stream with `injectSpike()` |
| `Engine/BaselineTracker.swift` | rolling per-user baseline + z-score |
| `Engine/CorrelationEngine.swift` | spike detection + content time-join |
| `Engine/WeeklyReport.swift` | aggregates spikes into ranked keyword insights |

## Run the tests

```bash
swift test
```

## iOS reality notes (why the design is shaped this way)

- **Cannot** silently read other apps' screens. Keyword-level capture from real apps
  (Instagram/TikTok) requires a **user-started ReplayKit broadcast** (visible red dot, no
  background auto-start). Automatic capture via **DeviceActivity** is app-level only.
- **Can** stream the WHOOP band live over CoreBluetooth in the background, and fire local
  notifications for live alerts.

## Next steps (iOS app target)

1. `WhoopBLESource` — CoreBluetooth implementation of `HeartRateSource`.
2. ReplayKit Broadcast Upload Extension + Vision OCR → emits `ContentEvent`s.
3. `LiveAlertService` — local notification on `onSpike`.
4. `WeeklyReportStore` — persist spikes, generate `WeeklyReport` weekly.
