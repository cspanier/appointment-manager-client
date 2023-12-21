@echo off
setlocal EnableDelayedExpansion
REM Enable UTF-8 support in this terminal.
chcp 65001 >NUL

REM ############################################################################
REM Initial setup.
REM ############################################################################

cls
REM Change current working directory to the location of this script.
cd %~dp0../

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

if "%1"=="" (
  REM If this script was called without parameters use cmake_menu.py to select
  REM the list of config files to use.
  REM Due to limitations in Batch file language we need to use a temporary file
  REM to communicate results from the Python script.
  set TEMP_ARGUMENTS_FILE=%TEMP%\cmake_arguments.txt
  python scripts/cmake_menu.py "!TEMP_ARGUMENTS_FILE!" || exit /B 0
  set CONFIG_FILES=
  for /F "usebackq delims=" %%A in ("!TEMP_ARGUMENTS_FILE!") do (
    set CONFIG_FILES=!CONFIG_FILES! "%%A"
  )
  if EXIST "!TEMP_ARGUMENTS_FILE!" del "!TEMP_ARGUMENTS_FILE!"
) else (
  set CONFIG_FILES=%*
)

REM Read all config files and query several specific settings that are needed
REM early in this setup script.
for /F "delims=| tokens=1,2,3,4 usebackq" %%i in (`python scripts/query_config.py -q python-packages-path -q cpp-toolset -q cpp-toolset-version -q windows-sdk-version !CONFIG_FILES!`) do (
  set PYTHON_PACKAGES_PATH=%%i
  set CPP_TOOLSET=%%j
  set CPP_TOOLSET_VER=%%k
  set WinSDKVer=%%l
)
if "%CPP_TOOLSET%"=="msvc17" (
  set need_vsvars=0
  if "%VisualStudioVersion%"=="17.0" (
    echo [✓] $ENV{VisualStudioVersion}: "%VisualStudioVersion%"
  ) else (
    echo [✗] $ENV{VisualStudioVersion}: "%VisualStudioVersion%" ^^!= "17.0"
    set need_vsvars=1
  )

  call :starts_with "%VCToolsVersion%" "%CPP_TOOLSET_VER%"
  if ERRORLEVEL 1 (
    echo [✓] $ENV{VCToolsVersion}: "%VCToolsVersion%" starts with "%CPP_TOOLSET_VER%"
  ) else (
    echo [✗] $ENV{VCToolsVersion}: "%VCToolsVersion%" doesn't start with "%CPP_TOOLSET_VER%"
    set need_vsvars=1
  )

  if "%VSCMD_ARG_TGT_ARCH%"=="x64" (
    echo [✓] $ENV{VSCMD_ARG_TGT_ARCH}: "%VSCMD_ARG_TGT_ARCH%"
  ) else (
    echo [✗] $ENV{VSCMD_ARG_TGT_ARCH}: "%VSCMD_ARG_TGT_ARCH%" ^^!= "x64"
    set need_vsvars=1
  )

  if "%WindowsSDKVersion%"=="%WinSDKVer%\" (
    echo [✓] $ENV{WindowsSDKVersion}: "%WindowsSDKVersion%"
  ) else (
    echo [✗] $ENV{WindowsSDKVersion}: "%WindowsSDKVersion%" ^^!= "%WinSDKVer%"
    set need_vsvars=1
  )

  if "!need_vsvars!"=="1" (
    echo * Calling vsdevcmd.bat to fix environment...
    REM ToDo: This code might choose the wrong path if multiple versions/editions are installed in parallel
    REM (e.g. Community and Professional edition).
    REM ToDo: Finding vswhere.exe from a path containing spaces within the for statement seems to be broken somehow.
    copy "c:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" scripts\
    for /f "tokens=*" %%i in ('scripts\vswhere.exe -latest -version "[17.0,18.0)" -property installationPath') do (
      pushd !CD!
      if not exist "%%i\VC\Tools\MSVC\%CPP_TOOLSET_VER%" (
        echo Error: Missing Microsoft Visual C++ build tools version %CPP_TOOLSET_VER%.
        set EXIT_CODE=10002
        goto :end
      )
      call "%%i\Common7\Tools\vsdevcmd.bat" ^
        -arch=amd64 ^
        -host_arch=amd64 ^
        -vcvars_ver=%CPP_TOOLSET_VER% ^
        -winsdk=%WinSDKVer% ^
        -app_platform=Desktop
      popd
    )
  )
)

:setup_venv
if not exist "%PYTHON_PACKAGES_PATH%" (
  echo Error: Path to Python prerequisites does not exist "%PYTHON_PACKAGES_PATH%"
  set EXIT_CODE=10003
  goto :end
)
set VENV_PATH=%~dp0.venv
if not exist %VENV_PATH% (
  python -m venv %VENV_PATH%
)
echo * Entering Python virtual environment...
call %VENV_PATH%/Scripts/activate.bat
echo * Installing required Python modules...
python -m pip install --no-index --find-links %PYTHON_PACKAGES_PATH% -r scripts/python_requirements.txt

REM Call Python cmake script and propagate exit code.
python scripts/cmake.py !CONFIG_FILES!
set EXIT_CODE=%ERRORLEVEL%
goto :end

:starts_with
set "text=%~1"
set "substr=%~2"
if defined substr call set "s=%substr%%%text:*%substr%=%%"
if /i "%text%" NEQ "%s%" exit /B 0
exit /B 1

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
