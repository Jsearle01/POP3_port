## Form B Report — P4.12 (PARTIAL) — a song fits at `$6B91`, with 593 bytes to spare

**Class:** recon.  wip.  Prod unchanged — no `src/`, no `build.bat`, no shipping disk.
**§1 answered. §2's wiring NOT done** — named in §6, not blocked by a hard-stop.

### 0 — Receipt / status (C-35 stamp)

t0=2026-08-18 10:00 (HEAD `e537074`, wip). Jay's ruling recorded: **"let's accept the drift for now
and I'll see/hear it to see if it throws anything off visually."** Acceptance pending observation;
the three remedies stay costed and stay his.

### 1 — Summary

**HARD-STOP 2 does not fire: a home exists.** The intro's program region is `$0200-$77FF` (30,208 B);
the intro image occupies **`$0200..$6B90`**; that leaves **`$6B91..$77FF` — 3,183 bytes free below the
trace ring.** The largest song is 2,590 B decompressed, so **one song at a time fits with 593 B to
spare**, resident, with no per-beat disk read at all.

**★ AND P4.11's "~1,840 B free" was WRONG, in my own report, one dispatch ago.** I read
`Section: prog (build/obj/intro_splash.o) load at 0200, length 6991` and reported the region as
ending at `$1D4F`. **That is one object file's contribution to the section, not the section.** The
linked image is 27,025 B and ends at `$6B90`. *The map was there to be read and I quoted a fragment
of it — the same shape of error as the capture window, in the same session that named it.*

### 2 — Files modified

None.

### 3 — Reasoning

#### 3A — the map, measured from the images rather than from a symbol table (AC1)

`lwlink --decb` output carries its own segment table; reading it is decisive where the link map's
per-object lengths are not:

```
intro_splash.bin (28132 B)   $0200..$6B90   27025 B      <- the intro, in one span
                             $7900..$7D43    1092 B      <- the kernel
intro_seq.bin    (2230 B)    $2000..$2462    1123 B      <- the LOADM'd stage
                             $7900..$7D43    1092 B
```

**The runtime map during an intro beat:**

| region | | |
|---|---|---|
| `$0200..$6B90` | the intro image | 27,025 B |
| **`$6B91..$77FF`** | **free** | **3,183 B** |
| `$7800..$78FF` | trace ring buffer | |
| `$7900..$7D43` | kernel | |
| `$7B7B..$7EFF` | stack space | *(per `pop.link`; see §7)* |
| `$8000..$F7FF` | MMU draw window — framebuffer | |

**★★ AND THE LOADM CEILING IS NOT THE CONSTRAINT HERE, exactly as P3.105 established.** The
`$2488..$2535` ceiling binds on what DECB must place at handover — `intro_seq.bin`'s `$2000..$2462`,
comfortably under it. The 27 KB image arrives by the driver's raw-track read. **A constraint binds on
a stage, not on a total**, and P4.11 applied the stage's constraint to the total.

#### 3B — one song, resident, no read (AC2)

| | |
|---|---|
| free | **3,183 B** |
| largest song, decompressed (`s_Buildup`) | **2,590 B** |
| **spare** | **593 B** |

**Songs play one at a time and `play_song(id, frames)` guarantees it** — peak, not sum, for the fourth
time in this project. So the option set the dispatch asked to be costed collapses:

- **a fixed resident buffer at `$6B91`** — fits; **no per-beat disk read**, so §4.8's read-before-reveal
  risk does not arise at all, and the two regressions (P3.72f, P3.78c) are not extended.
- a per-beat driver read — **unnecessary**, and it would add a read to a sequence that has already
  regressed twice on exactly that.
- decompress-on-demand — **unnecessary**, and P4.8 established it would not move the peak anyway.

**★ The songs would ship compressed on disk (3,190 B for all six, P4.8) and expand into the buffer.**
That is a design statement, not a measurement — see §7.

**593 B of margin is thin and I am not going to describe it as comfortable.** `s_Buildup` is 2,590 B
today; a re-capture, a packer change, or a row-format change moves it. **The `frac` byte alone is
20% of the row** and removing it would return ~520 B of the largest song — *a lever, unpulled,
named.*

#### 3C — what the cutscene beat does to this

**`link/pop_scene.link` stages the scene program at `$2500`** — inside the intro image's span. During
the cutscene beat the scene displaces part of the intro and the captions are reloaded afterwards
(P3.106). **`$6B91..$77FF` is above both**, so a song buffer there survives the displacement.

