# PowerShell script for Claude Code over GitHub Copilot model endpoints
# Windows-compatible version of the Makefile

param(
    [Parameter(Position=0)]
    [string]$Command = "help"
)

# Color output functions
function Write-Success { 
    param($Message) 
    Write-Host "[OK] $Message" -ForegroundColor Green 
}

function Write-Error { 
    param($Message) 
    Write-Host "[ERROR] $Message" -ForegroundColor Red 
}

function Write-Info { 
    param($Message) 
    Write-Host "[INFO] $Message" -ForegroundColor Cyan 
}

function Write-File { 
    param($Message) 
    Write-Host "[FILE] $Message" -ForegroundColor Yellow 
}

function Write-Status { 
    param($Message) 
    Write-Host "[STATUS] $Message" -ForegroundColor Magenta 
}

# Helper function to get master key from .env
function Get-MasterKey {
    if (-not (Test-Path ".env")) {
        Write-Error ".env file not found. Run '.\setup.ps1 setup' first."
        exit 1
    }
    $envContent = Get-Content ".env" -Raw
    if ($envContent -match 'LITELLM_MASTER_KEY\s*=\s*"?([^"\r\n]+)"?') {
        $key = $matches[1].Trim('"')
        return $key
    }
    Write-Error "LITELLM_MASTER_KEY not found in .env"
    exit 1
}

# Help command
function Show-Help {
    Write-Host "Available commands:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  .\setup.ps1 install-claude      - Install Claude Code desktop application"
    Write-Host "  .\setup.ps1 setup              - Set up virtual environment and dependencies"
    Write-Host "  .\setup.ps1 start              - Start LiteLLM proxy server"
    Write-Host "  .\setup.ps1 test               - Test the proxy connection"
    Write-Host "  .\setup.ps1 claude-enable      - Configure Claude Code to use local proxy"
    Write-Host "  .\setup.ps1 claude-status      - Show current Claude Code configuration"
    Write-Host "  .\setup.ps1 claude-disable     - Restore Claude Code to default settings"
    Write-Host "  .\setup.ps1 stop               - Stop running processes"
    Write-Host "  .\setup.ps1 list-models        - List all GitHub Copilot models"
    Write-Host "  .\setup.ps1 list-models-enabled - List only enabled GitHub Copilot models"
    Write-Host ""
}

# Setup environment
function Setup-Environment {
    Write-Host "Setting up environment..."
    
    # Create scripts directory if it does not exist
    if (-not (Test-Path "scripts")) {
        New-Item -ItemType Directory -Path "scripts" | Out-Null
    }
    
    # Create virtual environment
    Write-Host "Creating virtual environment..."
    python -m venv venv
    
    # Install dependencies
    Write-Host "Installing dependencies..."
    & ".\venv\Scripts\pip.exe" install -r requirements.txt
    
    # Generate .env file if it doesn't exist
    if (-not (Test-Path ".env")) {
        Write-Host "Generating .env file..."
        python generate_env.py
    } else {
        Write-Success ".env file already exists, skipping generation"
    }
    
    Write-Success "Setup complete"
}

# Install Claude Code
function Install-Claude {
    Write-Host "Installing Claude Code desktop application..."
    
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "Installing Claude Code via npm..."
        npm install -g @anthropic-ai/claude-code
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Claude Code installed successfully"
            Write-Info "You can now run '.\setup.ps1 claude-enable' to configure it"
        }
    } else {
        Write-Error "npm not found. Please install Node.js and npm first:"
        Write-Host "   https://nodejs.org/"
        Write-Host "   Then run: npm install -g @anthropic-ai/claude-code"
    }
}

# Start LiteLLM proxy
function Start-Proxy {
    Write-Host "Starting LiteLLM proxy..."
    
    # Activate virtual environment and start litellm
    & ".\venv\Scripts\Activate.ps1"
    & ".\venv\Scripts\litellm.exe" --config copilot-config.yaml --port 4444
}

# Stop running processes
function Stop-Processes {
    Write-Host "Stopping processes..."
    
    $processes = Get-Process | Where-Object { $_.ProcessName -like "*litellm*" -or $_.CommandLine -like "*litellm*" }
    if ($processes) {
        $processes | Stop-Process -Force
        Write-Success "Processes stopped"
    } else {
        Write-Host "No litellm processes found"
    }
}

# Test proxy connection
function Test-Proxy {
    Write-Host "Testing proxy connection..."
    
    $masterKey = Get-MasterKey
    
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $masterKey"
    }
    
    $body = @{
        model = "gpt-4"
        messages = @(
            @{
                role = "user"
                content = "Hello"
            }
        )
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:4444/chat/completions" -Method Post -Headers $headers -Body $body
        Write-Host ($response | ConvertTo-Json -Depth 10)
        Write-Host ""
        Write-Success "Test completed successfully!"
    } catch {
        Write-Error "Test failed: $_"
    }
}

