@echo off
rem sprite-tool.bat - launch the hand-authoring sprite tool from the repo root.
rem   Double-click it, or run:  sprite-tool.bat  [block frame_index | placement_id]
rem
rem   With no argument it opens the first cel found under content\, starting in the
rem   'kid' category. POP has no placement table until its first scene is placed
rem   (CLAUDE.md 2F), so there are no animation blocks to default to yet.
rem   Karateka's copy defaulted to 'player / climb_crawl f0' - neither exists in POP,
rem   which is why P1.2 made the defaults resolve from what is actually on disk.
rem
rem   Needs Python + Tkinter + Pillow.
rem   Convert cels first if content\ is empty - see harness\tools\sprite_convert.py.
cd /d "%~dp0"
python harness\tools\sprite_tool\sprite_tool_app.py %*
if errorlevel 1 (
    echo.
    echo [sprite-tool exited with an error above]
    pause
)
