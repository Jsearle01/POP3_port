## Form B Report — P3.15 (doc) — the heredoc edit hazard, and the practice change
**Class:** DOC / practice. **No code changed.** POP `wip`. **Karateka UNTOUCHED.**
**25.3: N/A — nothing built.**

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-28T21:31:04Z (POP HEAD `1419144`, wip; tracked tree clean bar the standing
untracked files and a MAME `coco3.cfg` write-back, reverted).
**No dispatch receipt.** Written on Jay's direct instruction, "write a report for the
heredoc change".

**Scope note, stated up front because the instruction is open to reading two ways.**
I have taken "the heredoc change" to mean the **working-practice change**: file edits
move off `python - <<'PY'` heredoc scripts and onto the Edit/Write tools. There is no
code delta to report — the change is to how I edit, not to what the port does. If a
different change was meant, this is the wrong report and I will write the right one.

---

### 1 — Summary

Editing files by piping a Python script into a bash heredoc failed **four times
today** across P3.11, P3.12 and P3.14, in three distinct ways. One of those failures
cost the most expensive wrong turn of the session: I spent several rounds reasoning
about a test gate I believed I had changed, on a file that still held the original
text.

The failures are not carelessness in the individual scripts. They are structural
properties of the technique: three escaping layers stacked on top of each other, and
a write that happens after the validation rather than before it. **The practice
change is to stop using it for edits**, and where a script genuinely is the right
tool, to write first and validate second.

---

### 2 — Files modified

None. This report only.

---

### 3 — Reasoning

#### 3A — Failure one: validate-then-write turns a failed check into a silent no-op

The shape that did the damage, written four times today:

```python
python - <<'PY'
t = p.read_text()
t = t.replace(old_A, new_A)      # succeeds
assert t.count(old_B) == 1       # FAILS -> the process dies here
t = t.replace(old_B, new_B)
p.write_bytes(t)                 # never runs
PY
```

The assertion is doing its job. The problem is **where the write is**. When the
second check fails, the first replacement — which was correct and which I had every
reason to believe in — is discarded along with it. The file on disk is untouched,
and the only output is a traceback about the *second* edit.

In P3.11 this produced the session's worst detour. The script set a harness WANT row
to `swaps = 1` and then failed on an unrelated matcher line. I read the traceback as
"the second edit didn't apply", carried on believing the row said `swaps = 1`, and
spent three MAME runs and two hypotheses explaining why a gate that was still
`loads = 2` behaved as though it were `loads = 2`. It recurred in P3.14 on the live
runner, where four substitutions were staged and the fourth aborted all of them.

**An edit tool that reports failure while leaving a partial intention unrecorded is
worse than one that fails cleanly**, because the failure message describes something
other than the state you are now in.

#### 3B — Failure two: three escaping layers

Writing a Lua file that must contain a literal `\n` inside a string means the
sequence has to survive bash's heredoc, Python's string literal, and finally Lua's
parser. It did not:

```
Fatal error: Error loading autoboot script harness/tools/port_wipe_motion.lua: syntax error
harness/tools/port_wipe_motion.lua:36: unfinished string near ''LOADM"INTROSEQ"'
```

`nk:post('LOADM"INTROSEQ"\n')` had become an actual newline, splitting the string
across two lines. **Two further heredoc-based attempts to repair it also failed**,
each in a way that looked like it had worked — the script reported success and the
file was unchanged. It was resolved by deleting the file and writing it with the
Write tool, where what I type is what lands.

#### 3C — Failure three: multi-line matches against unknown line endings

`intro_seq.s` was mixed CRLF/LF (923 CRLF, 0 LF at one point in the day; mixed at
others). A multi-line `old` string built with `\n` matches nothing in a CRLF file,
and `t.count(old) == 1` then fails for a reason that has nothing to do with the edit
being wrong. I added line-ending detection, which worked until the file was mixed,
at which point detection picked one and the other half stopped matching.

Single-line replacements were unaffected throughout — which is why the problem was
intermittent and looked like bad luck rather than a property of the method.

#### 3D — The practice change

1. **Edits go through Edit/Write.** They are atomic, they fail loudly, they do not
   half-apply, and they require having read the file first — which would have caught
   §3C immediately.
2. **When a script really is right** — a mechanical sweep over many occurrences, or a
   computed transformation — **write first, validate after.** Compute the new
   content, write it, then assert on what is now on disk. A failed assertion then
   describes the true state.
3. **Never trust "the script printed ok".** Read back the specific line that was
   supposed to change. §3B's repairs each printed a success message.
4. **Normalise line endings before multi-line matching**, as an explicit step, not as
   detection inside the matcher.

Point 2 is the general one and it is not really about heredocs: **validation belongs
after the mutation is durable, not between the mutation and its persistence.**

---

### 4 — Verification (AC-by-AC)

- **AC1 — the failures are real and evidenced.** Four occurrences today, quoted in
  §3A–§3C from the session's own tool output, across three dispatches.
- **AC2 — the mechanism is identified**, not just the symptom: write-after-validate,
  stacked escaping, and endings-dependent matching. Each has a distinct fix.
- **AC3 — the change is stated as a rule** (§3D) rather than an intention.
- **AC4 — no code changed**; nothing to regress. The last full run at this HEAD is
  P3.14's post-correction run: 17/17, all eleven endpoint comparisons byte-identical,
  512 KB and 128 KB, probe/mode/anim green.

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1:** N/A — no build. Verbatim evidence of the failures is in §3A–§3C.
**25.2:** N/A.
**25.3:** N/A — nothing built.

---

### 6 — Reactive deviations

- **The scope was interpreted, not confirmed** (see §0). "The heredoc change" has no
  code delta anywhere in the tree, so I have taken it as the practice change. Flagged
  rather than silently assumed.

---

### 7 — Uncertainty flags

- **This report may be answering the wrong question** (§0/§6). Cheap to redo.
- **The rule in §3D is a working practice, not an enforced one.** Nothing in the repo
  prevents the next heredoc edit. If it should be enforced, that is a CLAUDE.md
  change and therefore the Orchestrator's (§2D).
- **I do not know how often this succeeded silently.** Four failures were visible
  because something downstream broke. A heredoc edit that half-applied and was never
  contradicted would still be sitting in the tree unnoticed — and I have no way to
  audit for that beyond the tests, which are green.

---

### 8 — Follow-up candidates

1. **Consider whether §3D belongs in CLAUDE.md** (Orchestrator's call).
2. Carried, unchanged: prefetch (unblocked, ~6 s); rule on the constant-rate sweep vs
   the oracle's variable rate; mid-sweep guards for beats 5; the `FB_*_BLOCK` coupling
   with `gfx.s`; the 1.00 s inter-track disk gap; `anim_probe` spanning `$02DC`; the
   `Demo`/`PrincessScene` arc; keypress-to-start; `HAL_mem_size_detect`;
   `HAL_gfx_swap` clobbering X undocumented; `HAL_gfx_set_palette`; the banked-RAM
   block map; `build.bat` line endings; re-labelling the P3.7–P3.9 gates as
   `static-png`.

---

### 9 — User interaction during task

Jay: "write a report for the heredoc change." Scope interpreted per §0.

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-07-28-validate-after-the-write-not-between-the-change-and-its-persistence.md`

---

### 11 — Commit

See below — pushed to `origin/wip` before this report was surfaced.
