"""Sage backend — Flask app and route definitions.

Endpoints:
  POST /chat     — journaling chatbot; runs crisis detection, then the model
  GET  /health   — readiness probe for demos (confirms token + model config)

Run locally:
  pip install -r requirements.txt
  cp .env.example .env          # then fill in HF_API_TOKEN
  python app.py

------------------------------------------------------------------------------
DEMO / VALIDATION CHECKLIST
  1. GET /health should report hf_token_configured: true before demoing.
  2. Send a message matching a crisis pattern (e.g. "I want to die") — the
     response must have "crisis": true and the server log must show the
     short-circuit ("[crisis] ...") WITHOUT a Hugging Face call.
  3. Stop the backend and send a message from the app — the app should show a
     graceful error bubble, not crash.
  4. Test from a physical device using the machine's LAN IP, not 127.0.0.1.
------------------------------------------------------------------------------
"""

import logging

from flask import Flask, jsonify, request
from flask_cors import CORS

import config
import chat_service
from safety import CRISIS_RESPONSE, is_crisis_message

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("sage")

app = Flask(__name__)

# Broad CORS is fine for a hackathon so the Simulator / device / web client can
# all reach the API freely.
# NOTE: For any real deployment, restrict this to specific trusted origins,
# e.g. CORS(app, origins=["https://app.sage.example"]).
CORS(app)


@app.get("/health")
def health():
    """Readiness probe. Confirms token presence and active model."""
    return jsonify(
        {
            "ok": True,
            "hf_token_configured": config.is_hf_token_configured(),
            "model": config.HF_MODEL,
        }
    )


@app.post("/chat")
def chat():
    """Handle a chat turn: validate -> crisis check -> model."""
    # Reject non-JSON / malformed bodies cleanly.
    data = request.get_json(silent=True) or {}

    message = data.get("message")
    history = data.get("history", [])

    # --- Validation -------------------------------------------------------
    if not isinstance(message, str) or not message.strip():
        return jsonify({"error": "message is required"}), 400

    message = message.strip()
    # Cap length to avoid oversized prompts.
    if len(message) > config.MAX_MESSAGE_CHARS:
        message = message[: config.MAX_MESSAGE_CHARS]

    if not isinstance(history, list):
        history = []

    # --- Crisis short-circuit (BEFORE any model call) ---------------------
    if is_crisis_message(message):
        logger.info("[crisis] matched crisis pattern; returning fixed response, no HF call")
        return jsonify(
            {
                "reply": CRISIS_RESPONSE,
                "crisis": True,
                "model": "safety-rule",
            }
        )

    # --- Configuration guard ---------------------------------------------
    if not config.is_hf_token_configured():
        logger.error("HF_API_TOKEN is not configured")
        return jsonify({"error": "server misconfigured"}), 500

    # --- Model call -------------------------------------------------------
    try:
        reply = chat_service.generate_reply(message, history)
    except chat_service.ChatServiceError as exc:
        logger.warning("chat_service error: %s", exc)
        return jsonify({"error": str(exc)}), 502

    return jsonify(
        {
            "reply": reply,
            "crisis": False,
            "model": config.HF_MODEL,
        }
    )


if __name__ == "__main__":
    # host 0.0.0.0 so a physical device on the same LAN can reach the server.
    app.run(host="0.0.0.0", port=config.PORT, debug=True)
