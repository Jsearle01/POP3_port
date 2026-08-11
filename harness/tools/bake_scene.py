#!/usr/bin/env python3
r"""bake_scene.py — bake every cel the port's scene draws, at its phase AND its facing.

SUPERSEDES bake_walk.py, which baked the vizier's nine and knew nothing about facing or
about the princess. P3.65 (piece G) needs both:

  * Palert ends `aboutface,chx,9`  [SEQTABLE.S:1565] — the princess TURNS to the door and
    rests there, so her standing cel is drawn MIRRORED for the rest of the scene.
  * Vexit ends `aboutface,chx,16`  [SEQTABLE.S:1550] — the vizier turns and walks OUT on
    the walk cels, mirrored. (Not built yet; the table has the shape for it.)

WHY THE MIRROR IS BAKED AND NOT RUN. The oracle mirrors at draw time: OPACITY bit 7 routes
LAY to MLAY [HIRES.S:655]. blit_cel walks segment runs left to right, so a runtime mirror
would need reverse traversal AND bit-reversal within every byte, against a merge path
already at a 6809 floor of 22 cy/byte. sprite_convert has had `--mirror` since Karateka's
guard-facing work; this is the first POP use of it.

THE COLOUR RULE, WHICH IS THE PART THAT CAN GO WRONG SILENTLY. --mirror reverses the pixel
list and PRESERVES each pixel's already-chosen colour; the chroma was decided at the
PRE-mirror screen columns. So a mirrored cel is only correct at a render column whose
parity matches, and for an even pixel width that is the OPPOSITE parity — which is what
--flip-parity exists for [sprite_convert.py:152-167]. Both are applied here from the cel's
real render column, not guessed.

PHASES AND FACINGS COME FROM THE TRACE, NOT FROM THIS FILE. beat_recost walks the port's
plan the way ANIMCHAR does, stepping both characters per `play N`, so what a cel needs is
derived from where the machine actually puts it.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
import cel_parity_rule as R                                    # noqa: E402
import beat_recost as B                                        # noqa: E402

TABLE = ROOT / "oracle/source/01 POP Source/Images/IMG.CHTAB6.A"
OUT = ROOT / "content/cutscene/chars"
CONVERT = ROOT / "harness/tools/sprite_convert.py"
PREP = ROOT / "harness/tools/cel_blit_prep.py"

# THE SCENE AS THE PORT PLAYS IT — the current scene with Palert restored in front of it.
# `play N` advances BOTH characters, so the princess's opening runs while the vizier still
# stands at the door. The later beats (Vraise/Pback/Vexit/Pslump) are NOT here yet; adding
# them is adding rows to this list.
#
# ★ Palert IS BACK (P3.71), AND THE THING THAT BLOCKED IT IS GONE.
#
#   P3.65 measured it as not fitting and the arithmetic was right at the time: her eight
#   turn cels took the bundle to 17,929 B against a 14,848 B window, over by 3,081, and
#   lz_pack refused it —
#
#       vizier cels 6,906 + princess cels 5,841 + table 880 + torch 1,777 + code 2,525
#
#   — but every one of those cel bytes is now in the $C000 image rather than the bundle.
#   The bundle holds the code, the torch and the scripts; the cels answer to a 16,384 B
#   bank instead of the 14,848 B between FLAME_BASE and the disk parameter block. The
#   diagnosis "the wall is that the port has no per-beat load" was ALSO right and is
#   still true — it is simply no longer binding, because a bank the whole scene fits in
#   does not need staging. Jay's P3.45 question is deferred again, on better terms.
# ★ THE LEAD-IN IS BACK (P3.72e, Jay watching both live: "we need to add the pre turn
#   portion of the scene per the oracle"). PlayCut0 opens with SEVEN plays of both
#   characters standing before she hears anything —
#
#       jsr startV0 / startP0        ;Vstand and Pstand at CharX 197 and 120
#       lda #2  / jsr play
#       lda #s_Princess / jsr PlaySongI
#       lda #5  / jsr play
#       lda #Palert / jsr pjumpseq   ;princess hears something...
#
#   — and the port jumped straight to her turn, so the scene opened on her already
#   moving. That is a beat of stillness the original spends before anything happens, and
#   without it the opening reads as abrupt no matter what the cadence is.
# ★ HE ENTERS IN TWO STAGES, NOT ONE (P3.72i, Jay watching the oracle: "when the vizier
#   walks on screen from the right he stops (with a pause, probably music) and then
#   continues to stand in front of the princess"). PlayCut0 after the SPEED change:
#
#       lda #7 / sta SPEED
#       lda #5  / jsr play                   ;both hold
#       lda #Vapproach / jsr vjumpseq
#       lda #6  / jsr play
#       lda #Vstop / jsr vjumpseq
#       lda #4  / jsr play                   ;vizier enters  <- HE STOPS HERE
#       lda #s_Vizier / ldx #12 / jsr PlaySongI   ;...and the cue plays
#       lda #4  / jsr play
#       lda #Vapproach / jsr vjumpseq
#       lda #30 / jsr play
#       lda #Vstop / jsr vjumpseq
#       lda #4  / jsr play                   ;stops in front of princess
#
#   The port had only the second approach, so he walked in one unbroken 30-play stride.
#   `Vapproach` IS `Vwalk` -- SEQTABLE.S:128 is `:96 dw Vwalk` and SEQDATA.S:94 is
#   `Vapproach = 96` -- so the sequence was always right; the SHAPE of the entrance was
#   not.
#
# "-" MEANS PLAY WITHOUT JUMPING, which the oracle does twice here and the PLAN could not
#   express. trace_scene jumps only on "v"/"p" and scripts() appends only on "v"/"p", so
#   both already do the right thing with it; only the vocabulary was missing.
# ★★ AND IT DOES NOT FIT — THE BANK WALL, MEASURED (P3.72i).
#
#   The faithful entrance above is exactly this, and it is what the port should play:
#
#       ("p", "Pstand", 7), ("p", "Palert", 9),
#       ("-", "", 5), ("v", "Vwalk", 6), ("v", "Vstop", 4),     <- he enters and STOPS
#       ("-", "", 4),                                           <- the s_Vizier beat
#       ("v", "Vwalk", 30), ("v", "Vstop", 4), ("v", "Vstand", 0)
#
#   It bakes and it links, and the cel image comes out at 19,288 B against 15,872 B of
#   usable bank ($C000..$FDFF; $FE00-$FEFF is constant RAM and $FF00+ is I/O). OVER BY
#   3,416 B. The disk is not the constraint — five tracks would hold it — the WINDOW is.
#
#   WHY IT COSTS SO MUCH, and it is not the two extra plays. The stop shifts the vizier's
#   x by an odd number of CharX units, so when he resumes every one of his walk cels
#   lands on the OPPOSITE sub-byte phase. Each then needs TWO bakes instead of one:
#
#       before   48→{1} 49→{1} 50→{1} 51→{0} 52→{0} 53→{1} 54→{1} 55→{1} 56→{1}
#       after    48→{1,3} 49→{1,3} 50→{1,3} 51→{0,2} 52→{0,2} 53→{1,3} ...
#
#   Nine extra vizier cels at ~350 B each is ~3,150 B, which is the overflow almost
#   exactly. The beat is cheap; the PHASE EXPLOSION it triggers is not.
#
#   ★ THE STRUCTURAL ANSWER IS ALREADY IN THE TREE AND UNWIRED: shift_row.s. A runtime
#   shifter lets ONE baked phase serve all four and would cut the vizier's cel storage by
#   up to 4x — far more than the 3,416 B needed. That is the carried open item this beat
#   has now made binding, and it is Jay's call, not a thing to invent here.
# ★★★ AND IT FITS AFTER ALL — MOVE THE PAUSE BY ONE CharX UNIT (Jay: "would it be
#   possible to stop him at a slightly different x so we could reuse cels?"). Yes, and it
#   is the whole fix.
#
#   The phase is (2*(x + Fdx) + parity) mod 4, so a shift of an EVEN number of CharX units
#   leaves every phase untouched and an ODD one flips all of them. The oracle's 6-play
#   first approach happens to land ODD, which is the only reason his cels double. Swept
#   offline, with the pause point moved a step either way:
#
#       app1=6 app2=30   pauses CharX 186   ends CharX 135   18 viz bakes  <- the oracle
#       app1=5 app2=31   pauses CharX 187   ends CharX 135    9 viz bakes
#       app1=7 app2=29   pauses CharX 185   ends CharX 135    9 viz bakes
#
#   ONE CharX UNIT IS TWO APPLE PIXELS — half a byte-column — and it halves the bakes. The
#   total travel is unchanged at 36 plays and HE ENDS IN EXACTLY THE SAME PLACE, so the
#   only difference on screen is where he pauses, by half a column. Nine is also one FEWER
#   than the single-approach version that shipped before this, so the faithful two-stage
#   entrance now costs less than the unfaithful one it replaces.
#
#   The deviation is recorded rather than hidden: the oracle pauses him at 186 and this
#   pauses him at 185. Everything else about the beat is the oracle's.
# ★★ THE TWO SONG STUBS (P3.72l, Jay: "lets add the two sound stubs, one for the princess
#    and one for the vizier, just like they are in the other intro screens").
#
#    `PlaySongI` BLOCKS while the music plays [SUBS.S:822-842] and contains no wait
#    instruction at all — the pause IS the song, exactly as intro_seq.s's play_song
#    records. Stubbing these two to silence did not remove sound, it removed two BEATS:
#    the scene opened almost the moment the room appeared, and the vizier's stop was a
#    twitch instead of a hold.
#
#    ★ AND THE INTRO'S STUB CANNOT SIMPLY BE CALLED HERE, for the reason its own comment
#      predicted: "IT WAITS RATHER THAN ANIMATING ... the things the oracle's song loop
#      drives -- pburn, pstars, pflow -- are the PRINCESS ROOM's torches, stars and
#      hourglass ... If a beat ever gains a live element, it is driven from here." This is
#      that beat. The torches must keep flickering through both songs, so the interval has
#      to be spent in the room's own loop, not in a VBL spin.
#
#      It already is: a no-jump hold freezes both characters' sequences while room_loop
#      goes on flickering and swapping, which is precisely what the oracle's song loop
#      does. So the song's body is a hold — and the DURATION lives here, once, with the
#      holds DERIVED from it. Nothing is hand-written beside a call for anyone to
#      remember to delete when sound lands (P3.52's property, and P3.41's lesson).
#
#    DURATIONS ARE TRACE-MEASURED, NOT THE X OPERAND. P3.52 established that the oracle's
#    X is only PlaySongI's SOUND-OFF fallback (`txa / beq ]rts / jmp play`); with sound ON
#    the beat lasts as long as the song. Measured on the oracle, this scene:
#
#      s_Princess  room arrives f2688 -> her turn starts f3487 = 799 frames, of which
#                  play 2 + play 5 at the measured 5.38 f/play is ~38  ->  761 frames
#      s_Vizier    his last cel change f3676 -> first on resuming f4064 = 388 frames, of
#                  which 5 held plays at 6 f is 30                    ->  358 frames
#
#    (The oracle's own X values here are 8 and 12, which are neither of these.)
# THE MEASURED PLAY PERIOD, NOT cad_tab's 6. vm_nextframe re-bases its due as
# `now + count`, and since P3.72k the loop samples it at the FLAME rate (~2.8 frames)
# rather than at the step, so `now` is systematically a little late and a play costs
# ~7 frames rather than 6. Measured on the running port: the opening hold ran 937 frames
# over 134 plays = 6.99. Converting the songs at 6 made the opening 17% too long, so the
# divisor is the rate the machine actually keeps, read off the machine.
#
# (The re-base is worth fixing at source one day -- `due = due + count` would not drift
# with the sampling rate -- but that changes the VM's cadence and is not this task.)
SONG_FPS = 7

# ★★★ THE REMAINING BEATS DO NOT FIT, AND shift_row.s WILL NOT SAVE THEM (P3.72m recon).
#
#   Costed beat by beat against the 15,872 B usable bank, at the 633 B/bake this image
#   actually averages (12,922 B over 19 bakes, less the 880 B table). Vraise+Pback was
#   additionally BUILT and linked to check the model: 23,002 B measured against 23,060
#   estimated, so the numbers below are trustworthy.
#
#       current                    19 bakes   12,922 B     2,950 B free
#       + Vraise 1                 20         ~13,555      fits
#       + Pback 13                 35         ~23,060      OVER by  7,188
#       + hold 5                   40         ~26,229      OVER by 10,357
#       + Vexit 17                 52         ~33,833      OVER by 17,961
#       + hold 12                  63         ~40,804      OVER by 24,932
#       + Pslump 28                64         ~41,437      OVER by 25,565
#
#   The complete scene is 2.6x the bank. These are GENUINELY NEW CELS — viz 67-74, 85 for
#   the raise, 57-66 for the exit; pri 12-18 for the step back — not phase duplicates.
#
#   ★ AND THAT RETIRES THE ANSWER I GAVE TWICE. P3.72i said shift_row.s was the structural
#     fix, worth "up to 4x" because one baked phase could serve all four. That was true
#     WHILE cels were duplicated across phases — and P3.72j's one-CharX-unit alignment
#     removed the duplication. The image is now 9 viz bakes for 9 distinct cels and 10 pri
#     for 9 (cel 11 twice, for the mirror): ZERO phase duplication left. A runtime shifter
#     would save essentially nothing here. The recommendation was correct when it was made
#     and is obsolete now; acting on it would have cost a dispatch.
#
#   WHAT IS LEFT IS THE LOAD, which is Jay's P3.45 question and has been carried since.
#   P3.63 measured the scene's PEAK residency at 5,631 B against a 15,872 B bank — so any
#   single beat's working set fits several times over, and only the SCENE'S TOTAL does not.
#   The bank made the whole-scene-at-once approach reach much further than the bundle did;
#   it does not reach to the end.

PLAN = [("p", "Pstand", 7),       # play 2 + play 5, both standing [SUBS.S:665-672]
        ("song", "s_Princess", 761),   # ...with the cue between them; she waits
        ("p", "Palert", 9),       # she hears the door and turns
        ("-", "", 5),             # play 5 — both hold after the SPEED change
        ("v", "Vwalk", 7),        # Vapproach: he enters from the right (oracle 6, +1)
        ("v", "Vstop", 4),        # ...and STOPS, at CharX 185 against the oracle's 186
        ("song", "s_Vizier", 358),     # the cue over his stop — the beat Jay saw
        ("-", "", 4),             # play 4
        ("v", "Vwalk", 29),       # Vapproach again: he crosses to her (oracle 30, -1)
        ("v", "Vstop", 4),        # stops in front of the princess, CharX 135 either way
        ("v", "Vstand", 0)]       # 0 = hold; the script's last entry


def expand(plan):
    """PLAN -> the (who, seq, plays) form the tracer and the scripts consume.

    A song becomes a no-jump hold of its own measured length. This is the ONE place the
    conversion happens, so the frame count above stays the single home for the duration
    and the play count is never written by hand.
    """
    out = []
    for w, seq, n in plan:
        if w == "song":
            out.append(("-", "", max(1, round(n / SONG_FPS))))
        else:
            out.append((w, seq, n))
    return out

STEM = {}                         # (who, cel) -> file stem


def stem_for(who, cel):
    return STEM.setdefault((who, cel), "%s%d" % ("v" if who == "viz" else "p", cel))


def trace_scene():
    labels, toks = B.sequences()
    alt = R.altset2()
    viz = B.Char(197, R.FACE_LEFT, "Vstand", labels)
    pri = B.Char(120, R.FACE_LEFT, "Pstand", labels)
    plays = []
    for w, seq, n in expand(PLAN):
        if w == "v":
            viz.jump(seq, labels)
        if w == "p":
            pri.jump(seq, labels)
        for _ in range(n):
            viz.step(toks, labels, alt)
            pri.step(toks, labels, alt)
        plays.append((w, seq, n))
    return viz, pri


def needed():
    """{(who, cel, facing): (phases, x)} — facing 0 = left/normal, 1 = right/mirrored.

    THE X COMES BACK TOO, AND IT IS NOT COSMETIC (P3.72). --start-col decides the cel's
    COLOUR PARITY: sprite_convert picks each pixel's chroma from the screen column it
    will be rendered at. This baked every cel at the character's STARTING CharX, which is
    silently correct for anyone who has not moved -- and every cel in the scene was such a
    cel until Palert, whose `aboutface,chx,9` [SEQTABLE.S:1565] shifts the princess nine
    units before her standing cel is next drawn.

    Measured: her eight turn cels all bake at the column they are drawn at, and the
    MIRRORED cel 11 alone bakes at start-col 124 while the machine draws it at 142. So
    the x is taken from where the trace actually puts the cel, not from where the
    character began. The phase was already derived this way; only the column was not.
    """
    viz, pri = trace_scene()
    out = {}
    for who, ch in (("viz", viz), ("pri", pri)):
        for cel, ph, x, face in ch.drawn:
            out.setdefault((who, cel, 0 if face == R.FACE_LEFT else 1),
                           [set(), x])[0].add(ph)
    return {k: (tuple(sorted(v[0])), v[1]) for k, v in out.items()}


def convert_src(who, cel, mirror, render_col, quiet=True):
    """Convert the cel; mirrored variants get their own source at their own column."""
    alt = R.altset2()
    fimg, fdx, fdy, fchk, lab = alt[cel]
    stem = stem_for(who, cel) + ("_m" if mirror else "")
    src = OUT / ("%s_src.s" % stem)
    cmd = [sys.executable, str(CONVERT), "--table", str(TABLE),
           "--index", str(fimg & 0x7F), "--out", str(src), "--label", "%s_src" % stem,
           "--start-col", str(render_col)]
    if mirror:
        cmd.append("--mirror")
    if quiet:
        cmd.append("--quiet")
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0 or not src.exists():
        return None, (r.stderr or r.stdout or "")[:80]
    # ─── THE EVEN-WIDTH FLIP, and the test was VACUOUS (P3.72h) ──────────────────────
    #
    # Jay, on the first mirrored cel this port has ever shown: "her orange and blue
    # colors are swapping after she turns. i think you forgot parity."
    #
    # The rule is sprite_convert's own [sprite_convert.py:135-167]: --mirror reverses the
    # pixel list and PRESERVES each pixel's baked chroma, which was chosen at the
    # PRE-mirror screen columns. Reversing maps a pixel at column c to 2*start + W-1 - c,
    # so its column parity flips exactly when W is EVEN — and W there is
    #
    #     width_pixels = apple_width_bytes * 7
    #
    # This tested `coco3_width * 4`, which is EVEN FOR EVERY CEL THAT HAS EVER EXISTED.
    # So the branch was not a test at all: it applied --flip-parity to every mirrored cel
    # unconditionally, and read as a careful measurement while doing so ("applied from the
    # cel's own measured width rather than assumed"). It was measuring the padded CoCo
    # container instead of the sprite.
    #
    # Cel 11 is 3 Apple bytes = 21 px, ODD, so it must NOT be flipped — and it was.
    if mirror:
        width_pixels = 7 * R.awid(cel)
        if width_pixels % 2 == 0:
            r2 = subprocess.run(cmd + ["--flip-parity"], capture_output=True, text=True)
            if r2.returncode != 0:
                return None, "flip-parity pass failed"
    return src, None


def main():
    alt = R.altset2()
    want = needed()
    print("=== baking the scene: %d (cel, facing) combinations ===" % len(want))
    ok = fail = 0
    includes, table = [], {}
    for (who, cel, facing) in sorted(want):
        fimg, fdx, fdy, fchk, lab = alt[cel]
        # THE X THE TRACE PUTS THIS CEL AT, not the character's starting CharX — see
        # needed(). Baking the colour parity at a column the cel is never rendered at is
        # invisible for a character that never moves and wrong for one that does.
        face = R.FACE_LEFT if facing == 0 else 0
        rc = R.draw_x(want[(who, cel, facing)][1], fdx, fchk, face, R.awid(cel))
        src, err = convert_src(who, cel, facing == 1, rc)
        if src is None:
            print("  %s cel %-3d facing %d: CONVERT FAILED %s" % (who, cel, facing, err))
            fail += 1
            continue
        stem = stem_for(who, cel) + ("_m" if facing else "")
        for ph in want[(who, cel, facing)][0]:
            label = "%s_p%d" % (stem, ph)
            dst = OUT / ("%s.s" % label)
            b = subprocess.run([sys.executable, str(PREP), str(src), "--phase", str(ph),
                                "--label", label, "--out", str(dst)],
                               capture_output=True, text=True)
            good = "replay OK" in (b.stdout or "")
            print("  %-4s cel %-3d %-8s col %-4d phase %d  %s"
                  % (who, cel, "MIRRORED" if facing else "normal", rc, ph,
                     "OK" if good else "REPLAY FAILED"))
            if good:
                ok += 1
                includes.append(label)
                table[(cel, facing, ph)] = label
            else:
                fail += 1
                print("      %s" % (b.stdout or b.stderr or "").strip()[:110])
    print("\n  %d baked, %d failed" % (ok, fail))
    if fail:
        return 1
    emit(includes, table)
    return 0


def emit(includes, table):
    """TWO outputs now (P3.71), because the cels no longer live where the code does.

    cel_image.s   -> its own link unit at $C000, read off disk into a GIME bank. Holds
                     WALK_LO/WALK_N as its first two bytes, then walk_tab, then the cel
                     data. THE IMAGE DESCRIBES ITSELF: char_draw is in a different link
                     unit and cannot resolve a symbol across that boundary, so it reads
                     the bounds out of the image rather than keeping a second copy of
                     them. A duplicated layout constant is exactly what CHAR_TAB was.
    walk_scripts.s -> stays inside the bundle, included by char_draw.s. The scripts are
                     code-adjacent and tiny; only the cel PIXELS had to move.
    """
    lo = min(c for c, _f, _p in table)
    hi = max(c for c, _f, _p in table)
    L = ["* cel_image.s " + chr(0x2014) + " the scene's bake, and the lookup over it.",
         "* GENERATED by harness/tools/bake_scene.py " + chr(0x2014) + " do not hand-edit.",
         "*",
         "* LINKED AT $C000 AND READ OFF DISK INTO A GIME BANK (P3.69/P3.71). It is NOT",
         "* part of the flame bundle any more: the bundle had reached 11,921 B against a",
         "* 14,848 B window with five beats still to add, and the cels are the half of it",
         "* that never executes, so they are the half that can live behind a window",
         "* register. cutscene_room.s maps blocks at $FFA6/$FFA7 and re-applies that map",
         "* after every swap (HAL_gfx_swap writes all four window registers, so the",
         "* mapping cannot survive one " + chr(0x2014) + " P3.68).",
         "*",
         "* THE FIRST TWO BYTES ARE THE BOUNDS, and they are load-bearing: char_draw.s",
         "* reads WALK_LO/WALK_N from $C000/$C001 at run time because it links into a",
         "* different object and cannot see these symbols.",
         "*",
         "* EIGHT SLOTS PER CEL: two facings x four phases (P3.65, piece G). The facing",
         "* half is chosen by co_variant from CH_FACE; -1 is left and NORMAL, 0 is right",
         "* and MIRRORED [FRAMEADV.S:1970]. Cels drawn at one facing leave the other half",
         "* zero, which co_variant treats as 'fall back to the record's own pointer'.",
         "*",
         "* Which phases and facings each cel needs is DERIVED, not written: beat_recost",
         "* walks the port's plan the way ANIMCHAR does. Nothing here may disagree with it.",
         "*"]
    for cel in range(lo, hi + 1):
        got = [(f, p) for (c, f, p) in table if c == cel]
        if got:
            L.append("*   cel %-3d %s" % (cel, ", ".join(
                "%s ph%d" % ("mirrored" if f else "normal", p) for f, p in sorted(got))))
    L += ["",
          "                section prog",
          "* EXPORTED because link/pop_cels.link names it as the entry. lwlink resolves",
          "* `entry` against exported symbols only; a plain label gives",
          "* \"External symbol cel_image not found\" at link time. The image is never",
          "* executed -- the entry exists so the .bin carries a load address decb_to_raw",
          "* can check against build.bat's --base.",
          "                export  cel_image",
          "cel_image",
          "* --- the self-describing header, and it must stay FIRST -----------",
          "                fcb     %d              ; WALK_LO, read from $C000" % lo,
          "                fcb     %d              ; WALK_N,  read from $C001" % (hi - lo + 1),
          "* --- walk_tab at $C002: eight slots per cel, two facings x four phases ---",
          "cel_walk_tab"]
    for cel in range(lo, hi + 1):
        row = []
        for f in (0, 1):
            for p in range(4):
                row.append(table.get((cel, f, p), "0"))
        L.append("                fdb     " + ",".join(row) + "   ; cel %d" % cel)
    L.append("")
    for lab in includes:
        L.append('                include "content/cutscene/chars/%s.s"' % lab)
    L.append("")
    pathlib.Path(OUT / "cel_image.s").write_text("\n".join(L) + "\n", encoding="utf-8")

    # THE SCRIPTS STAY IN THE BUNDLE. They are two dozen bytes of sequence cursor that
    # char_draw dereferences directly; moving them behind a window register would buy
    # nothing and would put a second thing behind the map.
    S = ["* walk_scripts.s " + chr(0x2014) + " the scene's scripts. The CELS are in cel_image.s.",
         "* GENERATED by harness/tools/bake_scene.py " + chr(0x2014) + " do not hand-edit."]
    S += scripts()
    pathlib.Path(OUT / "walk_scripts.s").write_text("\n".join(S) + "\n", encoding="utf-8")
    print("  cel_image.s: cels %d..%d, %d slots, %d cel includes"
          % (lo, hi, (hi - lo + 1) * 8, len(includes)))
    print("  walk_scripts.s: the two scene scripts")


# The two scene scripts, DERIVED FROM THE SAME PLAN as the phases, because they are the
# same fact: which sequence runs for how many steps is what decides the positions, and the
# positions are what decide the phases. Written by hand in one place and derived in the
# other, they would drift, and the symptom would be a cel drawn at a phase nobody baked.
LABEL = {"Vstand": "viz_stand", "Vwalk": "viz_walk", "Vstop": "viz_stop",
         "Pstand": "pri_stand", "Palert": "pri_alert",
         "Vraise": "viz_raise", "Pback": "pri_back",
         "Vexit": "viz_exit", "Pslump": "pri_slump"}


def scripts():
    out = {"v": [["Vstand", 0]], "p": [["Pstand", 0]]}
    for w, seq, n in expand(PLAN):
        for who in ("v", "p"):
            if w == who:
                out[who].append([seq, 0])
            out[who][-1][1] += n
    L = ["",
         "* THE SCENE SCRIPTS: (sequence, plays), derived from bake_scene.PLAN.",
         "* A count of 0 means the sequence holds and the script is finished.",
         "* `play N` advances BOTH characters [SUBS.S:876], so the vizier's leading Vstand",
         "* is exactly as long as the princess's opening — he waits at the door while she",
         "* hears it."]
    for who, name in (("v", "viz_script"), ("p", "pri_script")):
        rows = [r for r in out[who] if r[1] > 0]
        L.append(name)
        for seq, n in rows[:-1]:
            L.append("                fdb     %s" % LABEL[seq])
            L.append("                fcb     %d" % n)
        L.append("                fdb     %s" % LABEL[rows[-1][0]])
        L.append("                fcb     0               ; hold")
    return L


if __name__ == "__main__":
    sys.exit(main())
