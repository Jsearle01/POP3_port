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
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path("C:/Projects/POP3_port")
sys.path.insert(0, str(ROOT / "harness/tools"))
import cel_parity_rule as R                                    # noqa: E402
import beat_recost as B                                        # noqa: E402
import cel_pack as K                                           # noqa: E402

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
#
#    s_Buildup, TRACED AT P3.77 and not yet in PLAN — it belongs with Vraise/Pback, which
#    do not fit until the swap lands, and alone it would add 6.6 s of dead pause to an
#    ending that has nothing after it:
#
#      s_Buildup  his last cel change -> Vraise's first, f4256 -> f4656 = 400 frames,
#                 less the one held play of Vstop's `play 4`      ->  394 frames (6.6 s)
#
#    Measured with the character box narrowed to screen x 200-350: the torches sit at
#    ~182 and ~362 and a wider box counts their flicker as scene motion (384 changes
#    against the true 281).
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

# How far past the script's last entry to simulate. The scene does not stop when the
# script does — every sequence ends in a `goto`, so both characters loop forever on
# whatever they were last given. Two full walk cycles (6 cels) is more than enough to
# close the set; the point is only to know WHICH cels the terminal loop draws, so the
# schedule's last beat names the page that holds them instead of claiming it needs none.
TERMINAL_STEPS = 60

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
        # ── THE REMAINING BEATS, IN PlayCut0's OWN ORDER [SUBS.S:709-750] (P3.78) ────
        ("song", "s_Buildup", 394),    # traced at P3.77; the cue over his second stop
        ("v", "Vraise", 1),       # `lda #Vraise / jsr vjumpseq / lda #1 / jsr play`
        # ★ Vraise MUST NOT LAND WITHOUT Pback. The oracle gives the raise ONE play and
        #   lets Pback's thirteen carry the gesture — the vizier's Vraise sequence keeps
        #   running through them. Landing Vraise alone would flick to a pose the scene
        #   then cannot continue from, which is why these two are one edit and not two.
        ("p", "Pback", 13),       # she backs away; his arms finish rising underneath
        ("-", "", 5),             # play 5 (the oracle raises SPEED to 12 here — see §7)
        ("v", "Vexit", 17),       # he turns and walks out; Vexit ends `goto Vwalk2`
        ("-", "", 12),            # play 12
        ("p", "Pslump", 28),      # she slumps against the wall
        ("v", "Vstand", 0)]       # 0 = hold; the script's last entry

# s_Magic and s_StTimer are NOT in the PLAN, and their absence is deliberate: PlayCut0
# plays both [SUBS.S:733,754] but neither has been traced off the oracle the way P3.77
# traced s_Buildup. A hold is a DURATION, and writing one nobody measured would be a
# fabricated number wearing a measured one's clothes. They add no cels, so their absence
# costs the pack nothing and the scene only runs shorter than the original.
#
# THE ORACLE'S SPEED CHANGES ARE ALSO NOT MODELLED. PlayCut0 sets SPEED 12 before the
# hourglass beat and again at the end [SUBS.S:729,752]; the port's cadence table is flat
# at the measured 7 frames/play (P3.72k). Applying SPEED would change every subsequent
# beat's real time and none of the port's holds were measured against it. Flagged, not
# faked.


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


