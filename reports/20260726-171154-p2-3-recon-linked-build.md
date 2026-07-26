## Form B Report — P2.3-recon — can ONE HAL source serve both absolute AND linked builds?
**Class:** RECON — fact-finding only. `wip`. **Prod byte-identity: N/A** (throwaway probes).

### 0 — Receipt / status (C-35 stamp)
t0=2026-07-26T17:11:54Z (HEAD `31e520c`, wip). Tracked tree **clean** at receipt.
**Toolchain:** `lwasm` **and** `lwlink` both present, both **lwtools 4.24** (`/c/WIN_LWTools/`). `lwlink`
supports `--decb`, `--entry=SYM`, `--script=FILE`, `--section-base`, and formats `decb, raw, lwex, os9, srec,
ihex`. Probes in `harness/tmp/linktest/` — throwaway, nothing added to `src/`.

---

### 1 — Summary

**ANSWER: ONE HAL SOURCE CAN SERVE BOTH MODELS. NO FORK. The one-kernel invariant is preserved, and POP-first
is clean — not a compromise.**

But **not** by the route the dispatch hypothesised. The hinge question ("does absolute tolerate `export`?")
came back **NEGATIVE**:

```
q1_with.s(2) : ERROR : Only supported for object target (EXPORT)     exit=1
```

`lwasm --decb` **errors** on `export`, produces no binary. Same for `import`, and — a third thing the dispatch
didn't anticipate — the same for `section`/`endsection` ("Cannot use sections unless using the object
target"). By the dispatch's stated logic that forces "both-together".

**It doesn't, because there is a third path the binary framing missed: conditional assembly.** Guard the
object-only directives behind `ifdef OBJTARGET` and the *identical file* builds both ways. Proven end to end:

| | absolute (`--decb`, guard off) | object+link (`--obj -DOBJTARGET`) |
|---|---|---|
| assembles | **exit 0** | **exit 0** |
| output | 16 B, **byte-identical** to a plain no-export build (`adfb350a…`) | 46 B object |
| links | n/a | **`lwlink` exit 0**, cross-module `JSR` resolved to `$200A` |
| **runs in MAME** | n/a | **`$0400 = $A5`, `$0401 = $5A` — PASS** |

The mechanism is **exactly the one P2.1 already used** for the runtime-blit dormancy guard, which the HAL
governance already sanctions as per-project **configuration, not a per-project fork**. So this needs no new
concept — it reuses a pattern already accepted in this codebase.

**Therefore: POP can move to a linked HAL while Karateka stays absolute, from ONE shared source.** Karateka
co-assembles it (guards off, byte-identical output to today); POP assembles it to objects and links (guards
on, exports live). Two build scripts, which are already allowed to differ. One kernel.

**Bonus (D4): `--section-base` is silently ignored** — both `=code=0x4000` and `=code=16384` still loaded at
`$2000`. A **linker script works**: `section code load 4000` → load addr `$4000`. A real conversion needs a
script, not the flag.

---

### 2 — Files modified
- `reports/20260726-171154-p2-3-recon-linked-build.md` — this report.
- `harness/tmp/linktest/` — **throwaway probes, explicitly disposable** (10 tiny files: `q1_*.s`, `a.s`, `b.s`,
  `c.s`, `d.s`, `link.scr`, `run.lua` + build artifacts).

**Not modified:** `src/`, the HAL, `hal.inc`, `build.bat`, Karateka, `oracle/source/`. No build conversion.

---

### 3 — Reasoning

#### 3.1 — Q1: absolute does NOT tolerate `export` (the hinge, answered unambiguously)

Two files identical but for one `export` line:

| probe | result |
|---|---|
| `q1_without.s` (`--decb`) | exit 0, 16 B, md5 `adfb350a5a1b22074ca07e99aaddc3eb` |
| `q1_with.s` (`--decb`) | **`ERROR : Only supported for object target (EXPORT)`, exit 1, no binary** |
| `q1_import.s` (`--decb`) | **`ERROR : Only supported for object target (IMPORT)`** |

