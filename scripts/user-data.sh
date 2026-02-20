#!/bin/bash
# user-data.sh — bootstraps a fresh Ubuntu 22.04 EC2 instance so it runs the
# SongVault Flask application as a systemd service on port 8080.
# This script is executed once by cloud-init when the instance first boots.
#
# Terraform's templatefile() function replaces ${db_host}, ${db_name},
# ${db_user}, and ${db_pass} with real values before encoding the script.
# All other heredocs use <<'EOF' (single-quoted) to prevent bash from
# trying to expand anything else.

# Stop the script if any command fails. Log everything for debugging.
set -e
exec > >(tee /var/log/songvault-bootstrap.log) 2>&1

# ---------------------------------------------------------------------------
# Step 1: Refresh the list of available packages.
# Always do this before installing anything to get the latest versions.
# ---------------------------------------------------------------------------
apt-get update -y

# ---------------------------------------------------------------------------
# Step 2: Install Python 3, pip (Python package installer), and git.
# ---------------------------------------------------------------------------
apt-get install -y python3 python3-pip git

# ---------------------------------------------------------------------------
# Step 3: Create the directory where our app will live.
# -p means create parent directories too, and don't error if they already exist.
# ---------------------------------------------------------------------------
mkdir -p /opt/songvault/app/templates

# ---------------------------------------------------------------------------
# Step 4: Write the Flask application code directly to disk.
# We use a single-quoted heredoc (<<'APPEOF') so bash does not try to
# expand any variables inside the Python code.
# ---------------------------------------------------------------------------
cat > /opt/songvault/app/app.py <<'APPEOF'
import os
import psycopg2
from flask import Flask, render_template, request, redirect, url_for

app = Flask(__name__)

# Database connection helper — reads from environment variables set in /etc/songvault.env
def get_conn():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ.get("DB_NAME", "songvault"),
        user=os.environ.get("DB_USER", "songvault_user"),
        password=os.environ["DB_PASS"],
    )

