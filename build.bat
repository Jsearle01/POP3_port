@echo off
REM build.bat — POP CoCo3 port build (native Windows; no WSL, no make).
REM
REM This is the BUILD half of the CLAUDE.md §1 test contract
REM   (25.1 fresh tool output = build.bat + run_*_test).
REM
REM Requires:
REM   lwasm    (LWTOOLS) on PATH
REM   imgtool  (MAME)    on PATH, or set IMGTOOL, or at C:\mame\imgtool.exe
REM
REM NOTE (carried from karateka build.bat, CLAUDE.md §2G): lwasm derives the
REM `include` base dir by splitting the source path on '/', so source args MUST
REM use forward slashes — backslashes make relative includes resolve against
REM the CWD and fail.
REM
REM Outputs (all under build/, which is gitignored — .dsk fixtures are
REM throwaway and generated per-task, never shared; idiom §3):
REM   build/loop_probe.bin   DECB binary  (LOADM-able)
REM   build/probe.dsk        RS-DOS disk  (PROBE.BIN)
setlocal

for %%I in ("%~dp0.") do set "REPO_ROOT=%%~fI"
cd /d "%REPO_ROOT%"

REM --- locate lwasm ------------------------------------------------------
where lwasm >nul 2>&1
if errorlevel 1 (
    echo ERROR: lwasm not found on PATH.
    echo Install LWTOOLS ^(lwasm/lwlink^) and add it to PATH, then re-run.
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

echo --- Harness-proof target (P1.1 loop probe) ---
lwasm --decb -o build/loop_probe.bin src/harness/loop_probe.s
if errorlevel 1 goto :error
call :size build/loop_probe.bin

echo --- Bootable RS-DOS disk image ---
REM .dsk is always 18 sectors/track (idiom §3); default geometry is correct.
if exist build\probe.dsk del /q build\probe.dsk
"%IMGTOOL%" create coco_jvc_rsdos build\probe.dsk
if errorlevel 1 goto :error
"%IMGTOOL%" put coco_jvc_rsdos build\probe.dsk build\loop_probe.bin PROBE.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :error
call :size build/probe.dsk
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
