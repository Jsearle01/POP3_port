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
REM   build/probe.dsk            RS-DOS disk  (PROBE.BIN)
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

echo --- Assemble: HAL kernel unit (object) ---
REM Every HAL module opens `section code` and exports its hal.inc entry points
REM under -DOBJTARGET. The six runtime-blit entry points stay DORMANT in POP
REM (PA.6 / P1.3) and are deliberately NOT exported: a POP call to one is now a
REM link error naming the symbol. Add -DPOP_HAL_RUNTIME_BLIT to enable them.
lwasm --obj -DOBJTARGET -DHAL_GFX_MODE_SERVICE -I . -o build/obj/hal_build.o src/harness/hal_build.s
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
lwasm --obj -DOBJTARGET -I . -o build/obj/intro_seq.o src/engine/intro_seq.s
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
lwlink --decb --script=link/pop.link --entry=intro_seq_entry --map=build/obj/introseq.map ^
       -o build/intro_seq.bin build/obj/intro_seq.o build/obj/hal_build.o
if errorlevel 1 goto :error
call :size build/intro_seq.bin

echo --- Bootable RS-DOS disk image ---
REM .dsk is always 18 sectors/track (idiom §3); default geometry is correct.
if exist build\probe.dsk del /q build\probe.dsk
"%IMGTOOL%" create coco_jvc_rsdos build\probe.dsk
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_jvc_rsdos build\probe.dsk build\loop_probe.bin PROBE.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
call :size build/probe.dsk
"%IMGTOOL%" put coco_jvc_rsdos build\probe.dsk build\mode_probe.bin MODE.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_jvc_rsdos build\probe.dsk build\anim_probe.bin ANIM.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_jvc_rsdos build\probe.dsk build\intro_splash.bin INTRO.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_jvc_rsdos build\probe.dsk build\intro_seq.bin INTROSEQ.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
"%IMGTOOL%" dir coco_jvc_rsdos build\probe.dsk
if errorlevel 1 goto :error

echo === BUILD COMPLETE ===
exit /b 0

:size
for %%I in ("%~1") do echo   %~1 (%%~zI bytes)
exit /b 0

:error
echo *** BUILD FAILED ***
exit /b 1
