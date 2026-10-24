# Sage

### Personalized mental health support, powered by AI and physiological insights.

Sage is a mental health application designed to help users recognize emotional patterns, identify potentially harmful digital content, and connect with the support they need.

By combining AI-powered content analysis, wearable health data, and personalized recommendations, Sage aims to create a healthier digital environment tailored to each individual.

## The Problem

Social media algorithms optimize for engagement, often without considering how content affects a user's mental well-being.

Content that seems harmless to one person may be emotionally triggering to another. For example, someone recovering from alcohol addiction might encounter advertisements for alcoholic beverages, potentially making recovery more difficult.

At the same time, many people struggle to seek professional mental health support due to fear, uncertainty, or difficulty finding accessible care.

## Our Solution

Sage aims to bridge the gap between digital behavior, physiological responses, and mental health support.

### 1. Personalized Content Monitoring

Sage aims to integrate with WHOOP wearable devices to analyze physiological signals such as:

- Heart rate
- Heart rate variability (HRV)
- Physiological stress indicators

By correlating these signals with digital content exposure, Sage can help identify potential emotional triggers.

Because physiological responses alone cannot determine emotional distress, user feedback will help validate these associations.

### 2. AI-Powered Content Filtering

Sage aims to recognize potentially triggering content and develop personalized filtering preferences.

For example:

1. A user encounters an alcohol-related advertisement.
2. Their wearable detects an elevated physiological response.
3. Sage identifies a possible correlation between the content and physiological changes.
4. The user confirms whether the content was distressing.
5. Sage learns from this feedback and helps reduce exposure to similar content.

The filtering implementation will depend on operating-system and social media platform restrictions.

### 3. AI Mental Health Companion

Sage includes a planned conversational AI assistant that helps users:

- Journal and reflect on daily experiences.
- Recognize recurring emotional patterns.
- Understand changes in their mood over time.
- Receive supportive prompts and coping suggestions.
- Explore options for professional mental health support.

The chatbot is designed to complement, not replace, licensed mental health professionals.

### 4. Connecting Users With Professional Support

Sage aims to reduce barriers to seeking mental health care by:

- Helping users discover therapists and psychiatrists.
- Exploring provider compatibility with their insurance coverage.
- Providing user-controlled summaries of emotional patterns.
- Allowing users to share selected information with professionals through explicit consent.

### 5. Community Support (Future Feature)

Sage also envisions connecting users with trained or appropriately moderated peer supporters who have experienced similar challenges.

The goal is to provide a supportive community while maintaining privacy and appropriate safety boundaries.

## Privacy and Safety

Mental health and physiological information are sensitive. Sage's design prioritizes:

- Explicit consent for collecting and sharing personal information.
- User control over data and filtering preferences.
- Secure handling of sensitive information.
- Transparency about AI-generated insights and their limitations.
- Avoiding medical diagnoses based solely on physiological data.

## Hackathon Goals

Our initial prototype will focus on demonstrating:

- Wearable data integration or representative physiological data.
- AI-powered content classification.
- Identification of potential correlations between content and physiological responses.
- User-confirmed trigger preferences.
- A basic mental health companion interface.

## Repository layout

| Path | What it is |
|------|------------|
| `Sources/`, `Package.swift` | **PulseCore** — the physiological engine (Swift Package). See `PulseCore.md`. |
| `ios/` | **Sage** — the SwiftUI app (4 screens). See `ios/README.md`. |
| `backend/` | **Sage backend** — Flask + Hugging Face chatbot. See `backend/README.md`. |
| `docs/INTEGRATION.md` | **How the three slices connect.** Read this before cross-slice work. |

The three slices are wired together: the engine's spikes flow into a shared
`SignalStore` that drives the Insights screen and the Chat signal card, and the app
sends that signal context to the backend so the chatbot can reference it. Full
contracts and the one-time Xcode/SPM linking step are in `docs/INTEGRATION.md`.

## Running the app

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen),
so `Sage.xcodeproj` is **not** committed (no `.pbxproj` merge conflicts). After
cloning or pulling, regenerate it:

```bash
brew install xcodegen      # one-time
xcodegen generate          # creates Sage.xcodeproj from project.yml
open Sage.xcodeproj        # pick an iPhone simulator, press ⌘R
```

Run `xcodegen generate` again any time `project.yml` changes or someone adds files
to `ios/`.

**Installing on a physical iPhone (no App Store):** see `docs/DEVICE_INSTALL.md` —
free development install over USB, including LAN-IP setup and signing.

**Backend (for the Chat screen):**

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # set HF_API_TOKEN
# NOTE: macOS AirPlay Receiver squats on port 5000 — use 5001 (or disable AirPlay).
PORT=5001 python app.py     # GET /health should show hf_token_configured: true
```

**Engine only (no Xcode, no hardware):**

```bash
swift test        # 13 unit tests
swift run PulseDemo   # full spike-detection + weekly-report simulation
```

See `docs/INTEGRATION.md` for how everything connects and `ios/README.md` /
`backend/README.md` for per-slice detail.

## Team

Developed by a team of three students for Hackachusetts 2026.

## Project Status

**In Development — Hackachusetts 2026**

Sage is a hackathon prototype. Features described above represent our product vision and development goals and may not all be available in the initial version.

---

**Our Mission:** Make digital spaces more mindful of individual mental health needs while making professional support easier to access.
