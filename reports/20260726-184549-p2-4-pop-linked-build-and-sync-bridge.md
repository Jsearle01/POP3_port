## Form B Report — P2.4 — POP → linked build model + the build-wired HAL-sync bridge
**Class:** BUILD — build-model conversion (absolute → object/linked) + cross-repo enforcement.
POP `wip` (conversion + bridge) and Karateka `wip` (bridge + shared guards ONLY; still absolute).
**Karateka `main` UNTOUCHED at `5eb92b1`** — verified before and after.
**Karateka prod byte-identity:** `88eba89b15cdf17c8d25e082d2d3e1f3cce57d38` — fresh pre-guard baseline,
and again after guards, after the bridge, and after the final rebuild. Never moved.

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-26T18:45:49Z (POP HEAD `a59722c`, wip; tracked tree clean).
Karateka at receipt: `wip` `c101093`, `main` `5eb92b1`, tracked clean.
Toolchain: `lwasm` **and** `lwlink`, both lwtools 4.24 (`/c/WIN_LWTools/`).

---

### 1 — Summary

**Both deliverables are in and verified. POP builds LINKED; the bridge is wired into both builds and has
been demonstrated passing, failing, and skipping — including twice when I did not intend it to.**

| | |
|---|---|
| POP build model | **object + linked** — `lwasm --obj -DOBJTARGET` → `lwlink --script=link/pop.link` |
| P1.1 probe | **PASS disk AND direct** — 6/6 observables, 2 segments verified |
| P1.3 compiled sprite | **PASS** — 492 bytes / 1968 px identical |
| ABI | **real** — 14/14 live `hal.inc` imports resolve to actual HAL addresses |
| Dormant blits | **not exported** — a POP call is now a LINK ERROR, demonstrated |
| Karateka | **byte-identical**, still absolute, guard-off; 6/6 informative tests PASS |
| Bridge | wired into **both** `build.bat`s; PASS + FAIL(both directions) + SKIP all demonstrated |

**The equivalence claim is stronger than "the test passed."** The linked binary's `$0200` segment is
**byte-identical** to the absolute build's 149-byte payload, with the same exec address. The linked output is
not merely behaviourally similar — it is the same program, plus a kernel segment at `$3000`. That also proves
dropping `setdp` in the object build cost nothing: no direct-page optimisation was being relied on.

**The ABI is now enforced by the toolchain, and I measured exactly how far that goes.** `lwlink` errors only
on a **referenced** undefined symbol — an unreferenced `import` links clean (§3.3). So the contract is
enforced at the point of USE, not of declaration, and "hal.inc's imports resolve" is only a real claim for
symbols something actually calls. That is why `hal_link_proof.s` calls **all fourteen** live entry points
rather than one.

**Two findings the recon could not have produced, because they only appear on real code:**

1. **`setdp` is a FOURTH object-incompatible directive class.** P2.3-recon enumerated three (`export`,
   `import`, `section`/`endsection`) from toy probes that had no direct-page usage to declare. POP's real HAL
   declares it in nine files, and every one errored.
2. **The P1.1 harness assumed a single-segment binary.** Its disk-mode gate polled `$0200` and posted `EXEC`
   the instant it saw `7E 02 08`. Correct for an absolute build. A linked binary has two segments and `$0200`
   lands *first*, so the gate typed `EXEC` into a still-running `LOADM`. The probe never ran, and the failure
   presented as a code fault. Direct mode passing while disk mode failed is what separated the two.

**The bridge caught two real drifts during its own dispatch, neither of them planted.** Once when I edited the
checker in POP and not in Karateka; once when a repair script double-applied a guard block across nine files.
Both were mine, both would have shipped unnoticed, and both were caught by the pre-build step on the next
build. That is better evidence than the injected demo.

---

### 2 — Files modified

**POP `wip` (commit `dd1cec4`):**
- `build.bat` — **converted**: obj-per-unit + `lwlink`, plus the HAL-sync pre-build step.
- `link/pop.link` — **NEW**. The linker script / memory map.
- `harness/tools/hal_sync_check.py` — **NEW**. The bridge (identical copy in both repos).
- `harness/smoke/probe_test.lua` — segment-aware disk gate (§3.6).
- `src/harness/hal_link_proof.s` — **NEW**. The ABI proof program.
- `src/harness/hal_build.s`, `src/harness/loop_probe.s` — guarded (`org`/`end`/`section`/`setdp`).
- `src/hal.inc` — 20 `import`s guarded.
- `src/hal/coco3-dsk/{sys,time,irq_vbl,gfx,input,sound,file,mem,hal_globals}.s` — guarded sections/exports/setdp.

