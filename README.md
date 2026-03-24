# Claude Code over GitHub Copilot-model endpoints - Setup Instructions

## Overview

This project allows you to use Claude Code with GitHub Copilot instead of Anthropic's servers. 
We can't send company information to Anthropic, but we already have an agreement with GitHub Copilot for our 
VSCode and IDEA agents.

The architecture uses:
- **Translation Layer**: LiteLLM proxy to translate between Claude Code and GitHub Copilot APIs
- **Local Proxy**: LiteLLM running locally (no external traffic to third parties)
- **GitHub Integration**: Direct connection to GitHub Copilot models we're already authorized to use

**References:**
- [Claude Code LLM Gateway Documentation](https://docs.anthropic.com/en/docs/claude-code/llm-gateway)
- [LiteLLM Quick Start](https://docs.litellm.ai/#quick-start-proxy---cli)
- [LiteLLM GitHub Copilot Provider](https://docs.litellm.ai/docs/providers/github_copilot)

## Quick Start

### 1. Install Claude Code (if not already installed)
```bash
# Install Claude Code desktop application via npm
make install-claude
```

This command installs Claude Code globally using npm. Requires Node.js and npm to be installed.

### 2. Initial Setup
```bash
# Set up environment, dependencies, and generate API keys
make setup
```

This command:
- Creates a Python virtual environment
- Installs required dependencies
- Generates random UUID-based API keys in `.env` file (only if it doesn't exist)

### 3. Configure Claude Code
```bash
# Configure Claude Code to use the local proxy
make claude-enable
```

This command:
- Backs up your existing Claude Code settings
- Configures Claude Code to use `http://0.0.0.0:4444` as the API endpoint
- Sets up model mappings (claude-sonnet-4, claude-opus-4, gpt-4)

### 4. Start the Proxy Server
- **Important**: The first run will trigger GitHub device authentication - follow the prompts in the terminal
```bash
# Start LiteLLM proxy server
make start
```

This will:
- Activate the virtual environment
- Start LiteLLM with the `copilot-config.yaml` configuration

### 5. Test the Connection
```bash
# Test that everything is working
make test
```

### 6. In your project folder, start Claude Code

```bash
# Open Claude Code in your project folder
claude
```

## Model Configuration

The proxy exposes these models to Claude Code:

| Claude Code Model | Maps to GitHub Copilot           |
|-------------------|----------------------------------|
| `claude-sonnet-4` | `github_copilot/claude-sonnet-4` |
| `gpt-4`         | `github_copilot/gpt-4`         |

## Additional Commands

### Check Status
```bash
# View current Claude Code configuration and proxy status
make claude-status
```

### Restore Original Settings
```bash
# Restore Claude Code to default Anthropic servers
make claude-disable
```

### Stop the Proxy
```bash
# Stop the LiteLLM proxy server
make stop
```

## Troubleshooting

- **Authentication Issues**: The first `make start` will prompt for GitHub authentication
- **Connection Problems**: Use `make test` to verify the proxy is working
- **Configuration Issues**: Use `make claude-status` to check your settings
- **Reset Everything**: Use `make claude-disable` then `make claude-enable` to reconfigure
