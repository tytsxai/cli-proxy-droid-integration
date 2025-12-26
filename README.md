# CLI Proxy API Integration for Factory CLI (Droid)

> Use third-party AI models (like GPT-5.2) with Factory CLI (Droid) through a local proxy server.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()

**English** | [中文](README_zh-CN.md) | [日本語](README_ja.md)

## Overview

This toolkit enables Factory CLI (Droid) to connect to third-party AI model providers through a local proxy. If you have API credentials from a third-party provider, this tool helps you:

1. **Auto-detect credentials** from multiple sources
2. **Configure custom models** in Factory CLI
3. **Run a local proxy** for stable API forwarding

## Quick Start

### Prerequisites

- Factory CLI (Droid) installed
- Third-party API credentials (stored in `~/.codex/config.toml` or `~/.codex/auth.json`)
- macOS or Linux

### Installation

```bash
git clone https://github.com/tytsxai/cli-proxy-droid-integration.git
cd cli-proxy-droid-integration
cp CLIProxyAPI/config.yaml.example CLIProxyAPI/config.yaml
# Edit config.yaml with your API credentials
./setup.sh
```

The setup script will:
- Read your API credentials automatically
- Configure Factory CLI with custom models
- Start the local proxy server on port 8317

### Usage

After setup, launch Droid:

```bash
droid
```

Then select your custom model:
1. Type `/model` to see available models
2. Select `gpt-5.2` or other configured models
3. Start chatting!

## How It Works

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Droid CLI  │────▶│  Local Proxy     │────▶│  Third-party    │
│             │     │  (port 8317)     │     │  AI Provider    │
└─────────────┘     └──────────────────┘     └─────────────────┘
```

The local proxy:
- Handles authentication automatically
- Provides OpenAI-compatible API endpoints
- Manages request retries and error handling

## Project Structure

```
.
├── setup.sh                 # One-click setup script
├── sync-credentials.sh      # Credential synchronization
├── verify-integration.sh    # Configuration verification
├── CLIProxyAPI/
│   ├── cli-proxy-api        # Proxy server binary
│   └── config.yaml.example  # Configuration template
└── README.md
```

## Configuration

### Credential Sources (Priority Order)

1. Environment variables: `CODEX_API_KEY` or `OPENAI_API_KEY`
2. `~/.codex/config.toml` → `experimental_bearer_token`
3. `~/.codex/auth.json` → `OPENAI_API_KEY`

### Key Configuration Files

| File | Purpose |
|------|---------|
| `~/.factory/config.json` | Droid custom model settings |
| `~/.cli-proxy-api/codex-yunyi.json` | Proxy authentication token |
| `CLIProxyAPI/config.yaml` | Proxy server configuration |

## Scripts Reference

| Script | Description |
|--------|-------------|
| `./setup.sh` | Complete setup (run this first) |
| `./sync-credentials.sh` | Sync credentials to proxy |
| `./verify-integration.sh` | Verify all configurations |

## Troubleshooting

### Token Not Found

Ensure your credentials exist:

```bash
ls -la ~/.codex/
cat ~/.codex/config.toml  # Look for experimental_bearer_token
```

### Custom Models Not Showing

Run the verification script:

```bash
./verify-integration.sh
```

### Port 8317 Already in Use

```bash
# Find the process
lsof -i :8317

# Kill it
kill <PID>

# Restart proxy
./setup.sh
```

### Direct Connection (No Proxy)

Edit `~/.factory/config.json` and change `base_url` to your provider's endpoint directly.

## Integration with Other Tools

The proxy provides an OpenAI-compatible API:

```bash
# Environment variables
export OPENAI_API_BASE=http://localhost:8317/v1
export OPENAI_API_KEY=dummy-not-used

# Test the API
curl http://localhost:8317/v1/models
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Factory CLI (Droid)](https://github.com/openai/codex) - The CLI tool this integrates with
- CLIProxyAPI - The proxy server component
