#!/bin/bash
# 一键配置脚本
# 完成 Droid + Yunyi 集成的所有配置

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_PROXY_DIR="$SCRIPT_DIR/CLIProxyAPI"
CONFIG_FILE="$CLI_PROXY_DIR/config.yaml"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log_info() { echo -e "${BLUE}[$(timestamp)] [INFO] $1${NC}"; }
log_success() { echo -e "${GREEN}[$(timestamp)] [ OK ] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[$(timestamp)] [WARN] $1${NC}"; }
log_error() { echo -e "${RED}[$(timestamp)] [FAIL] $1${NC}"; }
log_tip() { echo -e "${CYAN}[$(timestamp)] [TIP ] $1${NC}"; }

die() { log_error "$1"; exit 1; }

on_err() {
    local exit_code=$?
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ 脚本执行失败                                              ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_error "错误代码: $exit_code"
    echo ""
    echo -e "${YELLOW}🔍 排查步骤：${NC}"
    echo "   1. 查看代理日志: tail -50 $CLI_PROXY_DIR/proxy.log"
    echo "   2. 检查配置文件: cat $CONFIG_FILE"
    echo "   3. 运行验证脚本: ./verify-integration.sh"
    echo ""
    exit "$exit_code"
}
trap on_err ERR

# 显示欢迎界面
clear 2>/dev/null || true
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     🚀 Droid + Yunyi 第三方集成 - 一键配置                   ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║  让你的 Droid 使用第三方 AI 模型（如 gpt-5.2）               ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 显示前置条件
echo -e "${CYAN}📋 前置条件检查：${NC}"
echo "   ├─ 已安装 Droid/Factory CLI"
echo "   ├─ 已激活 yunyi 第三方 Codex 服务"
echo "   └─ 凭证文件已存在: ~/.codex/config.toml 或 ~/.codex/auth.json"
echo ""

# 显示当前配置
echo -e "${CYAN}📁 当前配置路径：${NC}"
echo "   ├─ 脚本目录:      $SCRIPT_DIR"
echo "   ├─ CLIProxyAPI:   $CLI_PROXY_DIR"
echo "   └─ 配置文件:      $CONFIG_FILE"
echo ""

# 显示即将执行的操作
echo -e "${CYAN}⚙️  即将执行的操作：${NC}"
echo "   1️⃣  检查 CLIProxyAPI 二进制文件"
echo "   2️⃣  同步 yunyi 第三方凭证"
echo "   3️⃣  配置 Droid 自定义模型"
echo "   4️⃣  停止现有代理进程"
echo "   5️⃣  启动 CLIProxyAPI 代理服务"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 步骤 1: 检查 CLIProxyAPI
log_info "步骤 1/5: 检查 CLIProxyAPI..."
if [ ! -f "$CLI_PROXY_DIR/cli-proxy-api" ]; then
    die "CLIProxyAPI 二进制文件不存在: $CLI_PROXY_DIR/cli-proxy-api (请先构建: cd CLIProxyAPI && go build -o cli-proxy-api ./cmd/server)"
fi
log_success "CLIProxyAPI 已就绪"

# 步骤 2: 同步凭证
log_info "步骤 2/5: 同步第三方凭证..."
chmod +x "$SCRIPT_DIR/sync-credentials.sh"
"$SCRIPT_DIR/sync-credentials.sh"
echo ""

# 步骤 3: 配置 Factory CLI (Droid)
log_info "步骤 3/5: 配置 Droid 自定义模型..."
mkdir -p "$HOME/.factory"
FACTORY_CONFIG="$HOME/.factory/config.json"

if [ -f "$FACTORY_CONFIG" ]; then
    local_backup="$FACTORY_CONFIG.bak.$(date '+%Y%m%d-%H%M%S')"
    cp "$FACTORY_CONFIG" "$local_backup"
    log_warn "检测到已有配置，已备份: $local_backup"
fi

cat > "$FACTORY_CONFIG" << 'EOF'
{
    "custom_models": [
        {
            "model": "gpt-5.2",
            "base_url": "http://localhost:8317/v1",
            "api_key": "dummy-not-used",
            "provider": "openai"
        },
        {
            "model": "gpt-5.2-codex",
            "base_url": "http://localhost:8317/v1",
            "api_key": "dummy-not-used",
            "provider": "openai"
        }
    ]
}
EOF
log_success "Droid 配置已写入: $FACTORY_CONFIG"

# 步骤 4: 停止现有代理
log_info "步骤 4/5: 检查并停止现有代理..."
if pgrep -f "cli-proxy-api" > /dev/null; then
    log_warn "发现运行中的 CLIProxyAPI，准备停止"
    pkill -f "cli-proxy-api" || true
    sleep 1
    log_success "已停止现有 CLIProxyAPI 进程"
else
    log_info "没有运行中的 CLIProxyAPI 进程"
fi

# 步骤 5: 启动代理
log_info "步骤 5/5: 启动 CLIProxyAPI..."
cd "$CLI_PROXY_DIR"
log_info "启动命令: ./cli-proxy-api --config config.yaml"
nohup ./cli-proxy-api --config config.yaml > proxy.log 2>&1 &
sleep 2

if pgrep -f "cli-proxy-api" > /dev/null; then
    log_success "CLIProxyAPI 启动成功 (端口 8317)"
else
    die "CLIProxyAPI 启动失败 (查看日志: tail -50 $CLI_PROXY_DIR/proxy.log)"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ 配置完成！                                               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# API 配置详情
echo -e "${CYAN}🔧 API 配置详情：${NC}"
echo "   ├─ 代理地址:      http://localhost:8317"
echo "   ├─ API 端点:      http://localhost:8317/v1/responses"
echo "   ├─ API 格式:      OpenAI 兼容格式"
echo "   └─ 认证方式:      无需额外认证（已内置 yunyi token）"
echo ""

# Droid 使用方法
echo -e "${CYAN}🎮 Droid 使用方法：${NC}"
echo "   1. 启动 Droid:    droid"
echo "   2. 选择模型:      /model"
echo "   3. 可用模型:      gpt-5.2, gpt-5.2-codex"
echo ""

# 其他应用集成
echo -e "${CYAN}🔌 其他应用集成：${NC}"
echo "   如需在其他工具中使用此 API，配置如下："
echo ""
echo "   # 环境变量方式"
echo "   export OPENAI_API_BASE=http://localhost:8317/v1"
echo "   export OPENAI_API_KEY=dummy-not-used"
echo ""
echo "   # cURL 测试"
echo "   curl http://localhost:8317/v1/models"
echo ""

# 配置文件位置
echo -e "${CYAN}📁 关键配置文件：${NC}"
echo "   ├─ Droid 模型配置:     ~/.factory/config.json"
echo "   ├─ 代理配置:           $CONFIG_FILE"
echo "   ├─ yunyi 凭证:         ~/.cli-proxy-api/codex-yunyi.json"
echo "   └─ 代理日志:           $CLI_PROXY_DIR/proxy.log"
echo ""

# 常用命令
echo -e "${CYAN}🛠️  常用命令：${NC}"
echo "   验证配置:    ./verify-integration.sh"
echo "   查看日志:    tail -f $CLI_PROXY_DIR/proxy.log"
echo "   停止代理:    pkill -f cli-proxy-api"
echo "   重启代理:    ./setup.sh"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log_tip "💡 提示：代理服务需保持运行，关闭终端后需重新启动"
log_tip "📖 更多文档：查看 README.md 获取详细指南"

