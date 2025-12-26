#!/bin/bash
# 集成验证脚本
# 检查 Droid + Yunyi + CLIProxyAPI 集成状态

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; }
log_fail() { echo -e "${RED}❌ FAIL${NC}: $1"; }
log_warn() { echo -e "${YELLOW}⚠️  WARN${NC}: $1"; }
log_info() { echo -e "${BLUE}ℹ️  INFO${NC}: $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILURES=0

echo "======================================"
echo "  Droid + Yunyi 集成验证"
echo "======================================"
echo ""

# 1. 检查凭证来源
echo "📋 检查凭证来源..."
echo "---"

# 检查 ~/.codex/config.toml
if [ -f "$HOME/.codex/config.toml" ]; then
    TOKEN=$(grep -E "^experimental_bearer_token\s*=" "$HOME/.codex/config.toml" 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' | head -1)
    if [ -n "$TOKEN" ]; then
        log_pass "~/.codex/config.toml 包含 experimental_bearer_token"
    else
        log_warn "~/.codex/config.toml 存在但没有 experimental_bearer_token"
    fi
else
    log_warn "~/.codex/config.toml 不存在"
fi

# 检查 ~/.codex/auth.json
if [ -f "$HOME/.codex/auth.json" ]; then
    if grep -q "OPENAI_API_KEY" "$HOME/.codex/auth.json" 2>/dev/null; then
        log_pass "~/.codex/auth.json 包含 OPENAI_API_KEY"
    else
        log_warn "~/.codex/auth.json 存在但没有 OPENAI_API_KEY"
    fi
else
    log_warn "~/.codex/auth.json 不存在"
fi

# 检查环境变量
if [ -n "$OPENAI_API_KEY" ] || [ -n "$CODEX_API_KEY" ]; then
    log_pass "环境变量中存在 API Key"
else
    log_info "环境变量中没有 API Key（可选）"
fi

echo ""

# 2. 检查 CLIProxyAPI 配置
echo "📋 检查 CLIProxyAPI..."
echo "---"

CLI_PROXY_TOKEN="$HOME/.cli-proxy-api/codex-yunyi.json"
if [ -f "$CLI_PROXY_TOKEN" ]; then
    log_pass "Token 文件存在: $CLI_PROXY_TOKEN"
    
    # 检查文件权限
    PERMS=$(stat -f "%OLp" "$CLI_PROXY_TOKEN" 2>/dev/null || stat -c "%a" "$CLI_PROXY_TOKEN" 2>/dev/null)
    if [ "$PERMS" = "600" ]; then
        log_pass "Token 文件权限正确 (600)"
    else
        log_warn "Token 文件权限: $PERMS (建议 600)"
    fi
    
    # 检查 JSON 格式
    if python3 -c "import json; json.load(open('$CLI_PROXY_TOKEN'))" 2>/dev/null; then
        log_pass "Token 文件 JSON 格式有效"
    else
        log_fail "Token 文件 JSON 格式无效"
        ((FAILURES++))
    fi
else
    log_fail "Token 文件不存在: $CLI_PROXY_TOKEN"
    log_info "运行 ./sync-credentials.sh 创建"
    ((FAILURES++))
fi

# 检查 CLIProxyAPI 进程
if pgrep -f "cli-proxy-api" > /dev/null; then
    log_pass "CLIProxyAPI 正在运行"
    PID=$(pgrep -f "cli-proxy-api" | head -1)
    log_info "PID: $PID"
else
    log_warn "CLIProxyAPI 未运行"
    log_info "运行 ./setup.sh 启动（或参考 setup.sh 中的启动命令）"
fi

# 检查端口
if command -v lsof &> /dev/null; then
    if lsof -i :8317 > /dev/null 2>&1; then
        log_pass "端口 8317 已监听"
    else
        log_warn "端口 8317 未监听"
    fi

    if lsof -i :8318 > /dev/null 2>&1; then
        log_pass "端口 8318 已监听 (CLIProxyAPI 上游)"
    else
        log_warn "端口 8318 未监听 (CLIProxyAPI 上游)"
    fi
fi

# 测试代理端点
if curl -s --connect-timeout 2 http://localhost:8317 > /dev/null 2>&1; then
    log_pass "CLIProxyAPI 端点可访问"
else
    log_warn "CLIProxyAPI 端点不可访问 (代理可能未启动)"
fi

echo ""

# 3. 检查 Droid 配置
echo "📋 检查 Droid 配置..."
echo "---"

# 检查 Droid 安装
if command -v droid &> /dev/null; then
    DROID_VERSION=$(droid --version 2>/dev/null || echo "unknown")
    log_pass "Droid 已安装 (版本: $DROID_VERSION)"
else
    log_fail "Droid 未安装"
    ((FAILURES++))
fi

# 检查 Droid 配置
FACTORY_CONFIG="$HOME/.factory/config.json"
if [ -f "$FACTORY_CONFIG" ]; then
    log_pass "Droid 配置存在: $FACTORY_CONFIG"
    
    # 检查自定义模型
    if grep -q "custom_models" "$FACTORY_CONFIG" 2>/dev/null; then
        MODEL_COUNT=$(grep -c '"model"' "$FACTORY_CONFIG" 2>/dev/null || echo "0")
        log_pass "配置了 $MODEL_COUNT 个自定义模型"
        
        # 检查是否指向本地代理
        if grep -q "localhost:8317" "$FACTORY_CONFIG" 2>/dev/null; then
            log_pass "模型配置指向本地代理 (localhost:8317)"
        elif grep -q "yunyi.cfd" "$FACTORY_CONFIG" 2>/dev/null; then
            log_warn "模型直接指向 yunyi.cfd（建议通过代理）"
        fi
    else
        log_warn "没有配置自定义模型"
    fi
else
    log_fail "Droid 配置不存在: $FACTORY_CONFIG"
    log_info "运行 ./setup.sh 创建"
    ((FAILURES++))
fi

echo ""
echo "======================================"
echo "  验证结果"
echo "======================================"
echo ""

if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}✅ 所有关键检查通过！${NC}"
    echo ""
    echo "下一步："
    echo "  1. 确保代理正在运行: ./setup.sh"
    echo "  2. 启动 Droid: droid"
    echo "  3. 选择自定义模型: /model → gpt-5.2"
else
    echo -e "${RED}❌ 有 $FAILURES 项检查失败${NC}"
    echo ""
    echo "建议运行: ./setup.sh"
fi
echo ""