def trace_scene(with_beats=False):
    """Walk the PLAN the way ANIMCHAR does, and record WHICH BEAT drew what.

    The per-beat split is new at P3.78 and it is the packer's whole input: the mapping
    may only change at a beat boundary, so "what does this beat draw" is exactly the set
    that has to be reachable while it runs. It is derived here, from the same walk that
    derives the phases, because a schedule kept anywhere else could disagree with the
    content it schedules — and P3.75 §3F named that as the worst version of the bug,
    since the symptom is silent garbage rather than a missing cel.
    """
    labels, toks = B.sequences()
    alt = R.altset2()
    viz = B.Char(197, R.FACE_LEFT, "Vstand", labels)
    pri = B.Char(120, R.FACE_LEFT, "Pstand", labels)
    beats = []
    plan = expand(PLAN)
    for bi, (w, seq, n) in enumerate(plan):
        if w == "v":
            viz.jump(seq, labels)
        if w == "p":
            pri.jump(seq, labels)
        mv, mp = len(viz.drawn), len(pri.drawn)
        # ★ THE LAST BEAT HAS 0 PLAYS AND STILL DRAWS FOREVER, which is a hole the
        # per-beat schedule would otherwise have at exactly its most dangerous point.
        # `play 0` means the SCRIPT holds, not that the sequences stop: Vexit ends
        # `goto Vwalk2` [SEQTABLE.S:1553] so the vizier keeps walking out after the
        # script's last entry, drawing cels that must still be mapped. A beat traced as
        # drawing nothing would be marked "needs no page" and the guard would go quiet
        # for the rest of the scene. So the terminal beat is SIMULATED: the sequences
        # loop, so a couple of loops' worth is the whole of its cel set.
        steps = n if n else TERMINAL_STEPS
        for _ in range(steps):
            viz.step(toks, labels, alt)
            pri.step(toks, labels, alt)
        drew = set()
        for who, ch, mk in (("viz", viz, mv), ("pri", pri, mp)):
            for cel, ph, x, face in ch.drawn[mk:]:
                drew.add((who, cel, 0 if face == R.FACE_LEFT else 1, ph))
        beats.append((bi, PLAN[bi][1] or "(hold)", n, drew))
    return (viz, pri, beats) if with_beats else (viz, pri)


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
    _viz, _pri, beats = trace_scene(with_beats=True)
    print("=== baking the scene: %d (cel, facing) combinations ===" % len(want))
    ok = fail = 0
    label_of, size_of = {}, {}
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
            m = re.search(r"(\d+) segment bytes", b.stdout or "")
            print("  %-4s cel %-3d %-8s col %-4d phase %d  %s"
                  % (who, cel, "MIRRORED" if facing else "normal", rc, ph,
                     "OK" if good else "REPLAY FAILED"))
            if good and m:
                ok += 1
                label_of[(who, cel, facing, ph)] = label
                size_of[(who, cel, facing, ph)] = int(m.group(1)) + 2   # + rows/width
            else:
                fail += 1
                print("      %s" % (b.stdout or b.stderr or "").strip()[:110])
    print("\n  %d baked, %d failed" % (ok, fail))
    if fail:
        return 1

    # ── THE PACK ────────────────────────────────────────────────────────────────────
    # The sizes handed to the packer are the SEGMENT-STREAM bytes cel_blit_prep reports
    # for the very files just written, so the pack is costed against the artifact rather
    # than against a model of it. build.bat re-checks every page against the LINK MAP
    # afterwards, which is the only measurement that can catch this one being wrong.
    lo = min(c for _w, c, _f, _p in label_of)
    hi = max(c for _w, c, _f, _p in label_of)
    table_bytes = (hi - lo + 1) * 8 * 2
    reads_at = [bi for bi, _nm, n, vs in beats if PLAN[bi][0] == "song" and n >= 40]
    try:
        p = K.pack(beats, size_of, table_bytes, reads_at)
    except K.PackError as e:
        print("\n*** THE SCENE DOES NOT PACK ***\n  %s" % e)
        return 1
    print()
    print(K.report(p, size_of))
    emit(p, label_of, size_of, lo, hi)
    return 0


