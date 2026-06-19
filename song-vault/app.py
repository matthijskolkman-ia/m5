"""
Song Vault — Locked music catalog with authorization codes.
Max 5 unlocks per catalog.
"""
import json
import secrets
from pathlib import Path

from flask import Flask, render_template, request, jsonify, session

app = Flask(__name__)
app.secret_key = secrets.token_hex(32)

# Resolve paths relative to this script, not the CWD
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
CATALOG_FILE = DATA_DIR / "catalog.json"


def load_catalog() -> dict:
    with open(CATALOG_FILE) as f:
        return json.load(f)


def save_catalog(catalog: dict):
    with open(CATALOG_FILE, "w") as f:
        json.dump(catalog, f, indent=2)


@app.route("/")
def index():
    catalog = load_catalog()
    # Don't leak auth codes to the client
    safe_catalog = {k: v for k, v in catalog.items() if k != "auth_codes"}
    unlocked = session.get("unlocked", False)
    return render_template("vault.html",
                           catalog=safe_catalog,
                           unlocked=unlocked)


@app.route("/api/unlock", methods=["POST"])
def unlock():
    code = request.json.get("code", "").strip().upper()
    catalog = load_catalog()

    # Check if vault is already exhausted
    remaining = catalog["max_authorizations"] - catalog["authorizations_used"]
    if remaining <= 0:
        return jsonify({
            "success": False,
            "message": "This catalog has reached its maximum of 5 authorizations.",
            "remaining": 0,
        })

    # Validate code
    if code not in catalog["auth_codes"]:
        return jsonify({
            "success": False,
            "message": "Invalid authorization code.",
            "remaining": remaining,
        })

    # Check if this specific code was already used
    used_codes = session.get("used_codes", [])
    if code in catalog.get("redeemed_codes", []):
        return jsonify({
            "success": False,
            "message": f"Code {code} has already been redeemed.",
            "remaining": remaining,
        })

    # Redeem it
    if "redeemed_codes" not in catalog:
        catalog["redeemed_codes"] = []
    catalog["redeemed_codes"].append(code)
    catalog["authorizations_used"] += 1
    save_catalog(catalog)

    session["unlocked"] = True
    session["unlock_code"] = code

    remaining = catalog["max_authorizations"] - catalog["authorizations_used"]
    return jsonify({
        "success": True,
        "message": f"Catalog unlocked! {remaining} authorization(s) remaining.",
        "remaining": remaining,
    })


@app.route("/api/status")
def status():
    catalog = load_catalog()
    remaining = catalog["max_authorizations"] - catalog["authorizations_used"]
    return jsonify({
        "unlocked": session.get("unlocked", False),
        "remaining": remaining,
        "total": catalog["max_authorizations"],
    })


@app.route("/api/catalog")
def api_catalog():
    """Return full catalog data (only if unlocked)."""
    if not session.get("unlocked", False):
        return jsonify({"error": "Not authorized"}), 403

    catalog = load_catalog()
    safe_catalog = {k: v for k, v in catalog.items() if k != "auth_codes"}
    return jsonify(safe_catalog)


if __name__ == "__main__":
    import socket
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)

    print(f"""
╔══════════════════════════════════════════╗
║       🔒  Song Vault                ║
║   Authorized Music Catalog System   ║
╠══════════════════════════════════════════╣
║  Local:   http://127.0.0.1:5050        ║
║  Network: http://{local_ip}:5050{' ' * (24 - len(local_ip))}║
║  Max 5 authorizations per catalog   ║
╚══════════════════════════════════════════╝
""")
    app.run(debug=True, host="0.0.0.0", port=5050)