**★ I did not verify that on the machine.** It follows from the addresses and it is the kind of thing
this session has repeatedly found to be true in the source and different in the running system.

### 4 — Verification (AC-by-AC)

- **AC1 where a song lives, established and costed; P3.105 precedent considered; 16-colour map
  measured not inherited** — **PASS** (§3A/§3B). The map was read from the built images.
- **AC2 one song resident, not six** — **PASS** (§3B).
- **AC3-AC7, AC9 wiring, hold cost, scenery, abort, permanent assert, suites** — **NOT DONE.** No
  hard-stop fired; these are simply not built. See §6.
- **AC8 new disk read lands unseen** — **N/A by design**: the resident-buffer answer adds no read.
- **AC10 Jay's gate** — **not reached**; nothing new to hear.
- **AC11 route accounting** — §6. Karateka and `main` untouched.

### 5 — Verdict-time evidence (v0.7 §11)

```
intro_splash.bin (28132 B)   $0200..$6B90   27025 B
                             $7900..$7D43    1092 B   exec $0200
intro_seq.bin    (2230 B)    $2000..$2462    1123 B   <- the LOADM'd stage, under the ceiling
                             $7900..$7D43    1092 B   exec $2000

pop.link:  $0200-$77FF  PROGRAM (section `prog`) — 30,208 B
           $7800-$78FF  trace ring buffer

free at runtime: $6B91..$77FF = 3,183 B
largest song   : 2,590 B decompressed (s_Buildup)     -> fits, 593 B spare
```

**25.1:** N/A — nothing built. **25.2/25.3:** N/A — the gate was not reached.

### 6 — Reactive deviations and route accounting

**ROUTE ACCOUNTING — and this is the part that matters most in this report.**

**What this contains:** §1's question answered — the map, the free region, the fit, and the
consequence that no per-beat read is needed.

**What it does NOT contain, and NOT because anything stopped it:** §2 in full — the six songs wired,
the cost measured in a hold, the scenery re-checked, the abort wired to `song_stop` with a no-live-FIRQ
assertion, the PLAN-duration assert made permanent, the suites re-run, and the gate offered.
**No hard-stop fired. That work is simply not done, and calling it "blocked" would be false.**

**A correction rather than a deviation:** P4.11's "~1,840 B free" was mine and was wrong (§1). It did
not change any decision — it made the problem look harder than it is — but it was reported as a
measurement and it was a misread.

### 7 — Uncertainty flags

- **★ `$6B91..$77FF` is free by ARITHMETIC on the images, not by observation.** Nothing was run to
  confirm the region is untouched during a beat. **A write tap over that range across a full intro is
  one run and it is what I would do before putting a buffer there.**
- **`pop.link`'s own comment places stack space at `$7B7B-$7EFF`** — *above* the kernel's
  `$7900..$7D43`, which overlaps. One of the two is stale. **It does not affect `$6B91..$77FF`, but
  it means the map comment cannot be trusted where it has not been checked against a built image.**
- **The compressed-on-disk / expand-into-buffer arrangement is proposed, not built or measured.**
  `lz_unpack` expands in place from a blob the caller positions; where the packed blob would sit
  during expansion into `$6B91` is not worked out.
- **593 B of margin** is one packer change from disappearing (§3B).
- **The cutscene's `$2500` staging is reasoned from addresses, not observed** (§3C).
- **P4.11's drift figures remain ASSEMBLED, not EXECUTED** — unchanged by this dispatch, and Jay's
  acceptance is against those numbers.

### 8 — Follow-up candidates

- **Confirm `$6B91..$77FF` is untouched** with a write tap over a full intro, before relying on it.
- Then §2 as written: wire six, measure in a hold, keep the scenery decoupled, wire the abort and
  assert the FIRQ is down, make the PLAN assert permanent.
- Reconcile `pop.link`'s stack/kernel overlap (§7).
- Drop the dead `frac` byte if margin is ever wanted (−20% of every table).
- Unchanged: the timbre ruling; capture-vs-interpret; `MUSIC.SET*`; the gameplay arc's re-homed
  intents; `Demo` unbuilt.

### 9 — User interaction during task

Jay's drift ruling, verbatim: **"let's accept the drift for now and I'll see/hear it to see if it
throws anything off visually."** Recorded as acceptance pending observation, per the dispatch.

### 10 — Candidate(s) captured this task

None. P4.12's lesson — that I quoted one object's length as a section's extent — is the same
[[the-sample-was-the-specification]] shape already captured this session, and a second row would be
a duplicate rather than an instance.

### 11 — Commit

See below — pushed to origin/wip before this report.
