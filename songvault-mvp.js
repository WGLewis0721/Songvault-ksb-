// Shared SongVault MVP data helpers
// Used by index.html, add_song.html, and setlist.html

var SAMPLE_SONGS = [
  {
    id: 1,
    title: "Bohemian Rhapsody",
    song_key: "Bb Major",
    tempo_bpm: 72,
    mood: "epic",
    duration_sec: 354,
    lyrics: "Is this the real life? Is this just fantasy?\nCaught in a landslide, no escape from reality…"
  },
  {
    id: 2,
    title: "Hotel California",
    song_key: "B Minor",
    tempo_bpm: 76,
    mood: "haunting",
    duration_sec: 391,
    lyrics: "On a dark desert highway, cool wind in my hair…\nWarm smell of colitas rising up through the air…"
  },
  {
    id: 3,
    title: "Wonderwall",
    song_key: "F# Minor",
    tempo_bpm: 87,
    mood: "nostalgic",
    duration_sec: 258,
    lyrics: "Today is gonna be the day that they're gonna throw it back to you…\nBy now you should've somehow realized what you gotta do…"
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
  return s > 0 ? m + "m " + s + "s" : m + "m";
}

function svEscHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
