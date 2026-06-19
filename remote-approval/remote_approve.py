"""
Remote Approval — Phone-based approval for long-running LLM/automation tasks.

Supports two backends:
  - Telegram Bot (free, interactive Approve/Deny buttons)
  - Pushover     (paid, reliable push with emergency priority)

Usage:
    from remote_approve import RemoteApproval

    ra = RemoteApproval()
    approved = ra.ask(
        title="Deep Data Detective",
        message="API cost has reached $3.42. Continue?",
        timeout=300,
    )
    if approved:
        print("User approved, continuing...")
"""
import time
import json
from pathlib import Path
from dataclasses import dataclass
from typing import Optional

import requests

CONFIG_FILE = Path.home() / ".remote_approval.json"

# ---------------------------------------------------------------------------
# One-time setup wizard
# ---------------------------------------------------------------------------

def setup_wizard():
    """Interactive setup — run once. Supports Telegram and Pushover."""
    print("""
╔══════════════════════════════════════════╗
║       📱 Remote Approval Setup          ║
╠══════════════════════════════════════════╣
║  Choose notification backend:           ║
║                                         ║
║  [1] Telegram Bot (free, 2-min setup)   ║
║  [2] Pushover     ($5, reliable push)   ║
╚══════════════════════════════════════════╝
""")
    choice = input("Enter 1 or 2: ").strip()

    if choice == "1":
        _setup_telegram()
    elif choice == "2":
        _setup_pushover()
    else:
        print("❌ Invalid choice. Run again.")


def _setup_telegram():
    print("""
╔══════════════════════════════════════════╗
║     📱 Telegram Bot Setup               ║
╠══════════════════════════════════════════╣
║  1. Open Telegram on your phone         ║
║  2. Search for @BotFather               ║
║  3. Send: /newbot                       ║
║  4. Choose a name (e.g. M5 Approvals)   ║
║  5. Choose a username (e.g. m5_bot)     ║
║  6. Copy the token BotFather gives you  ║
║  7. Paste it below                      ║
╚══════════════════════════════════════════╝
""")
    token = input("Bot token: ").strip()
    if not token:
        print("❌ No token provided.")
        return

    print("\n📱 Now send any message to your bot in Telegram (e.g. 'hello').")
    print("   Waiting for detection...")

    for _ in range(30):
        try:
            resp = requests.get(
                f"https://api.telegram.org/bot{token}/getUpdates", timeout=5
            )
            data = resp.json()
            if data.get("ok") and data["result"]:
                chat_id = data["result"][-1]["message"]["chat"]["id"]
                username = data["result"][-1]["message"]["chat"].get("username", "you")
                break
        except Exception:
            pass
        time.sleep(2)
    else:
        print("❌ Couldn't detect a message. Check that you sent one to the bot.")
        return

    config = {"backend": "telegram", "token": token, "chat_id": chat_id}
    CONFIG_FILE.write_text(json.dumps(config, indent=2))
    print(f"\n✅ Connected to @{username}!")

    requests.post(
        f"https://api.telegram.org/bot{token}/sendMessage",
        json={
            "chat_id": chat_id,
            "text": "✅ *Remote Approval is ready!*\n\nYou'll get pings here when your M5 needs you.",
            "parse_mode": "Markdown",
        },
    )
    print("   Test notification sent — check your phone!\n")


def _setup_pushover():
    print("""
╔══════════════════════════════════════════╗
║     📱 Pushover Setup                   ║
╠══════════════════════════════════════════╣
║  1. Go to https://pushover.net          ║
║  2. Log in & note your User Key         ║
║     (shown on your dashboard)           ║
║  3. Scroll down to 'Your Applications'  ║
║  4. Click 'Create an Application'       ║
║  5. Name it 'M5 Approvals'              ║
║  6. Copy the API Token/Key              ║
║  7. Paste both below                    ║
╚══════════════════════════════════════════╝
""")
    user_key = input("User Key: ").strip()
    api_token = input("API Token: ").strip()

    if not user_key or not api_token:
        print("❌ Both fields are required.")
        return

    config = {"backend": "pushover", "user_key": user_key, "api_token": api_token}
    CONFIG_FILE.write_text(json.dumps(config, indent=2))

    # Send test notification
    resp = requests.post("https://api.pushover.net/1/messages.json", data={
        "token": api_token,
        "user": user_key,
        "title": "✅ M5 Approvals Ready",
        "message": "You'll now get priority alerts when your M5 needs approval.",
        "priority": 0,
    })
    if resp.json().get("status") == 1:
        print("\n✅ Pushover connected! Test notification sent — check your phone!\n")
    else:
        print(f"\n❌ Pushover error: {resp.json()}\n")


# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

@dataclass
class AskResult:
    approved: bool
    response: str  # "approved", "denied", or "timeout"


# ---------------------------------------------------------------------------
# Telegram Backend
# ---------------------------------------------------------------------------

class _TelegramBackend:
    def __init__(self, token: str, chat_id: int):
        self.token = token
        self.chat_id = chat_id
        self.base_url = f"https://api.telegram.org/bot{token}"
        self._last_update_id = 0

    def _send(self, text: str, keyboard: Optional[list] = None) -> int:
        payload = {"chat_id": self.chat_id, "text": text, "parse_mode": "Markdown"}
        if keyboard:
            payload["reply_markup"] = json.dumps({"inline_keyboard": keyboard})
        resp = requests.post(f"{self.base_url}/sendMessage", json=payload, timeout=10)
        data = resp.json()
        if not data.get("ok"):
            raise RuntimeError(f"Telegram error: {data.get('description')}")
        return data["result"]["message_id"]

    def _remove_keyboard(self, msg_id: int, final_text: str):
        requests.post(
            f"{self.base_url}/editMessageText",
            json={"chat_id": self.chat_id, "message_id": msg_id,
                  "text": final_text, "parse_mode": "Markdown"},
            timeout=10,
        )

    def notify(self, title: str, message: str, emoji: str = "ℹ️"):
        self._send(f"{emoji} *{title}*\n\n{message}")

    def ask(self, title: str, message: str,
            approve_label: str = "✅ Approve", deny_label: str = "❌ Deny",
            timeout: int = 600, emoji: str = "🔐") -> AskResult:

        text = f"{emoji} *{title}*\n\n{message}"
        keyboard = [[
            {"text": approve_label, "callback_data": "approve"},
            {"text": deny_label, "callback_data": "deny"},
        ]]

        msg_id = self._send(text, keyboard)
        print(f"📱 Approval request sent via Telegram (waiting {timeout}s)...")

        deadline = time.time() + (timeout if timeout > 0 else float("inf"))

        while time.time() < deadline:
            try:
                params = {
                    "offset": self._last_update_id + 1,
                    "timeout": min(30, max(1, int(deadline - time.time()))),
                }
                resp = requests.get(f"{self.base_url}/getUpdates", params=params, timeout=35)
                data = resp.json()
                if data.get("ok") and data["result"]:
                    for update in data["result"]:
                        self._last_update_id = update["update_id"]
                        cb = update.get("callback_query")
                        if cb and cb["message"]["message_id"] == msg_id:
                            choice = cb["data"]
                            from_user = cb["from"].get("first_name", "Someone")

                            if choice == "approve":
                                result = AskResult(approved=True, response="approved")
                                self._remove_keyboard(msg_id,
                                    f"{emoji} *{title}*\n\n{message}\n\n✅ Approved by {from_user}")
                            else:
                                result = AskResult(approved=False, response="denied")
                                self._remove_keyboard(msg_id,
                                    f"{emoji} *{title}*\n\n{message}\n\n❌ Denied by {from_user}")

                            requests.post(
                                f"{self.base_url}/answerCallbackQuery",
                                json={"callback_query_id": cb["id"]}, timeout=5,
                            )
                            return result
            except Exception as e:
                print(f"   ⚠️ Poll error: {e}")
                time.sleep(2)

        self._remove_keyboard(msg_id, f"{emoji} *{title}*\n\n{message}\n\n⏰ Timed out")
        return AskResult(approved=False, response="timeout")


# ---------------------------------------------------------------------------
# Pushover Backend
# ---------------------------------------------------------------------------

