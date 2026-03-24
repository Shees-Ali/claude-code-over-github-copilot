# PowerShell script to list GitHub Copilot models in copilot-config.yaml format
# Usage: .\list-copilot-models.ps1 [-EnabledOnly]

param(
    [switch]$EnabledOnly
)

$ErrorActionPreference = "Stop"

$GITHUB_TOKEN_FILE = "$env:USERPROFILE\.config\litellm\github_copilot\access-token"

# Check if GitHub token exists
if (-not (Test-Path $GITHUB_TOKEN_FILE)) {
    Write-Host "[ERROR] GitHub Copilot token not found at $GITHUB_TOKEN_FILE" -ForegroundColor Red
    Write-Host "   Run '.\setup.ps1 start' first to authenticate with GitHub"
    exit 1
}

# Read the token (strip any whitespace)
$GITHUB_TOKEN = (Get-Content $GITHUB_TOKEN_FILE -Raw).Trim()

Write-Host "# GitHub Copilot Models Available" -ForegroundColor Yellow
Write-Host "# Generated on $(Get-Date)"
Write-Host "# Usage: Copy the desired models to your copilot-config.yaml"
Write-Host ""

# Fetch models from GitHub Copilot API
$headers = @{
    "Authorization" = "Bearer $GITHUB_TOKEN"
}

try {
    $response = Invoke-RestMethod -Uri "https://api.githubcopilot.com/models" -Headers $headers
    
    # Filter chat models
    $chatModels = $response.data | Where-Object { $_.capabilities.type -eq "chat" }
    
    # Filter by enabled status if requested
    if ($EnabledOnly) {
        Write-Host "# Showing only enabled models" -ForegroundColor Cyan
        $chatModels = $chatModels | Where-Object { 
            $_.policy.state -eq "enabled" -or $null -eq $_.policy
        }
    } else {
        Write-Host "# Showing all models (enabled and unconfigured)" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "model_list:"
    
    foreach ($model in $chatModels) {
        $state = if ($model.policy.state) { $model.policy.state } else { "enabled" }
        $maxOutput = $model.capabilities.limits.max_output_tokens
        $maxContext = $model.capabilities.limits.max_context_window_tokens
        
        Write-Host "  - model_name: $($model.id)"
        Write-Host "    litellm_params:"
        Write-Host "      model: github_copilot/$($model.id)"
        Write-Host "      extra_headers: {`"Editor-Version`": `"vscode/1.85.1`", `"Copilot-Integration-Id`": `"vscode-chat`"}"
        Write-Host "    # $($model.name) ($($model.vendor)) - $state"
        Write-Host "    # Max tokens: $maxOutput, Context: $maxContext"
        Write-Host ""
    }
    
    Write-Host ""
    Write-Host "# To use these models:" -ForegroundColor Yellow
    Write-Host "# 1. Copy desired model entries to your copilot-config.yaml"
    Write-Host "# 2. Restart LiteLLM: .\setup.ps1 stop && .\setup.ps1 start"
    Write-Host "# 3. Test with: .\setup.ps1 test"
    
} catch {
    Write-Host "[ERROR] Failed to fetch models: $_" -ForegroundColor Red
    exit 1
}
