# 📱 Remote Approval

> **Phone-based approval for long-running LLM & automation tasks.**  
> Your laptop pings your phone when it needs a sudo password, budget approval, or a critical decision. Tap Approve or Deny — the script continues.

---

## How it works

```
┌──────────┐     ┌──────────────┐     ┌──────────┐
│  Python   │────▶│  Telegram    │────▶│  Your    │
│  script   │     │  Bot API     │     │  Phone   │
│  (M5)     │◀────│  (polling)   │◀────│  (tap)   │
└──────────┘     └──────────────┘     └──────────┘
```

1. Your script hits a decision point (sudo needed, cost threshold, destructive action)
2. It sends a message to your phone via Telegram with **Approve / Deny** buttons
3. The script blocks and polls for your tap
4. You tap on your phone — script continues or aborts

No servers, no webhooks, no port forwarding. Just a free Telegram bot.

---

## Quickstart

### 1. Install

```bash
cd remote-approval
pip install -r requirements.txt
```

### 2. Create a Telegram bot (one-time, 2 minutes)

1. Open Telegram on your phone
2. Search for **@BotFather** and start a chat
3. Send `/newbot`
4. Choose a name: `M5 Approvals`
5. Choose a username: `my_m5_approvals_bot`
6. **Copy the token** BotFather gives you

### 3. Run the setup wizard

```bash
python3 -c "from remote_approve import setup_wizard; setup_wizard()"
```

Paste your token, then send any message to your bot in Telegram. The wizard auto-detects your chat ID. A test notification confirms everything works.

### 4. Use it

```python
from remote_approve import RemoteApproval

ra = RemoteApproval()

# Ask for approval — blocks until you tap
result = ra.ask(
    title="💰 API Cost Alert",
    message="DeepSeek usage hit $5.00. Continue?",
    timeout=300,
)
if result.approved:
    print("Continuing...")

# One-way notification (no response needed)
ra.notify("✅ Done", "Analysis complete!")
```

---

## Use cases

### 🖥️ Sudo password approval

```python
result = ra.ask(
    title="🖥️ Sudo Required",
    message="A task needs `sudo`:\n\n`brew update && brew upgrade`\n\nRun it?",
    timeout=120,
)
if result.approved:
    subprocess.run(["sudo", "brew", "update"])
```

### 💰 API cost threshold

```python
if estimated_cost > budget * 0.7:
    result = ra.ask(
        title="💰 Cost Warning",
        message=f"Used ${current_cost:.2f} of ${budget:.2f} budget.\nContinue?",
        timeout=300,
    )
    if not result.approved:
        sys.exit(0)
```

### ⚠️ Destructive actions

```python
result = ra.ask(
    title="⚠️ Delete Files?",
    message=f"About to delete {n} files in ./cache/\nNot in backup. Proceed?",
    approve_label="🗑️ Delete",
    deny_label="📁 Keep",
    timeout=120,
)
```

### 🔔 Completion notification

```python
ra.notify(
    title="✅ Job Done",
    message="Dataset processed: 1.2M rows in 47 minutes.\nReport: output/report.html",
)
```

---

## API

### `RemoteApproval(config_path=None)`

Loads config from `~/.remote_approval.json` by default.

### `.ask(title, message, approve_label, deny_label, timeout, emoji) → AskResult`

| Param | Default | Description |
|-------|---------|-------------|
| `title` | — | Bold header, e.g. `"API Cost Alert"` |
| `message` | — | Body text, supports Markdown |
| `approve_label` | `"✅ Approve"` | Text on approve button |
| `deny_label` | `"❌ Deny"` | Text on deny button |
| `timeout` | `600` | Seconds to wait. `0` = forever |
| `emoji` | `"🔐"` | Emoji prefix |

Returns `AskResult(approved: bool, response: str)` where `response` is `"approved"`, `"denied"`, or `"timeout"`.

### `.notify(title, message, emoji)`

One-way notification. No response needed. Returns immediately.

---

## Alternatives

Don't want to use Telegram? The pattern is the same — swap the `_send` method.

### Pushover ($5 one-time, excellent reliability)

