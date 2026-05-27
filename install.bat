@echo off
:: Arignan one-click installer for Windows.
:: Usage: Double-click install.bat (no admin required)

setlocal enabledelayedexpansion

set "ARIGNAN_HOME=%USERPROFILE%\.arignan"
set "VENV_DIR=%ARIGNAN_HOME%\venv"
set "WHEEL_URL=https://github.com/rogue-infinity/Open-Arignan/releases/latest/download/open_arignan-latest-py3-none-any.whl"
set "SCRIPT_DIR=%~dp0"

echo === Arignan Installer ===
echo.

:: --- Python check ---
echo [1/5] Checking for Python 3.10+...

python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Python not found. Attempting to install via winget...
    winget --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo.
        echo [error] Python 3.10+ and winget are both unavailable.
        echo Please install Python manually from: https://www.python.org/downloads/
        echo Make sure to check "Add Python to PATH" during installation.
        pause
        exit /b 1
    )
    echo Installing Python 3.12 via winget...
    winget install Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% neq 0 (
        echo.
        echo [error] winget install failed. Please install Python manually:
        echo   https://www.python.org/downloads/
        pause
        exit /b 1
    )
    :: Refresh PATH so newly installed python is available
    call refreshenv >nul 2>&1
    python --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo.
        echo [error] Python was installed but is not yet on PATH.
        echo Please close this window, reopen a new terminal, and run install.bat again.
        pause
        exit /b 1
    )
)

for /f "tokens=*" %%v in ('python --version 2^>^&1') do set "PY_VER=%%v"
echo   Found: %PY_VER%

:: --- Create venv ---
echo [2/5] Creating virtual environment at %VENV_DIR% ...
if not exist "%ARIGNAN_HOME%" mkdir "%ARIGNAN_HOME%"
python -m venv "%VENV_DIR%"
if %errorlevel% neq 0 (
    echo [error] Failed to create virtual environment.
    pause
    exit /b 1
)

set "VENV_PYTHON=%VENV_DIR%\Scripts\python.exe"
set "VENV_PIP=%VENV_DIR%\Scripts\pip.exe"

:: --- Download and install wheel ---
echo [3/5] Downloading and installing Arignan...
call "%VENV_PIP%" install --upgrade pip --quiet

:: Try downloading the wheel, fall back to local source
curl --fail --silent --location --output "%TEMP%\open_arignan.whl" "%WHEEL_URL%" 2>nul
if %errorlevel% equ 0 (
    call "%VENV_PIP%" install "%TEMP%\open_arignan.whl" --quiet
    del /f /q "%TEMP%\open_arignan.whl" 2>nul
) else (
    echo   Pre-built wheel not found, installing from source...
    call "%VENV_PIP%" install "%SCRIPT_DIR%" --quiet
)
if %errorlevel% neq 0 (
    echo [error] Package installation failed.
    pause
    exit /b 1
)

:: --- Run setup_flow ---
echo [4/5] Running Arignan setup (downloading models -- may take a while)...
call "%VENV_PYTHON%" "%SCRIPT_DIR%setup.py" --app-home "%ARIGNAN_HOME%"
if %errorlevel% neq 0 (
    echo [error] Arignan setup failed. Check the output above.
    pause
    exit /b 1
)

:: --- Create launcher shortcuts ---
echo [5/5] Creating launch shortcuts...

:: Desktop launcher
set "DESKTOP_LAUNCHER=%USERPROFILE%\Desktop\Arignan.bat"
(
    echo @echo off
    echo set TOKENIZERS_PARALLELISM=false
    echo start "" "%VENV_PYTHON%" -m arignan.cli gui --app-home "%ARIGNAN_HOME%"
    echo timeout /t 2 /nobreak ^>nul
    echo start "" http://127.0.0.1:7860
) > "%DESKTOP_LAUNCHER%"
echo   Created desktop shortcut: %DESKTOP_LAUNCHER%

:: Start Menu launcher
set "START_MENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
if not exist "%START_MENU%" mkdir "%START_MENU%"
set "STARTMENU_LAUNCHER=%START_MENU%\Arignan.bat"
(
    echo @echo off
    echo set TOKENIZERS_PARALLELISM=false
    echo start "" "%VENV_PYTHON%" -m arignan.cli gui --app-home "%ARIGNAN_HOME%"
    echo timeout /t 2 /nobreak ^>nul
    echo start "" http://127.0.0.1:7860
) > "%STARTMENU_LAUNCHER%"
echo   Created Start Menu shortcut: %STARTMENU_LAUNCHER%

echo.
echo === Setup complete! ===
echo.
echo To launch Arignan:
echo   - Double-click "Arignan.bat" on your Desktop
echo   - Or find it in the Start Menu
echo.
echo You can also run from the command line:
echo   "%VENV_PYTHON%" -m arignan.cli gui --app-home "%ARIGNAN_HOME%"
echo.
pause
