# What the branch harness cannot see

`scripts/branch-harness.ps1` drives a real Caesar session against a disposable fixture map
and reports which of the skill's reference files that session read. Every claim made on the
skill-restructure map (#109) rests on that report, so every claim is bounded by this list.
Read it before quoting a harness result as evidence.

## 1. A read is not a use

The transcript records that a file was opened. It records nothing about whether the session
understood it, followed it, or acted on it. A pointer that fires and is then ignored is
indistinguishable here from a pointer that fires and changes the answer. The harness can
prove a pointer is *reachable*; it cannot prove it is *load-bearing*.

## 2. Not reading is not proof of not knowing

The session inherits SKILL.md in full at skill-load time. Anything already written in
SKILL.md needs no read, so a branch that produces the right behaviour with an empty read
list has told us nothing about whether a reference would have helped. This cuts the other
way too: after a restructure, a *fall* in reads is ambiguous between "the pointer is dead"
and "the session already had what it needed".

## 3. One roll, not a distribution

Each fixture is one session. Model behaviour is stochastic, and a pointer that fires four
times in five reads as "fires" on one run and "does not fire" on another. Nothing here is
run to significance, and the harness has no repeat mode. Treat a single missing read as a
lead, not a finding.

## 4. Dispatch is switched off

The harness prompt tells the session that `spawn-ticket-agent.ps1` and nested `claude` calls
will not run, and to compose and print the dispatch prompt instead of firing it. That keeps
a fixture run from spending real money and littering real worktrees, and it is why the
Drive-with-a-dispatch fixture is observable at all. But it means the harness observes the
session **up to** the spawn and never past it. Anything a centurion would read, and anything
SKILL.md says about harvesting a landing, is outside the frame.

## 5. Fixture maps are small, and context pressure is the thing being restructured

Every fixture map has two or three children. Real maps run to nineteen. The restructure this
harness exists to check is largely about context cost, and the harness's own maps are too
small to apply the pressure that would make a pointer worth following. A pointer that fires
on a two-ticket fixture may be skipped on a nineteen-ticket map, and the harness would not
see it.

## 6. Only one branch per session, and only the first move

The report is built from a single-turn `-p` run. It sees the session's opening move on the
branch and nothing after it. A reference that Caesar would reach for on turn six — mid-grill,
after a landing, at the merge gate — is invisible, because the session never gets a turn six.

## 7. Markers judge the text, not the behaviour

`expect_markers` are regexes over the session's final message. A session that says the right
words and would have done the wrong thing scores as fired. A session that does the right
thing in different words scores as not fired. Both have to be read by a human before the
column means anything.

## 8. It watches the installed skill, not the working tree

The observed file is whatever `~/.claude/skills/caesar` resolves to — a junction onto one
checkout's `skill/` directory. A branch under test has to be installed (or the junction
re-pointed) before the harness sees it. The runner prints the roots it is watching on every
run; if that path is not the branch you meant to test, the whole report is about a different
file.

## 9. Paths are matched, not file identity

Reads are attributed by string-prefix match against the known skill roots. A session that
reaches a reference by some path the runner does not know about — a copy, a different
checkout, a `gh` fetch of the file from GitHub — is not counted, and the report will
under-report rather than error.

## 10. Fixture issues are closed, not deleted

Cleanup closes the issues and comments why; it does not delete them. They stay in the repo's
issue history, labelled `caesar:fixture` and titled `[FIXTURE <id>]`. That is deliberate —
deletion needs `gh api --method DELETE`, which every Caesar deny list blocks — but it means
the issue numbering of the real map has fixture-shaped gaps in it forever.
