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

# --- LLM provider selection ----------------------------------------------
#
# The backend talks to any OpenAI-compatible /chat/completions endpoint. By
# default it targets a LOCAL Ollama server, which needs no token and no
# internet — ideal for development and offline demos. Point these at Hugging
# Face's router (or any other provider) by setting the env vars below.
#
#   LLM_PROVIDER   : "ollama" (default) or "hf"
#   LLM_API_BASE   : full chat-completions URL
#   LLM_MODEL      : model id the provider understands
#   LLM_API_TOKEN  : bearer token (not needed for local Ollama)
#
# Legacy HF_* env vars are still honored as fallbacks so existing .env files
# keep working.

LLM_PROVIDER = os.getenv("LLM_PROVIDER", "ollama").strip().lower()

# Token: prefer LLM_API_TOKEN, fall back to the legacy HF_API_TOKEN.
LLM_API_TOKEN = os.getenv("LLM_API_TOKEN") or os.getenv("HF_API_TOKEN")

if LLM_PROVIDER == "hf":
    _default_base = "https://router.huggingface.co/v1/chat/completions"
    _default_model = "meta-llama/Llama-3.1-8B-Instruct"
else:  # ollama (local) is the default
    _default_base = "http://localhost:11434/v1/chat/completions"
    _default_model = "llama3.2:3b"

LLM_API_BASE = os.getenv("LLM_API_BASE", _default_base)
LLM_MODEL = os.getenv("LLM_MODEL") or os.getenv("HF_MODEL") or _default_model

# Local providers (Ollama) don't require authentication.
LLM_REQUIRES_TOKEN = LLM_PROVIDER == "hf"

# --- Backwards-compatible aliases -----------------------------------------
# Older code paths / health checks reference these names.
HF_API_TOKEN = LLM_API_TOKEN
HF_MODEL = LLM_MODEL

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

# --- LLM request handling -------------------------------------------------

# Alias kept for existing imports in chat_service.
HF_API_BASE = LLM_API_BASE

# Per-request timeout (seconds) for the model call. Local models can be slow to
# warm up on first use, so this is generous.
HF_REQUEST_TIMEOUT = int(os.getenv("LLM_REQUEST_TIMEOUT", "120"))

# When a hosted provider returns 503 (model loading), wait this long then retry.
HF_RETRY_DELAY_SECONDS = 4


def is_hf_token_configured() -> bool:
    """True when the selected provider is ready to serve requests.

    For local providers (Ollama) no token is needed, so this is always True.
    For hosted providers (HF) a non-empty token must be present.
    """
    if not LLM_REQUIRES_TOKEN:
        return True
    return bool(LLM_API_TOKEN and LLM_API_TOKEN.strip())
