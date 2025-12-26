# CLI Proxy API Integration for Factory CLI (Droid)

> Use third-party AI models with Factory CLI (Droid) through a local OpenAI-compatible proxy server.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()

**English** | [中文](README_zh-CN.md) | [한국어](README_ko.md)

---

## What is This?

This toolkit helps you connect **Factory CLI (Droid)** to third-party AI model providers. If you have API credentials from a third-party provider, this tool:

1. **Auto-detects your credentials** from multiple sources
2. **Configures custom models** in Factory CLI
3. **Runs a local proxy** that provides OpenAI-compatible API endpoints

### Architecture

```
┌─────────────────┐     ┌─────────────────────┐     ┌──────────────────┐
│  Factory CLI    │────▶│  Local Proxy        │────▶│  Third-party     │
│  (Droid)        │     │  (localhost:8317)   │     │  AI Provider     │
└─────────────────┘     └─────────────────────┘     └──────────────────┘
```

---

## Prerequisites

Before you begin, ensure you have:

- [ ] **Factory CLI (Droid)** installed on your system
- [ ] **API credentials** from your third-party provider
- [ ] **macOS or Linux** operating system
- [ ] **Basic terminal knowledge**

---

## Installation (Step by Step)

### Step 1: Clone the Repository

```bash
cd ~/Desktop
git clone https://github.com/tytsxai/cli-proxy-droid-integration.git
cd cli-proxy-droid-integration
```

### Step 2: Create Your Configuration File

```bash
cp CLIProxyAPI/config.yaml.example CLIProxyAPI/config.yaml
```

### Step 3: Edit Configuration with Your API Credentials

Open `CLIProxyAPI/config.yaml` in your editor:

```bash
nano CLIProxyAPI/config.yaml
# Or use: vim, code, or any text editor
```

Find the `codex-api-key` section and update it:

```yaml
codex-api-key:
  - api-key: "YOUR_ACTUAL_API_KEY"
    prefix: "provider"
    base-url: "https://your-provider-api-endpoint.com/api"
```

### Step 4: Run the Setup Script

```bash
chmod +x setup.sh
./setup.sh
```

This script will:
- Sync your credentials
- Configure Factory CLI custom models
- Start the local proxy server on port 8317

### Step 5: Verify Installation

```bash
./verify-integration.sh
```

You should see all checks passing with green checkmarks.

---

## Usage

### Start Using Droid with Custom Models

```bash
droid
```

Once inside Droid:
1. Type `/model` to see available models
2. Select your custom model (e.g., `gpt-5.2`)
3. Start chatting!

### Daily Commands

```bash
# Start the proxy (if not running)
./setup.sh

# Check status
./verify-integration.sh

# View proxy logs
tail -f CLIProxyAPI/proxy.log

# Stop the proxy
pkill -f cli-proxy-api
```

---

## Troubleshooting

### Problem: "Token not found"

**Cause:** The script cannot find your API credentials.

**Solution:**
```bash
# Check if credentials exist
ls -la ~/.codex/
cat ~/.codex/config.toml
```

### Problem: Port 8317 already in use

**Cause:** Another process is using the port.

**Solution:**
```bash
# Find what's using the port
lsof -i :8317

# Kill the process
kill <PID>

# Restart
./setup.sh
```

### Problem: Custom models not showing in Droid

**Cause:** Factory CLI configuration may be incorrect.

**Solution:**
```bash
# Check configuration
cat ~/.factory/config.json

# Re-run setup
./setup.sh
```

### Problem: API request errors

**Cause:** Network issues or incorrect API endpoint.

**Solution:**
```bash
# Check proxy logs
tail -50 CLIProxyAPI/proxy.log

# Test API endpoint
curl http://localhost:8317/v1/models
```

### Need More Help? Ask AI!

If you encounter issues not covered above, you can ask any AI assistant for help:

1. Copy this entire README file
2. Paste it to ChatGPT, Claude, or any AI assistant
3. Describe your problem

The AI will understand the project structure and help you troubleshoot.

---

## Project Structure

```
.
├── setup.sh                      # One-click setup script
├── sync-credentials.sh           # Credential synchronization
├── verify-integration.sh         # Configuration verification
├── CLIProxyAPI/
│   ├── cli-proxy-api             # Proxy server binary
│   └── config.yaml.example       # Configuration template
├── README.md                     # English documentation
├── README_zh-CN.md               # Chinese documentation
└── README_ko.md                  # Korean documentation
```

### Key Configuration Files

| File | Purpose |
|------|---------|
| `~/.factory/config.json` | Droid custom model settings |
| `~/.cli-proxy-api/codex-yunyi.json` | Proxy authentication token |
| `CLIProxyAPI/config.yaml` | Proxy server configuration |

---

## Acknowledgments

This project uses the following open-source tools:

- **[CLIProxyAPI](https://github.com/anthropics/cli-proxy-api)** - The core proxy server component
- **[Factory CLI (Droid)](https://github.com/openai/codex)** - The CLI tool this integrates with

Special thanks to all contributors and the open-source community.

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