The byte-identical check the dispatch asked for could not be performed *as framed* — there is no second binary
to compare, because the assembler refuses to emit one. That is a stronger answer than "differs": **absolute
rejects the directive outright.**

This also explains P2.2's finding cleanly. `hal.inc` carries 16 `import` directives; it is not merely
"not included" by convention — it is **structurally unincludable** in a `--decb` build. Same error, same cause.

#### 3.2 — The third path, and why the dispatch's binary framing missed it

The dispatch framed Q1 as tolerated-or-errors, with "errors → fork forced". That treats the directive as
unconditionally present in the source. It needn't be. `lwasm` supports `ifdef`/`else`/`endc`, and P2.1 already
uses exactly that to keep POP's runtime-blit dormant while leaving the code byte-identical to Karateka's.

Applying the same mechanism to the object-only directives:

```asm
                ifdef   OBJTARGET
                export  foo
                section code
                else
                org     $4000
                endc
foo             lda     #$A5
                sta     $0400
                rts
                ifdef   OBJTARGET
                endsection
                endc
```

- `lwasm --decb c.s` → exit 0, and the binary is **byte-identical** to the plain no-export version.
- `lwasm --obj -DOBJTARGET c.s` → exit 0, valid object.

**Three directive classes need guarding, not one:** `export`, `import`, and `section`/`endsection`. The third
is the one most likely to be missed — it errors for the same reason but is easy to overlook because it isn't
about symbol visibility. Absolute builds need an `org` where object builds need a `section`, which the `else`
branch supplies.

#### 3.3 — Q2: the linked path works, proven by execution not by exit code

Two modules — `c.s` exports `foo` (writes `$A5` to `$0400`), `d.s` imports it, calls it, then writes `$5A` to
`$0401` to prove the call *returned*. Assembled `--obj`, linked with `lwlink --decb --entry=start`.

The emitted code proves the linker did its job:
```
BD 20 0A  86 5A  B7 04 01  20 FE  86 A5  B7 04 00  39
JSR $200A  LDA #$5A  STA $0401  BRA *   LDA #$A5  STA $0400  RTS
     ^-- resolved cross-module target; foo sits at $200A
```
Loaded into MAME through P1.1's direct-load harness with both target bytes pre-cleared to `$00`:
`$0400 = $A5`, `$0401 = $5A`. **The cross-module call executed and returned.** Exit codes alone would not have
shown that; the second byte is what proves control came back.

#### 3.4 — Q3: the conclusion, in one-kernel terms

**One HAL source, carrying guarded `export`/`import`/`section` directives, builds both models.** Karateka
continues to co-assemble it absolute with the guards off — and its output is byte-identical to what it builds
today, so adopting the guards costs Karateka nothing. POP assembles the same file to objects with
`-DOBJTARGET` and links it.

**The one-kernel invariant is preserved.** The two repos hold the same HAL source; only the build scripts
differ, and they are already permitted to. **POP-first is correct, not a compromise** — and, importantly, it
does not require converting Karateka on POP's schedule.

#### 3.5 — D4: the linker-script shape

`--section-base` is **silently ignored** — no error, no warning, code still at `$2000`:
```
--section-base=code=0x4000 -> load addr $2000
--section-base=code=16384  -> load addr $2000
```
A linker script works:
```
section code load 4000
entry start
```
→ load addr `$4000`, exec `$4000`.

**Shape a real POP conversion would need:** one section per placement region, since the absolute build
currently bakes addresses that a linker must be told — the framebuffers at `$8000`/`$C000`
(`KCOCO3_FB_A_BASE`/`_B_BASE`), the `$0200` DECB load/exec address, the trace buffer at `$7800`, and the DP
band split (HAL `$00-$1F` / engine `$20-$7F`) which is `setdp`/`equ` rather than a section. **Silent-ignore is
the gotcha to carry forward** — a conversion that used the flag and checked only the exit code would place
everything at the default and look fine.

---

### 4 — Verification (AC-by-AC)