def emit(p, label_of, size_of, lo, hi):
    """Write the split image: one RESIDENT source at $C000 and one per rotating page.

    ★ WHY THE WALK TABLE IS NOT WRITTEN HERE ANY MORE (P3.78). It holds ABSOLUTE
    pointers, and after the split most of them point into a DIFFERENT LINK UNIT — every
    rotating page links at $E000 as its own object, so `fdb v67_p0` from the resident
    unit is a symbol lwlink cannot resolve and would not be asked to. The addresses are
    therefore taken from the pages' own LINK MAPS, by cel_table.py, after they are
    linked: the linker is the authority on where it put something, and reading the map
    is measuring the artifact instead of predicting it. build.bat runs the two passes.

    Four kinds of file come out of here:

      cel_res.s        the pinned $FFA6 page — magic, bounds, the table's include, and
                       the cels every page's beats may need
      cel_pgN.s        one per rotating page, each linked at $E000, each carrying ITS
                       OWN signature as its first two bytes
      cel_pages.s      the disk manifest cutscene_room.s reads: which page is on which
                       track, in which block, and which arrive mid-scene
      cel_plan.s       the per-beat schedule, included by walk_scripts.s
      cel_pack.json    label -> page, for cel_table.py's second pass
    """
    pages = p["pages"]
    res = sorted(p["resident"])

    # ── which two disk tracks each unit lands on ────────────────────────────────────
    # Whole tracks, because disk_read_range reads nothing else (its own header). The
    # free spans are what packing the intro assets opened up; track 17 is the DECB
    # directory and no span may cross it (idiom §4).
    spans = [[11, 6], [20, 5], [32, 3]]           # (first track, tracks available)
    def take(n):
        for s in spans:
            if s[1] >= n:
                t = s[0]
                s[0] += n
                s[1] -= n
                return t
        raise SystemExit("*** out of raw disk tracks: %d more wanted ***" % n)

    # EVERY UNIT IS TWO TRACKS, UNIFORMLY, and padded to the window it is read into. Not
    # "however many tracks its bytes need" — see cel_pack's read-geometry note: a
    # whole-track read into a window smaller than the read overruns into the I/O page,
    # and the skew that prevents it is defined against the window's size, not the
    # content's. A page with room to spare simply reads a track of padding.
    units = [("res", None)] + [("pg%d" % g["index"], g) for g in pages]
    place = {name: (take(K.UNIT_TRACKS), K.UNIT_TRACKS) for name, _g in units}

    # ── the resident page ───────────────────────────────────────────────────────────
    L = ["* cel_res.s " + chr(0x2014) + " the PINNED page of the split cel image.",
         "* GENERATED by harness/tools/bake_scene.py " + chr(0x2014) + " do not hand-edit.",
         "*",
         "* Linked at $C000 (link/pop_cels_res.link) and mapped through $FFA6 for the",
         "* whole scene. It holds the three things that cannot be allowed to go away:",
         "*",
         "*   the MAGIC          $C000/$C001, so the engine can tell this page from any",
         "*                      other block that might be mapped under it",
         "*   the BOUNDS         $C002/$C003, read at run time because char_draw links",
         "*                      into a different object and cannot see these symbols",
         "*   the WALK TABLE     $C004, consulted on every cel placed " + chr(0x2014) + " which is",
         "*                      exactly why this page is pinned and the other is not",
         "*",
         "* ...and the cels that a rotating page could not serve: the standing cels the",
         "* song holds draw (pinning those is what lets a disk read hide in a hold), plus",
         "* whatever the packer had to pin to bring an over-large beat under one block.",
         "*",
         "* THE TABLE IS AN INCLUDE FROM build/, NOT TEXT IN THIS FILE. Its entries are",
         "* absolute addresses into the rotating pages, which are separate link units; they",
         "* come from those pages' link maps in a second pass. See emit()'s header.",
         "",
         "                section prog",
         "                export  cel_image",
         "cel_image",
         "                fcb     $%02X,$%02X         ; CEL_MAGIC, read from $C000/$C001"
         % (K.CEL_MAGIC >> 8, K.CEL_MAGIC & 0xFF),
         "                fcb     %d              ; WALK_LO, read from $C002" % lo,
         "                fcb     %d              ; WALK_N,  read from $C003" % (hi - lo + 1),
         '                include "build/obj/cel_walk_tab.s"',
         ""]
    L.append("* --- the pinned cels (%s B) ---" % format(p["resident_bytes"], ","))
    for k in res:
        L.append('                include "content/cutscene/chars/%s.s"' % label_of[k])
    (OUT / "cel_res.s").write_text("\n".join(L) + "\n", encoding="utf-8")

    # ── the rotating pages ──────────────────────────────────────────────────────────
    for g in pages:
        vs = sorted(g["variants"])
        P = ["* cel_pg%d.s " % g["index"] + chr(0x2014) + " one rotating page of the split image.",
             "* GENERATED by harness/tools/bake_scene.py " + chr(0x2014) + " do not hand-edit.",
             "*",
             "* Linked at $E000 (link/pop_cels_pg.link) " + chr(0x2014) + " the SAME address as every",
             "* other page, because only one of them is mapped at a time. That is what makes",
             "* them separate link units rather than sections of one image.",
             "*",
             "* ★ THE FIRST TWO BYTES ARE THIS PAGE'S OWN SIGNATURE, AND THAT IS THE POINT.",
             "* P3.77 put one magic at $C000 and its own uncertainty flag said what splitting",
             "* would do to it: a single magic proves the PINNED page is mapped and says",
             "* nothing about the rotating one " + chr(0x2014) + " which is the half that changes, and so the",
             "* half that can be wrong. Every page therefore says WHICH page it is, and the",
             "* beat schedule carries the value this beat's pointers need. A shared magic, or",
             "* a plausibility test, would pass on any of the five.",
             "*",
             "*   beats %d..%d   block $%02X   %s B of %s"
             % (g["beats"][0], g["beats"][-1], g["block"],
                format(g["bytes"], ","), format(K.ROT_CAP, ",")),
             "",
             "                section prog",
             "                export  cel_page%d" % g["index"],
             "cel_page%d" % g["index"],
             "                fdb     $%04X           ; the signature for THIS page"
             % g["sig"],
             ""]
        for k in vs:
            P.append('                include "content/cutscene/chars/%s.s"' % label_of[k])
        (OUT / ("cel_pg%d.s" % g["index"])).write_text("\n".join(P) + "\n",
                                                       encoding="utf-8")

    # ── the manifest the second pass and the room both read ─────────────────────────
    man = {"walk_lo": lo, "walk_n": hi - lo + 1, "magic": K.CEL_MAGIC,
           "res_base": K.RES_BASE, "rot_base": K.ROT_BASE,
           "resident": [[list(k), label_of[k]] for k in res],
           "pages": [{"index": g["index"], "block": g["block"], "sig": g["sig"],
                      "bytes": g["bytes"], "track": place["pg%d" % g["index"]][0],
                      "tracks": place["pg%d" % g["index"]][1], "cap": K.ROT_CAP,
                      "base": K.ROT_BASE,
                      "cels": [[list(k), label_of[k]] for k in sorted(g["variants"])]}
                     for g in pages],
           "res_track": place["res"][0], "res_tracks": place["res"][1],
           "res_cap": K.RES_CAP, "track_bytes": K.TRACK,
           "res_bytes": 4 + p["table_bytes"] + p["resident_bytes"],
           "reads": p["reads"], "schedule": p["schedule"]}
    (OUT / "cel_pack.json").write_text(json.dumps(man, indent=1), encoding="utf-8")

    emit_pages_s(p, place)
    emit_plan_s(p)
    S = ["* walk_scripts.s " + chr(0x2014) + " the scene's scripts. The CELS are in the split image.",
         "* GENERATED by harness/tools/bake_scene.py " + chr(0x2014) + " do not hand-edit."]
    S += scripts()
    S += ['', '* --- the per-beat block schedule, from the same PLAN -----------------',
          '                include "content/cutscene/chars/cel_plan.s"']
    (OUT / "walk_scripts.s").write_text("\n".join(S) + "\n", encoding="utf-8")

    print("\n  cel_res.s      %s B  track %d (+%d)"
          % (format(4 + p["table_bytes"] + p["resident_bytes"], ","),
             place["res"][0], place["res"][1]))
    for g in pages:
        print("  cel_pg%d.s      %s B  track %d (+%d)  block $%02X  sig $%04X"
              % (g["index"], format(g["bytes"] + 2, ","),
                 place["pg%d" % g["index"]][0], place["pg%d" % g["index"]][1],
                 g["block"], g["sig"]))
    print("  cel_plan.s / cel_pages.s / walk_scripts.s / cel_pack.json")


