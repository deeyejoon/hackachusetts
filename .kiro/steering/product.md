# Product

**Kiro** (the iOS app is branded **Sage** in code) is a mental-health app for
Hackachusetts 2026, built by a team of three. It helps users recognize emotional
patterns, spot digital content that physically affects them, and connect with support.

## What it does

- **Personalized content monitoring** — correlates physiological signals (heart rate,
  HRV) from a WHOOP band with the content a user was exposed to, to surface *unusual*
  reactions. It never claims content is "harmful"; meaning comes from correlated
  keywords and the user's own labeling.
- **AI journaling companion (Sage)** — a warm, non-clinical chatbot. Not a therapist,
  never diagnoses. A crisis-language safety net runs before any model call.
- **Insights** — a weekly report of the keywords a user had unusual reactions to.
- **Connect / Community** — professional-care matching and peer support (mocked for now).

## Branding note

The README calls the product **Kiro**; all iOS and backend code calls it **Sage**.
Treat them as the same product until the team picks one name. Don't rename either
side unprompted.

## Implemented vs. mocked (keep this honest)

| Area | Status |
|------|--------|
| Backend `/chat` + Hugging Face model | Real (needs `HF_API_TOKEN`) |
| Backend crisis safety | Real |
| iOS Chat screen | Real, talks to backend |
| iOS Insights "Signals this week" | Real (from `SignalStore`); emotions/pattern cards illustrative |
| iOS Connect / Community | Mocked placeholders |
| PulseCore engine + weekly report | Real, tested, runs headless |
| PulseKit (WHOOP BLE / OCR / notifications) | Real code, on-device only, not yet linked into the app |
| Live WHOOP hardware | Not yet wired; app runs on `SignalStore` sample data |

## Principles

- Non-judgmental, supportive tone everywhere user-facing.
- Physiological signals describe "unusual for you," not "bad."
- Privacy first: data stays on device unless the user explicitly shares it.
- The app must stay demoable without a WHOOP band (mock/sample data paths exist).
