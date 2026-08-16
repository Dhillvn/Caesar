# Holding several maps

Disclosed from `SKILL.md` ([#113](https://github.com/Dhillvn/Caesar/issues/113)): discovery,
the `caesar:driving` claim, and withdrawal, when more than one map is in play.

## Holding several maps

A map is yours only while its issue carries **`caesar:driving`**. Discovery is one
command:

```
gh search issues --owner Dhillvn --label wayfinder:map --label caesar:driving --state open
```

`--owner` is mandatory — a label-only search returns twenty strangers' public maps.

`--state open` is mandatory too, and for a subtler reason: the search covers **every**
state by default, so a map closed by hand while still carrying `caesar:driving` comes back
as a live map. `numen-ops#35` sat on the command centre that way for six weeks. The label
is the claim, but the issue's state outranks it — a closed map is never being driven.

**No state file.** GitHub reports which tickets are assigned and open; `git worktree
list` reports what is still running. Both are already the truth, so a scratch file
could only disagree with them.

Withdrawing from a map is **drain, never kill**: centurions in the field finish and post
their artifacts, nothing new starts.
