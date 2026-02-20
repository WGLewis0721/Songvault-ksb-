import os
import psycopg2
from flask import Flask, render_template, request, redirect, url_for

app = Flask(__name__)

# ---------------------------------------------------------------------------
# Database connection helper
# Reads connection details from environment variables so secrets never live
# in source code.  DB_HOST and DB_PASS must be set — they have no defaults
# because connecting to the wrong database silently would be a serious bug.
# ---------------------------------------------------------------------------
def get_conn():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ.get("DB_NAME", "songvault"),
        user=os.environ.get("DB_USER", "songvault_user"),
        password=os.environ["DB_PASS"],
    )


# ---------------------------------------------------------------------------
# init_db — creates the songs and setlist tables if they do not already exist.
# Called at module load so the schema is always ready before the first request,
# whether running directly with python or via gunicorn.
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# GET / — homepage: fetch all songs ordered by most-recently updated and
# render them in a table so the user can see their full catalogue at a glance.
# ---------------------------------------------------------------------------
@app.route("/")
def index():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, title, song_key, tempo_bpm, mood, duration_sec
        FROM songs
        ORDER BY updated_at DESC
    """)
    songs = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("index.html", songs=songs)


# ---------------------------------------------------------------------------
# GET/POST /add — display an empty form (GET) or insert a new song (POST).
# Duration is collected as minutes in the form and converted to seconds before
# storing, keeping the database column consistent.
# ---------------------------------------------------------------------------
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
        cur.execute("""
            INSERT INTO songs (title, lyrics, song_key, tempo_bpm, mood, duration_sec)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (title, lyrics, song_key, tempo_bpm, mood, duration_sec))
        conn.commit()
        cur.close()
        conn.close()
        return redirect(url_for("index"))

    return render_template("add_song.html")


# ---------------------------------------------------------------------------
# GET/POST /setlist — manage the ordered setlist.
# On POST: wipe the existing setlist and re-insert the checked songs in order,
#   giving a simple way to rebuild the setlist from scratch each time.
# On GET: JOIN setlist with songs to display titles, durations, and total runtime.
# ---------------------------------------------------------------------------
@app.route("/setlist", methods=["GET", "POST"])
def setlist():
    conn = get_conn()
    cur = conn.cursor()

    if request.method == "POST":
        # Remove all existing setlist rows before re-inserting the new selection.
        cur.execute("DELETE FROM setlist")
        song_ids = request.form.getlist("song_ids")
        for position, song_id in enumerate(song_ids, start=1):
            cur.execute(
                "INSERT INTO setlist (song_id, position) VALUES (%s, %s)",
                (int(song_id), position),
            )
        conn.commit()

    # Fetch all songs for the checkbox form.
    cur.execute("SELECT id, title FROM songs ORDER BY title")
    all_songs = cur.fetchall()

    # Fetch the current setlist with song details for the ordered display.
    cur.execute("""
        SELECT s.title, s.duration_sec
        FROM setlist sl
        JOIN songs s ON s.id = sl.song_id
        ORDER BY sl.position
    """)
    current_setlist = cur.fetchall()

    # Calculate total runtime in seconds.
    total_sec = sum(row[1] or 0 for row in current_setlist)

    cur.close()
    conn.close()
    return render_template(
        "setlist.html",
        all_songs=all_songs,
        current_setlist=current_setlist,
        total_sec=total_sec,
    )


# ---------------------------------------------------------------------------
# Entry point — when run directly (python app.py) start the dev server.
# In production gunicorn imports this module and uses the `app` object directly.
# init_db() above already ran at import time so the schema is ready either way.
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
