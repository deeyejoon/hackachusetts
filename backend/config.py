"""Environment-driven configuration for the Sage backend.

All runtime configuration is sourced from environment variables, loaded from a
local `.env` file (see `.env.example`) via python-dotenv. Secrets such as the
Hugging Face token are never hardcoded.
"""

import os

from dotenv import load_dotenv

# Load variables from a local .env file if present. In production the process
# environment is expected to be populated by the platform instead.
load_dotenv()

# Required. When missing, the /chat route responds with 500 "server misconfigured".
HF_API_TOKEN = os.getenv("HF_API_TOKEN")

# Optional, with a sensible default.
HF_MODEL = os.getenv("HF_MODEL", "mistralai/Mistral-7B-Instruct-v0.2")

# Optional. Cast to int defensively so a bad value doesn't crash startup silently.
try:
    PORT = int(os.getenv("PORT", "5000"))
except ValueError:
    PORT = 5000

# --- Request handling limits ---------------------------------------------

# Hard cap on an incoming user message, in characters. Longer messages are
# truncated before being used to build the model prompt.
MAX_MESSAGE_CHARS = 2000

# Only the most recent N turns of history are kept when building the prompt,
# to bound payload size and token usage.
MAX_HISTORY_TURNS = 6

# --- Hugging Face Inference API ------------------------------------------

HF_API_BASE = "https://api-inference.huggingface.co/models"

# Per-request timeout (seconds) for the Hugging Face call.
HF_REQUEST_TIMEOUT = 30

# When HF returns 503 (model loading), wait this long then retry once.
HF_RETRY_DELAY_SECONDS = 4


def is_hf_token_configured() -> bool:
    """True when a non-empty Hugging Face token is available."""
    return bool(HF_API_TOKEN and HF_API_TOKEN.strip())
