# CLI Proxy API 集成工具 - Factory CLI (Droid)

> 通过本地代理服务器，让 Factory CLI (Droid) 使用第三方 AI 模型（如 GPT-5.2）

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()

[English](README.md) | **中文** | [日本語](README_ja.md)

## 概述

本工具包让 Factory CLI (Droid) 能够通过本地代理连接第三方 AI 模型提供商。如果你有第三方提供商的 API 凭证，本工具可以帮助你：

1. **自动检测凭证** - 从多个来源自动读取
2. **配置自定义模型** - 在 Factory CLI 中使用
3. **运行本地代理** - 稳定的 API 转发服务

## 快速开始

### 前置条件

- 已安装 Factory CLI (Droid)
- 第三方 API 凭证（存储在 `~/.codex/config.toml` 或 `~/.codex/auth.json`）
- macOS 或 Linux 系统

### 安装

```bash
git clone https://github.com/tytsxai/cli-proxy-droid-integration.git
cd cli-proxy-droid-integration
cp CLIProxyAPI/config.yaml.example CLIProxyAPI/config.yaml
# 编辑 config.yaml 填入你的 API 凭证
./setup.sh
```

### 使用方法

配置完成后，启动 Droid：

```bash
droid
```

然后选择自定义模型：
1. 输入 `/model` 查看可用模型
2. 选择 `gpt-5.2` 或其他已配置的模型
3. 开始对话！

## 工作原理

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Droid CLI  │────▶│  本地代理        │────▶│  第三方 AI      │
│             │     │  (端口 8317)     │     │  提供商         │
└─────────────┘     └──────────────────┘     └─────────────────┘
```

本地代理的功能：
- 自动处理身份验证
- 提供 OpenAI 兼容的 API 端点
- 管理请求重试和错误处理

## 项目结构

```
.
├── setup.sh                 # 一键配置脚本
├── sync-credentials.sh      # 凭证同步脚本
├── verify-integration.sh    # 配置验证脚本
├── CLIProxyAPI/
│   ├── cli-proxy-api        # 代理服务二进制文件
│   └── config.yaml.example  # 配置模板
└── README.md
```

## 配置说明

### 凭证来源（优先级顺序）

1. 环境变量：`CODEX_API_KEY` 或 `OPENAI_API_KEY`
2. `~/.codex/config.toml` → `experimental_bearer_token`
3. `~/.codex/auth.json` → `OPENAI_API_KEY`

### 关键配置文件

| 文件 | 用途 |
|------|------|
| `~/.factory/config.json` | Droid 自定义模型设置 |
| `~/.cli-proxy-api/codex-yunyi.json` | 代理认证令牌 |
| `CLIProxyAPI/config.yaml` | 代理服务配置 |

## 故障排除

### 找不到令牌

确保凭证文件存在：

```bash
ls -la ~/.codex/
cat ~/.codex/config.toml
```

### 端口 8317 被占用

```bash
lsof -i :8317
kill <PID>
./setup.sh
```

### 验证配置

```bash
./verify-integration.sh
```

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件
