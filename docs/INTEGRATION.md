# Kiro — Integration Guide

This is the shared contract between the three slices of Kiro (the app is branded
**Sage** in the iOS layer). It describes how the pieces connect so all three of us
can work on one coherent product instead of three disconnected demos.

Read this first. When you change a cross-slice contract (a JSON shape, a model
field, an endpoint), update this file in the same change.

## The three slices

| Slice | Path | Owner area | Status |
|-------|------|------------|--------|
| **PulseCore / PulseKit** | `Sources/` | Physiological engine (Swift Package) | Engine real + tested; iOS layer real but runs only on-device |
| **Sage iOS app** | `ios/` | SwiftUI UI (4 screens) | Chat real; Insights/Connect/Community were mocked, Insights + Chat signal now consume real data |
| **Sage backend** | `backend/` | Flask + Hugging Face chatbot | Real, with crisis safety net |

## The data flow (end to end)

```
WHOOP band / Mock ──HRSample──▶ CorrelationEngine ──SpikeEvent──▶ SignalStore (iOS)
                                      ▲                                │
ReplayKit+OCR ──ContentEvent─────────┘                                ├──▶ InsightsView  (weekly report)
                                                                       ├──▶ ChatView      (signal card seed)
                                                                       └──▶ LiveAlertService (local notification)

ChatView ──POST /chat { message, history, signal_context? }──▶ Flask ──▶ Hugging Face
```

The key design rule from `PulseCore.md` holds: **PulseCore is source-agnostic and
UI-agnostic.** It emits `SpikeEvent`s. Everything the user sees is a *rendering* of
those events plus their own labels. The engine never claims content is "harmful."

## Contract 1 — PulseCore `SpikeEvent`/`WeeklyReport` → iOS

PulseCore's public models (`Sources/PulseCore/Models/*`, `Engine/WeeklyReport.swift`)
are the canonical shapes. The iOS app mirrors them in a tiny, dependency-free value
type (`ios/Models/PhysioSignal.swift`) so the UI compiles and runs **before** the
Xcode target links PulseCore over SPM. The field names line up 1:1:

| PulseCore | iOS `PhysioSignal` |
|-----------|--------------------|
| `SpikeEvent.timestamp` | `timestamp` |
| `SpikeEvent.bpm` | `bpm` |
| `SpikeEvent.baselineBpm` | `baselineBpm` |
| `SpikeEvent.zScore` | `zScore` |
| `SpikeEvent.correlatedContent[].keywords` | `keywords` |
| `SpikeEvent.correlatedContent[].appName` | `appName` |

When the Xcode app target adds PulseCore as a local Swift Package dependency,
`ios/Networking/PulseCoreBridge.swift` converts a real `SpikeEvent` into a
`PhysioSignal` with no change to any view. Until then, `SignalStore` serves
representative sample signals so the screens look real in the simulator.

### How to link PulseCore into the Xcode app (one-time)

1. Create the app target per `ios/README.md`.
2. **File → Add Package Dependencies… → Add Local…** and pick the repo root
   (the folder with `Package.swift`). Add the **PulseCore** product (and
   **PulseKit** for the on-device BLE/OCR/notification layer).
3. In `ios/Networking/PulseCoreBridge.swift`, remove the `#if !USE_PULSECORE`
   stub section and flip the target to compile the real bridge (instructions are
   inline in that file). The views and the store never change.

## Contract 2 — iOS `SignalStore`

`ios/ViewModels/SignalStore.swift` is the single source of truth for physiological
signals in the app. It is an `ObservableObject` injected into the environment by
`SageApp`. Both `InsightsView` and `ChatViewModel` read from it:

- `store.weeklyReport` — ranked trigger keywords for the Insights screen.
- `store.latestSignal` — the most recent spike, used to seed the Chat signal card.

Feeding it:
- **Now (no hardware):** `SignalStore` loads sample signals so the UI is populated.
- **On device:** `PulseCoreBridge` subscribes to `CorrelationEngine.onSpike` and
  calls `store.record(_:)` for each real spike.

## Contract 3 — Backend `POST /chat`

Request (unchanged fields plus one optional addition):

```json
{
  "message": "string (required)",
  "history": [ { "role": "user|assistant", "content": "string" } ],
  "signal_context": {
    "keywords": ["whiskey", "bar"],
    "app_name": "instagram",
    "bpm_delta": 22
  }
}
```

- `signal_context` is **optional and backward-compatible**. Older clients that omit
  it behave exactly as before.
- When present, the backend folds a short, non-clinical note into the system prompt
  so Sage can gently reference what the user physically reacted to. It never
  diagnoses and never asserts the content is harmful — same guardrail as the engine.

Response is unchanged:

```json
{ "reply": "string", "crisis": false, "model": "..." }
```

Crisis handling is unchanged and still runs **before** any model call or signal use.

## Build & verify

```bash
# Swift package (engine): builds + runs headless on macOS, no Xcode needed
swift build
swift test
swift run PulseDemo

# Backend
cd backend && python app.py      # GET /health should show hf_token_configured: true
```

The iOS app target itself is created in Xcode (see `ios/README.md`); PulseKit and the
SwiftUI views require the iOS SDK and do not build from the command line on macOS.

## Ground rules so we don't break each other

1. PulseCore must keep building and testing on macOS from the command line. Keep
   iOS-only code (CoreBluetooth, ReplayKit, Vision, UserNotifications) in **PulseKit**
   behind `#if canImport(...)`.
2. The crisis safety check in `backend/safety.py` runs before everything. Don't move it.
3. Cross-slice shape changes get reflected here and in `PhysioSignal` together.
4. Prefer extending over replacing. The mocked Connect/Community screens are fine as
   placeholders; swap their data sources when the real ones exist.
