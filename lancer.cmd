@echo off
setlocal
set "GODOT=%USERPROFILE%\Downloads\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot 4.3 introuvable dans Downloads. Voir docs\PREMIER_JET_3D.md.
  pause
  exit /b 1
)
"%GODOT%" --headless --import --path "%~dp0."
start "Rift Hunters" "%GODOT%" --path "%~dp0."