# init_db — creates the tables if they do not already exist.
# Called at module load so the schema is ready before the first request.
def init_db():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS songs (
            id           SERIAL PRIMARY KEY,
            title        TEXT NOT NULL,
            lyrics       TEXT NOT NULL,
            song_key     TEXT,
            tempo_bpm    INT,
            mood         TEXT,
            duration_sec INT,
            updated_at   TIMESTAMP DEFAULT NOW()
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS setlist (
            id       SERIAL PRIMARY KEY,
            song_id  INT REFERENCES songs(id),
            position INT NOT NULL
        )
    """)
    conn.commit()
    cur.close()
    conn.close()

# Call init_db at module load so it runs for both direct execution and gunicorn.
init_db()

@app.route("/")
def index():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, title, song_key, tempo_bpm, mood, duration_sec FROM songs ORDER BY updated_at DESC")
    songs = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("index.html", songs=songs)

@app.route("/add", methods=["GET", "POST"])
def add_song():
    if request.method == "POST":
        title = request.form["title"]
        song_key = request.form.get("song_key", "")
        tempo_bpm = request.form.get("tempo_bpm") or None
        mood = request.form.get("mood", "")
        duration_min_str = (request.form.get("duration_min") or "").strip()
        duration_sec = int(float(duration_min_str) * 60) if duration_min_str else 0
        lyrics = request.form["lyrics"]
        conn = get_conn()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO songs (title, lyrics, song_key, tempo_bpm, mood, duration_sec) VALUES (%s, %s, %s, %s, %s, %s)",
            (title, lyrics, song_key, tempo_bpm, mood, duration_sec)
        )
        conn.commit()
        cur.close()
        conn.close()
        return redirect(url_for("index"))
    return render_template("add_song.html")

@app.route("/setlist", methods=["GET", "POST"])
def setlist():
    conn = get_conn()
    cur = conn.cursor()
    if request.method == "POST":
        cur.execute("DELETE FROM setlist")
        song_ids = request.form.getlist("song_ids")
        for position, song_id in enumerate(song_ids, start=1):
            cur.execute("INSERT INTO setlist (song_id, position) VALUES (%s, %s)", (int(song_id), position))
        conn.commit()
    cur.execute("SELECT id, title FROM songs ORDER BY title")
    all_songs = cur.fetchall()
    cur.execute("""
        SELECT s.title, s.duration_sec
        FROM setlist sl
        JOIN songs s ON s.id = sl.song_id
        ORDER BY sl.position
    """)
    current_setlist = cur.fetchall()
    total_sec = sum(row[1] or 0 for row in current_setlist)
    cur.close()
    conn.close()
    return render_template("setlist.html", all_songs=all_songs, current_setlist=current_setlist, total_sec=total_sec)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
APPEOF

# ---------------------------------------------------------------------------
# Step 5: Write the Python dependency list.
# ---------------------------------------------------------------------------
cat > /opt/songvault/app/requirements.txt <<'REQEOF'
flask==3.0.0
psycopg2-binary==2.9.9
gunicorn==22.0.0
REQEOF

# ---------------------------------------------------------------------------
# Step 6: Write the index.html HTML template.
# ---------------------------------------------------------------------------
cat > /opt/songvault/app/templates/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>SongVault 🎵</title>
</head>
<body>
  <h1>SongVault 🎵</h1>
  <nav>
    <a href="/add">➕ Add Song</a> |
    <a href="/setlist">🎶 Setlist</a>
  </nav>
  <h2>All Songs</h2>
  {% if songs %}
  <table border="1" cellpadding="6">
    <thead>
      <tr>
        <th>Title</th><th>Key</th><th>Tempo (BPM)</th><th>Mood</th><th>Duration (sec)</th>
      </tr>
    </thead>
    <tbody>
      {% for id, title, song_key, tempo_bpm, mood, duration_sec in songs %}
      <tr>
        <td>{{ title }}</td>
        <td>{{ song_key or '—' }}</td>
        <td>{{ tempo_bpm or '—' }}</td>
        <td>{{ mood or '—' }}</td>
        <td>{{ duration_sec or '—' }}</td>
      </tr>
      {% endfor %}
    </tbody>
  </table>
  {% else %}
  <p>No songs yet. <a href="/add">Add your first song!</a></p>
  {% endif %}
</body>
</html>
HTMLEOF

# ---------------------------------------------------------------------------
# Step 7: Write the add_song.html HTML template.
# ---------------------------------------------------------------------------
cat > /opt/songvault/app/templates/add_song.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Add Song — SongVault 🎵</title>
</head>
<body>
  <h1>➕ Add a New Song</h1>
  <form method="POST" action="/add">
    <p>
      <label>Title *<br>
        <input type="text" name="title" required placeholder="e.g. Bohemian Rhapsody" size="40">
      </label>
    </p>
    <p>
      <label>Key<br>
        <input type="text" name="song_key" placeholder="e.g. G Major" size="20">
      </label>
    </p>
    <p>
      <label>Tempo (BPM)<br>
        <input type="number" name="tempo_bpm" min="1" max="300" placeholder="e.g. 120">
      </label>
    </p>
    <p>
      <label>Mood<br>
        <input type="text" name="mood" placeholder="e.g. melancholic" size="20">
      </label>
    </p>
    <p>
      <label>Duration (minutes)<br>
        <input type="number" name="duration_min" step="0.1" min="0" placeholder="e.g. 3.5">
      </label>
    </p>
    <p>
      <label>Lyrics *<br>
        <textarea name="lyrics" rows="10" cols="60" required placeholder="Paste lyrics here..."></textarea>
      </label>
    </p>
    <button type="submit">💾 Save Song</button>
  </form>
  <p><a href="/">← Back to All Songs</a></p>
</body>
</html>
HTMLEOF

# ---------------------------------------------------------------------------
# Step 8: Write the setlist.html HTML template.
# ---------------------------------------------------------------------------
cat > /opt/songvault/app/templates/setlist.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Setlist — SongVault 🎵</title>
</head>
<body>
  <h1>Setlist Builder</h1>
  <h2>Choose Songs for Setlist</h2>
  <form method="POST" action="/setlist">
    {% if all_songs %}
      {% for s in all_songs %}
      <p>
        <input type="checkbox" id="song_{{ s[0] }}" name="song_ids" value="{{ s[0] }}">
        <label for="song_{{ s[0] }}">{{ s[1] }}</label>
      </p>
      {% endfor %}
    {% else %}
      <p>No songs yet. <a href="/add">Add some songs first!</a></p>
    {% endif %}
    <button type="submit">Update Setlist</button>
  </form>
  <h2>Current Setlist</h2>
  {% if current_setlist %}
  <ol>
    {% for title, duration_sec in current_setlist %}
    <li>{{ title }} ({{ duration_sec or 0 }} sec)</li>
    {% endfor %}
  </ol>
  <p><strong>Total Runtime: {{ total_sec }} seconds</strong></p>
  {% else %}
  <p>No setlist yet. Check songs above and click Update Setlist.</p>
  {% endif %}
  <p><a href="/">← Back to All Songs</a></p>
</body>
</html>
HTMLEOF

# ---------------------------------------------------------------------------
# Step 9: Install Flask, psycopg2 (PostgreSQL driver), and gunicorn
# (production web server). pip3 reads the requirements.txt we just wrote.
# ---------------------------------------------------------------------------
pip3 install -r /opt/songvault/app/requirements.txt

# ---------------------------------------------------------------------------
# Step 10: Write database connection info to a protected env file.
# chmod 600 = only root can read it. The ${} values are replaced by Terraform's
# templatefile() at deploy time — they are not bash variables.
# ---------------------------------------------------------------------------
cat > /etc/songvault.env <<EOF
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASS=${db_pass}
EOF
chmod 600 /etc/songvault.env

# ---------------------------------------------------------------------------
# Step 11: Register the app as a system service. systemd will start it on boot
# and restart it if it crashes. EnvironmentFile reads from our protected env file.
# ---------------------------------------------------------------------------
cat > /etc/systemd/system/songvault.service <<'SVCEOF'
[Unit]
Description=SongVault Flask App
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/songvault/app
EnvironmentFile=/etc/songvault.env
ExecStart=/usr/bin/gunicorn -w 2 -b 0.0.0.0:8080 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

# ---------------------------------------------------------------------------
# Step 12: Tell systemd to reload its config after we added the new service file.
# ---------------------------------------------------------------------------
systemctl daemon-reload

# ---------------------------------------------------------------------------
# Step 13: Make the service start automatically every time this server reboots.
# ---------------------------------------------------------------------------
systemctl enable songvault

# ---------------------------------------------------------------------------
# Step 14: Start the service right now.
# ---------------------------------------------------------------------------
systemctl start songvault

# ---------------------------------------------------------------------------
# Step 15: Write a timestamp so we know exactly when setup finished.
# Check this log with: sudo tail -50 /var/log/songvault-bootstrap.log
# ---------------------------------------------------------------------------
echo "SongVault bootstrap complete at $(date)" >> /var/log/songvault-bootstrap.log
