# Codex CLI Auth Proxy for Droid & Other Tools

> **Reuse your Codex CLI authentication** to power Droid (Factory CLI) and any OpenAI-compatible application through a local proxy server.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()

**English** | [中文](README_zh-CN.md)

---

## Quick Start (TL;DR)

```bash
git clone https://github.com/tytsxai/cli-proxy-droid-integration.git
cd cli-proxy-droid-integration
cp CLIProxyAPI/config.yaml.example CLIProxyAPI/config.yaml
# Edit config.yaml with your API credentials
./setup.sh
droid  # Then type /model to select custom model
```

---

## Why This Project?

**The Problem:** You have a valid Codex CLI subscription/authentication, but you want to use it with other tools like Droid (Factory CLI), or build your own applications.

**The Solution:** This proxy server extracts your Codex CLI credentials and exposes them as a standard **OpenAI-compatible API** on `localhost:8317`.

### Architecture

```
┌─────────────────┐     ┌─────────────────────┐     ┌──────────────────┐
│  Droid / Apps   │────▶│  Local Proxy        │────▶│  AI Provider     │
│                 │     │  (localhost:8317)   │     │  (via Codex)     │
└─────────────────┘     └─────────────────────┘     └──────────────────┘
```

---

## Use Cases

### 1. Use Codex Auth with Droid (Primary)

If you have Codex CLI credentials and want to use them in Droid:

```
Codex CLI Auth  →  This Proxy  →  Droid (Factory CLI)
```

### 2. Build Your Own Applications (Advanced)

The proxy exposes a standard OpenAI-compatible API. You can use it with:

- **Python applications** using `openai` library
- **Node.js applications** using OpenAI SDK
- **Any tool** that supports custom OpenAI endpoints
- **curl** for direct API calls

```bash
# Example: Use with any OpenAI-compatible client
export OPENAI_API_BASE=http://localhost:8317/v1
export OPENAI_API_KEY=dummy

# Now any OpenAI client will use your Codex credentials
python your_app.py
```

### 3. API Gateway for Multiple Tools

Run the proxy once, use it everywhere:

```
                    ┌─── Droid
                    │
localhost:8317 ─────┼─── Your Python Script
                    │
                    ├─── VS Code Extension
                    │
                    └─── Any OpenAI Client
```

---

## Prerequisites

Before you begin, ensure you have:

- [ ] **Factory CLI (Droid)** installed on your system
- [ ] **API credentials** from your third-party provider
- [ ] **macOS or Linux** operating system
- [ ] **Basic terminal knowledge**

### Where Are My Credentials?

The proxy auto-detects credentials from these locations (in order):

| Priority | Location | Key |
|----------|----------|-----|
| 1 | Environment | `CODEX_API_KEY` or `OPENAI_API_KEY` |
| 2 | `~/.codex/config.toml` | `experimental_bearer_token` |
| 3 | `~/.codex/auth.json` | `OPENAI_API_KEY` |

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

### Use as OpenAI-Compatible API

```bash
# Test the API
curl http://localhost:8317/v1/models

# Chat completion
curl http://localhost:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-5.2", "messages": [{"role": "user", "content": "Hello"}]}'
```

### Python Example

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8317/v1",
    api_key="dummy"
)

response = client.chat.completions.create(
    model="gpt-5.2",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
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

## FAQ

**Q: Do I need to keep the proxy running?**
A: Yes. The proxy must be running for Droid or other apps to connect. Run `./setup.sh` to start it.

**Q: Can I change the port?**
A: Yes. Edit `CLIProxyAPI/config.yaml` and change `port: 8317` to your preferred port.

**Q: Is my API key secure?**
A: Yes. The key is stored locally in `~/.cli-proxy-api/` with restricted permissions (600). It never leaves your machine.

**Q: Can I use this with Claude/Anthropic API?**
A: This proxy is designed for OpenAI-compatible APIs. For Anthropic, you'd need a different setup.

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
├── CONTRIBUTING.md               # Contribution guidelines
└── LICENSE                       # MIT License
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