- **AC1 — Q1 definitive. MET.** `export` in `--decb`: **ERROR, exit 1, no binary** (§3.1, verbatim §5). The
  byte-identical check is reported as *not performable as framed* and why — the assembler refuses to emit.
  Unambiguous.
- **AC2 — Q2 answered; `lwlink` confirmed. MET.** `lwlink` 4.24 present. Two-module `--obj` + link **exit 0**,
  cross-module `JSR` resolved to `$200A`, and the binary **runs in MAME**: `$0400=$A5`, `$0401=$5A`.
- **AC3 — Q3 concluded plainly, no hedging. MET.** **One source CAN serve both models; NO fork; POP-first is
  clean** (§3.4) — via guarded directives, which is neither of the two outcomes the dispatch enumerated.
- **AC4 — throwaway only. MET.** Everything under `harness/tmp/linktest/`. `src/`, HAL, `build.bat`, Karateka
  all untouched (§5).

---

### 5 — Verdict-time evidence (v0.7 §11)

**25.1 — Q1, the hinge (verbatim):**
```
=== Q1a: absolute (--decb) WITHOUT export ===        exit=0
=== Q1b: absolute (--decb) WITH export ===
q1_with.s(2) : ERROR : Only supported for object target (EXPORT)
  exit=1
  q1_without.bin 16 bytes
  cmp: q1_with.bin: No such file or directory        <- no binary emitted at all
  adfb350a5a1b22074ca07e99aaddc3eb *q1_without.bin

=== Q1c: import in absolute ===
q1_import.s(2) : ERROR : Only supported for object target (IMPORT)
```

**25.1 — the third path, guarded (verbatim):**
```
--- absolute (--decb), guard OFF: ---   exit=0
--- byte-identical to the plain no-export build? ---
  *** BYTE-IDENTICAL to q1_without.bin ***
  adfb350a5a1b22074ca07e99aaddc3eb *q1_without.bin
  adfb350a5a1b22074ca07e99aaddc3eb *q1_guarded_abs.bin
```

**25.1 — sections also need guarding (verbatim):**
```
a.s(5) : ERROR : Cannot use sections unless using the object target
a.s(9) : ERROR : Cannot use sections unless using the object target
```

**25.1 — ONE source, BOTH models (verbatim):**
```
--- ABSOLUTE (--decb, guard off): ---        exit=0
--- OBJECT (--obj -DOBJTARGET, guard on): ---  exit=0
  c_abs.bin 16 bytes      c_obj.o 46 bytes
--- absolute output byte-identical to the plain no-export build? ---
  *** BYTE-IDENTICAL to q1_without.bin ***
```

**25.1 — Q2, link + run (verbatim):**
```
  d_obj.o exit=0        lwlink exit=0
  linked2: 16 bytes @ $2000
    BD 20 0A 86 5A B7 04 01 20 FE 86 A5 B7 04 00 39
    JSR target = $200A  (foo, resolved by the linker)

  loaded, exec=$2000
  $0400 = $A5  (want $A5 — written by foo, the LINKED-IN module)
  $0401 = $5A  (want $5A — written after foo RETURNED)
  VERDICT: PASS — cross-module call executed and returned
```

**25.1 — D4, section placement (verbatim):**
```
  --section-base=code=0x4000 -> load addr $2000     <- SILENTLY IGNORED
  --section-base=code=16384  -> load addr $2000     <- SILENTLY IGNORED
  script-linked load addr = $4000   exec = $4000    <- linker script WORKS
```

**25.2 — throwaway probes:** `harness/tmp/linktest/` — disposable, retained only as evidence.

**25.3 — N/A.** No visual; the `$0400`/`$0401` assertion is the observable. No PNG generated or surfaced.

**`git status --porcelain` (tracked):** the report + `harness/tmp/linktest/`. `src/`, HAL, `build.bat`,
Karateka: untouched.

---

### 6 — Reactive deviations