# Configure Claude Code to use local proxy
function Enable-ClaudeProxy {
    Write-Host "Configuring Claude Code to use local proxy..."
    
    $masterKey = Get-MasterKey
    $claudeDir = "$env:USERPROFILE\.claude"
    $settingsFile = "$claudeDir\settings.json"
    
    # Create backup if settings exist
    if (Test-Path $settingsFile) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = "$settingsFile.backup.$timestamp"
        Copy-Item $settingsFile $backupFile
        Write-File "Backed up existing settings to $backupFile"
    }
    
    # Run Python script to enable proxy
    python scripts\claude_enable.py $masterKey
    
    Write-Success "Claude Code configured to use local proxy"
    Write-Info "Make sure to run '.\setup.ps1 start' to start the LiteLLM proxy server"
}

# Restore Claude Code to default settings
function Disable-ClaudeProxy {
    Write-Host "Restoring Claude Code to default settings..."
    
    $claudeDir = "$env:USERPROFILE\.claude"
    $settingsFile = "$claudeDir\settings.json"
    
    # Create backup of proxy settings
    if (Test-Path $settingsFile) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $proxyBackup = "$settingsFile.proxy_backup.$timestamp"
        Copy-Item $settingsFile $proxyBackup
        Write-File "Backed up proxy settings to $proxyBackup"
    }
    
    # Try to restore from latest backup
    $backups = Get-ChildItem -Path "$settingsFile.backup.*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($backups) {
        $latestBackup = $backups[0].FullName
        Copy-Item $latestBackup $settingsFile
        Write-Success "Restored settings from $latestBackup"
    } else {
        python scripts\claude_disable.py
    }
}

# Show Claude Code configuration status
function Show-ClaudeStatus {
    Write-Host "Current Claude Code configuration:" -ForegroundColor Yellow
    Write-Host "=================================="
    
    $claudeDir = "$env:USERPROFILE\.claude"
    $settingsFile = "$claudeDir\settings.json"
    
    if (Test-Path $settingsFile) {
        Write-Host "[FILE] Settings file: $settingsFile"
        Write-Host ""
        
        $settings = Get-Content $settingsFile -Raw
        try {
            $json = $settings | ConvertFrom-Json | ConvertTo-Json -Depth 10
            Write-Host $json
        } catch {
            Write-Host $settings
        }
        
        Write-Host ""
        
        if ($settings -match "localhost:4444" -or $settings -match "0\.0\.0\.0:4444") {
            Write-Status "Status: Using local proxy"
            
            try {
                # Try to connect to the server (even 401 means server is running)
                $null = Invoke-WebRequest -Uri "http://localhost:4444/health" -TimeoutSec 2 -ErrorAction Stop
                Write-Success "Proxy server: Running"
            } catch {
                if ($_.Exception.Response.StatusCode.value__ -eq 401) {
                    Write-Success "Proxy server: Running"
                } else {
                    Write-Error "Proxy server: Not running (run '.\setup.ps1 start')"
                }
            }
        } else {
            Write-Host "[INFO] Status: Using default Anthropic servers"
        }
    } else {
        Write-Host "[FILE] No settings file found - using Claude Code defaults"
        Write-Host "[INFO] Status: Using default Anthropic servers"
    }
}

# List GitHub Copilot models
function List-Models {
    param([switch]$EnabledOnly)
    
    if ($EnabledOnly) {
        Write-Host "Listing enabled GitHub Copilot models..."
        & ".\list-copilot-models.ps1" -EnabledOnly
    } else {
        Write-Host "Listing available GitHub Copilot models..."
        & ".\list-copilot-models.ps1"
    }
}

# Clean up
function Clean {
    Write-Host "Cleaning up..."
    
    if (Test-Path "venv") {
        Remove-Item -Recurse -Force "venv"
        Write-Success "Removed virtual environment"
    }
    
    if (Test-Path "__pycache__") {
        Remove-Item -Recurse -Force "__pycache__"
        Write-Success "Removed Python cache"
    }
}

# Main command dispatcher
switch ($Command.ToLower()) {
    "help" { Show-Help }
    "setup" { Setup-Environment }
    "install-claude" { Install-Claude }
    "start" { Start-Proxy }
    "stop" { Stop-Processes }
    "test" { Test-Proxy }
    "claude-enable" { Enable-ClaudeProxy }
    "claude-disable" { Disable-ClaudeProxy }
    "claude-status" { Show-ClaudeStatus }
    "list-models" { List-Models }
    "list-models-enabled" { List-Models -EnabledOnly }
    "clean" { Clean }
    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host ""
        Show-Help
        exit 1
    }
}