**Karateka `wip` (commit `372cd6d`) — bridge + shared guards ONLY:**
- `build.bat` — HAL-sync pre-build step. **No other change; still `--decb`.**
- `harness/tools/hal_sync_check.py` — **NEW**, byte-identical to POP's.
- `src/hal.inc`, `src/hal/coco3-dsk/*.s` — the same guards (OFF here).

**Not modified:** Karateka `main`; any engine code; `oracle/source/`; POP's `dist/mame-cfg/` (MAME rewrote it
during test runs again — restored, §6.5).

---

### 3 — Reasoning

#### 3.1 — Preconditions
POP `a59722c` clean; Karateka `wip` `c101093`, `main` `5eb92b1`, clean; `lwasm`+`lwlink` 4.24 both present.

#### 3.2 — Phase A: guarding the shared source (§2a)

Four directive classes are rejected by `lwasm`'s absolute target and must be conditional: `export`, `import`,
`section`/`endsection`, and — new here — **`setdp`**. All are wrapped in `ifdef OBJTARGET`, the mechanism
P2.1 already established as governance rule 3 (configuration, not fork).

**The blit exports had to follow the code, not a rule.** POP guards the six runtime-blit entry points dormant;
Karateka has no guard and calls all six from 25 live sites. So POP's blit exports **nest inside the dormancy
guard** while Karateka's sit at top level — exporting a symbol that does not exist is an assembly error, so
this is forced, not stylistic. My first attempt applied one layout to both repos and failed on Karateka
immediately; the fix was to detect the guard's presence rather than assume it.

**Hard-stop 11.2, cleared against a FRESH baseline.** I rebuilt Karateka before touching anything rather than
trusting the known SHA:
```
PRE (fresh build):  88eba89b15cdf17c8d25e082d2d3e1f3cce57d38   17,978 bytes
POST (guards in):   88eba89b15cdf17c8d25e082d2d3e1f3cce57d38   BYTE-IDENTICAL
```

#### 3.3 — Phase A: the ABI is real, and its limit is measurable

Two probes settled how far linking enforces the contract:

| probe | result |
|---|---|
| `import never_defined_symbol`, **not called** | `lwlink` **exit 0** — links clean |
| `import never_defined_symbol`, **JSR'd** | `External symbol ... not found`, **exit 1** |

**Enforcement is at the point of use.** An unreferenced declaration costs nothing and proves nothing. This is
why `hal_link_proof.s` calls every one of the 14 live entry points, and why the six dormant ones can safely
remain declared-but-unexported. All 14 resolved:
```
$0200: JSR $3000 -> HAL_sys_init        $0211: JSR $30B6 -> HAL_gfx_init
$0203: JSR $3058 -> HAL_time_init       $0214: JSR $3110 -> HAL_gfx_clear
$0206: JSR $3078 -> HAL_time_vbl_wait   $0217: JSR $312E -> HAL_gfx_present
$0209: JSR $3090 -> HAL_time_frame_count  ... 14 of 14, 0 unresolved
```

**The dormancy guard became build-enforced, which it was not before.** A POP call to a dormant blit:
```
External symbol HAL_gfx_blit_sprite_masked not found in dormant_probe.o:prog
lwlink exit=1
```
In the absolute build the same call assembled to a `JSR` at whatever address the label happened to resolve to.
The linked model converted a silent wrong answer into a loud one.

#### 3.4 — Phase A: the linker script (§2b, AC4)

`--section-base` is **silently ignored** (P2.3-recon D4) — no error, exit 0, section still at the default. A
conversion that used the flag and checked the exit code would place everything wrong and look healthy. Only a
script places sections. `link/pop.link` records the full map with its references, and states plainly why the
program is low and the kernel high: **`$0200` is forced**, because `probe_test.lua` reads `probe_status` at
`$0203` as a literal address and gates `LOADM` on `7E 02 08` at `$0200`. Kernel-low is the better long-term
shape and the script says so; it becomes available when the engine replaces the probe.

Placement verified from the map, not assumed:
```
Section: prog (loop_probe.o) load at 0200, length 0095
Section: code (hal_build.o)  load at 3000, length 0181
```

#### 3.5 — Phase A: equivalence (hard-stop 11.4)

