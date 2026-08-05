# The PowerShell rule

Every silent-failure bug this project has shipped is one family: **content with spaces or
newlines shredded by passing it through PowerShell**. Every one of them looked correct
while reading and failed without an error.

So, when content travels:

- **Clause 1 — To a native tool: through a file.** `--body-file`, `--input`, `-F`. Never argv.
- **Clause 2 — From a native tool: to a file.** `Start-Process -RedirectStandardOutput`.
  Never a variable, if the value is going to be written back somewhere. Native output is an
  **array of lines**, and `-NoNewline` joins an array with no separator. `-NoNewline` on
  anything that might be an array is banned outright.
- **Clause 3 — Any `^`-anchored regex: apply it to a string, never to an array.** `^` never
  matches in an array pipeline, so the check silently reports zero and reads as a clean result.
- **Clause 4 — Verify structure, not phrasing.** A check that asks "is the old text gone?"
  passes on a destroyed file.
