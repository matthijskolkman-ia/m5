"""
🎵 Jukebox — Type a song, it plays. No results. Just music.
"""
from flask import Flask, render_template_string, request, jsonify
import subprocess
import webbrowser
import socket

app = Flask(__name__)

HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Jukebox</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
    background: #0a0a0f; color: #fff;
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; min-height: 100vh;
    gap: 0;
  }
  .player { width: min(700px, 95vw); aspect-ratio: 16/9; background: #111; border-radius: 16px; overflow: hidden; margin-bottom: 24px; box-shadow: 0 20px 60px rgba(0,0,0,0.5); }
  .player iframe { width: 100%; height: 100%; border: none; }
  .search-box {
    display: flex; gap: 10px; width: min(500px, 90vw);
  }
  .search-box input {
    flex: 1; padding: 14px 20px; border-radius: 12px; border: 1px solid #333;
    background: #12121a; color: #fff; font-size: 16px; outline: none;
    transition: border-color 0.2s;
  }
  .search-box input:focus { border-color: #ff0050; }
  .search-box button {
    padding: 14px 24px; border-radius: 12px; border: none;
    background: #ff0050; color: #fff; font-weight: 700; font-size: 16px;
    cursor: pointer; transition: background 0.2s;
  }
  .search-box button:hover { background: #cc0040; }
  .now-playing {
    margin-top: 16px; color: #888; font-size: 14px; text-align: center;
    min-height: 20px;
  }
  .now-playing strong { color: #ff0050; }
  footer { position: fixed; bottom: 16px; color: #333; font-size: 11px; }
</style>
</head>
<body>

<div class="player" id="player">
  <iframe id="yt" src="" allow="autoplay" allowfullscreen></iframe>
</div>

<div class="search-box">
  <input type="text" id="query" placeholder="Type a song..." autofocus autocomplete="off" spellcheck="false">
  <button onclick="play()">▶ Play</button>
</div>

<div class="now-playing" id="nowPlaying"></div>

<footer>🎵 Jukebox · Type it, play it</footer>

<script>
const input = document.getElementById('query');

input.addEventListener('keydown', e => { if (e.key === 'Enter') play(); });

async function play() {
  const q = input.value.trim();
  if (!q) return;

  input.disabled = true;
  document.getElementById('nowPlaying').innerHTML = 'Searching...';

  try {
    const res = await fetch('/search?q=' + encodeURIComponent(q));
    const data = await res.json();

    if (data.videoId) {
      const yt = document.getElementById('yt');
      yt.src = `https://www.youtube.com/embed/${data.videoId}?autoplay=1&mute=1&rel=0`;
      document.getElementById('nowPlaying').innerHTML =
        `Now playing: <strong>${data.title}</strong>`;
    } else {
      document.getElementById('nowPlaying').innerHTML = 'Not found 😕';
    }
  } catch(e) {
    document.getElementById('nowPlaying').innerHTML = 'Connection error';
  }

  input.disabled = false;
  input.select();
}
</script>
</body>
</html>
"""

@app.route("/")
def index():
    return render_template_string(HTML)

@app.route("/search")
def search():
    q = request.args.get("q", "")
    if not q:
        return jsonify({"error": "No query"})
    try:
        result = subprocess.run(
            ["python3", "-m", "yt_dlp", f"ytsearch1:{q}", "--get-id", "--get-title", "--no-playlist"],
            capture_output=True, text=True, timeout=15
        )
        lines = result.stdout.strip().split("\n")
        if len(lines) >= 2:
            return jsonify({
                "videoId": lines[1].strip(),
                "title": lines[0].strip(),
            })
        return jsonify({"error": "Not found"})
    except Exception as e:
        return jsonify({"error": str(e)})

if __name__ == "__main__":
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    print(f"""
╔══════════════════════════════════════╗
║         🎵 Jukebox                 ║
║   Type a song. It plays.           ║
╠══════════════════════════════════════╣
║  http://localhost:5090              ║
║  http://{local_ip}:5090{' ' * (22 - len(local_ip))}║
╚══════════════════════════════════════╝
""")
    webbrowser.open("http://localhost:5090")
    app.run(host="0.0.0.0", port=5090, debug=False)
