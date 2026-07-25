@echo off
rem sprite-tool.bat — launch the hand-authoring sprite tool from the repo root.
rem   Double-click it, or run:  sprite-tool.bat  [category-block frame | placement_id]
rem   Defaults to player / climb_crawl f0. Needs Python + Tkinter + Pillow.
cd /d "%~dp0"
python harness\tools\sprite_tool\sprite_tool_app.py %*
if errorlevel 1 (
    echo.
    echo [sprite-tool exited with an error above]
    pause
)