def emit_plan_s(p):
    """The per-beat schedule — FOUR BYTES A BEAT, and it lives beside the scripts.

    ONE HOME PER FACT (P3.31, and this project has been bitten by it three times). The
    plays, the block and the signature all come from the same PLAN walk that decides
    which cel is drawn on which step; a schedule written anywhere else could drift from
    the content it serves, and P3.75 §3F named that as the worst version of the bug
    because the symptom is not a missing cel but the wrong bytes drawn confidently.

        fcb  plays      animation steps this beat lasts; 0 = the last beat, holds
        fcb  block      what $FFA7 must show while it runs
        fdb  sig        the signature that block must answer with, or 0 for
                        "this beat draws only pinned cels and needs no page"
        fcb  read       page+1 to read into that block during this beat, else 0
    """
    L = ["* cel_plan.s " + chr(0x2014) + " the per-beat block schedule.",
         "* GENERATED by harness/tools/bake_scene.py " + chr(0x2014) + " do not hand-edit.",
         "*",
         "* Ticked once per animation step by vm_beat_tick, in lockstep with the two",
         "* character scripts because all three are derived from the same PLAN walk.",
         "*",
         "* SIG 0 MEANS 'NO ROTATING PAGE NEEDED', and it is a real state rather than a",
         "* hole in the check: the song holds draw only pinned standing cels, so their",
         "* block is free " + chr(0x2014) + " which is exactly why a track read can land in it. A guard",
         "* that demanded a page signature through a hold would refuse to draw for the",
         "* whole six seconds. cel_pack ASSERTS that a beat marked this way really does",
         "* draw only resident cels, so the marking cannot drift from the content.",
         "",
         "* ★★ NO COLUMN PADDING INSIDE AN OPERAND, EVER. `fcb %-3d,$%02X` renders beat 0",
         "* as `fcb 7  ,$0D` and lwasm TERMINATES THE OPERAND AT THE WHITESPACE: one byte",
         "* emitted, not two, with no error and no warning. Rows then have two different",
         "* lengths depending on whether the play count happened to be three digits, the",
         "* five-byte stride walks into the middle of its neighbours, and what comes out is",
         "* a schedule that maps block $00 and asks for page 109. Alignment goes in the",
         "* COMMENT, which is what a comment is for.",
         "cel_plan"]
    for s in p["schedule"]:
        L.append("                fcb     %d,$%02X" % (s["plays"], s["block"]))
        L.append("                fdb     $%04X" % s["sig"])
        L.append("                fcb     %d               ; beat %-2d %-12s plays %-4d%s%s"
                 % (0 if s["read"] is None else s["read"] + 1, s["beat"], s["name"],
                    s["plays"], "  pinned-only" if s["resident_only"] else "",
                    "  READ page %d" % s["read"] if s["read"] is not None else ""))
    L.append("                fcb     0,0")
    L.append("                fdb     0")
    L.append("                fcb     0               ; terminator")
    L.append("cel_plan_end")
    L.append("* cel_plan_end exists so the stride can be CHECKED rather than trusted:")
    L.append("* bundle_offsets_check.py compares (cel_plan_end - cel_plan) against")
    L.append("* 5 x (beats + 1) out of the link map, and fails the build on any other")
    L.append("* answer. The bug above assembled cleanly and ran; nothing but a byte count")
    L.append("* could have caught it.")
    (OUT / "cel_plan.s").write_text("\n".join(L) + "\n", encoding="utf-8")


