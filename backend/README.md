# Sage Backend

Flask API powering Sage's journaling chatbot (Screen 1). Real Hugging Face
integration with crisis-language safety and graceful error handling.

## Setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env            # then fill in HF_API_TOKEN
python app.py
```

The server listens on `0.0.0.0:5000` so a physical device on the same Wi-Fi can
reach it. Find your machine's LAN IP with `ipconfig getifaddr en0` (macOS) and
point the iOS app at `http://<that-ip>:5000`.

## Endpoints

### `GET /health`
```json
{ "ok": true, "hf_token_configured": true, "model": "mistralai/Mistral-7B-Instruct-v0.2" }
```

### `POST /chat`
Request:
```json
{ "message": "I've been feeling off all week", "history": [ { "role": "user", "content": "hi" }, { "role": "assistant", "content": "Hey, I'm here." } ] }
```

Optional `signal_context` (backward-compatible — omit it and nothing changes). When
present, a short non-clinical note about a recent physiological reaction is folded
into the system prompt so Sage can gently reference it. See `docs/INTEGRATION.md`,
Contract 3.
```json
{ "message": "...", "history": [], "signal_context": { "keywords": ["whiskey", "bar"], "app_name": "instagram", "bpm_delta": 22 } }
```
Response:
```json
{ "reply": "...", "crisis": false, "model": "mistralai/Mistral-7B-Instruct-v0.2" }
```

Errors: `400` empty message, `500` token not configured, `502` model failure.

## Safety

`safety.py` runs a case-insensitive crisis check **before** any model call. On a
match, the server returns a fixed hotline response with `"crisis": true` and
`"model": "safety-rule"` — it never contacts Hugging Face. Verify this in the
server logs (look for `[crisis]`).

## Demo checklist

1. `GET /health` reports `hf_token_configured: true`.
2. A crisis-pattern message returns `crisis: true` and logs `[crisis]` with no HF call.
3. With the backend stopped, the app shows a graceful error bubble (no crash).
4. Tested from a physical device via LAN IP, not just the Simulator on 127.0.0.1.

> CORS is wide open (`CORS(app)`) for the hackathon. Restrict to trusted origins
> before any real deployment.
