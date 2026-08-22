#!/bin/bash
# harness/smoke/run_room_live.sh
#
# POP P3.17 phase A — the princess's room, LIVE at normal speed (Jay's 25.3 gate).
#
# THROTTLED on purpose (no -nothrottle) and the window stays open until closed. The
# room is static, so this gate is about the PICTURE and the palette rather than
# motion — but it is still the running machine on the real launch path
# (LOADM"ROOM"+EXEC off a mounted floppy, CLAUDE.md §4 launch path `live-disk`),
# not a poked image and not a rendered framebuffer.
#
# SINCE P3.31 THE SCENE HAS A GAIT IN IT, and that changes what this gate is for. The
# vizier walks left from x=197 at a measured 8.24 video frames per cel, against a
# 6-frame floor that the cadence table asks for and the draw overruns. (The 3.18 that
# stood here was a per-ITERATION figure from before the VM paced off real VBLs; P3.101
# measured the walk in at 8.24 f/cel and the walk out at 8.14, and P3.102 showed why
# the achieved rate can only be a whole number of frames.) Whether that
# is the right PACE is not a thing any byte comparison can answer -- CLAUDE.md §4:
# motion-bearing gates need a live run, and "density is not motion" (P3.29). This is
# the runner for it. A rejection is a policy revisit, not a defect.
#
# The byte comparison in run_room_test.sh already proves the displayed buffer IS the
# converted room. What this adds is the thing a byte comparison cannot judge: whether
# the 4-colour palette looks right on a real screen. That is Jay's eye, and the
# palette here is deliberately Karateka's starting point, not a final choice.
#
# MONITOR=composite looks at the other monitor type; MAME_RAM=128K runs it on a
# 128 KB machine.
set -u

cd "$(dirname "$0")/../.." || exit 1

MAME="${MAME:-/c/mame/mame.exe}"
MAME_ROMS="${MAME_ROMS:-C:/mame/roms}"
MONITOR="${MONITOR:-rgb}"

SRC_DSK="build/probe.dmk"
DSK="build/run_room_live.dmk"
BIN="build/cutscene_room.bin"

[ -f "$BIN" ] || { echo "[run_room_live] missing $BIN — run build.bat first"; exit 1; }
[ -f "$SRC_DSK" ] || { echo "[run_room_live] missing $SRC_DSK — run build.bat first"; exit 1; }
cp -f "$SRC_DSK" "$DSK" || exit 1

# ONE HOME for which machine this runs on: 128 KB, the target (CLAUDE.md 2K).
. "$(dirname "$0")/ramsize.sh"
. "$(dirname "$0")/cfgdir.sh"