1. **The dispatch's two-outcome framing was incomplete, and the answer lies outside it.** Q1 came back
   "errors", which the dispatch maps to "fork forced / both-together". I did not stop there, because
   conditional assembly is a third option and this codebase already uses it (P2.1's dormancy guard). Reporting
   the conclusion the *evidence* supports rather than the branch the dispatch pre-assigned to that evidence.
2. **A third directive class needed guarding.** The dispatch named `export`/`import`; `section`/`endsection`
   fails identically and is required by the object model. Found by testing, not anticipated.
3. **`--section-base` silently ignored** (§3.5) — no error, wrong address. Surfaced because a future conversion
   checking only exit codes would be misled.
4. **Probes left in-tree under `harness/tmp/linktest/`** rather than deleted, as §9 permits, so the evidence is
   reproducible. Marked disposable; delete freely.

---

### 7 — Uncertainty flags

1. **The probes are trivial compared to the real HAL.** Two modules, one cross-module call, one section. The
   real conversion has ~10 modules, DP equates shared across files, `setdp`, hardware equates, and
   `hal_globals.s`-style declarations that currently rely on single-pass co-assembly visibility. **The
   one-source pattern is proven; its cost at HAL scale is not.**
2. **Karateka's absolute build was NOT re-run with guards applied.** I proved a *toy* file is byte-identical
   with guards off. I did not add guards to any real HAL module or rebuild Karateka. The claim "costs Karateka
   nothing" is inferred from the toy, not measured on the artifact — **that is the first thing a conversion
   dispatch should verify**, and it is cheap (rebuild, compare `88eba89…`).
3. **Cross-module symbol visibility is the unquantified risk.** Absolute co-assembly makes *every* symbol
   visible to every file; the object model makes only exported ones visible. Any HAL/engine symbol currently
   relied on implicitly must become an explicit `export`/`import` pair. P2.1 already found 6 such couplings
   (`page_register`, `PAGE_A_TOKEN`, `s4_dest_row`, …) — there are likely more, and each needs guarding on
   both sides.
4. **DP/`setdp` behaviour under linking was not tested.** The HAL's DP policy is central and `setdp` is an
   assemble-time directive; whether the object model changes anything there is unverified.
5. **No `lwar`/library packaging was explored** — relevant if the "kernel" is eventually distributed as a
   library rather than linked from objects.

---

### 8 — Follow-up candidates

1. **Cheapest next step, and it de-risks everything:** add the guards to ONE real HAL module, rebuild Karateka
   absolute, and confirm the prod binary is still `88eba89…`. Converts §7.2 from inference to measurement for
   near-zero cost.
2. **Enumerate the implicit cross-module symbols** the object model would require explicit `export`/`import`
   for (§7.3) — sizes the real conversion better than any estimate.
3. **Write the real linker script** for POP's placement map (§3.5), gated on 1 & 2.
4. **The `hal.inc` question P2.2 raised is now answerable:** its 16 `import` directives are not vestigial
   clutter — they are exactly what the object model needs. Under the guarded pattern `hal.inc` could become a
   real, includable contract. That is the strongest argument yet for the linked model, and it belongs in the
   OS-kernel decision.
5. Standing: the **§2A.3 authorship ruling** (now **seventeen** deferrals).

---

### 9 — User interaction during task
**None.**

---

### 10 — Candidate(s) captured this task

`seeds/POP/live/2026-07-26-a-binary-framed-question-can-have-a-third-answer.md` — *"When a dispatch pre-assigns
conclusions to outcomes ('if A then X, if B then Y'), the evidence can land on B while the correct conclusion is
neither X nor Y — because the framing fixed an assumption the evidence doesn't require; answer the question the
evidence supports, not the branch the framing assigned to it."*
Fresh single-instance row (`initiator: clyde`); no existing entry read or edited.

Arose from §3.2: Q1 came back "errors", which the dispatch mapped to "fork forced / both-together". That mapping
silently assumed the directive must be unconditionally present in the source. It needn't be — and the escape
was a mechanism this very codebase adopted one dispatch earlier.

---

### 11 — Commit
`61a719d` — pushed to `origin/wip`.
