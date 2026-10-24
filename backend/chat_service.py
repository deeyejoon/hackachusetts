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


def build_prompt(message, history):
    """Build a Mistral-Instruct chat-template prompt.

    The template wraps each exchange as:
        <s>[INST] {system}\n\n{user} [/INST] {assistant} </s>
    with the system prompt folded into the FIRST user turn only, and the final
    (new) user turn left open for the model to complete:
        ...<s>[INST] {new_user} [/INST]

    Args:
        message: The new user message (already validated/truncated).
        history: Prior turns, oldest first, each {"role", "content"}.

    Returns:
        The assembled prompt string.
    """
    turns = _trim_history(history)
    # Append the new user message as the final, unanswered turn.
    turns = turns + [{"role": "user", "content": message}]

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
            user_content = f"{SYSTEM_PROMPT}\n\n{user_content}"
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


def generate_reply(message, history):
    """Generate a model reply for the given message and history.

    Handles HTTP 503 (model loading) by retrying once after a short delay.

    Args:
        message: The new user message (validated/truncated upstream).
        history: Prior turns, oldest first.

    Returns:
        The model's reply text, stripped.

    Raises:
        ChatServiceError: on timeout, repeated 503, non-200, or empty output.
    """
    prompt = build_prompt(message, history)

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
