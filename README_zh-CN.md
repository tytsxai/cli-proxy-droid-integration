# CLI Proxy API 集成工具 - Factory CLI (Droid)

> 通过本地代理服务器，让 Factory CLI (Droid) 使用第三方 AI 模型

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()

[English](README.md) | **中文**

---

## 这是什么？

本工具包帮助你将 **Factory CLI (Droid)** 连接到第三方 AI 模型提供商。功能包括：

1. **自动检测凭证** - 从多个来源自动读取
2. **配置自定义模型** - 在 Factory CLI 中使用
3. **运行本地代理** - 提供 OpenAI 兼容的 API 端点

### 架构图

```
┌─────────────────┐     ┌─────────────────────┐     ┌──────────────────┐
│  Factory CLI    │────▶│  本地代理           │────▶│  第三方 AI       │
│  (Droid)        │     │  (localhost:8317)   │     │  提供商          │
└─────────────────┘     └─────────────────────┘     └──────────────────┘
```

---

## 前置条件

开始之前，请确保你有：

- [ ] 已安装 **Factory CLI (Droid)**
- [ ] 第三方提供商的 **API 凭证**
- [ ] **macOS 或 Linux** 操作系统
- [ ] 基本的终端操作知识

---

## 安装步骤（详细）

### 步骤 1：克隆仓库

```bash
cd ~/Desktop
git clone https://github.com/tytsxai/cli-proxy-droid-integration.git
cd cli-proxy-droid-integration
```

### 步骤 2：创建配置文件

```bash
cp CLIProxyAPI/config.yaml.example CLIProxyAPI/config.yaml
```

### 步骤 3：编辑配置文件

用编辑器打开 `CLIProxyAPI/config.yaml`：

```bash
nano CLIProxyAPI/config.yaml
# 或使用: vim, code 等编辑器
```

找到 `codex-api-key` 部分并修改：

```yaml
codex-api-key:
  - api-key: "你的实际API密钥"
    prefix: "provider"
    base-url: "https://你的API端点地址/api"
```

### 步骤 4：运行配置脚本

```bash
chmod +x setup.sh
./setup.sh
```

脚本会自动：
- 同步你的凭证
- 配置 Factory CLI 自定义模型
- 在端口 8317 启动本地代理

### 步骤 5：验证安装

```bash
./verify-integration.sh
```

看到绿色对勾表示配置成功。

---

## 使用方法

### 启动 Droid

```bash
droid
```

进入后：
1. 输入 `/model` 查看可用模型
2. 选择自定义模型（如 `gpt-5.2`）
3. 开始对话！

### 日常命令

```bash
# 启动代理（如未运行）
./setup.sh

# 检查状态
./verify-integration.sh

# 查看日志
tail -f CLIProxyAPI/proxy.log

# 停止代理
pkill -f cli-proxy-api
```

---

## 常见问题排查

### 问题：找不到令牌

**原因：** 脚本无法找到 API 凭证

**解决方法：**
```bash
ls -la ~/.codex/
cat ~/.codex/config.toml
```

### 问题：端口 8317 被占用

**解决方法：**
```bash
lsof -i :8317
kill <PID>
./setup.sh
```

### 问题：自定义模型不显示

**解决方法：**
```bash
cat ~/.factory/config.json
./setup.sh
```

### 遇到问题？让 AI 帮你！

如果遇到上述未涵盖的问题：

1. 复制本 README 文件内容
2. 发送给 ChatGPT、Claude 或其他 AI 助手
3. 描述你的问题

AI 会理解项目结构并帮你排查。

---

## 项目结构

```
.
├── setup.sh                      # 一键配置脚本
├── sync-credentials.sh           # 凭证同步脚本
├── verify-integration.sh         # 配置验证脚本
├── CLIProxyAPI/
│   ├── cli-proxy-api             # 代理服务二进制
│   └── config.yaml.example       # 配置模板
├── README.md                     # 英文文档
└── README_zh-CN.md               # 中文文档
```

---

## 致谢

本项目使用了以下开源工具：

- **[CLIProxyAPI](https://github.com/anthropics/cli-proxy-api)** - 核心代理服务组件
- **[Factory CLI (Droid)](https://github.com/openai/codex)** - 本项目集成的 CLI 工具

感谢所有贡献者和开源社区。

---

## 贡献

欢迎贡献！请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 了解指南。

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。
