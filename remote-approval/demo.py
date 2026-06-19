#!/usr/bin/env python3
"""
Demo: Remote Approval in action.
Shows three use cases:
1. sudo password — phone approves, script runs the sudo command
2. API cost threshold — DeepSeek bills mounting, ask to continue
3. Critical decision — LLM wants to delete a file, needs human OK

Run: python3 demo.py
(requires setup_wizard() run first)
"""
import subprocess
import sys
import time
from remote_approve import RemoteApproval, setup_wizard, CONFIG_FILE

# ── Check if configured ────────────────────────────────────────────────
if not CONFIG_FILE.exists():
    print("🔧 First-time setup needed!\n")
    setup_wizard()
    if not CONFIG_FILE.exists():
        sys.exit(1)
    print("\n" + "=" * 50 + "\n")

ra = RemoteApproval()


# ══════════════════════════════════════════════════════════════════════════
# DEMO 1: Sudo password approval
# ══════════════════════════════════════════════════════════════════════════
print("─" * 50)
print("📟 DEMO 1: Sudo Approval")
print("─" * 50)

result = ra.ask(
    title="🖥️ Sudo Required",
    message="A task needs to run with sudo privileges:\n\n"
            "`sudo softwareupdate --list`\n\n"
            "Approve to run it remotely?",
    timeout=60,
)

if result.approved:
    print("✅ Approved! Running sudo command...")
    # In real use, you'd use subprocess or pexpect with the password
    # For demo, we just simulate:
    time.sleep(1)
    print("   Command would execute here.")
else:
    print(f"❌ Not approved ({result.response}). Skipping.")


# ══════════════════════════════════════════════════════════════════════════
# DEMO 2: API cost threshold
# ══════════════════════════════════════════════════════════════════════════
print("\n─" * 50)
print("📟 DEMO 2: API Cost Threshold")
print("─" * 50)

simulated_cost = 3.42
budget = 10.00

result = ra.ask(
    title="💰 DeepSeek Cost Alert",
    message=f"Deep Data Detective has used *${simulated_cost:.2f}* so far.\n"
            f"Your budget is *${budget:.2f}*.\n\n"
            f"Estimated remaining cost: ~$2.00.\n\n"
            f"Continue the analysis?",
    timeout=120,
    emoji="💰",
)

if result.approved:
    print("✅ Continuing analysis...")
else:
    print("❌ Analysis halted — budget protected.")


# ══════════════════════════════════════════════════════════════════════════
# DEMO 3: Critical decision (file deletion)
# ══════════════════════════════════════════════════════════════════════════
print("\n─" * 50)
print("📟 DEMO 3: Critical Decision")
print("─" * 50)

result = ra.ask(
    title="⚠️ Destructive Action",
    message="The automation wants to:\n\n"
            "*Delete* `/tmp/large_dataset.csv` (2.3 GB)\n\n"
            "This file is not in your backup set.\n"
            "Proceed?",
    approve_label="🗑️ Delete it",
    deny_label="📁 Keep it",
    timeout=120,
    emoji="⚠️",
)

if result.approved:
    print("✅ File would be deleted.")
else:
    print("📁 File kept safe.")

# ── One-way notification ────────────────────────────────────────────────
print("\n─" * 50)
print("📟 Bonus: One-way notification")
print("─" * 50)
ra.notify(
    title="✅ Demo Complete",
    message="All three approval scenarios tested.\nYour M5 remote approval system is ready!",
    emoji="🎉",
)
print("📱 Check your phone — final notification sent!\n")
