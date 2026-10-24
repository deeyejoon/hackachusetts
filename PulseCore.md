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

## WHOOP connection ("pairing") — how it actually works

WHOOP's user-facing term is "pair," but the transport is the **standard BLE Heart Rate
Profile** (service `0x180D`, characteristic `0x2A37`) — the same profile Peloton/Zwift use.
So `WhoopBLESource` uses plain CoreBluetooth; there is no proprietary pairing to implement.

**Required step:** the band does not broadcast HR by default. In the WHOOP app, turn on
`Device Settings → Heart Rate Broadcast → Start Broadcast`. Until then the band emits nothing
on `0x180D` and scanning finds nothing — `WhoopBLESource` reports `.noDeviceFound` after a
15s timeout so onboarding can prompt the user instead of hanging silently. Because it uses the
standard profile, any BLE chest strap also works for testing without a WHOOP band.

## iOS integration layer (PulseKit target)

iOS-only, builds against the iOS SDK (not macOS). Each piece implements or feeds the same
PulseCore abstractions, so the engine is unchanged.

| File | Role |
|------|------|
| `WhoopBLESource.swift` | real `HeartRateSource` over CoreBluetooth (standard HR profile) |
| `LiveAlertService.swift` | turns `CorrelationEngine.onSpike` into a real local notification |
| `ScreenKeywordCapture.swift` | ReplayKit frames → Vision OCR → real `ContentEvent` keywords |

## Next steps (iOS app target)

1. Xcode app target that wires: `WhoopBLESource` → `CorrelationEngine` → `LiveAlertService`.
2. Broadcast Upload Extension hosting `ScreenKeywordCapture`, feeding the engine via App Group.
3. `WeeklyReportStore` — persist spikes, generate `WeeklyReport` weekly.
4. Minimal SwiftUI screen — live HR + weekly trigger report.