class _PushoverBackend:
    def __init__(self, user_key: str, api_token: str):
        self.user_key = user_key
        self.api_token = api_token
        self.push_url = "https://api.pushover.net/1/messages.json"
        self.receipt_url = "https://api.pushover.net/1/receipts"

    def _send(self, title: str, message: str, priority: int = 0,
              expire: int = 600, retry: int = 30) -> Optional[str]:
        """Send a Pushover message. Returns receipt ID for priority=2 (emergency)."""
        data = {
            "token": self.api_token,
            "user": self.user_key,
            "title": title,
            "message": message,
            "priority": priority,
        }
        if priority == 2:
            data["expire"] = expire
            data["retry"] = retry

        resp = requests.post(self.push_url, data=data, timeout=10)
        result = resp.json()
        if result.get("status") != 1:
            raise RuntimeError(f"Pushover error: {result}")
        return result.get("receipt")

    def _poll_receipt(self, receipt: str, timeout: int) -> bool:
        """Poll Pushover receipt until acknowledged or expired. Returns True if acked."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            resp = requests.get(
                f"{self.receipt_url}/{receipt}.json",
                params={"token": self.api_token},
                timeout=10,
            )
            data = resp.json()
            if data.get("status") != 1:
                time.sleep(3)
                continue
            if data.get("acknowledged") == 1:
                return True
            if data.get("expired") == 1:
                return False
            time.sleep(3)
        return False

    def notify(self, title: str, message: str, emoji: str = "ℹ️"):
        full_title = f"{emoji} {title}"
        self._send(full_title, message, priority=0)
        print(f"📱 Notification sent via Pushover: {title}")

    def ask(self, title: str, message: str,
            approve_label: str = "Approve", deny_label: str = "Deny",
            timeout: int = 600, emoji: str = "🔐") -> AskResult:
        """
        Pushover approval: sends emergency-priority (priority=2) notification.
        The user must tap & hold → Acknowledge on their phone to approve.
        If they do nothing, the notification expires = denied.
        """
        full_title = f"{emoji} {title}"
        full_message = (
            f"{message}\n\n"
            f"⏰ Expires in {timeout // 60} min.\n"
            f"Tap & hold the notification → Acknowledge to approve.\n"
            f"Do nothing = deny."
        )

        receipt = self._send(full_title, full_message, priority=2,
                             expire=timeout, retry=min(60, timeout // 4))
        if not receipt:
            return AskResult(approved=False, response="error")

        print(f"📱 Emergency alert sent via Pushover! (expires in {timeout}s)")
        print(f"   Tap & hold the notification on your phone → Acknowledge to approve.")

        acked = self._poll_receipt(receipt, timeout)
        if acked:
            # Cancel the emergency (stop the repeated alerts)
            requests.post(
                f"{self.receipt_url}/{receipt}/cancel.json",
                data={"token": self.api_token}, timeout=10,
            )
            return AskResult(approved=True, response="approved")
        else:
            return AskResult(approved=False, response="denied")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

class RemoteApproval:
    """Send approval requests to your phone. Auto-detects Telegram or Pushover."""

    def __init__(self, config_path: Optional[Path] = None):
        cfg_file = config_path or CONFIG_FILE
        if not cfg_file.exists():
            raise FileNotFoundError(
                f"Config not found at {cfg_file}. Run setup_wizard() first."
            )
        cfg = json.loads(cfg_file.read_text())
        backend = cfg["backend"]

        if backend == "telegram":
            self._backend = _TelegramBackend(cfg["token"], cfg["chat_id"])
        elif backend == "pushover":
            self._backend = _PushoverBackend(cfg["user_key"], cfg["api_token"])
        else:
            raise ValueError(f"Unknown backend: {backend}")

        self.backend_name = backend

    def notify(self, title: str, message: str, emoji: str = "ℹ️"):
        """Send a one-way notification (no response needed)."""
        self._backend.notify(title, message, emoji)

    def ask(self, title: str, message: str,
            approve_label: str = "✅ Approve", deny_label: str = "❌ Deny",
            timeout: int = 600, emoji: str = "🔐") -> AskResult:
        """
        Send an approval request to your phone and wait for a response.

        Telegram:  Shows Approve/Deny interactive buttons. Tap one.
        Pushover:  Emergency alert with repeated notifications.
                   Tap & hold → Acknowledge = approve.
                   Do nothing = deny (notification expires).

        Returns AskResult(approved=bool, response=str).
        """
        return self._backend.ask(title, message, approve_label, deny_label, timeout, emoji)
