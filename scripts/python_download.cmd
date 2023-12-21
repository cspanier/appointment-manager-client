@echo off

REM If you don't know what this script is used for you probably don't need to run it.

cd %~dp0
REM Check version of Python available in PATH.
set PYTHON_MAJOR_VERSION=0
set PYTHON_MINOR_VERSION=0
for /F "delims=. tokens=1,2 usebackq" %%i in (`python -c "import sys; print(sys.version)"`) do (
  set PYTHON_MAJOR_VERSION=%%i
  set PYTHON_MINOR_VERSION=%%j
)
echo * Found Python version %PYTHON_MAJOR_VERSION%.%PYTHON_MINOR_VERSION%
if %PYTHON_MAJOR_VERSION% LSS 3 goto :old_python
if %PYTHON_MINOR_VERSION% LSS 11 goto :old_python

echo Enter virtual environment
set VENV_PATH=%~dp0.venv
echo VENV_PATH=%VENV_PATH%
if not exist %VENV_PATH% (
  python -m venv %VENV_PATH%
)
call %VENV_PATH%/Scripts/activate.bat

echo Downloading required Python modules

cd
if not exist python_prerequisites (
  mkdir python_prerequisites
)
cd python_prerequisites
python -m pip install --upgrade pip
python -m pip download -r ../python_requirements.txt
goto :end

:old_python
echo Error: Python ^>=3.11 either not intalled, or in PATH behind an older version.
set EXIT_CODE=10001
goto :end

:end
REM Only pause if this script was called directly from Windows Explorer,
REM in which case CMDCMDLINE is something like "cmd.exe /C ...".
REM No need to pause when this script was called from a console session.
for /F "tokens=2" %%i in ("%CMDCMDLINE%") do (
  if /I "%%i"=="/C" pause
)
REM The final exit.
exit /b %EXIT_CODE%
