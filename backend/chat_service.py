"""Chat service: prompt construction and Hugging Face Inference API calls.

This module owns everything about talking to the model:
  - building a Mistral-Instruct chat prompt from the system prompt + history
  - calling the Hugging Face Inference API with a timeout
  - handling the "model is loading" (HTTP 503) case with a single retry
  - parsing the two response shapes HF may return

Crisis handling is intentionally NOT here — callers must run
`safety.is_crisis_message` first and short-circuit before reaching this module.
"""

import time

import requests

import config

# Prepended to every conversation. Defines Sage's voice and guardrails.
SYSTEM_PROMPT = (
    "You are Sage, a warm, non-judgmental journaling companion inside a mental "
    "health app. You are NOT a therapist and you never diagnose. You reflect "
    "feelings back, ask gentle open-ended questions, and help the user process "
    "what's on their mind. Keep replies short (2-4 sentences), conversational, "
    "and never clinical. If the user seems to want professional help, gently "
    "suggest they check the Connect tab in the app."
)


class ChatServiceError(Exception):
    """Raised when the model call fails in a way the caller should surface as 502."""


def _trim_history(history):
    """Return the last MAX_HISTORY_TURNS turns, oldest first.

    Non-dict entries and entries missing role/content are dropped defensively.
    """
    if not history:
        return []

    cleaned = []
    for turn in history:
        if not isinstance(turn, dict):
            continue
        role = turn.get("role")
        content = turn.get("content")
        if role in ("user", "assistant") and isinstance(content, str) and content.strip():
            cleaned.append({"role": role, "content": content.strip()})

    return cleaned[-config.MAX_HISTORY_TURNS:]


def _signal_note(signal_context):
    """Render an optional physiological-signal note for the system prompt.

    `signal_context` is an optional dict the iOS app sends when a recent heart-rate
    spike was correlated with on-screen content. We fold a short, non-clinical note
    into the system prompt so Sage can gently acknowledge what the user physically
    reacted to — without diagnosing or calling the content harmful (same guardrail
    the PulseCore engine keeps).

    Returns an empty string when no usable context is present, so prompts for older
    clients are byte-for-byte unchanged.
    """
    if not isinstance(signal_context, dict):
        return ""

    keywords = signal_context.get("keywords")
    if not isinstance(keywords, list):
        keywords = []
    # Keep only short, clean string keywords; cap to avoid prompt bloat.
    keywords = [k.strip() for k in keywords if isinstance(k, str) and k.strip()][:6]

    app_name = signal_context.get("app_name")
    if not isinstance(app_name, str) or not app_name.strip():
        app_name = None

    bpm_delta = signal_context.get("bpm_delta")
    if not isinstance(bpm_delta, (int, float)):
        bpm_delta = None

    if not keywords and not app_name:
        return ""

    parts = []
    if keywords:
        parts.append("content about " + ", ".join(keywords))
    if app_name:
        parts.append(f"in {app_name.strip()}")
    where = " ".join(parts)

    delta_phrase = ""
    if bpm_delta:
        delta_phrase = f" (heart rate rose about {int(round(bpm_delta))} bpm above their usual)"

    return (
        f"\n\nCONTEXT (do not quote verbatim): The user recently had an unusual "
        f"physiological reaction while viewing {where}{delta_phrase}. This is an "
        f"observation, not a diagnosis, and the content is not necessarily harmful. "
        f"If it feels natural, you may gently acknowledge it and invite them to "
        f"reflect — but follow the user's lead and never insist."
    )


