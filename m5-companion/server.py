"""
M5 Companion Server — Provides system stats to the LilyGo display via HTTP.
Run: python3 server.py
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import socket
import subprocess
import os

PORT = 5099

def get_stats():
    # CPU usage via top
    cpu = 0
    try:
        out = subprocess.check_output(["top", "-l", "1", "-n", "0"], stderr=subprocess.DEVNULL).decode()
        for line in out.split("\n"):
            if "CPU usage" in line:
                parts = line.split(",")
                user = float(parts[0].split(":")[1].strip().replace("%",""))
                sys = float(parts[1].strip().replace("%",""))
                cpu = user + sys
                break
    except: cpu = 0

    # Memory
    vm = subprocess.check_output(["vm_stat"]).decode()
    pages = {}
    for line in vm.split("\n"):
        if ":" in line and "page" in line.lower():
            key = line.split(":")[0].strip().replace('"','')
            val = line.split(":")[1].strip().rstrip(".")
            try: pages[key] = int(val)
            except: pass
    page_size = 16384  # ARM64 page size
    used = (pages.get("Pages active", 0) + pages.get("Pages wired down", 0)) * page_size
    total_mem = int(subprocess.check_output(["sysctl", "-n", "hw.memsize"]).decode().strip())
    ram_pct = (used / total_mem * 100) if total_mem > 0 else 0

    # Uptime
    uptime = "?"
    try:
        out = subprocess.check_output(["uptime"]).decode()
        uptime = out.split("up")[1].split(",")[0].strip()
    except: pass

    # Hostname
    host = socket.gethostname()

    # Check if iPhone is on network (via arp or bonjour)
    phone_nearby = "Maybe"
    try:
        arp = subprocess.check_output(["arp", "-a"]).decode()
        if "iPhone" in arp: phone_nearby = "Yes"
    except: pass

    return {
        "host": host,
        "cpu": round(cpu, 1),
        "ram": round(ram_pct, 1),
        "uptime": uptime,
        "phone": phone_nearby,
    }

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/stats":
            data = json.dumps(get_stats()).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", len(data))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # silent

if __name__ == "__main__":
    ip = socket.gethostbyname(socket.gethostname())
    print(f"🖥️  M5 Companion Server")
    print(f"   http://{ip}:{PORT}/stats")
    print(f"   Waiting for LilyGo...")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
