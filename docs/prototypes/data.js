// ponytail: one shared data file, three designs. Identical numbers by construction.
// Mirrors docs/prototypes/fixture.md exactly.
const G = {
  gen: "2026-08-16 10:18", ago: "12s", slotsUsed: 0, slotsCap: 4,
  maps: 4, open: 21, decided: 28, needsRaj: 10, caesarHolds: 11,
  pr: { n: 174, t: "Report a centurion's own failure modes back into the session", repo: "Dhillvn/Caesar", draft: true, url: "https://github.com/Dhillvn/Caesar/pull/174" },
  runs: [
    { n: 168, repo: "Dhillvn/Caesar", cls: "LANDED", cost: "$2.41", turns: 38, when: "2026-08-15 16:02" },
    { n: 167, repo: "Dhillvn/Caesar", cls: "ERRORED", cost: "$5.00", turns: 61, when: "2026-08-15 14:47", why: "budget cap reached" },
    { n: 166, repo: "Dhillvn/numen-ops", cls: "LANDED (no GIST)", cost: "$1.12", turns: 19, when: "2026-08-15 11:20" },
    { n: 161, repo: "Dhillvn/Caesar", cls: "LANDED", cost: "$3.08", turns: 44, when: "2026-08-14 18:55" }
  ]
};

const MAPS = [
  {
    repo: "Dhillvn/Caesar", num: 178, letter: "A",
    title: "One self-refreshing command centre for every Caesar map",
    decided: 0, last: null,
    t: [
      [179, "Measure the sweep, and choose how the page stays fresh", "research", "Caesar", "Ongoing", ""],
      [180, "Retire caesar:driving from the maps that are finished", "task", "Caesar", "Ongoing", ""],
      [181, "Emit the whole picture as one JSON document", "task", "Caesar", "Ongoing", ""],
      [182, "Prototype how the command centre looks", "prototype", "You", "Queued", ""],
      [183, "Build the renderer and the refresh loop, and make every row on the page click through to GitHub", "task", "Caesar", "Blocked", "179, 181, 182"],
      [184, "Make it one command that stays running", "task", "Caesar", "Blocked", "183"],
      [186, "Decide what the page shows when a sweep fails", "grilling", "You", "Queued", ""],
      [187, "Rule whether the history view belongs on the page", "grilling", "You", "Queued", ""],
      [188, "Package the command centre so a cold machine can run it", "task", "Caesar", "Blocked", "184"]
    ]
  },
  {
    repo: "Dhillvn/numen-ops", num: 61, letter: "B",
    title: "Give every scheduled job a health signal Raj can read",
    decided: 12, last: { n: 78, t: "Ship the heartbeat file format" },
    t: [
      [79, "Alert when a job misses two consecutive runs", "task", "Caesar", "Needs you", ""],
      [80, "Survey what the nine jobs already write on failure", "research", "Caesar", "Queued", ""],
      [81, "Rule where the health signal is surfaced", "grilling", "You", "Queued", ""],
      [83, "Wire the heartbeat into the remaining six jobs", "task", "Caesar", "Blocked", "80"],
      [84, "Decide the retention window for heartbeat history", "grilling", "You", "Queued", ""]
    ]
  },
  {
    repo: "Dhillvn/Caesar", num: 140, letter: "C",
    title: "Caesar drives several maps in one session without losing the thread",
    decided: 7, last: { n: 158, t: "Withdraw from a map as a drain, not a stop" },
    t: [
      [159, "Rule how a session picks between two live frontiers", "grilling", "You", "Queued", ""],
      [160, "Measure the context cost of a two-map startup", "research", "Caesar", "Queued", ""],
      [162, "Teach status.ps1 to group by map rather than by repo", "task", "Caesar", "Blocked", "159"],
      [163, "Decide whether a withdrawn map keeps its claim", "grilling", "You", "Queued", ""]
    ]
  },
  {
    repo: "Dhillvn/numen-ops", num: 44, letter: "D",
    title: "Every credential on the machine has a known owner and an expiry",
    decided: 9, last: { n: 71, t: "Inventory every token the scheduled jobs hold" },
    t: [
      [72, "Rotate the gws refresh token to a minimum-scope client", "task", "Caesar", "Needs you", ""],
      [73, "Decide which credentials may live in a cloud runner", "grilling", "You", "Queued", ""],
      [75, "Record an expiry date against every token", "task", "Caesar", "Blocked", "72"]
    ]
  }
];

// Rows sort by what needs Raj first — flagged, then his queue, then Caesar's work, then blocked.
function rank(t) {
  if (t[4] === "Needs you") return 0;
  if (t[3] === "You") return 1;
  if (t[4] === "Ongoing") return 2;
  if (t[4] === "Queued") return 3;
  return 4;
}
function sorted(m) { return m.t.slice().sort(function (a, b) { return rank(a) - rank(b) || a[0] - b[0]; }); }
function issueUrl(m, n) { return "https://github.com/" + m.repo + "/issues/" + n; }