echo "[run_room_live] POP CoCo3 — the princess's room, 4-colour, normal speed, $MONITOR${MAME_RAM:+, $MAME_RAM}"
echo "[run_room_live] boot, LOADM\"ROOM\", EXEC — then THREE track reads (room, flame bundle,"
echo "[run_room_live]   and the \$C000 cel bank added at P3.71) and the room appears."
echo "[run_room_live] She hears the door and turns; he walks in from the right, stops,"
echo "[run_room_live]   walks again and stops in front of her. Her turn leaves her MIRRORED"
echo "[run_room_live]   for the rest of the scene, which is what the turn is for."
echo "[run_room_live]"
echo "[run_room_live] P3.78 — THE IMAGE IS NOW SPLIT ACROSS GIME BLOCKS AND PAGED PER BEAT."
echo "[run_room_live]   NEW AND UNGATED: he raises his arms (Vraise), she backs away (Pback),"
echo "[run_room_live]   he turns and walks out (Vexit), she slumps (Pslump)."
echo "[run_room_live]"
echo "[run_room_live] * ONE DELIBERATE FREEZE NOW, NOT TWO. The re-encode landed at P3.85 and"
echo "[run_room_live]   did what it said: 5 pages -> 4, two staged reads -> one, three loads -> two."
echo "[run_room_live]   The remaining read hides in the s_Buildup hold before he raises his arms;"
echo "[run_room_live]   the torches STOP for ~2.8 s there. No DMA -- the CPU IS the transfer."
echo "[run_room_live]   Jay accepted the duration at P3.84. Getting to ZERO needs the grouping"
echo "[run_room_live]   push (4 pages against 3 blocks), which is NOT done."
echo "[run_room_live]"
echo "[run_room_live] ** IT RUNS TO THE END NOW, and both suites are green on both memory"
echo "[run_room_live]   sizes -- the exit clips correctly and the scene reaches its last beat."
echo "[run_room_live]   Vraise -> Pback -> Vexit -> Pslump have NEVER been gated by eye."
echo "[run_room_live]"
echo "[run_room_live] ** NEW SINCE THE LAST GATE (P3.85b/c) -- THE HOURGLASS IS IN."
echo "[run_room_live]   It appears after Pback at byte col 38, with the sand running through"
echo "[run_room_live]   psandcount's three frames, and it stays to the end of the scene."
echo "[run_room_live]   s_Magic is in too: a 113-frame hold, traced off the oracle, between the"
echo "[run_room_live]   hourglass beat and Vexit. The scene is 19 beats now, not 18."
echo "[run_room_live]"
echo "[run_room_live] ** WATCH THE FLASH, AND WATCH THE BLUE AFTER IT. Five white strobes, one"
echo "[run_room_live]   per play, over the beat where the hourglass appears. Last gate they did"
echo "[run_room_live]   not read as white at all and left the blue permanently light-green --"
echo "[run_room_live]   the restore table had \$1B where the HAL's gfx_pal4 has \$19. Fixed and"
echo "[run_room_live]   now gated by palette_check.py, but the DURATION of each strobe is a"
echo "[run_room_live]   derived number, not a traced one: the oracle's own on/off ratio inside"
echo "[run_room_live]   each play has not been measured."
echo "[run_room_live]"
echo "[run_room_live]"
echo "[run_room_live] ** P3.98 -- THE EXIT STRIDE'S LURCH IS THE ORACLE'S OWN, NOT A DEFECT."
echo "[run_room_live]   You said the walk out looks like skipping. It does, and the mechanism"
echo "[run_room_live]   is Mechner's: a MIRRORED image is laid one sprite-width to the LEFT"
echo "[run_room_live]   of its coordinate [HIRES.S MLayGen: LDA XCO / SEC / SBC WIDTH], and"
echo "[run_room_live]   the walk cels are 3,4,5,5,4,4 bytes wide -- so the anchor swings 14 px"
echo "[run_room_live]   across the cycle and redistributes the stride. The entry walk is not"
echo "[run_room_live]   mirrored and has no such term, which is why it looks different."
echo "[run_room_live]   NOT CHANGED: correcting it would be a divergence, like 'fixing' the"
echo "[run_room_live]   authentic back-step at P3.51. IF YOU WANT IT SMOOTHED ANYWAY, SAY SO --"
echo "[run_room_live]   that is a deliberate departure and it is your call, not mine."
echo "[run_room_live]"
echo "[run_room_live] ** THIS RUN IS 128 KB, THE TARGET MACHINE (P3.97/P3.98). Every earlier"
echo "[run_room_live]   gate ran at 512 KB by default."
echo "[run_room_live]"
echo "[run_room_live] ** P3.96 -- THE FEET ARE FIXED. WATCH THE END OF THE RAISE AND THE"
echo "[run_room_live]   START OF THE TURN, which is where you put it across three gates."
echo "[run_room_live]   A cel number names a TABLE and an image; the bake read the image and"
echo "[run_room_live]   hard-coded the table, so eight vcast frames came from 13-row stubs"
echo "[run_room_live]   where the real cels are 48-50 rows. Cels store bottom-up, so a 13-row"
echo "[run_room_live]   draw IS the feet. He should now be WHOLE throughout."
echo "[run_room_live]   Load count and freeze are UNCHANGED: still 4 pages, one read, one"
echo "[run_room_live]   freeze in the s_Buildup hold. Nothing was traded for this."
echo "[run_room_live]"
echo "[run_room_live] ** P3.94 -- YOU SAID 'i only see one long strobe'. YOU WERE RIGHT."
echo "[run_room_live]   Measured on the palette (not the counter): the screen was white for"
echo "[run_room_live]   ONE RUN OF 41 FRAMES, 0.68 s, with no dark gap. Five arms, one strobe."
echo "[run_room_live]   The white was held for 3 DRAWN frames and the next arm beat it to zero."
echo "[run_room_live]   The oracle brackets ONE FRAME'S DRAW -- flashon / FrameAdv / flashoff,"
echo "[run_room_live]   decrementing once per bracket -- so its five are five SINGLE-frame"
echo "[run_room_live]   flashes. Now 1 drawn frame: white 5, dark 5, white 4, dark 4, white 3,"
echo "[run_room_live]   dark 3, white 4, dark 4, white 3. FIVE STROBES, ~50% duty."
echo "[run_room_live]   ** COUNT THEM, and check the blue is BLUE in each dark gap. **"
echo "[run_room_live]"
echo "[run_room_live] ** P3.93 -- THE OTHER DEFECT YOU REPORTED. TWO THINGS TO WATCH:"
echo "[run_room_live]   1. THE FLASH STROBES FIVE TIMES, not once, and the FIRST strobe now"
echo "[run_room_live]      lands on the SAME FRAME the hourglass appears. You said 'the"
echo "[run_room_live]      hourglass still appears before the flash' -- it did, by 0.53 s."
echo "[run_room_live]      Two blocks sat below a branch that only fell through on a beat's"
echo "[run_room_live]      last play, so the glass went up when the beat began and the flash"
echo "[run_room_live]      fired when it ended. They now run once per play, as the oracle does."
echo "[run_room_live]   2. THE SAND FLOWS. It was advancing once per BEAT -- one change across"
echo "[run_room_live]      a 28-play beat -- and it froze entirely for the scene's last 27"
echo "[run_room_live]      plays. Same branch. It now runs through to the end."
echo "[run_room_live]"
echo "[run_room_live]   The blue must still come back BLUE after every one of the five strobes,"
echo "[run_room_live]   not just the first. That is the P3.85c restore bug's blast radius and"
echo "[run_room_live]   it has only ever been tested against ONE strobe."
echo "[run_room_live]"
echo "[run_room_live] ** P3.90 -- THE HOURGLASS IS NOW SCENERY, AND THE EXIT IS ~20% FASTER."
echo "[run_room_live]   Your reading, implemented: only the SAND is animation. The glass body is"
echo "[run_room_live]   drawn when it CHANGES (twice in the scene) instead of ~20 times a second."
echo "[run_room_live]   The last three beats went 10.00 -> 8.17 / 8.68 / 8.00 frames per play."
echo "[run_room_live]   WATCH: the glass must not flicker, tear, or lose a hole where he walks"
echo "[run_room_live]   past it, and the sand must still run. 44 automated captures say it is"
echo "[run_room_live]   byte-identical -- but the sand is motion and a suite cannot judge motion."
echo "[run_room_live]"
echo "[run_room_live]   ONE BEAT IS TIGHT: her slump clears its budget by 1.4%, and its worst"
echo "[run_room_live]   frames still miss, so ~1 step in 3 there is still slow. Expected, measured,"
echo "[run_room_live]   and not safe to build on -- reported rather than smoothed over."
echo "[run_room_live]"
echo "[run_room_live] ** THE ENTRY WALK IS UNCHANGED -- you accepted it and the hourglass is not"
echo "[run_room_live]   on screen then. Still open and NOT fixed: the hourglass appearing before"
echo "[run_room_live]   the flash, and all of him but his feet vanishing as he turns to leave."
echo "[run_room_live]"
echo "[run_room_live] ** P3.87 -- NOTHING ELSE IN THE PICTURE HAS CHANGED SINCE THE LAST GATE."
echo "[run_room_live]   src/ is byte-identical. P3.87 was measurement only: the pace slip is"
echo "[run_room_live]   attributed (a step can only fire on a 3-frame loop boundary, so it lands"
echo "[run_room_live]   on 6, 8 or 10 and never between) and you ruled it stays AS IS. Do not"
echo "[run_room_live]   re-report the vizier's pace -- it is measured, accepted and closed."
echo "[run_room_live]"
echo "[run_room_live] ** TWO THINGS TO LOOK AT, and one of them has never been affirmed:"
echo "[run_room_live]   1. THE FLASH, over the beat where the hourglass appears. The restore bug"
echo "[run_room_live]      was fixed at P3.85c -- the blue must come back BLUE after each strobe,"
echo "[run_room_live]      not light green. You have not confirmed it, so it is NOT recorded as"
echo "[run_room_live]      passed. Please say either way."
echo "[run_room_live]   2. THE TURN, inside Vexit, just before he walks out. Cels 63 and 66"
echo "[run_room_live]      moved 4 px right at P3.103 -- the same converter trim that displaced"
echo "[run_room_live]      one walk cel in six. THE WALK-OUT IS GATED ('the exit walk looks"
echo "[run_room_live]      good', P3.103); the TURN was changed by the same fix and is not."
echo "[run_room_live]      Also unaffirmed: the mirrored cels' CHROMA is wrong on three of the"
echo "[run_room_live]      six walk cels (P3.103a). Colour, not position; it needs your ruling"
echo "[run_room_live]      because the colour model is DO-NOT-EDIT."
echo "[run_room_live]"
echo "[run_room_live] NOT IN YET: the 16-colour swap, the Prolog2 handoff, s_StTimer (untraced)."
echo "[run_room_live] palette is Karateka's 4c starting point: black / orange / blue / white."
echo "[run_room_live] close the window when you are done."

export P_PROG="ROOM"
export P_BIN="$BIN"
export P_OUT="build/room_live.log"

"$MAME" coco3 \
    -rompath "$MAME_ROMS" \
    $RAMOPT \
    -cfg_directory "dist/mame-cfg/$MONITOR" \
    -ext fdc \
    -flop1 "$DSK" \
    -window -nomaximize -prescale 2 \
    -sound none \
    -autoboot_script harness/smoke/room_live.lua