```
ABSOLUTE : [('DATA','0x200',149), ('EXEC','0x200',0)]
LINKED   : [('DATA','0x200',149), ('DATA','0x3000',385), ('EXEC','0x200',0)]
*** PROBE PAYLOAD BYTE-IDENTICAL ***
```

#### 3.6 — The harness fix, and why it was required rather than incidental

P1.1 failed on first run under the linked model. **Direct mode passed all six observables** while disk mode
failed after "posted EXEC" — which located the fault in the DECB load path, not the code. The gate polled
`$0200` alone; with two segments, `$0200` lands first and `EXEC` was typed into a running `LOADM`.

Fixed by verifying **every** segment (first and last byte) before posting `EXEC`, reusing the DECB parser the
Lua already had for direct mode. Gating on the last segment rather than the first holds for any segment count,
so adding kernel sections later cannot silently re-break it. The 14-frame delay between the old gate (frame
592) and the new one (frame 606) is the kernel segment landing — the race, measured.

This is harness code, not engine code, and the conversion could not pass without it.

#### 3.7 — Phase B: the bridge, and the judgment inside it (§3a, AC5)

**Location (§2A.3, Clyde's call): one byte-identical copy in each repo, at the same path, included in its own
compared set.** A single canonical copy referenced by both would make each repo depend on the other, and would
be unreachable in exactly the case the graceful skip exists for. Self-inclusion answers "who watches the
watcher" — and it forced the sibling path to be **derived** from a `{POP3_port ↔ karateka_coco3}` map rather
than written in, since a per-repo path constant would make the copies differ permanently.

**What counts as sanctioned divergence — the load-bearing judgment.** Tolerated: line endings (both trees are
internally mixed and cross-repo different — a byte diff false-fails on every file and the check gets disabled
within a week); the POP dormancy guard's own directive lines (**the code inside is still compared**); export
*placement*, compared as a per-file set so the ABI surface is still checked; comment-only lines; and one
declared POP-local file (`hal_globals.s`, whose Karateka counterpart lives in engine code POP does not have).
Everything else — every instruction, every `equ`, the whole `hal.inc` contract — must match exactly.

**Wired as a pre-build step in both `build.bat`s**, failing the build on drift, warning-and-continuing when
the sibling is genuinely absent.

#### 3.8 — Phase B: demonstrated failing (§3d, AC6)

Injected a real `nop` into POP's `time.s` — an instruction, not a comment. **Both** builds blocked, naming the
file and the differing line, exit 1 each. Reverted.

**More convincing were the two unplanned catches.** (a) I edited the checker in POP only; the next POP build
blocked on `hal_sync_check.py` itself. (b) A repair script double-applied a guard block across nine files; the
check flagged all nine before any build could consume them. Neither was planted, and neither would have been
noticed otherwise.

---

### 4 — Verification (AC-by-AC)

- **AC1 — POP builds LINKED, P1.1 passes. MET.** `=== BUILD COMPLETE ===`; P1.1 **PASS in disk mode** (6/6,
  2 segments verified) **and direct mode** (6/6). Verbatim §5.
- **AC2 — the exports make the ABI real. MET.** 14/14 live imports resolve to real HAL addresses (§3.3), with
  the enforcement boundary measured (referenced vs unreferenced) rather than assumed.
- **AC3 — Karateka byte-identical under guard-off. MET.** `88eba89b…` against a fresh pre-change baseline,
  re-verified after the bridge and after the final rebuild. 6/6 informative tests PASS.
- **AC4 — linker script is a real, documented artifact. MET.** `link/pop.link` — full memory map with
  references, the `--section-base` silent-ignore trap, and why `$0200` is forced. Placement verified from the
  map.
- **AC5 — sync check EOL-normalised and guard-aware. MET.** Passes on the current aligned state from **both**
  directions; 11 files compared.
- **AC6 — build-wired in BOTH repos, demonstrated failing. MET.** Both builds blocked on an injected
  instruction-level drift, exit 1 (§3.8), plus two unplanned real catches.
- **AC7 — graceful skip demonstrated. MET.** Sibling moved aside → `WARNING ... SKIPPED`, build ran to
  `=== BUILD COMPLETE ===`, **exit 0**. Sibling restored.
- **AC8 — Karateka change is only the bridge (+ shared guards), on `wip`. MET.** `main` `5eb92b1` local and
  remote. Karateka still builds `--decb`.
- **AC9 — clean status. MET.** Both repos clean but for the intended commits + this report + standing
  untracked (`docs/ground-truth/` PDFs, per Jay's standing ruling).

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 — hard-stop 11.2, guard-off byte-identity (verbatim):**
```
=== HARD-STOP 11.2: guard-off byte-identity ===
PRE : 88eba89b15cdf17c8d25e082d2d3e1f3cce57d38
POST: 88eba89b15cdf17c8d25e082d2d3e1f3cce57d38
*** BYTE-IDENTICAL - guard-off costs karateka nothing ***
```

**25.1 — the fourth directive class (verbatim):**
```
src/hal/coco3-dsk/hal_globals.s(21) : ERROR : SETDP not permitted for object target
src/hal/coco3-dsk/sys.s(74)  : ERROR : SETDP not permitted for object target
... nine modules, same error
```

**25.1 — POP LINKED BUILD (verbatim):**
```
[hal-sync] OK -- HAL source aligned with karateka_coco3 (11 files compared, EOL/guard/export-placement normalised)
--- Assemble: HAL kernel unit (object) ---     build/obj/hal_build.o (1358 bytes)
--- Assemble: P1.1 loop probe (object) ---     build/obj/loop_probe.o (414 bytes)
--- Assemble: HAL ABI link proof (object) ---  build/obj/hal_link_proof.o (383 bytes)
--- Link: probe + HAL kernel ---               build/loop_probe.bin (549 bytes)
--- Link: HAL ABI proof (every live hal.inc import must resolve) ---
                                               build/hal_link_proof.bin (444 bytes)
--- Bootable RS-DOS disk image ---             build/probe.dsk (161280 bytes)
PROBE.BIN   549   2 B
=== BUILD COMPLETE ===
```

**25.1 — section placement, from the map (verbatim):**
```
Section: prog (build/obj/loop_probe.o) load at 0200, length 0095
Section: code (build/obj/hal_build.o)  load at 3000, length 0181
```

**25.1 — the ABI resolved (verbatim):**
```
$0200:  JSR $3000   -> HAL_sys_init          $0214:  JSR $3110   -> HAL_gfx_clear
$0203:  JSR $3058   -> HAL_time_init         $0217:  JSR $312E   -> HAL_gfx_present
$0206:  JSR $3078   -> HAL_time_vbl_wait     $021A:  JSR $3146   -> HAL_input_init
$0209:  JSR $3090   -> HAL_time_frame_count  $021D:  JSR $315D   -> HAL_input_poll
$020E:  JSR $309B   -> HAL_time_delay        $0220:  JSR $3177   -> HAL_sound_init
$0211:  JSR $30B6   -> HAL_gfx_init          $0223:  JSR $317A   -> HAL_file_init
                                             $0226:  JSR $317D   -> HAL_mem_size_detect
                                             $0229:  JSR $3056   -> HAL_sys_panic
14 cross-module JSRs, 14 resolved to real HAL entry points, 0 unresolved
```

**25.1 — the enforcement boundary, measured (verbatim):**
```
import never_defined_symbol, NOT called:  lwlink exit=0     <- links clean
import never_defined_symbol, JSR'd:
  External symbol never_defined_symbol not found in p2.o:code
  Incomplete reference at p2.o:code+04
  lwlink exit=1
```

**25.1 — dormant blit is a LINK ERROR (verbatim):**
```
External symbol HAL_gfx_blit_sprite_masked not found in build/obj/dormant_probe.o:prog
Incomplete reference at build/obj/dormant_probe.o:prog+01
lwlink exit=1
```

**25.1 — behavioural equivalence (verbatim):**
```
ABSOLUTE : [('DATA', '0x200', 149), ('EXEC', '0x200', 0)]
LINKED   : [('DATA', '0x200', 149), ('DATA', '0x3000', 385), ('EXEC', '0x200', 0)]
probe payload  absolute=149 B   linked=149 B
*** PROBE PAYLOAD BYTE-IDENTICAL - the linked output IS the same program ***
```

**25.1 — P1.1 under the linked model, DISK mode (verbatim):**
```
# disk: image present at frame 606 ($0200 = 7E 02 08, 2 segment(s) verified)
# probe RUNNING at frame 672 (PC=$0270)
# probe COMPLETE at frame 791
magic_is_BEEF                PASS want $BEEF got $BEEF
status_is_complete           PASS want 2 got 2
probe_vbl_count              PASS want 120 got 120
framebuffer_A_fill           PASS all 15360 bytes = $1B
framebuffer_B_fill           PASS all 15360 bytes = $E4
mame_frames_match_vbls       PASS MAME frame delta 119 vs expected 120 (tol +/-2)
# checks=6 passed=6 failed=0
# VERDICT: PASS
[run_probe_test] PASS
```

**25.1 — P1.3 regression (verbatim):**
```
magic_is_C0DE                PASS got $C0DE
framebuffer_matches_cel      PASS all 492 bytes (1968 px) identical
# VERDICT: PASS
[run_compiled_test] PASS
```

**25.1 — BRIDGE DEMO 1, PASS aligned + karateka byte-identical (verbatim):**
```
[hal-sync] OK -- HAL source aligned with POP3_port (11 files compared, EOL/guard/export-placement normalised)
--- Production binary ---   build/karateka.bin (17978 bytes)
=== BUILD COMPLETE ===
PRE : 88eba89b15cdf17c8d25e082d2d3e1f3cce57d38
POST: 88eba89b15cdf17c8d25e082d2d3e1f3cce57d38
*** BYTE-IDENTICAL - AC3 holds with guards + bridge in place ***
```

**25.1 — BRIDGE DEMO 2, FAIL on injected drift, BOTH directions (verbatim):**
```
--- POP build ---
[hal-sync] *** HAL DRIFT -- BUILD BLOCKED ***
[hal-sync] POP3_port vs karateka_coco3
[hal-sync]   src/hal/coco3-dsk/time.s: content differs at substantive line 52
        POP3_port: nop ; DELIBERATE P2.4 DRIFT DEMO
        karateka_coco3: deca ; decrement
*** BUILD BLOCKED BY HAL DRIFT ***                              exit=1

--- KARATEKA build (same drift, other direction) ---
[hal-sync] *** HAL DRIFT -- BUILD BLOCKED ***
[hal-sync] karateka_coco3 vs POP3_port
[hal-sync]   src/hal/coco3-dsk/time.s: content differs at substantive line 52
        karateka_coco3: deca ; decrement
        POP3_port: nop ; DELIBERATE P2.4 DRIFT DEMO
*** BUILD BLOCKED BY HAL DRIFT ***                              exit=1
```

**25.1 — BRIDGE DEMO 3, GRACEFUL SKIP (verbatim):**
```
[hal-sync] WARNING: sibling repo not found at C:\Projects\karateka_coco3 -- HAL-sync check SKIPPED
--- Assemble: HAL kernel unit (object) ---
=== BUILD COMPLETE ===
--- exit code (must be 0 = WARN and continue) ---   exit=0
```

**25.1 — the two UNPLANNED catches (verbatim):**
```
[hal-sync]   harness/tools/hal_sync_check.py: content differs at substantive line 120
        POP3_port: drift.append((rel, 'ABI surface differs -- ' + '; '.join(bits)))
        karateka_coco3: drift.append((rel, 'ABI surface differs ? ' + '; '.join(bits)))

[hal-sync]   src/hal/coco3-dsk/sys.s: content differs at substantive line 3
        POP3_port: ifdef OBJTARGET
        karateka_coco3: setdp 0                     ... and six more files
```

**25.1 — karateka informative tests, post-change (verbatim):**
```
run_gfx_init_precheck        exit=0    RESULT: PASS
run_gfx_init_test            exit=0    MAME TEST: PASS
run_kernel_dispatch_test     exit=0    MAME TEST: PASS
run_sys_init_test            exit=0    RESULT: PASS
run_timer_framesync_test     exit=0    MAME TEST: PASS
run_vbl_irq_test             exit=0    MAME TEST: PASS
```

**25.2 — artifacts:** `link/pop.link`; `harness/tools/hal_sync_check.py` (identical in both repos);
`build.bat` (POP, converted + wired) and `build.bat` (Karateka, wired only);
`src/harness/hal_link_proof.s`; `harness/smoke/probe_test.lua`.
POP `wip` `dd1cec4`; Karateka `wip` `372cd6d`; Karateka `main` `5eb92b1` untouched.

**25.3 — N/A per §8.** The probe render did not change: the `$0200` payload is byte-identical and all six
observables (including both full framebuffer scans) match the same spec. Nothing to surface.

---

### 6 — Reactive deviations

1. **`setdp` — a fourth object-incompatible directive class** (§3.2), not in the recon's set of three. Nine
   files affected. Guarded the same way; the linked probe's byte-identity proves it cost nothing.
2. **The P1.1 Lua harness had to change** (§3.6). Not cosmetic — the conversion could not pass without it, and
   the old gate's single-segment assumption was invisible until a binary had two segments. Harness code, not
   engine code.
3. **`hal_link_proof.s` is a new file the dispatch did not name.** AC2 asks for the imports to resolve and the
   cross-module call to work *on POP's real HAL*; nothing in POP called the HAL (P2.1 §7.1), and adding calls
   to the probe would have broken the equivalence hard-stop. A separate program satisfies both.
4. **Blit-export placement differs per repo** (§3.2) — forced by where the code is, not chosen.
5. **`dist/mame-cfg/rgb/coco3.cfg` restored again.** MAME rewrites it on exit and strips its comment block;
   the RGB setting survives. Same as P2.2-merge. It is a template, not a constant.
6. **A `git checkout --` during the drift demo reverted uncommitted P2.4 guards along with the injected
   `nop`**, so the graceful-skip demo initially ran against a broken tree and printed `*** BUILD FAILED ***`
   after a correct `SKIPPED` warning. Guards restored and the demo re-run clean (§5). Reported because that
   first demo output is misleading on its face — the skip worked; the build failed for an unrelated,
   self-inflicted reason.
7. **The repair for (6) double-applied the setdp guard** across nine files (its idempotence check looked back
   4 lines; the block is 7 deep). Caught by the bridge, normalised, re-verified.

---

### 7 — Uncertainty flags

1. **POP's HAL still is not exercised at runtime.** P2.1 §7.1 stands. The probe carries its own inline GIME
   setup and does not call the HAL; `hal_link_proof.s` links but is not meant to run. POP's green means the
   HAL **assembles, links, and exposes a resolvable ABI** — not that POP's HAL executes. This is now the
   oldest open item and the cheapest remaining real proof.
2. **The kernel's `$3000` placement is provisional.** It is headroom, not a measurement, and the
   program-low/kernel-high layout is forced by the harness's literal `$0203`. Revisit when the engine replaces
   the probe.
3. **Only the 6 informative Karateka tests were re-run**, not all 17 — justified by byte-identity, still a
   subset. The four known-broken runners remain broken on both branches.
4. **The sync check tolerates comment divergence by design.** A contract change made *only* in a comment (a
   changed reference, a revised calling-convention note) will not fail a build. That is deliberate — failing
   builds over prose trains people to bypass the check — but it is a real gap, and `hal.inc` carries a lot of
   load-bearing prose.
5. **`hal.inc`'s nine `equ *` stubs are meaningless in the object build** (they equate to a section-relative
   `*`). They were equally meaningless in the absolute build, where they equated to wherever the include
   landed. They are markers for unimplemented entry points, not addresses — but nothing enforces that.
6. **The bridge assumes both repos sit as siblings** under `/c/Projects` with those exact directory names. Any
   other layout silently degrades to the graceful skip — correct behaviour, but it means "no drift reported"
   and "not checked" look similar in a log. The WARNING line is the only distinguisher.

---

### 8 — Follow-up candidates

1. **Make POP's HAL actually run** (§7.1) — re-point a probe at `HAL_gfx_init` and friends now that they link.
   Small, and it closes the oldest gap.
2. **Karateka's linked conversion** — the guards are already in place and OFF, so the remaining work is its
   `build.bat` and a linker script. That is the step that retires this bridge.
3. **The single-source extraction** — the milestone the bridge protects. Deleting `hal_sync_check.py` and its
   two call sites is the completion signal.
4. **Revisit the memory map** when the engine replaces the probe (§7.2) — kernel-low is the better shape.
5. **Decide whether comment drift should be checkable** (§7.4), e.g. comparing `[ref:]` markers specifically
   without failing on prose.
6. Standing: the **§2A.3 authorship ruling** (now **twenty** deferrals). This dispatch made a §2A.3 call
   (script location) and recorded the reasoning inline rather than in an idioms file.

---

### 9 — User interaction during task
**None during execution.** The dispatch carried the design (build-wired bridge, POP-first sequencing, graceful
skip) and the authorisation for the Karateka-side change.

---

### 10 — Candidate(s) captured this task
`seeds/POP/live/2026-07-26-wire-the-consistency-check-into-the-build-not-into-a-convention.md` — enforcement
belongs in the build, not in a convention; it must be shown failing; graceful skip is what keeps it alive; and
temporary infrastructure should name its own deletion condition. Committed and pushed to the pool.

---

### 11 — Commit
**POP:** `dd1cec4` (conversion + bridge) + `760396f` (this report) — pushed to POP `origin/wip`.
**Karateka:** `372cd6d` on `wip` — bridge + shared guards only, still absolute. Pushed.
**Karateka `main` @ `5eb92b1` — untouched.**
