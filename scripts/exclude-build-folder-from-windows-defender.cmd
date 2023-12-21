@echo off
setlocal EnableDelayedExpansion

REM Administrative permissions required. Detecting permissions...
net session >nul 2>&1
if NOT %errorLevel% == 0 (
  echo Error: You must run this script with administrative permissions.
  pause
  goto :EOF
)

for /D %%d in ("%~dp0..\evolution\Bin*" "%~dp0..\build-*") do (
  call :normalize_path "%%d"
  powershell -inputformat none -outputformat none -NonInteractive -Command "Add-MpPreference -ExclusionPath '!ABSOLUTE_PATH!'"
)
goto :EOF

:normalize_path
  set ABSOLUTE_PATH=%~f1
  exit /B
