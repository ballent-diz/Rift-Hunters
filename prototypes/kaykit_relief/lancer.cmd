@echo off
setlocal
set "GODOT=%USERPROFILE%\Downloads\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot 4.3 introuvable dans Downloads. Consultez README.md.
  pause
  exit /b 1
)
start "Rift Hunters - test relief" "%GODOT%" --path "%~dp0."
