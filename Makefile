# Simplified Makefile for Claude Code over GitHub Copilot model endpoints

.PHONY: help setup install-claude start stop clean test verify claude-enable claude-disable claude-status list-models list-models-enabled

# Default target
help:
	@echo "Available targets:"
	@echo "  make install-claude - Install Claude Code desktop application"
	@echo "  make setup         - Set up virtual environment and dependencies"
	@echo "  make start         - Start LiteLLM proxy server"
	@echo "  make test          - Test the proxy connection"
	@echo "  make claude-enable - Configure Claude Code to use local proxy"
	@echo "  make claude-status - Show current Claude Code configuration"
	@echo "  make claude-disable - Restore Claude Code to default settings"
	@echo "  make stop          - Stop running processes"
	@echo "  make list-models        - List all GitHub Copilot models"
	@echo "  make list-models-enabled - List only enabled GitHub Copilot models"

# Set up environment
setup:
	@echo "Setting up environment..."
	@mkdir -p scripts
	@python3 -m venv venv
	@./venv/bin/pip install -r requirements.txt
	@if [ ! -f .env ]; then \
		echo "Generating .env file..."; \
		python3 generate_env.py; \
	else \
		echo "✓ .env file already exists, skipping generation"; \
	fi
	@echo "✓ Setup complete"

# Install Claude Code desktop application
install-claude:
	@echo "Installing Claude Code desktop application..."
	@if command -v npm >/dev/null 2>&1; then \
		echo "Installing Claude Code via npm..."; \
		npm install -g @anthropic-ai/claude-code && echo "✓ Claude Code installed successfully" && \
		echo "💡 You can now run 'make claude-enable' to configure it"; \
	else \
		echo "❌ npm not found. Please install Node.js and npm first:"; \
		echo "   https://nodejs.org/"; \
		echo "   Then run: npm install -g @anthropic-ai/claude-code"; \
	fi

# Start LiteLLM proxy
start:
	@echo "Starting LiteLLM proxy..."
	@source venv/bin/activate && litellm --config copilot-config.yaml --port 4444

# Stop running processes
stop:
	@echo "Stopping processes..."
	@pkill -f litellm 2>/dev/null || true
	@echo "✓ Processes stopped"

# Test proxy connection
test:
	@echo "Testing proxy connection..."
	@curl -X POST http://0.0.0.0:4444/chat/completions \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $$(grep LITELLM_MASTER_KEY .env | cut -d'=' -f2 | tr -d '\"')" \
		-d '{"model": "gpt-4", "messages": [{"role": "user", "content": "Hello"}]}'
	@echo ""
	@echo "✅ Test completed successfully!"

# Configure Claude Code to use local proxy
claude-enable:
	@echo "Configuring Claude Code to use local proxy..."
	@if [ ! -f .env ]; then echo "❌ .env file not found. Run 'make setup' first."; exit 1; fi
	@MASTER_KEY=$$(grep LITELLM_MASTER_KEY .env | cut -d'=' -f2 | tr -d '"'); \
	if [ -z "$$MASTER_KEY" ]; then echo "❌ LITELLM_MASTER_KEY not found in .env"; exit 1; fi; \
	if [ -f ~/.claude/settings.json ]; then \
		cp ~/.claude/settings.json ~/.claude/settings.json.backup.$$(date +%Y%m%d_%H%M%S); \
		echo "📁 Backed up existing settings to ~/.claude/settings.json.backup.$$(date +%Y%m%d_%H%M%S)"; \
	fi; \
	python3 scripts/claude_enable.py "$$MASTER_KEY"
	@echo "✅ Claude Code configured to use local proxy"
	@echo "💡 Make sure to run 'make start' to start the LiteLLM proxy server"

# Restore Claude Code to default settings
claude-disable:
	@echo "Restoring Claude Code to default settings..."
	@if [ -f ~/.claude/settings.json ]; then \
		cp ~/.claude/settings.json ~/.claude/settings.json.proxy_backup.$$(date +%Y%m%d_%H%M%S); \
		echo "📁 Backed up proxy settings to ~/.claude/settings.json.proxy_backup.$$(date +%Y%m%d_%H%M%S)"; \
	fi
	@if ls ~/.claude/settings.json.backup.* >/dev/null 2>&1; then \
		LATEST_BACKUP=$$(ls -t ~/.claude/settings.json.backup.* | head -1); \
		cp "$$LATEST_BACKUP" ~/.claude/settings.json; \
		echo "✅ Restored settings from $$LATEST_BACKUP"; \
	else \
		python3 scripts/claude_disable.py; \
	fi

# Show current Claude Code configuration
claude-status:
	@echo "Current Claude Code configuration:"
	@echo "=================================="
	@if [ -f ~/.claude/settings.json ]; then \
		echo "📄 Settings file: ~/.claude/settings.json"; \
		echo ""; \
		cat ~/.claude/settings.json | python3 -m json.tool 2>/dev/null || cat ~/.claude/settings.json; \
		echo ""; \
		if grep -q "http://0.0.0.0:4444" ~/.claude/settings.json 2>/dev/null; then \
			echo "🔗 Status: Using local proxy"; \
			if curl -s http://0.0.0.0:4444/health >/dev/null 2>&1; then \
				echo "✅ Proxy server: Running"; \
			else \
				echo "❌ Proxy server: Not running (run 'make start')"; \
			fi; \
		else \
			echo "🌐 Status: Using default Anthropic servers"; \
		fi; \
	else \
		echo "📄 No settings file found - using Claude Code defaults"; \
		echo "🌐 Status: Using default Anthropic servers"; \
	fi

# List available GitHub Copilot models
list-models:
	@echo "Listing available GitHub Copilot models..."
	@./list-copilot-models.sh

# List only enabled models
list-models-enabled:
	@echo "Listing enabled GitHub Copilot models..."
	@./list-copilot-models.sh --enabled-only
