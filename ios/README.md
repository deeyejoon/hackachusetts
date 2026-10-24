# Sage iOS App (SwiftUI)

Four-screen SwiftUI prototype. Screen 1 (Chat) is a real integration against the
Flask backend; Screens 2–4 (Insights, Connect, Community) use mocked data.

## Opening in Xcode

These are plain `.swift` sources organized by role. To run them:

1. In Xcode: **File → New → Project → iOS → App** (SwiftUI, Swift). Name it `Sage`.
2. Delete the generated `ContentView.swift` and the generated `*App.swift`.
3. Drag the folders here (`Models`, `ViewModels`, `Views`, `Networking`, `Theme`)
   and `SageApp.swift` into the project (copy if needed, create groups).
4. Set the deployment target to **iOS 16.0** or later.
5. Build and run.

> `SageApp.swift` is the `@main` entry point, so remove the template's own
> `@main` struct to avoid a duplicate-entry-point error.

## Pointing at the backend

`Networking/ChatAPIClient.swift` holds one configuration line:

```swift
static let baseURL = URL(string: "http://127.0.0.1:5000")!
```

- **Simulator:** keep `127.0.0.1`.
- **Physical device:** change to your Mac's LAN IP, e.g. `http://192.168.1.42:5000`
  (find it with `ipconfig getifaddr en0`). The device and Mac must share Wi-Fi.

### App Transport Security (local HTTP)

The backend is plain HTTP for the hackathon. iOS blocks non-HTTPS by default,
so add this to the app target's **Info.plist** to allow local connections:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

## Structure

```
ios/
  SageApp.swift              @main entry point
  Models/ChatMessage.swift   message model (role, style, signal metadata)
  ViewModels/ChatViewModel.swift   state, networking orchestration, seed content
  Networking/ChatAPIClient.swift   URLSession wrapper (ChatSending protocol, typed errors)
  Views/
    RootTabView.swift        bottom tab bar
    ChatView.swift           Screen 1 + typing indicator
    MessageBubbleView.swift  bubble shape + normal/user/signal/crisis variants
    InsightsView.swift       Screen 2 (mocked)
    ConnectView.swift        Screen 3 (mocked)
    CommunityView.swift      Screen 4 (mocked)
  Theme/
    SageColors.swift         palette
    SageFonts.swift          serif/sans helpers (Fraunces/Inter with fallbacks)
```

## Fonts (optional)

`SageFonts` uses Fraunces (serif) and Inter (sans) if bundled, else falls back to
the system serif / default. To use the brand fonts, add the `.ttf` files to the
target and list them under **Fonts provided by application** in Info.plist.

## Demo checklist

- Confirm the backend `GET /health` shows `hf_token_configured: true` first.
- Send a crisis-pattern message ("I want to die") — a dark bubble with tappable
  988 / 741741 links should appear, and the backend must log `[crisis]` with no
  Hugging Face call.
- Stop the backend and send a message — a graceful error bubble appears, no crash.
- Test on a physical device via LAN IP, not just the Simulator on 127.0.0.1.

## Architecture notes

- `ChatAPIClient` is injected into `ChatViewModel` via the `ChatSending` protocol,
  so the view model can be unit-tested with a mock client (no live network).
- The seed `.signal` message is UI-only and is excluded from the history payload
  sent to the backend.
- History is trimmed to the last ~10 messages client-side; the backend trims
  again to its own limit.
```
