#!/bin/bash
# 凭证同步脚本
# 自动从多来源读取第三方 yunyi 凭证并同步到 CLIProxyAPI

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# 配置路径
CODEX_CONFIG="$HOME/.codex/config.toml"
CODEX_AUTH="$HOME/.codex/auth.json"
CLI_PROXY_DIR="$HOME/.cli-proxy-api"
CLI_PROXY_TOKEN="$CLI_PROXY_DIR/codex-yunyi.json"

echo "======================================"
echo "  Yunyi 凭证同步工具"
echo "======================================"
echo ""

# 创建 CLI Proxy API 目录
mkdir -p "$CLI_PROXY_DIR"

# 变量存储找到的 token
TOKEN=""
TOKEN_SOURCE=""
BASE_URL="https://yunyi.cfd/codex"

# 来源 1: 环境变量
log_info "检查环境变量..."
if [ -n "$CODEX_API_KEY" ]; then
    TOKEN="$CODEX_API_KEY"
    TOKEN_SOURCE="环境变量 CODEX_API_KEY"
    log_success "从 CODEX_API_KEY 读取到 token"
elif [ -n "$OPENAI_API_KEY" ]; then
    TOKEN="$OPENAI_API_KEY"
    TOKEN_SOURCE="环境变量 OPENAI_API_KEY"
    log_success "从 OPENAI_API_KEY 读取到 token"
fi

# 来源 2: ~/.codex/config.toml
if [ -z "$TOKEN" ] && [ -f "$CODEX_CONFIG" ]; then
    log_info "检查 $CODEX_CONFIG..."
    # 解析 TOML 中的 experimental_bearer_token (使用 cut 和 tr 确保正确提取)
    TOML_TOKEN=$(grep -E "^experimental_bearer_token\s*=" "$CODEX_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d ' "' | head -1)
    if [ -n "$TOML_TOKEN" ]; then
        TOKEN="$TOML_TOKEN"
        TOKEN_SOURCE="$CODEX_CONFIG (experimental_bearer_token)"
        log_success "从 config.toml 读取到 token"
    fi
    
    # 同时提取 base_url（如果存在，在 [model_providers.yunyi] 节中）
    TOML_BASE_URL=$(awk '/\[model_providers.yunyi\]/,/^\[/' "$CODEX_CONFIG" 2>/dev/null | grep -E "^base_url\s*=" | sed 's/base_url\s*=\s*"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | tr -d '"' | head -1)
    if [ -n "$TOML_BASE_URL" ]; then
        BASE_URL="$TOML_BASE_URL"
        log_info "使用 base_url: $BASE_URL"
    fi
fi

# 来源 3: ~/.codex/auth.json
if [ -z "$TOKEN" ] && [ -f "$CODEX_AUTH" ]; then
    log_info "检查 $CODEX_AUTH..."
    # 使用 python 解析 JSON（macOS 自带）
    if command -v python3 &> /dev/null; then
        AUTH_TOKEN=$(python3 -c "import json; f=open('$CODEX_AUTH'); d=json.load(f); print(d.get('OPENAI_API_KEY', ''))" 2>/dev/null)
        if [ -n "$AUTH_TOKEN" ]; then
            TOKEN="$AUTH_TOKEN"
            TOKEN_SOURCE="$CODEX_AUTH (OPENAI_API_KEY)"
            log_success "从 auth.json 读取到 token"
        fi
    else
        # 备用：使用 grep/sed
        AUTH_TOKEN=$(grep -o '"OPENAI_API_KEY"[[:space:]]*:[[:space:]]*"[^"]*"' "$CODEX_AUTH" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')
        if [ -n "$AUTH_TOKEN" ]; then
            TOKEN="$AUTH_TOKEN"
            TOKEN_SOURCE="$CODEX_AUTH (OPENAI_API_KEY)"
            log_success "从 auth.json 读取到 token"
        fi
    fi
fi

# 检查是否找到 token
if [ -z "$TOKEN" ]; then
    log_error "未找到有效的 yunyi token！"
    echo ""
    echo "请确保至少存在以下一项："
    echo "  1. 环境变量 CODEX_API_KEY 或 OPENAI_API_KEY"
    echo "  2. $CODEX_CONFIG 中的 experimental_bearer_token"
    echo "  3. $CODEX_AUTH 中的 OPENAI_API_KEY"
    exit 1
fi

echo ""
log_info "Token 来源: $TOKEN_SOURCE"
log_info "Token 值: ${TOKEN:0:8}...${TOKEN: -8}"
log_info "API 地址: $BASE_URL"
echo ""

# 生成 CLIProxyAPI token 文件
log_info "写入 $CLI_PROXY_TOKEN..."

cat > "$CLI_PROXY_TOKEN" << EOF
{
    "access_token": "$TOKEN",
    "refresh_token": "",
    "expires_at": 9999999999,
    "token_type": "Bearer",
    "email": "yunyi@third-party.com",
    "provider": "yunyi",
    "base_url": "$BASE_URL"
}
EOF

# 设置安全权限
chmod 600 "$CLI_PROXY_TOKEN"

log_success "凭证同步完成！"
echo ""
echo "======================================"
echo "  同步结果"
echo "======================================"
echo "Token 文件: $CLI_PROXY_TOKEN"
echo "权限: $(ls -la "$CLI_PROXY_TOKEN" | awk '{print $1}')"
echo ""
log_info "现在可以启动 CLIProxyAPI 并使用 Droid 了"
