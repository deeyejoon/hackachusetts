# Installing Sage on a physical iPhone (no App Store)

This is a free **development install** over USB. It works with a normal (free) Apple
ID — no paid Developer Program needed. The catch: a free-provisioned app expires
after **7 days**, after which you re-run from Xcode to refresh it. Fine for a demo.

You need: a Mac with Xcode, an iPhone, and a USB-to-Lightning/USB-C cable.

---

## 1. Generate and open the project

```bash
brew install xcodegen          # one-time
cd /Users/daniely/hackachusetts
xcodegen generate
open Sage.xcodeproj
```

## 2. Point the app at the backend over your LAN

The Simulator can use `127.0.0.1`, but a **phone cannot reach your Mac's loopback**.
It must use the Mac's LAN IP.

1. Find your Mac's IP (same Wi-Fi as the phone):
   ```bash
   ipconfig getifaddr en0        # e.g. 136.167.121.9
   ```
2. In `project.yml`, set the backend URL under `targets → Sage → info → properties`
   (use port **5001** — see the AirPlay note in Step 6):
   ```yaml
   SAGE_BASE_URL: "http://136.167.121.9:5001"
   ```
3. Regenerate:
   ```bash
   xcodegen generate
   ```

`ChatAPIClient` reads `SAGE_BASE_URL` from Info.plist; if it's empty it falls back to
`127.0.0.1:5000`. No source edit required.

> ⚠️ **Campus / public Wi-Fi often blocks phone↔laptop traffic** (client isolation).
> `136.167.x.x` looks like a campus network. If the Chat screen can't reach the
> backend, use a **phone hotspot**: connect the Mac to the iPhone's hotspot, re-read
> `ipconfig getifaddr en0`, and use that IP. Home Wi-Fi also works.

## 3. Sign the app with your Apple ID

In Xcode:

1. Select the **Sage** target → **Signing & Capabilities** tab.
2. Tick **Automatically manage signing**.
3. **Team:** pick your Apple ID. If none is listed: **Add an Account…**, sign in with
   a free Apple ID, then select the resulting "(Personal Team)".
4. If you see "bundle identifier is not available", change the **Bundle Identifier**
   to something unique, e.g. `com.yourname.sage` (also editable in `project.yml`).

## 4. Connect the iPhone and run

1. Plug the iPhone into the Mac. Unlock it and tap **Trust This Computer** if asked.
2. Enable **Developer Mode** on the phone if prompted:
   **Settings → Privacy & Security → Developer Mode → On**, then reboot.
3. In Xcode's run-destination dropdown (top bar), pick your iPhone (not a simulator).
4. Press **⌘R**.

## 5. Trust the developer certificate on the phone

The first launch shows "Untrusted Developer". On the iPhone:

**Settings → General → VPN & Device Management → [your Apple ID] → Trust**

Re-launch the app (tap its icon, or ⌘R again).

## 6. Run the backend so Chat works

> ⚠️ **Port 5000 is taken on macOS by AirPlay Receiver** (the `ControlCenter`
> process). Either disable it (System Settings → General → AirDrop & Handoff →
> AirPlay Receiver → Off) or just run the backend on **port 5001**, as shown below.
> If you use 5001, set `SAGE_BASE_URL: "http://<mac-lan-ip>:5001"` in `project.yml`
> (Step 2) and regenerate.

On the Mac, on the same network:

```bash
cd backend
source .venv/bin/activate
cp .env.example .env            # set HF_API_TOKEN
PORT=5001 python app.py         # binds 0.0.0.0:5001 — reachable over the LAN
```

Sanity-check from the Mac:
```bash
curl http://127.0.0.1:5001/health          # local
curl http://<mac-lan-ip>:5001/health        # the address the phone uses
```
Both should return `"hf_token_configured": true` once your `.env` has a token. If the
second fails, your firewall or network is blocking it — see the hotspot note above,
and allow incoming connections for Python if macOS prompts.

---

## Demo script (on the phone)

1. **Chat tab** — the top card shows a real physiological signal seeded from
   `SignalStore`. Type a message; Sage replies, and the request carries
   `signal_context` so Sage can gently reference the trigger.
2. **Crisis path** — send "I want to die". You get the dark hotline bubble; the
   backend logs `[crisis]` and makes no model call.
3. **Offline grace** — stop the backend, send a message: a friendly error bubble,
   no crash.
4. **Insights tab** — "Signals this week" is the real ranked trigger report from
   `SignalStore` (no backend needed).

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| "Untrusted Developer" | Step 5 — trust the cert in Settings. |
| App won't install, "device not registered" | Free teams auto-register on first run; just retry ⌘R. |
| App opens but Chat errors | Backend not running, or phone can't reach the Mac's IP (Step 2 / hotspot). |
| "Bundle identifier is not available" | Change it to `com.yourname.sage`. |
| App disappears / won't launch after a week | Free provisioning expired (7 days). Re-run from Xcode. |
| Developer Mode toggle missing | Connect to Xcode once; it appears after the first install attempt. |
