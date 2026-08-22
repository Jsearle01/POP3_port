@echo off
REM build.bat — POP CoCo3 port build (native Windows; no WSL, no make).
REM
REM This is the BUILD half of the CLAUDE.md §1 test contract
REM   (25.1 fresh tool output = build.bat + run_*_test).
REM
REM BUILD MODEL: OBJECT + LINKED (P2.4). POP no longer assembles to an absolute
REM binary. Each translation unit is assembled to an object with
REM `lwasm --obj -DOBJTARGET`, and `lwlink` places them via link/pop.link:
REM
REM     KERNEL   src/harness/hal_build.s  -> build/obj/hal_build.o   (section code)
REM     PROGRAM  src/harness/loop_probe.s -> build/obj/loop_probe.o  (section prog)
REM                    |
REM                    +-- lwlink --script=link/pop.link --> build/loop_probe.bin
REM
REM The HAL's `export`s and hal.inc's `import`s are live in this model, so the
REM contract is resolved by the linker instead of being documentation nothing
REM checks. A call to a HAL entry point that is not exported is now a LINK ERROR.
REM
REM WHY -DOBJTARGET AND NOT A SEPARATE SOURCE TREE: one guarded HAL source serves
REM BOTH build models (P2.3-recon). karateka assembles the SAME files absolute with
REM the guard off and its binary does not change by one byte. One kernel, two builds.
REM
REM Requires:
REM   lwasm, lwlink  (LWTOOLS) on PATH
REM   python                   on PATH  (the HAL-sync pre-build check)
REM   imgtool        (MAME)    on PATH, or set IMGTOOL, or at C:\mame\imgtool.exe
REM
REM NOTE (carried from karateka build.bat, CLAUDE.md §2G): lwasm derives the
REM `include` base dir by splitting the source path on '/', so source args MUST
REM use forward slashes — backslashes make relative includes resolve against
REM the CWD and fail.
REM
REM Outputs (all under build/, which is gitignored — .dsk fixtures are
REM throwaway and generated per-task, never shared; idiom §3):
REM   build/obj/*.o              relocatable objects
REM   build/obj/*.map            link maps (the ABI, resolved)
REM   build/loop_probe.bin       DECB binary  (LOADM-able, exec $0200)
REM   build/hal_link_proof.bin   DECB binary  (ABI proof; not meant to run)
REM   build/probe.dmk            RS-DOS disk  (PROBE.BIN)
setlocal

for %%I in ("%~dp0.") do set "REPO_ROOT=%%~fI"
cd /d "%REPO_ROOT%"

REM ======================================================================
REM PRE-BUILD: HAL-SYNC BRIDGE (P2.4 Phase B)
REM
REM POP is LINKED and karateka is ABSOLUTE, from one guarded HAL source that
REM currently lives as two copies. This diffs them (EOL-normalised, guard-aware)
REM and FAILS THE BUILD on substantive drift — a script that merely exists
REM enforces nothing, so it runs here, on every build, before anything is
REM assembled. If the sibling repo is genuinely absent the check WARNS and the
REM build proceeds: a check that blocks legitimate builds gets deleted.
REM
REM TEMPORARY BY DESIGN — this block and harness/tools/hal_sync_check.py both
REM delete cleanly when the kernel becomes a single shared source.
REM ======================================================================
where python >nul 2>&1
if errorlevel 1 (
    echo [hal-sync] WARNING: python not found on PATH — HAL-sync check SKIPPED.
) else (
    python harness\tools\hal_sync_check.py
    if errorlevel 1 (
        echo *** BUILD BLOCKED BY HAL DRIFT — see [hal-sync] above ***
        exit /b 1
    )
)

REM --- locate lwasm / lwlink --------------------------------------------
where lwasm >nul 2>&1
if errorlevel 1 (
    echo ERROR: lwasm not found on PATH.
    echo Install LWTOOLS ^(lwasm/lwlink^) and add it to PATH, then re-run.
    exit /b 1
)
where lwlink >nul 2>&1
if errorlevel 1 (
    echo ERROR: lwlink not found on PATH.
    echo POP builds LINKED as of P2.4; lwlink is required, not optional.
    exit /b 1
)

REM --- locate imgtool ----------------------------------------------------
if not defined IMGTOOL (
    where imgtool >nul 2>&1
    if errorlevel 1 (
        if exist "C:\mame\imgtool.exe" (
            set "IMGTOOL=C:\mame\imgtool.exe"
        ) else (
            echo ERROR: imgtool not found on PATH and not at C:\mame\imgtool.exe.
            echo imgtool ships with MAME. Set IMGTOOL to its full path and re-run.
            exit /b 1
        )
    ) else (
        set "IMGTOOL=imgtool"
    )
)

if not exist build mkdir build
if not exist build\obj mkdir build\obj
if not exist build\assets mkdir build\assets

REM ======================================================================
REM THE TWO ADDRESSES THAT MORE THAN ONE FILE HAS TO AGREE ON.
REM
REM DR_VARBASE is disk_read.s's 7-byte parameter block; three assemblies have to be
REM told the same value or the kernel and its callers put it in different places.
REM FLAME_BASE is where the cutscene bundle lives; char_draw.s calls its own tables at
REM that address, cutscene_room.s expands the bundle to it, and link/pop_flames.link
REM links it there. It was $4200 written out three times independently, which is fine
REM until one of them moves. It moved (P3.31), so it is one variable now.
REM
REM 0x, NOT $ -- lwasm's -D takes a C-style literal and silently defines a $-prefixed
REM value as ZERO, with no warning (see the DR_VARBASE note below).
REM ======================================================================
set DR_VARBASE=0x6A00
set FLAME_BASE=0x3000
REM CEL_BASE AND CEL_TRACK ARE GONE AT P3.78, and their removal is the point rather than
REM tidying. They were this file's copy of two facts the SPLIT image now decides for
REM itself: the pinned page is at $C000 and each rotating page at $E000 (their two link
REM scripts say so, and decb_to_raw checks the binaries against the bases in
REM cel_pack.json), and the tracks are allocated by the packer because there are twelve
REM of them across three spans instead of one run of three. A `set CEL_TRACK=11` left
REM here would have been a stale constant with a live-looking name -- which is exactly
REM what CHAR_TAB was when it silently went eight bytes wrong (char_draw.s:131).
REM CEL_VARBASE is a real one, though, and it is shared: two objects that never link
REM together have to agree on where the beat's block number and page signature live.
REM $FE02 is in the constant page, which MC3=1 pins through every MMU remap -- the one
REM property this variable needs, since the thing it describes IS the remap. disk_read.s
REM owns $FE00/$FE01 and documents $FE02-$FE1F as free.
set CEL_VARBASE=0xFE02

REM SCENE_BASE / SCENE_CALL_OFF — where the scene's program is read to after the LOADM
REM handover, and the offset of its CALLED entry (P3.107). Both assemblies take them from
REM here so there is one home; cutscene_room.s asserts that room_call really is at
REM SCENE_BASE+SCENE_CALL_OFF and fails the build otherwise, because intro_seq.s calls that
REM address and cannot see the label.
REM ★ RAISED $2500 -> $2600 at P4.47. The scene program is read as a WHOLE TRACK -- 4608
REM bytes for a 1,191-byte program -- so the read starts at SCENE_BASE and runs to
REM SCENE_BASE+$1200. At $2500 that clipped the last 14 bytes of lz_unpack.o ($2480..$250D),
REM which load_screen still needs for beats 3, 4 and 5. The intro prog grew past $2500 when
REM BEAT_KEEP was added; the map tool LISTED the two regions overlapping and did not flag it.
REM $2600 puts the scene at $2600..$2A54 and leaves 242 B of prog headroom, taking the free
REM span above the scene from 1565 B to 1309 B. Nothing else moves.
set SCENE_BASE=0x2600
REM ★ Where the intro's program lives on disk, and the offset of the entry the stage-1
REM loader jumps to (P4.46). Both the loader and intro_seq.s take these from here, and
REM intro_seq.s asserts that intro_seq_boot really is at INTRO_BOOT_OFF -- so a drift is a
REM build error rather than a jump into the middle of probe_magic.
set INTRO_TRK=33
REM P5.5: the baked tile page for LEVEL0 screen 1. Track 34 is the LAST track of the
REM 35-track image and the only one nothing else claims -- 9-16 and 18-32 are assets or
REM cel pages, 17 is the RS-DOS directory, 33 is the intro's program.
set TILE_TRK=34
set INTRO_BOOT_OFF=11
set SCENE_CALL_OFF=11
REM The window the bundle is expanded inside: FLAME_BASE up to (not into) the disk
REM driver's parameter block. Loading through DR_VARBASE while the driver is using it
REM is what hung the room in P3.30, and it hung silently -- a read that lands on a live
REM parameter block does not fail, it just makes the next read read the wrong track.
set /a FLAME_WINDOW=0x6A00-0x3000

echo --- Assemble: HAL kernel unit (object) ---
REM Every HAL module opens `section code` and exports its hal.inc entry points
REM under -DOBJTARGET. The six runtime-blit entry points stay DORMANT in POP
REM (PA.6 / P1.3) and are deliberately NOT exported: a POP call to one is now a
REM link error naming the symbol. Add -DPOP_HAL_RUNTIME_BLIT to enable them.
REM 0x1F00, NOT $1F00: lwasm's -D takes a C-style literal and silently defines a
REM `$`-prefixed value as ZERO. It does not warn. Both sides then put the disk
REM parameter block at $0000 -- inside the HAL's DP scratch band -- and the first
REM read that follows any HAL call reads a clobbered track number.
REM DR_VARBASE relocates disk_read.s's 7 scratch bytes off its $2100 default,
REM which is inside POP's program region. $1F00 clears the intro's runtime asset
REM bundle ($0A00-$1BFF) and its patch save buffer ($1C00-$1EFF).
lwasm --obj -DOBJTARGET -DHAL_GFX_MODE_SERVICE -DDR_VARBASE=%DR_VARBASE% -I . -o build/obj/hal_build.o src/harness/hal_build.s
if errorlevel 1 goto :error
call :size build/obj/hal_build.o

echo --- Assemble: P1.1 loop probe (object) ---
lwasm --obj -DOBJTARGET -I . -o build/obj/loop_probe.o src/harness/loop_probe.s
if errorlevel 1 goto :error
call :size build/obj/loop_probe.o

echo --- Assemble: HAL ABI link proof (object) ---
lwasm --obj -DOBJTARGET -I . -o build/obj/hal_link_proof.o src/harness/hal_link_proof.s
if errorlevel 1 goto :error
call :size build/obj/hal_link_proof.o

echo --- Assemble: P2.5 mode-cycling probe (object) ---
lwasm --obj -DOBJTARGET -I . -o build/obj/mode_probe.o src/harness/mode_probe.s
if errorlevel 1 goto :error
call :size build/obj/mode_probe.o

echo --- Assemble: P3.2 intro splash (first engine screen) ---
lwasm --obj -DOBJTARGET -I . -o build/obj/intro_splash.o src/engine/intro_splash.s
if errorlevel 1 goto :error
call :size build/obj/intro_splash.o

echo --- Assemble: P3.3 intro sequencer (both credits, one mechanism) ---
lwasm --obj -DOBJTARGET -DDR_VARBASE=%DR_VARBASE% -DSCENE_BASE=%SCENE_BASE% -DSCENE_CALL_OFF=%SCENE_CALL_OFF% -DINTRO_BOOT_OFF=%INTRO_BOOT_OFF% -I . -o build/obj/intro_seq.o src/engine/intro_seq.s

if errorlevel 1 goto :error

lwasm --obj -DOBJTARGET -I . -o build/obj/lz_unpack.o src/engine/lz_unpack.s

if errorlevel 1 goto :error

REM ★ THE TWO TRANSCRIPTIONS OF THE ORACLE'S SEQUENCES MUST AGREE (P3.78).
REM char_draw.s carries the scene's sequences as hand-written `fcb` streams; beat_recost
REM parses the same sequences out of SEQTABLE.S to decide which cels each beat draws, and
REM the packer builds the bank layout from THAT. Nothing compared them, and they disagreed:
REM the tracer read `:loop` as a global label where Mechner's assembler scopes it to the
REM enclosing routine, so Pback's `goto :loop` retargeted to Pslump's and the trace had the
REM princess holding cel 18 where the engine holds 17. The packer then provisioned a cel
REM the scene never draws and omitted one it draws for four beats -- and the beat after
REM Pback drew from an unmapped page, which the blitter walked as a segment stream and
REM never returned from. The room hung with interrupts masked, five beats from the end.
REM
REM The packer's own "is this beat's set reachable" assertion could not catch it: both
REM sides of that check come from the same trace, so it agreed with itself. This is the
REM independent one -- run it BEFORE the bundle is assembled, since char_draw.s is what it
REM reads and the bake is what it protects.
python harness/tools/verify_sequences.py
if errorlevel 1 (
    echo *** BUILD BLOCKED: the port's sequences and the traced oracle disagree ***
    exit /b 1
)

REM ★★ THE HARNESS'S OWN OFFSETS, SWEPT ON EVERY BUILD (P3.83).
REM
REM A stale checker does not fail -- it PASSES FOR THE WRONG REASON, and all five this
REM project has found were found by accident while chasing something else: P3.65's reader
REM of a file the bake no longer produced; P3.71's capture path that un-mapped the cel bank
REM and so caused the failure it was measuring; P3.80's room_test.lua at the pre-16-bit
REM ch_last offsets, which is why "296 bytes disturbed" was blamed on the clip for two
REM dispatches; P3.82's flame checker skipping every position line on a field count that
REM had been wrong for eleven dispatches; and P3.83's beat counter, which reported 16 of 18
REM for a scene that reaches all eighteen.
REM
REM This is that sweep made mechanical, so the sixth is found on purpose. It is DEMONSTRATED
REM to fire: seeding walk_test.lua's CH_CEL back to its pre-16-bit value exits 1.
python harness/tools/harness_offsets_check.py
if errorlevel 1 goto :error

REM --- a cel number names a TABLE and an image, and the bake must use both (P3.95) ---
REM decodeim [CTRLSUBS.S:1017-1037] returns FCharTable AND FCharImage. bake_scene computed
REM the image and hard-coded the table as CHTAB6.A, so eight vcast-* frames were baked from
REM 13-row stubs where CHTAB7 holds the real 48-to-50-row cels -- the vizier drawn as his
REM feet and nothing above them, for a frame at his raise and at his turn. NOTHING ELSE CAN
REM SEE THIS: a wrong-table bake is a well-formed file of a plausible size holding real cel
REM data, so the assembler, the packer, the link map and the pixel checkers all agree with
REM it. Three live gates and Jay's eye is what found it.
python harness/tools/chartable_audit.py
if errorlevel 1 goto :error

REM --- the flash's restore palette must match the HAL's live table (P3.85c) --------
REM char_draw.s duplicates gfx_pal4 because the flame bundle links separately from the
REM room that holds the HAL and gfx_pal4 is not exported. The duplicate had $1B for blue
REM where the table has $19 -- a value taken from an inline store in gfx.s's init path
REM rather than from the table the machine loads; the two disagree inside the HAL itself.
REM The flash RESTORES that palette after painting white, so the wrong byte repainted the
REM scene permanently the first time it fired. It did not look like a flash bug -- Jay:
REM "it changes the blue color to a light greenish color but doesn't 'flash white at all."
python harness/tools/palette_check.py
if errorlevel 1 (
    echo *** BUILD BLOCKED: a harness offset no longer matches the build ***
    exit /b 1
)

REM ★ EVERY BAKED CEL WALKED THE WAY THE 6809 WALKS IT (P3.85).
REM cel_blit_prep replays each cel as it emits it, but that checks the PIXELS. This checks
REM the STREAM'S SHAPE: does every cel consume exactly the bytes it occupies? A stream that
REM ends one byte early leaves the blitter reading the NEXT cel's header as a segment, and
REM the damage surfaces somewhere else entirely -- which is the failure mode a format change
REM produces. Added when the segment header was packed to one byte.
python harness/tools/verify_cel_streams.py
if errorlevel 1 (
    echo *** BUILD BLOCKED: a baked cel stream is malformed ***
    exit /b 1
)

echo --- Assemble+link+PACK: cutscene code bundle (disk-resident) ---
REM MOVED AHEAD OF THE ROOM (P3.31), because the room now depends on this step's
REM OUTPUT and not merely on its existence: lz_pack emits build/obj/flame_load.inc,
REM which tells cutscene_room.s where the packed blob has to be read to. That address
REM is `FLAME_BASE + window - blob` and steps by a whole track when the bundle grows,
REM so it is generated rather than written down. Build order is the dependency.
REM char_draw.s NO LONGER TAKES -DFLAME_BASE (P3.62): it is linked into the bundle
REM alongside blit_core.o below, so it imports blit_cel/blit_save/blit_erase instead of
REM calling them through a hard-coded offset. Only cutscene_room.s needs the base now.
REM %SEEDFLAG% is normally EMPTY. It exists so a deliberately-seeded fault can be built
REM without editing this file (P3.71 §2 — a probe's silence counts only once it has been
REM shown to detect a seeded failure). Set it in the environment, never here.
lwasm --obj -DOBJTARGET %SEEDFLAG% -DCEL_VARBASE=%CEL_VARBASE% -I . -o build/obj/char_draw.o src/engine/char_draw.s
if errorlevel 1 goto :error
lwasm --obj -DOBJTARGET -I . -o build/obj/blit_core.o src/engine/blit_core.s
if errorlevel 1 goto :error
REM --- the torch flames as SEGMENT STREAMS, one set per torch (P3.54) ------------
REM They were COMPILED SPRITES until now -- the last ones in the tree. P3.18 measured
REM that representation at 8.2x the RAM of packed bitmaps and it is what put the
REM cutscene outside 128 KB; the characters moved to segment streams and the flames
REM never did. Retiring them frees 532 B AND fixes the alignment in the same change.
REM
REM TWO SETS, BECAUSE THE TWO TORCHES SIT ON DIFFERENT SUB-BYTE PHASES. ptorchoff is
REM db 0,6 [SUBS.S:307] and Apple hires is 7 px/byte against CoCo3's 4, so torch 0
REM lands on phase 0 and torch 1 on phase 1. One set can only place both on the same
REM phase, which is why the right torch was a pixel left of true. Torch 0 keeps phase
REM 3 (px 111) and torch 1 phase 1 (px 201) -- both at their TRUE positions now.
REM cel_blit_prep REPLAYS the blit over a background before emitting, so a cel that
REM does not reconstruct is never written.
if not exist buildlames_seg mkdir buildlames_seg
for %%N in (1 2 3 4 5 6 7 8 9) do (
  python harness/tools/cel_blit_prep.py content/cutscene/flames/flame%%N/converted.s --phase 3 --label flseg0_%%N --out build/flames_seg/t0_%%N.s || goto :error
  python harness/tools/cel_blit_prep.py content/cutscene/flames/flame%%N/converted.s --phase 1 --label flseg1_%%N --out build/flames_seg/t1_%%N.s || goto :error
)
REM --- the hourglass and its sand, the same way (P3.85) --------------------------
REM Five cels, not the twelve P3.64 costed and six dispatches then deferred against:
REM PlayCut0 reaches glass states 0 and 1 only [SUBS.S:722,745], plus the three sand
REM frames. 994 B measured. They ride in the flame bundle rather than the paged cel
REM image because they are live from the hourglass beat to the end of the scene, across
REM a block change the packer will not let a cel straddle.
REM
REM PHASES ARE NOT THE SAME FOR THE TWO, for the torches' reason. CoCo px = Apple px + 20
REM (280 centred in 320): glassx 19 -> px 153 = byte 38 phase 1, and flowx 20 -> px 160 =
REM byte 40 phase 0. One phase for both would put the glass a pixel off, which is the
REM exact defect P3.56 spent a dispatch correcting on the left torch.
if not exist build\glass_seg mkdir build\glass_seg
python harness/tools/cel_blit_prep.py content/cutscene/glass/glass0/converted.s --phase 1 --label glseg_g0 --out build/glass_seg/g0.s || goto :error
python harness/tools/cel_blit_prep.py content/cutscene/glass/glass1/converted.s --phase 1 --label glseg_g1 --out build/glass_seg/g1.s || goto :error
python harness/tools/cel_blit_prep.py content/cutscene/glass/flow0/converted.s --phase 0 --label glseg_f0 --out build/glass_seg/f0.s || goto :error
python harness/tools/cel_blit_prep.py content/cutscene/glass/flow1/converted.s --phase 0 --label glseg_f1 --out build/glass_seg/f1.s || goto :error
python harness/tools/cel_blit_prep.py content/cutscene/glass/flow2/converted.s --phase 0 --label glseg_f2 --out build/glass_seg/f2.s || goto :error

lwasm --obj -DOBJTARGET -I . -o build/obj/flame_cels.o src/engine/flame_cels.s
if errorlevel 1 goto :error
lwlink --decb --script=link/pop_flames.link --map=build/obj/flames.map -o build/flame_cels.bin build/obj/flame_cels.o build/obj/blit_core.o build/obj/char_draw.o
if errorlevel 1 goto :error
REM ★ THE CHECK THAT WAS MISSING AT P3.54 (P3.62). cutscene_room.s is a SEPARATE image and
REM must reach into this bundle by arithmetic (BLIT_TAB equ FLAME_BASE+40), so its numbers
REM and the linker's layout are two independent assertions of one fact with nothing
REM comparing them. When they drifted, the build linked cleanly, the room booted, the disk
REM read twice and the VM stepped before it jumped into cel data -- so neither a green
REM link nor a good boot is evidence here. This compares the room's `equ`s against the map
REM and fails the build on any divergence. It must run AFTER the flames link (it reads the
REM map) and BEFORE the room is assembled against those same constants.
python harness/tools/bundle_offsets_check.py --room src/engine/cutscene_room.s --map build/obj/flames.map
if errorlevel 1 goto :error
REM --base must equal the link script's load address EXACTLY; decb_to_raw fails the
REM build if the two have drifted, which is the only check that can see that pair.
python harness/tools/decb_to_raw.py --bin build/flame_cels.bin --out build/assets/flames.raw --base %FLAME_BASE%
if errorlevel 1 goto :error
REM THE BUNDLE IS PACKED, AND IT IS STRUCTURAL RATHER THAN AN OPTIMISATION. Unpacked
REM it is over 14 KB and load_tracks reads WHOLE TRACKS, so no track count lands it in
REM the 14,848 B between FLAME_BASE and the disk driver's parameter block: two tracks
REM are too few and three overrun into $6A00 while the driver is using it (P3.30 hung
REM the room exactly there). Packed it is two tracks, and the in-place expand is
REM memory-to-memory, which has no track granularity at all.
python harness/tools/lz_pack.py build/assets/flames.raw --out-dir build/assets ^
       --window-cap %FLAME_WINDOW% --dest-base %FLAME_BASE% --emit-inc build/obj/flame_load.inc
if errorlevel 1 goto :error

REM ======================================================================
REM THE CEL IMAGE IS SPLIT AS OF P3.78, and it is built AFTER the disk image
REM exists, because placing it needs the .dsk to write into. See the block
REM further down, past the imgtool create -- this note is left here, where the
REM single-image build used to be, so the move is visible rather than silent.
REM
REM It was ONE unit linked at $C000 (link/pop_cels.link, P3.71) while the scene
REM was eleven beats. The full scene is 39,682 B of cel image against a bank
REM that is 31,744 B addressable, so it is now a PINNED page at $C000 plus five
REM ROTATING pages that all link at $E000 and take turns in $FFA7.
REM ======================================================================

echo --- Assemble: P3.17 princess room (4-colour, static) ---

lwasm --obj -DOBJTARGET -DDR_VARBASE=%DR_VARBASE% -DFLAME_BASE=%FLAME_BASE% -DCEL_VARBASE=%CEL_VARBASE% -DSCENE_CALL_OFF=%SCENE_CALL_OFF% -I . -o build/obj/cutscene_room.o src/engine/cutscene_room.s
if errorlevel 1 goto :error
call :size build/obj/intro_seq.o

echo --- Link: probe + HAL kernel ---
REM --section-base is SILENTLY IGNORED by lwlink (P2.3-recon D4) — the script is
REM the only thing that actually places a section. Do not "simplify" this to a flag.
lwlink --decb --script=link/pop.link --map=build/obj/probe.map ^
       -o build/loop_probe.bin build/obj/loop_probe.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/loop_probe.bin

echo --- Link: HAL ABI proof (every live hal.inc import must resolve) ---
lwlink --decb --script=link/pop.link --entry=link_proof_entry --map=build/obj/proof.map ^
       -o build/hal_link_proof.bin build/obj/hal_link_proof.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/hal_link_proof.bin

echo --- Assemble: P2.6 double-buffered animation probe (object) ---
lwasm --obj -DOBJTARGET -I . -o build/obj/anim_probe.o src/harness/anim_probe.s
if errorlevel 1 goto :error

REM P4.2 — the tone-cost INSTRUMENT. Not a sound system: it measures how much of a frame a
REM square wave costs, in the two architectures the sound design forks on. It ships on the
REM probe disk like the other harness probes and is not reached by anything the port runs.
lwasm --obj -DOBJTARGET -I . -o build/obj/tone_probe.o src/harness/tone_probe.s
if errorlevel 1 goto :error

REM P4.5 -- the SONG SLICE. It plays a table MEASURED off the running oracle's own speaker
REM (harness/tools/oracle_speaker_intervals.lua), packed here. Nothing is decoded from
REM MUSIC.SET*. Like tone_probe it is a harness probe and is NOT written to the shipping
REM disk -- run_song_slice.sh puts it on a copy, because P4.2's instrument on probe.dmk
REM took granules over a reserved cel-page track and broke the walk suite.
if not exist build\gen mkdir build\gen
REM -- THE TWO CONSTANTS BELOW ARE MEASURED, NOT ASSUMED (P4.6 SS1). song_live.lua's
REM    P_PULSE tap times the port's own $FF20 writes, so the emitted pulse and the emitted
REM    segment period are read off the bus and fed back here. P4.5 modelled the pulse
REM    instead and every one of them ran ~6.6 us wide.
REM      SONG_PULSE_OVH  cycles in the emitted pulse OUTSIDE the delay loop
REM      SONG_LATENCY    us from the timer hitting zero to the period actually restarting.
REM    * WITH THE DITHER RETIRED (Jay: "i don't hear a difference") the timer AUTO-RELOADS
REM      and the handler never rewrites it -- so this is almost entirely the GIME's own
REM      nnn+2 (SockmasterGime.md:83), measured free-running at +127.80 us = 2.01 ticks.
REM      The dither build's figures were 170.24/225.22 and are NOT interchangeable.
REM      SONG_LATENCY_ADV  ditto on the interrupt that also walks the table (+55 us)
REM    * SONG_CUT -- where the captured stream is cut, in seconds. Jay, hearing the 6.5 s
REM      version looped against the oracle: "the port sounds like the same piece repeated 3
REM      times. the oracle sounds like 3 different pieces." It was not a loop bug -- the port
REM      only HAD 6.5 s, because P4.4 captured a 400-frame window and everything since was
REM      built on it. The capture is now 5400 frames (90 s) and the cut lands on the 6-second
REM      silence at 36.6 s, which is where the music itself stops: 42.5 s of it, ending on a
REM      rest rather than mid-phrase. The raw capture stays whole; the cut lives HERE.
set SONG_CUT=37.6
set SONG_PULSE_OVH=5.0
set SONG_LATENCY=127.80
set SONG_LATENCY_ADV=195.78
REM -- TWO TABLES, ONE CODE PATH. A is the as-built quantisation (frac=0); B carries the
REM    fractional tick so the mean period is right. The ONLY difference Jay hears is the
REM    detune -- which is what makes the A/B a question he can answer (his words: "it's
REM    going to be hard to gate something without knowing what it would sound like the
REM    other way").
python harness/tools/pack_song.py --pairs content/sound/princess_cutscene_speaker_pairs.txt --out build/gen/song_a.s --label song_a --latency-us %SONG_LATENCY% --latency-adv-us %SONG_LATENCY_ADV% --pulse-overhead-cyc %SONG_PULSE_OVH% --max-seconds %SONG_CUT% --max-runs 6000
if errorlevel 1 goto :error
python harness/tools/pack_song.py --pairs content/sound/princess_cutscene_speaker_pairs.txt --out build/gen/song_b.s --label song_b --dither --latency-us %SONG_LATENCY% --latency-adv-us %SONG_LATENCY_ADV% --pulse-overhead-cyc %SONG_PULSE_OVH% --max-seconds %SONG_CUT% --max-runs 6000
if errorlevel 1 goto :error
lwasm --obj -DOBJTARGET -I . -o build/obj/song_probe.o src/harness/song_probe.s
if errorlevel 1 goto :error

REM -- THE INTERPRETED PLAYER (P4.19). The note stream, not a recording.
REM    gen_msys_tables.py emits BOTH the tables and the 1,024-byte song page from the SAME
REM    decoded grammar msys_decode.py validates against the oracle's capture -- one home
REM    for each fact (CLAUDE.md §2F), so the port and the validator cannot disagree.
REM    ★ The generated files carry NO `section` directive: they are included inside
REM    msys_player.s's section, and lwasm cannot nest sections.
python harness/tools/gen_msys_tables.py
if errorlevel 1 goto :error
lwasm --obj -DOBJTARGET -I . -o build/obj/msys_player.o src/engine/msys_player.s
if errorlevel 1 goto :error
call :size build/obj/msys_player.o
REM -- THE A/B's CAPTURE SIDE: the SAME song the interpreter walks, at the SAME length.
REM    song_a is PlayCut0's whole 37.6 s stretch; s_Princess is 12.7 s. Pairing those is
REM    not an A/B. This packs the oracle's own per-song capture of song 7 -- one of only
REM    two of the eleven that are uncontaminated (P4.19 §3E).
python harness/tools/pack_song.py --pairs content/sound/song_7_s_Princess_pairs.txt --out build/gen/song_princess.s --label song_a --latency-us %SONG_LATENCY% --latency-adv-us %SONG_LATENCY_ADV% --pulse-overhead-cyc %SONG_PULSE_OVH% --max-seconds 0 --max-runs 8000
if errorlevel 1 goto :error
lwasm --obj -DOBJTARGET -I . -o build/obj/interp_probe.o src/harness/interp_probe.s
if errorlevel 1 goto :error
call :size build/obj/anim_probe.o

echo --- Link: mode-cycling probe + HAL kernel ---
REM Exercises the P2.5 kernel service across the linked ABI: the probe imports
REM HAL_gfx_set_mode and the published geometry from hal.inc, so a service that
REM is declared but not exported fails HERE rather than at runtime.
lwlink --decb --script=link/pop.link --entry=mode_entry --map=build/obj/mode.map ^
       -o build/mode_probe.bin build/obj/mode_probe.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/mode_probe.bin

echo --- Link: animation probe + HAL kernel ---
REM Proves the double-buffer ABI resolves: HAL_gfx_swap plus the published
REM draw base and swap counters all come from the kernel object.
lwlink --decb --script=link/pop.link --entry=anim_entry --map=build/obj/anim.map ^
       -o build/anim_probe.bin build/obj/anim_probe.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/anim_probe.bin

REM ★★★ pop_engine.link, NOT pop.link. The P1.x probes link at $0200 under a HARNESS
REM CONTRACT (their verifier gates the LOADM on the bytes at $0200), and this instrument
REM has no such contract — so at $0200 its 1,354 bytes run $0200..$074A, straight through
REM all three regions pop_engine.link names: the line-input buffer at $02DC where typing
REM EXEC lands, the text screen at $0400 where DECB prints "OK", and DBUF0/DBUF1 at $0600.
REM P3.5 caught that on the bus ($02DD <- 'E', $02DE <- 'X'): the command that starts the
REM program corrupts the program. $2000 clears all three.
lwlink --decb --script=link/pop_engine.link --entry=probe_entry --map=build/obj/tone.map ^
       -o build/tone_probe.bin build/obj/tone_probe.o build/obj/hal_build.o
if errorlevel 1 goto :error

lwlink --decb --script=link/pop_engine.link --entry=probe_entry --map=build/obj/song.map ^
       -o build/song_probe.bin build/obj/song_probe.o build/obj/hal_build.o
if errorlevel 1 goto :error

REM ★★ ONE BINARY, BOTH PLAYERS. Pass A interprets MUSIC.SET1's own bytes; pass B replays
REM    the P4.4 capture through the IDENTICAL FIRQ+DAC back end. Two binaries is how the
REM    thing measured and the thing demonstrated drift apart (P4.6), and this A/B is the
REM    bigger question -- the two paths do not share a note.
REM ★★★ AND AGAIN AS A DISK-RESIDENT UNIT. The probe LOADMs the player; the INTRO will
REM     READ it, the way the caption bundle, the scene, the scene bundle and four cel
REM     pages all arrive (intro_seq.s:51 -- "that is exactly why the assets are READ
REM     here rather than LOADED here"). P4.19 linked it into INTROSEQ.BIN first and
REM     LOADM truncated: the suite read $7900..$7D43 as "34..00" against "34..39".
REM     ★★ ONE ADDRESS FOR BOTH PATHS ($0E00), so there is ONE binary and the ear gate
REM     tests exactly what ships.
lwlink --decb --script=link/pop_msys.link --entry=msys_entry --map=build/obj/msys.map -o build/msys_player.bin build/obj/msys_player.o
if errorlevel 1 goto :error
call :size build/msys_player.bin
python harness/tools/decb_to_raw.py --bin build/msys_player.bin --out build/assets/msys_player.raw --base 0x0A00
if errorlevel 1 goto :error

lwlink --decb --script=link/pop_engine.link --entry=probe_entry --map=build/obj/interp.map ^
       -o build/interp_probe.bin build/obj/interp_probe.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/interp_probe.bin
call :size build/song_probe.bin
call :size build/anim_probe.bin

echo --- Link: intro splash + HAL kernel ---
lwlink --decb --script=link/pop.link --entry=intro_entry --map=build/obj/intro.map ^
       -o build/intro_splash.bin build/obj/intro_splash.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/intro_splash.bin

echo --- Link: intro sequencer + HAL kernel ---
REM The tightest link in the project: 28,468 bytes of asset in a 30,208-byte
REM program region. Check build/obj/introseq.map after ANY asset change -- lwlink
REM places overlapping sections silently, and did so three times in P3.2.
REM link/pop_engine.link, NOT link/pop.link: the engine loads at $2000 because
REM Color BASIC's line-input buffer at $02DC is where the typed EXEC lands, on top
REM of a program loaded at $0200 (P3.5). The probes keep $0200 -- they are pinned
REM there by the P1.1 harness contract and are small enough to stay under $02DC.
REM ★★★ msys_player.o IS DELIBERATELY NOT HERE, AND IT WAS TRIED (P4.19). Linking it in
REM     took the image from 2,215 B of payload to 5,317 and LOADM TRUNCATED: the suite
REM     read $7900..$7D43 as "34..00" against "34..39" -- the kernel segment started and
REM     did not finish. That is the LOADM ceiling this file's link script documents
REM     ("prog ending $2487 boots; $2535 image corrupted"), and it is a TOTAL SIZE limit,
REM     not an address one -- the player links and runs fine at $0E00 in interp_probe.bin,
REM     which is 9 KB, because that binary is LOADM'd off a single-file disk.
REM     ★★ THE ROUTE IS THE ONE link/pop_engine.link ALREADY NAMES: put it on a
REM     disk-resident track and read it with the HAL's WD1773 primitive, the way the
REM     caption bundle, the scene and the cel pages all arrive. That is a design step.
lwlink --decb --script=link/pop_engine.link --entry=intro_seq_entry --map=build/obj/introseq.map ^
       -o build/intro_seq.bin build/obj/intro_seq.o build/obj/lz_unpack.o build/obj/hal_build.o

if errorlevel 1 goto :error

call :size build/intro_seq.bin



echo --- Link: princess room + HAL kernel ---

lwlink --decb --script=link/pop_engine.link --entry=room_entry --map=build/obj/room.map -o build/cutscene_room.bin build/obj/cutscene_room.o build/obj/lz_unpack.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/intro_seq.bin

echo --- Link: the scene, STAGED PAST THE LOADM HANDOVER (P3.106) ---
REM The same objects, linked at $2500 instead of $2000 and read from a track by the intro
REM AFTER BASIC has handed over. link/pop_scene.link carries the whole reasoning; the short
REM form is that the merged image was ~$820 over the MEASURED ceiling $2488..$2535, and the
REM ceiling binds on what is resident AT THE HANDOVER rather than on what the program holds.
REM
REM hal_build.o is present so the scene's HAL_* calls resolve (lwasm object mode makes an
REM undefined symbol an external automatically); the kernel SEGMENT is then dropped, because
REM it is already resident at $7900 and re-reading it from a track while it executes the
REM read would overwrite the routine mid-transfer.
lwlink --decb --script=link/pop_scene.link --entry=room_entry --map=build/obj/scene.map -o build/scene_prog.bin build/obj/cutscene_room.o build/obj/lz_unpack.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/scene_prog.bin

REM ★ THE DROP IS ONLY SAFE IF THE TWO KERNELS ARE THE SAME BYTES AT THE SAME ADDRESS.
REM They are, by construction — and "by construction" is the exact shape of assumption this
REM project has been bitten by four times, so it is asserted against the artefacts rather
REM than trusted from the inputs.
python harness/tools/kernel_identical_check.py --resident build/intro_seq.bin --staged build/scene_prog.bin
if errorlevel 1 goto :error

REM ★ THE $5400 CONDITION, ASSERTED. The TITLE caption's save runs $5400..$68F1 and the
REM scene's packed bundle lands $5800..$69FF — they overlap, and only the absence of a patch
REM on beats 4 and 5 makes the call safe. A comment describing an unenforced discipline has
REM failed here twice, so it is a check.
python harness/tools/beat_patch_check.py
if errorlevel 1 goto :error

python harness/tools/decb_to_raw.py --bin build/scene_prog.bin --out build/assets/scene_prog.raw --base %SCENE_BASE% --span-end 0x7900
if errorlevel 1 goto :error

echo --- Bootable RS-DOS disk image ---
REM .dsk is always 18 sectors/track (idiom §3); default geometry is correct.
REM DMK, interleave 0 (SEQUENTIAL) -- NOT JVC. MAME synthesises a near-pessimal
REM physical order for JVC and the whole-track m=1 read paid ~0.89 revolutions per
REM SECTOR for it: 3.31 s/track here, 3.33 s/track on karateka. DMK keeps the
REM authored order, and sequential is the FASTEST for a Read-Multiple loader --
REM which inverts the usual RS-DOS spread-the-sectors convention.
REM [karateka docs/project/interleave-realization-mame.md; POP idiom 29]
REM
REM *** THOSE 3.31 s ARE THE PRE-DMK JVC FIGURE AND HAVE NOT BEEN TRUE SINCE P3.6. ***
REM They are kept above only to say what the DMK switch bought. On the CURRENT build,
REM measured at P3.75b by decomposing the room's three reads (1 track, 1 track, 3
REM tracks -- harness/tools/load_timing.lua):
REM
REM     one TRACK     72 frames   1.20 s
REM     one SPIN-UP   36 frames   0.60 s   (dr_spinup, a delay LOOP, not a hardware wait)
REM
REM The stale number outlived its correction by sixty-nine dispatches and then misled a
REM design report into costing a mid-scene read at 3.3 s instead of 1.2. A measurement
REM quoted in a comment needs the date of the tree it was taken on, or it becomes a
REM claim about a build nobody can identify.
if exist build\probe.dmk del /q build\probe.dmk
"%IMGTOOL%" create coco_dmk_rsdos build\probe.dmk --tracks=35 --sectors=18 --sectorlength=256 --interleave=0
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_dmk_rsdos build\probe.dmk build\loop_probe.bin PROBE.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
call :size build/probe.dmk
"%IMGTOOL%" put coco_dmk_rsdos build\probe.dmk build\mode_probe.bin MODE.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_dmk_rsdos build\probe.dmk build\anim_probe.bin ANIM.BIN --ftype=binary --ascii=binary
REM ★★★ P4.2's tone-cost instrument is NOT put on this disk, and that is the point.
REM It was, for one build, and it broke run_walk_test: DECB allocated its granules over a
REM reserved cel-page track, the engine's own bank guard fired, and the walk suite reported
REM "0 of 19 beats". The instrument is not part of the port and the shipping disk has no
REM room to spare (13,824 B free), so run_tone_cost.sh adds TONE.BIN to its OWN COPY at run
REM time. An instrument that perturbs its neighbours is not an instrument.
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_dmk_rsdos build\probe.dmk build\intro_splash.bin INTRO.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
REM ★★★ INTROSEQ.BIN IS NO LONGER A DECB FILE (P4.46). The stage-1 loader reads the
REM intro's PROGRAM off a raw track and jumps to it, so nothing LOADMs it any more. Two
REM things follow, both wanted:
REM   * the disk's file area drops from 18 granules to 17 and comes off the boundary it
REM     was sitting on -- 18 was exactly tracks 0..8, and the next granule IS track 9's
REM     raw asset span, which is how ROOM.BIN got silently overwritten at P4.29.
REM   * the kernel segment is never read at all: the loader's own $7900 is the same
REM     hal_build.o at the same address, so the intro finds it already resident.
REM build/intro_seq.bin is still BUILT and still map-checked; only the prog SEGMENT of it
REM reaches the disk, as build/assets/intro_prog.raw below.
REM ROOM.BIN IS PUT LAST OF ALL, AFTER THE RAW TRACKS ARE RESERVED (P4.25b) -- see the
REM block below the reservations. It is the only file that has ever reached granule 18.
echo --- Raw intro assets onto whole tracks ---
REM The screen is NOT a DECB file. disk_read_range reads whole tracks and knows
REM nothing about directories, and a program at $0200 cannot LOADM past one
REM granule anyway (idioms 23). Tracks 27-34 sit above the track-17 directory;
REM the granules are reserved in the FAT with no directory entry, which DECB
REM tolerates exactly (karateka decb-loadm-boot-gates.md gate G1).
python harness/tools/make_intro_assets.py --out-screen build/assets/intro_screen.raw --out-bundle build/assets/intro_bundle.raw ^
       --prolog content/intro/prolog1.bin build/assets/prolog1.raw ^
       --prolog content/intro/prolog2.bin build/assets/prolog2.raw
if errorlevel 1 goto :error

REM Pack the screens. Raw they are 7 tracks / 9.0 s each and disk is a third of the
REM intro; packed they are 2 tracks / 2.6 s, and the engine expands each one in
REM place inside the buffer it will be displayed from, so this costs no RAM and
REM works on a 128 KB machine. lz_pack.py verifies each blob by decoding it out of
REM a single buffer exactly as lz_unpack does.
python harness/tools/lz_pack.py build/assets/intro_screen.raw build/assets/prolog1.raw build/assets/prolog2.raw --out-dir build/assets
if errorlevel 1 goto :error
REM The princess room is 4-colour: 15,360 B raw, one track packed.
python harness/tools/lz_pack.py content/cutscene/princess_room.raw --out-dir build/assets
if errorlevel 1 goto :error

python harness/tools/raw_tracks.py --dsk build/probe.dmk --asset build/assets/intro_screen.lz --track 27 --tracks 2 --reserve --imgtool "%IMGTOOL%"
if errorlevel 1 goto :error
python harness/tools/raw_tracks.py --dsk build/probe.dmk --asset build/assets/intro_bundle.raw --track 25 --tracks 2 --reserve --imgtool "%IMGTOOL%"
if errorlevel 1 goto :error
REM the two prologue screens: the FIRST beats with their own picture, so they
REM need their own raw spans. Both still clear the track-17 directory; packing
REM freed tracks 11-15 and 20-24, which nothing claims yet.
python harness/tools/raw_tracks.py --dsk build/probe.dmk --asset build/assets/prolog1.lz --track 9 --tracks 2 --reserve --imgtool "%IMGTOOL%"
if errorlevel 1 goto :error
python harness/tools/raw_tracks.py --dsk build/probe.dmk --asset build/assets/prolog2.lz --track 18 --tracks 2 --reserve --imgtool "%IMGTOOL%"
if errorlevel 1 goto :error
python harness/tools/raw_tracks.py --dsk build/probe.dmk --asset build/assets/princess_room.lz --track 29 --tracks 1 --reserve --imgtool "%IMGTOOL%"
if errorlevel 1 goto :error
python harness/tools/raw_tracks.py --dsk build/probe.dmk --asset build/assets/flames.lz --track 30 --tracks 2 --reserve --imgtool "%IMGTOOL%"
REM ★ Track 32: the first free one (9-31 are allocated, 17 is the RS-DOS directory).
REM   --reserve marks the granules used-with-no-directory-entry so DECB cannot
REM   allocate a file over them -- P4.2 lost a suite to exactly that.
python harness/tools/raw_tracks.py --dsk build/probe.dmk --asset build/assets/msys_player.raw --track 32 --tracks 1 --reserve --imgtool "%IMGTOOL%"
if errorlevel 1 goto :error
REM The scene's program, on track 24. One track holds 9,216 B against the image's ~1,150.
REM
REM ★ NOT TRACK 17, AND P3.104's MAP WAS WRONG ABOUT THAT. That map read "tracks 17 and 24
REM are free" from the ASSET allocation, and 17 carries no asset — because it is the RS-DOS
REM DIRECTORY track. raw_tracks.py refused it outright ("tracks 17..17 cross the directory
REM track 17 - that is silent corruption, pick another span"), which is the check doing
REM exactly its job: free-of-assets and free are different questions, and only one of them
REM was asked.
python harness/tools/raw_tracks.py --dsk build/probe.dmk --asset build/assets/scene_prog.raw --track 24 --tracks 1 --reserve --imgtool "%IMGTOOL%"
if errorlevel 1 goto :error

REM ======================================================================
REM ROOM.BIN, PUT HERE AND NOT WITH THE OTHER FILES (P4.25b)
REM
REM THE FILES ARE ALLOCATED FROM GRANULE 0 UPWARD AND THE RAW ASSETS ARE NOT.
REM PROBE+MODE+ANIM+INTRO+INTROSEQ fill granules 0..17, which is tracks 0..8 -- and the
REM first raw asset track is 9, which IS granules 18,19. ROOM.BIN is the sixth file and
REM the first one ever to reach that far: at P4.25b the scene program grew by 55 bytes,
REM cutscene_room.bin crossed 2,304 into a second granule, and ROOM.BIN landed on 18,19.
REM
REM ★ THE RAW WRITE THEN WON, SILENTLY. raw_tracks.py wrote prolog1.lz over track 9 and
REM reserved it; ROOM.BIN's directory entry still pointed there. `imgtool get ROOM.BIN`
REM returned 2,102 bytes of packed screen starting 78 00 13 48 -- not even a DECB header --
REM and nothing in the build said a word. The asset was fine; the FILE was destroyed.
REM
REM ★★ SO THE ORDER IS THE FIX, NOT A BIGGER DISK. Reserving first marks those granules
REM $C9 and DECB's allocator skips them, which is precisely what --reserve is for; it had
REM simply never been exercised at the boundary because no file had reached it. Putting
REM ROOM.BIN after the reservations lets it land in the first genuinely free span.
REM
REM ★★★ AND IT IS VERIFIED BY READ-BACK, NOT BY THE PUT'S EXIT CODE -- the exit code was 0
REM for the corrupt one. disk_file_readback_check.py compares every DECB file on the image
REM against the artefact it came from, and runs below.
REM
REM ★★★ AND MOVING THE PUT WAS NOT ENOUGH -- MEASURED, NOT ASSUMED. With ROOM.BIN put
REM AFTER every reservation, the read-back check still found it on granules 18,19: imgtool's
REM RS-DOS allocator does NOT skip $C9 entries. raw_tracks.py's header says reserving means
REM "DECB never allocates over them", and that had never been exercised at the boundary
REM because no file had ever reached it. It is a claim about DECB, not about imgtool.
REM
REM ★★ SO THE FILE SET IS THE PROBLEM, AND IT IS ARITHMETIC RATHER THAN ORDER:
REM     PROBE 1 + MODE 1 + ANIM 1 + INTRO 13 + INTROSEQ 2 = 18 granules = 0..17 = tracks 0..8
REM     the first raw asset track is 9, which IS granules 18,19
REM ROOM.BIN's two granules are the overflow, and WHICH file overflows is arbitrary -- the
REM SET needs 20 where 18 exist.
REM
REM ★ ROOM.BIN IS THE ONE TO DROP, AND JAY ALREADY RULED ON WHY. It boots the STANDALONE
REM room, whose suites were retired at P3.103 ("walk and room should be deprecated anyway.
REM they have been gated in the intro sequence"). integ_test.lua's own header records that
REM the integrated scene is reached by a `jsr` from the intro, NOT by LOADM"ROOM" -- so
REM nothing that still runs reads this file. P3.103's caution that removing a file "moves
REM the tracks" does not apply: it was the LAST put, so nothing follows it to move.
REM
REM build\cutscene_room.bin IS STILL BUILT and still map-checked; it is simply not placed on
REM this image. Anyone wanting the standalone room can put it on a scratch disk.
REM ======================================================================
REM "%IMGTOOL%" put coco_dmk_rsdos build\probe.dmk build\cutscene_room.bin ROOM.BIN --ftype=binary --ascii=binary

REM ======================================================================
REM THE STAGE-1 LOADER AND ITS "loading" SCREEN (P4.46)
REM
REM ★★★ IT RUNS HERE, AFTER THE BUNDLE, BECAUSE THE LETTERS COME OUT OF THE BUNDLE. The
REM word is set in the game's own byline face: gen_loading.py lifts the glyphs from the
REM byline caption in build/assets/intro_bundle.raw every build, so the artwork is the one
REM home for the letterforms and there is no second copy to drift (CLAUDE.md §2F). `l` and
REM `i` are the font's own `j` stem at ascender and x height -- dotless and without j's top
REM terminal, both on Jay's ruling after seeing them rendered.
REM
REM ★★ AND IT IS A SEPARATE BINARY BECAUSE THE SCREEN'S DATA MUST BE RESIDENT BEFORE THE
REM FIRST DISK READ -- that is what a loading screen is -- so it cannot come off a track
REM like the captions do. Measured: 263 B of patch plus a 16-byte palette plus the code is
REM ~486 B of prog, and link/pop_engine.link's ceiling note is explicit that the intro has
REM nowhere to put it ("prog ending $2487 boots; $2535 image corrupted... treat $2480 as the
REM practical limit"), with the intro's prog already ending $24FA.
REM ======================================================================
python harness/tools/gen_loading.py --bundle build/assets/intro_bundle.raw --out build/gen/loading_data.s
if errorlevel 1 goto :error

lwasm --obj -DOBJTARGET -DDR_VARBASE=%DR_VARBASE% -DINTRO_BASE=0x2000 -DINTRO_TRK=%INTRO_TRK% ^
      -DINTRO_SEC=18 -DINTRO_BOOT_OFF=%INTRO_BOOT_OFF% -I . -o build/obj/loader.o src/boot/loader.s
if errorlevel 1 goto :error

lwlink --decb --script=link/pop_boot.link --entry=boot_entry --map=build/obj/loader.map ^
       -o build/loader.bin build/obj/loader.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/loader.bin

REM ★ THE INTRO'S PROGRAM ONLY -- the kernel segment is dropped. The loader's own $7900 is
REM the same hal_build.o at the same address, so re-reading it would at best be wasted and
REM at worst overwrite the routine performing the read. link/pop_scene.link makes the same
REM cut for the same reason, and kernel_identical_check.py is what makes it a checked fact
REM rather than an assumption.
python harness/tools/decb_to_raw.py --bin build/intro_seq.bin --out build/assets/intro_prog.raw --base 0x2000 --span-end 0x7900
if errorlevel 1 goto :error
python harness/tools/raw_tracks.py --dsk build/probe.dmk --asset build/assets/intro_prog.raw --track %INTRO_TRK% --tracks 1 --reserve --imgtool "%IMGTOOL%"
if errorlevel 1 goto :error

echo --- P5.5: the tile page and the tile renderer ---
REM THE BAKE VERIFIES ITSELF BEFORE IT EMITS. bake_screen.py replays the page it is about
REM to write and compares it byte-for-byte against hgr_screen_convert's framebuffer for the
REM same screen; anything but EXACT is a non-zero exit, so a bake defect cannot reach the
REM disk. It also refuses a page over 8,192 B, which is the GIME block's real capacity at
REM $FFA6 -- see link/pop_tiles.link for why this one is 8,192 and the rotating page is 7,680.
if not exist build\gen mkdir build\gen
python harness/tools/bake_screen.py --level LEVEL0 --screen 1 --out build/gen/tile_screen1.s --out-ref build/assets/tile_screen1_ref.bin
if errorlevel 1 goto :error
lwasm --obj -DOBJTARGET -I . -o build/obj/tile_screen1.o build/gen/tile_screen1.s
if errorlevel 1 goto :error
lwlink --decb --script=link/pop_tiles.link --map=build/obj/tile_page.map -o build/tile_page.bin build/obj/tile_screen1.o
if errorlevel 1 goto :error
python harness/tools/decb_to_raw.py --bin build/tile_page.bin --out build/assets/tile_page.raw --base 0xc000
if errorlevel 1 goto :error
REM ★ THE PAGE IS 7,280 B AND A TRACK IS 4,608. The uncompressed page needs TWO tracks and
REM there is exactly ONE free track left on the image (34 -- see the map at the head of this
REM file), so the raw form cannot be delivered at all. lz_pack takes it to 1,390 B, which is
REM under a third of one track. This is the same route the intro screens and the cutscene
REM room already take; nothing about it is new except that here it is LOAD-BEARING rather
REM than a saving. The renderer stages the track in main RAM and expands into $C000, so the
REM in-place high-water argument in lz_pack.py's header does not apply to this blob -- source
REM and destination do not overlap.
python harness/tools/lz_pack.py build/assets/tile_page.raw --out-dir build/assets
if errorlevel 1 goto :error
python harness/tools/raw_tracks.py --dsk build/probe.dmk --asset build/assets/tile_page.lz --track %TILE_TRK% --tracks 1 --reserve --imgtool "%IMGTOOL%"
if errorlevel 1 goto :error
lwasm --obj -DOBJTARGET -DDR_VARBASE=%DR_VARBASE% -DTILE_TRK=%TILE_TRK% -I . -o build/obj/tile_probe.o src/engine/tile_probe.s
if errorlevel 1 goto :error
lwlink --decb --script=link/pop_tile.link --entry=tile_entry --map=build/obj/tile.map -o build/tile_probe.bin build/obj/tile_probe.o build/obj/lz_unpack.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/tile_probe.bin

"%IMGTOOL%" put coco_dmk_rsdos build\probe.dmk build\loader.bin LOADER.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_dmk_rsdos build\probe.dmk build\tile_probe.bin TILE.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error

echo --- The SPLIT cel image: pinned page + rotating pages (P3.78) ---
REM Two-pass, and driven from content/cutscene/chars/cel_pack.json rather than from a
REM page count written here. The count is what the packer is allowed to change when the
REM scene gains a beat, so hard-coding `for %%N in (0 1 2 3 4)` would put that fact in a
REM second place -- and the first symptom of the two disagreeing is a page that never got
REM linked, which reads as cels that are simply absent.
REM
REM Pass 1 links every rotating page at $E000 (link/pop_cels_pg.link). Pass 2 reads their
REM link MAPS and writes the walk table from the addresses the linker chose -- it cannot
REM be labels any more, because the table lives in the pinned unit and most of what it
REM points at does not. Pass 3 links the pinned page at $C000 with that table in it.
REM Pass 4 flattens each and places it on its own whole tracks.
REM
REM EVERY PAGE IS CHECKED AGAINST 7,680 B ON THE LINKED LENGTH, not on the packer's
REM estimate -- $E000..$FDFF is what the window reaches, and a page that overran would
REM write cel data at addresses the CPU answers from the constant page and the I/O
REM registers instead. That check lives in cel_table.py and it fails the build.
python harness/tools/cel_link.py --dsk build/probe.dmk --imgtool "%IMGTOOL%"
if errorlevel 1 goto :error

"%IMGTOOL%" dir coco_dmk_rsdos build\probe.dmk
if errorlevel 1 goto :error

REM ======================================================================
REM SECTION-OVERLAP AND LOADM-FLOOR GATE (P4.19)
REM
REM lwlink PLACES OVERLAPPING SECTIONS SILENTLY -- this file has said so since P3.2
REM ("did so three times"), and a check that asks a human to look is a check that
REM eventually is not run. At P4.19 the music player at $1000 ran to $2167, straight
REM through the engine's own load address, and the symptom was "the LOADM/EXEC did
REM not take" -- the signature of a DIFFERENT fault, one region away.
REM
REM It also asserts the LOADM FLOOR. DECB's file buffers reach above $0A00; bisection
REM found $0D00 loads and RUNS with silently damaged data, and $0E00 is clean.
REM ======================================================================
python harness\tools\map_overlap_check.py build/obj/introseq.map build/obj/interp.map build/obj/scene.map build/obj/room.map build/obj/song.map build/obj/tile.map
if errorlevel 1 (
    echo *** BUILD BLOCKED: linked sections collide or sit below the LOADM floor ***
    exit /b 1
)

REM ======================================================================
REM DISK FILE READ-BACK (P4.25b) -- the check the exit codes could not be
REM
REM map_overlap_check above asks whether the LINKED IMAGES collide in the CPU's address
REM space. This asks the same question one layer down, about the DISK: do the DECB files
REM and the raw asset tracks collide in GRANULES?
REM
REM They did, and nothing noticed. `imgtool put ROOM.BIN` returned 0, the directory listing
REM showed a plausible size, and raw_tracks.py had already overwritten the granules that
REM entry pointed at. The file on the shipped image was 2,102 bytes of packed prolog1.
REM
REM ★ SO THIS COMPARES BYTES, NOT EXIT CODES, and it runs on every build for the same
REM reason the HAL-sync check does: a check that has to be remembered enforces nothing.
REM ======================================================================
python harness\tools\disk_file_readback_check.py --dsk build/probe.dmk --imgtool "%IMGTOOL%" ^
    PROBE.BIN=build/loop_probe.bin MODE.BIN=build/mode_probe.bin ANIM.BIN=build/anim_probe.bin ^
    INTRO.BIN=build/intro_splash.bin LOADER.BIN=build/loader.bin TILE.BIN=build/tile_probe.bin
if errorlevel 1 (
    echo *** BUILD BLOCKED: a file on the disk image is not what the build produced ***
    exit /b 1
)

echo === BUILD COMPLETE ===
exit /b 0

:size
for %%I in ("%~1") do echo   %~1 (%%~zI bytes)
exit /b 0

:error
echo *** BUILD FAILED ***
exit /b 1
