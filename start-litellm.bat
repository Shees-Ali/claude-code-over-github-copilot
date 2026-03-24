@echo off
REM Batch file to start LiteLLM proxy server for Claude Code
REM Can be added to Windows Startup folder or Task Scheduler

REM Change to the script's directory
cd /d "%~dp0"

echo ==========================================
echo  Claude Code LiteLLM Proxy Server
echo ==========================================
echo.

REM Check if virtual environment exists
if not exist "venv\Scripts\litellm.exe" (
    echo ERROR: Virtual environment not found or litellm not installed.
    echo Please run: .\setup.ps1 setup
    echo.
    pause
    exit /b 1
)

REM Check if config file exists
if not exist "copilot-config.yaml" (
    echo ERROR: copilot-config.yaml not found.
    echo.
    pause
    exit /b 1
)

REM Check if .env file exists
if not exist ".env" (
    echo ERROR: .env file not found.
    echo Please run: .\setup.ps1 setup
    echo.
    pause
    exit /b 1
)

echo Starting LiteLLM proxy on port 4444...
echo Endpoint: http://0.0.0.0:4444
echo.
echo Press Ctrl+C to stop the server
echo.

REM Start LiteLLM proxy
"%~dp0venv\Scripts\litellm.exe" --config "%~dp0copilot-config.yaml" --port 4444

REM If the server exits, pause to show any error messages
if errorlevel 1 (
    echo.
    echo Server stopped with error code: %errorlevel%
    pause
)