def build_prompt(message, history, signal_context=None):
    """Build a Mistral-Instruct chat-template prompt.

    The template wraps each exchange as:
        <s>[INST] {system}\n\n{user} [/INST] {assistant} </s>
    with the system prompt folded into the FIRST user turn only, and the final
    (new) user turn left open for the model to complete:
        ...<s>[INST] {new_user} [/INST]

    Args:
        message: The new user message (already validated/truncated).
        history: Prior turns, oldest first, each {"role", "content"}.
        signal_context: Optional dict describing a recent physiological spike +
            correlated content. When present, a short non-clinical note is folded
            into the system prompt. Omitted/None keeps prompts identical to before.

    Returns:
        The assembled prompt string.
    """
    turns = _trim_history(history)
    # Append the new user message as the final, unanswered turn.
    turns = turns + [{"role": "user", "content": message}]

    system_prompt = SYSTEM_PROMPT + _signal_note(signal_context)

    prompt = ""
    first_user = True
    i = 0
    while i < len(turns):
        turn = turns[i]
        if turn["role"] != "user":
            # Skip a leading/dangling assistant turn with no preceding user turn.
            i += 1
            continue

        user_content = turn["content"]
        if first_user:
            user_content = f"{system_prompt}\n\n{user_content}"
            first_user = False

        prompt += f"<s>[INST] {user_content} [/INST]"

        # If an assistant reply follows, close this exchange.
        if i + 1 < len(turns) and turns[i + 1]["role"] == "assistant":
            prompt += f" {turns[i + 1]['content']} </s>"
            i += 2
        else:
            # Open turn awaiting the model's completion.
            i += 1

    return prompt


def _parse_generated_text(data):
    """Extract generated text from HF's list- or dict-shaped response."""
    if isinstance(data, list) and data:
        first = data[0]
        if isinstance(first, dict):
            return first.get("generated_text", "")
    if isinstance(data, dict):
        return data.get("generated_text", "")
    return ""


def _post_to_hf(prompt):
    """Send one request to the HF Inference API and return the parsed reply.

    Returns a tuple (text, status_code, raw_json_or_none). Network/timeout
    failures raise ChatServiceError directly.
    """
    url = f"{config.HF_API_BASE}/{config.HF_MODEL}"
    headers = {
        "Authorization": f"Bearer {config.HF_API_TOKEN}",
        "Content-Type": "application/json",
    }
    payload = {
        "inputs": prompt,
        "parameters": {
            "max_new_tokens": 150,
            "temperature": 0.7,
            "return_full_text": False,
        },
    }

    try:
        resp = requests.post(
            url, headers=headers, json=payload, timeout=config.HF_REQUEST_TIMEOUT
        )
    except requests.exceptions.Timeout:
        raise ChatServiceError("The model took too long to respond. Please try again.")
    except requests.exceptions.RequestException as exc:
        raise ChatServiceError(f"Could not reach the model service: {exc}")

    return resp


def generate_reply(message, history, signal_context=None):
    """Generate a model reply for the given message and history.

    Handles HTTP 503 (model loading) by retrying once after a short delay.

    Args:
        message: The new user message (validated/truncated upstream).
        history: Prior turns, oldest first.
        signal_context: Optional physiological-signal context (see build_prompt).

    Returns:
        The model's reply text, stripped.

    Raises:
        ChatServiceError: on timeout, repeated 503, non-200, or empty output.
    """
    prompt = build_prompt(message, history, signal_context)

    resp = _post_to_hf(prompt)

    # HF returns 503 while a model is cold-starting. Retry once.
    if resp.status_code == 503:
        time.sleep(config.HF_RETRY_DELAY_SECONDS)
        resp = _post_to_hf(prompt)
        if resp.status_code == 503:
            raise ChatServiceError(
                "The model is still warming up. Please try again in a moment."
            )

    if resp.status_code != 200:
        # Surface a trimmed body for debugging without leaking too much.
        detail = resp.text[:200] if resp.text else f"HTTP {resp.status_code}"
        raise ChatServiceError(f"Model service error: {detail}")

    try:
        data = resp.json()
    except ValueError:
        raise ChatServiceError("Model returned an unreadable response.")

    text = _parse_generated_text(data).strip()
    if not text:
        raise ChatServiceError("Model returned an empty response.")

    return text