```python
# pip install python-pushover
import pushover

def send_pushover(title, message, approve_url=None):
    pushover.init("YOUR_APP_TOKEN")
    pushover.Client("YOUR_USER_KEY").send_message(
        message, title=title,
        url=approve_url, url_title="Approve" if approve_url else None,
    )
```

| Pros | Cons |
|------|------|
| Native iOS/Android apps | $5 one-time purchase |
| Emergency priority (bypasses silent mode) | No inline buttons (URL-based actions) |
| No polling needed | Simpler interaction model |

### ntfy.sh (free, open-source, self-hostable)

```python
import requests

def send_ntfy(topic, title, message, actions=None):
    payload = {"topic": topic, "title": title, "message": message}
    if actions:
        payload["actions"] = actions  # [{"action": "view", "label": "Approve", "url": "..."}]
    requests.post("https://ntfy.sh", json=payload)
```

| Pros | Cons |
|------|------|
| Completely free & open-source | No native inline buttons (uses click actions) |
| Self-hostable (your own server) | Polling or HTTP server needed for response |
| iOS + Android apps available | Smaller user base |

**Approval flow with ntfy:** Send a notification with a click action URL pointing to a tiny Flask endpoint on your laptop. When you tap, the endpoint receives the request and the script continues.

### Slack / Discord webhook

```python
import requests

def send_slack(webhook_url, title, message):
    requests.post(webhook_url, json={
        "blocks": [
            {"type": "header", "text": {"type": "plain_text", "text": title}},
            {"type": "section", "text": {"type": "mrkdwn", "text": message}},
        ]
    })
```

| Pros | Cons |
|------|------|
| No extra setup if you use Slack/Discord | No simple Approve/Deny back-channel |
| Rich formatting, threads, channels | Requires webhook URL setup |
| Good for teams | Polling interaction API is complex |

### Apple Shortcuts + iMessage

For Apple-only setups, you can use the `shortcuts` CLI to send yourself an iMessage:

```bash
shortcuts run "Notify Me" -i "Analysis complete: report.html ready"
```

No interactive approve/deny, but useful for one-way pings without any third-party setup.

---

## Comparison

| Feature | Telegram Bot | Pushover | ntfy.sh | Slack/Discord |
|---------|:---:|:---:|:---:|:---:|
| **Cost** | Free | $5 once | Free | Free |
| **Inline buttons** | ✅ | ❌ | ➖ | ✅ (complex) |
| **Polling-based** | ✅ | ❌ (push) | ❌ (push) | ❌ (push) |
| **Self-hostable** | ❌ | ❌ | ✅ | ➖ |
| **Setup time** | 2 min | 3 min | 2 min | 5 min |
| **Reliability** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **iOS app** | ✅ | ✅ | ✅ | ✅ |
| **Android app** | ✅ | ✅ | ✅ | ✅ |

**Recommendation:** Telegram Bot is the sweet spot — free, fast setup, native Approve/Deny buttons, works great for this use case.

---

## Using with existing projects

### Deep Data Detective

Already integrated. When you run `python3 main.py data/file.csv`, it auto-detects if `~/.remote_approval.json` exists and pings your phone on start and completion.

### Any Python script

```python
try:
    from remote_approve import RemoteApproval
    ra = RemoteApproval()
except (ImportError, FileNotFoundError):
    ra = None  # gracefully degrade if not configured

# ... long task ...

if ra:
    ra.notify("✅ Done", "Task completed successfully.")
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `FileNotFoundError: ~/.remote_approval.json` | Run `setup_wizard()` first |
| No notification on phone | Check you've sent at least one message to the bot in Telegram |
| Timeout every time | Increase `timeout` or check your phone has Telegram notifications enabled |
| `ImportError: No module named 'remote_approve'` | Add the path: `sys.path.insert(0, '/path/to/remote-approval')` |

---

## Files

```
remote-approval/
├── remote_approve.py      # Core module (drop into any project)
├── demo.py                # Interactive demo of all 3 use cases
├── requirements.txt       # Only dependency: requests
├── README.md              # This file
└── ~/.remote_approval.json  # Created by setup_wizard (in home dir)
```

---

## License

MIT — use it, remix it, ship it. 📱
