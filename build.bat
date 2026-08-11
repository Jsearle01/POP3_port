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
REM CEL_BASE is the third address of this kind (P3.71): where the cel image is linked,
REM where cutscene_room.s maps the bank, and what char_draw.s's CEL_BASE equ names. Same
REM 0x-not-$ rule as the two above -- and link/pop_cels.link needs it a THIRD way, as
REM bare `C000`, because lwlink's script parser takes neither prefix.
set CEL_BASE=0xC000
REM Whole tracks, on the free span packing opened up (tracks 11-15 and 20-24 are unused).
set CEL_TRACK=11
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
lwasm --obj -DOBJTARGET -DDR_VARBASE=%DR_VARBASE% -I . -o build/obj/intro_seq.o src/engine/intro_seq.s

if errorlevel 1 goto :error

lwasm --obj -DOBJTARGET -I . -o build/obj/lz_unpack.o src/engine/lz_unpack.s

if errorlevel 1 goto :error

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
lwasm --obj -DOBJTARGET %SEEDFLAG% -I . -o build/obj/char_draw.o src/engine/char_draw.s
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

echo --- Assemble: the CEL IMAGE, its own unit at $C000 (P3.71) ---
REM The scene's cel pixels and their [cel][facing][phase] table, linked SEPARATELY from
REM the bundle and read off disk into a GIME bank mapped at CPU $C000. See
REM link/pop_cels.link for why $C000, and why the load address is bare hex there.
REM
REM UNPACKED, DELIBERATELY, unlike the flame bundle one step above. The bundle is packed
REM because it must land in the 14,848 B between FLAME_BASE and the disk parameter block
REM and no whole-track count fits it. This has no such neighbour: it is read straight
REM into a bank whose 16,384 B belong to nothing else, so whole tracks are free and an
REM expand step would only add a copy and a second failure mode.
lwasm --obj -DOBJTARGET -I . -o build/obj/cel_image.o content/cutscene/chars/cel_image.s
if errorlevel 1 goto :error
lwlink --decb --script=link/pop_cels.link --map=build/obj/cels.map -o build/cel_image.bin build/obj/cel_image.o
if errorlevel 1 goto :error
python harness/tools/decb_to_raw.py --bin build/cel_image.bin --out build/assets/cel_image.raw --base %CEL_BASE%
if errorlevel 1 goto :error
call :size build/assets/cel_image.raw

echo --- Assemble: P3.17 princess room (4-colour, static) ---

lwasm --obj -DOBJTARGET -DDR_VARBASE=%DR_VARBASE% -DFLAME_BASE=%FLAME_BASE% -I . -o build/obj/cutscene_room.o src/engine/cutscene_room.s
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
lwlink --decb --script=link/pop_engine.link --entry=intro_seq_entry --map=build/obj/introseq.map ^
       -o build/intro_seq.bin build/obj/intro_seq.o build/obj/lz_unpack.o build/obj/hal_build.o

if errorlevel 1 goto :error

call :size build/intro_seq.bin



echo --- Link: princess room + HAL kernel ---

lwlink --decb --script=link/pop_engine.link --entry=room_entry --map=build/obj/room.map -o build/cutscene_room.bin build/obj/cutscene_room.o build/obj/lz_unpack.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/intro_seq.bin

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
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_dmk_rsdos build\probe.dmk build\intro_splash.bin INTRO.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_dmk_rsdos build\probe.dmk build\intro_seq.bin INTROSEQ.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_dmk_rsdos build\probe.dmk build\cutscene_room.bin ROOM.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
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
if errorlevel 1 goto :error
REM The cel image, onto the span packing opened up (tracks 11-15 and 20-24 were free).
REM THREE whole tracks = 13,824 B, against an image of 13,049 B with Palert in the scene.
REM Two tracks held the pre-Palert 7,633 B and would silently truncate this one, so the
REM count is a real constraint and not a round number: it must be >= the image and the
REM room's CEL_TRACKS must match, or load_tracks reads the wrong number of sectors.
python harness/tools/raw_tracks.py --dsk build/probe.dmk --asset build/assets/cel_image.raw --track %CEL_TRACK% --tracks 3 --reserve --imgtool "%IMGTOOL%"
if errorlevel 1 goto :error

"%IMGTOOL%" dir coco_dmk_rsdos build\probe.dmk
if errorlevel 1 goto :error

echo === BUILD COMPLETE ===
exit /b 0

:size
for %%I in ("%~1") do echo   %~1 (%%~zI bytes)
exit /b 0

:error
echo *** BUILD FAILED ***
exit /b 1