def emit_pages_s(p, place):
    """The disk manifest cutscene_room.s includes: where every page is and where it goes."""
    L = ["* cel_pages.s " + chr(0x2014) + " where each page of the split cel image lives on disk.",
         "* GENERATED by harness/tools/bake_scene.py " + chr(0x2014) + " do not hand-edit.",
         "*",
         "* Read by cutscene_room.s: the startup loader walks the STARTUP rows, and a",
         "* mid-scene read indexes this table by the page number the beat schedule names.",
         "* build.bat places the very same tracks from cel_pack.json, so the disk and this",
         "* table cannot disagree without the build being re-run.",
         "*",
         "* ★ TWO ROWS' WORTH OF FACT PER PAGE, IN TWO BYTES: its first track, and the",
         "* GIME block it belongs in. Everything else is a constant, because every unit is",
         "* the same shape — two whole tracks, read in two calls, the second SKEWED so it",
         "* ends exactly at the top of the window. cel_pack's read-geometry note has the",
         "* whole argument; the short of it is that a plain two-track read into $E000",
         "* overruns 1,536 bytes into the constant page and the I/O registers, and takes",
         "* the GIME with it.",
         "*",
         "*   fcb first_track, block",
         "",
         "CEL_N_PAGES     equ     %d" % len(p["pages"]),
         # ★ HOW MANY STAGED READS THE SCENE OWES (P3.84). The drive is held across all of
         # them so dr_spinup's conditional skips every one after the first, and released
         # the moment the last completes — so the count has to be a fact the pack owns
         # rather than a number the engine remembers.
         "CEL_N_READS     equ     %d" % len(p["reads"]),
         "CEL_SECS        equ     18              ; one track, and a read is always one",
         "CEL_RES_BLOCK   equ     $%02X" % K.RES_BLOCK,
         "CEL_RES_TRK     equ     %d" % place["res"][0],
         "CEL_RES_LO      equ     $%04X           ; track A lands here" % K.RES_BASE,
         "CEL_RES_HI      equ     $%04X           ; track B, ending at $%04X"
         % (K.SKEW_RES, K.RES_BASE + K.RES_CAP),
         "CEL_PAGE_LO     equ     $%04X" % K.ROT_BASE,
         "CEL_PAGE_HI     equ     $%04X           ; ending at $%04X — the last byte the"
         % (K.SKEW_ROT, K.ROT_BASE + K.ROT_CAP),
         "*                                       ;   window owns before MC3 and I/O",
         "",
         "cel_page_tab"]
    for g in p["pages"]:
        t, n = place["pg%d" % g["index"]]
        # NO PADDING INSIDE THE OPERAND — see the note over cel_plan. This line carried
        # the identical `%-3d,` and emitted `fcb 13 ,$0D`, i.e. ONE byte, so every page
        # after the first read its neighbour's track into its neighbour's block: page 0
        # went to block $0F, page 1 fetched page 2's tracks into a FRAMEBUFFER block, and
        # page 2 fetched page 4's into block $00. The scene ran; the vizier stopped
        # animating, because the guard correctly refused every frame whose page was
        # missing. One formatting habit, two tables, and the second one was written after
        # the first had already been diagnosed.
        L.append("                fcb     %d,$%02X             ; page %d, %s B of %s"
                 % (t, g["block"], g["index"], format(g["bytes"], ","),
                    format(K.ROT_CAP, ",")))
    L.append("cel_page_tab_end")
    L.append("")
    L.append("* The pages that must be in RAM before the scene starts: one per block, the")
    L.append("* first user of each. The rest arrive in the song holds.")
    startup = []
    seen = set()
    for g in p["pages"]:
        if g["block"] not in seen:
            seen.add(g["block"])
            startup.append(g["index"])
    L.append("CEL_N_STARTUP   equ     %d" % len(startup))
    L.append("cel_startup_tab")
    L.append("                fcb     " + ",".join(str(i) for i in startup))
    (OUT / "cel_pages.s").write_text("\n".join(L) + "\n", encoding="utf-8")


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
