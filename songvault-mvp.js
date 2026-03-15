// Shared SongVault MVP data helpers
// Used by index.html, add_song.html, and setlist.html

var SAMPLE_SONGS = [
  {
    id: 1,
    title: "Driving Home at 3am",
    song_key: "A Minor",
    tempo_bpm: 78,
    mood: "melancholic",
    duration_sec: 252,
    lyrics: "The city lights blur through the rain…\nEvery red light holds me here again…"
  },
  {
    id: 2,
    title: "Glass Half Full",
    song_key: "G Major",
    tempo_bpm: 124,
    mood: "upbeat",
    duration_sec: 208,
    lyrics: "I choose to see the good in everything…\nEvery ending is a new beginning…"
  },
  {
    id: 3,
    title: "Letters I Never Sent",
    song_key: "D Minor",
    tempo_bpm: 92,
    mood: "hopeful",
    duration_sec: 301,
    lyrics: "Words piled up on paper, never reaching you…\nMaybe someday I'll find the courage to…"
  },
  {
    id: 4,
    title: "November Again",
    song_key: "E Minor",
    tempo_bpm: 68,
    mood: "dark",
    duration_sec: 235,
    lyrics: "The leaves fall like the words I should have said…\nAnother year of silence in my head…"
  },
  {
    id: 5,
    title: "Sunday Morning Slow",
    song_key: "C Major",
    tempo_bpm: 84,
    mood: "upbeat",
    duration_sec: 284,
    lyrics: "Coffee and sunlight and nothing to do…\nThe whole world is quiet and I think of you…"
  },
  {
    id: 6,
    title: "Wolves at the Door",
    song_key: "B Minor",
    tempo_bpm: 110,
    mood: "dark",
    duration_sec: 198,
    lyrics: "Something's scratching at the edges of my sleep…\nHunger that I've been trying not to keep…"
  }
];

function svLoadSongs() {
  var raw = localStorage.getItem("sv_songs");
  if (raw) return JSON.parse(raw);
  // First visit — seed sample songs so the demo is immediately useful
  localStorage.setItem("sv_songs", JSON.stringify(SAMPLE_SONGS));
  return SAMPLE_SONGS;
}

function svSaveSongs(songs) {
  localStorage.setItem("sv_songs", JSON.stringify(songs));
}

function svLoadSetlist() {
  return JSON.parse(localStorage.getItem("sv_setlist") || "[]");
}

function svFmtDuration(sec) {
  if (!sec) return "\u2014"; // em-dash
  var m = Math.floor(sec / 60);
  var s = sec % 60;
  return s > 0 ? m + "m " + (s < 10 ? "0" + s : s) + "s" : m + "m";
}

function svEscHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
