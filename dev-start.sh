#!/bin/bash
# ============================================================
# sub2api 本地开发一键启动脚本
# 使用方式：在 Git Bash 中运行  ./dev-start.sh
# ============================================================

set -e

# ---- 配置 ----
GOROOT_DIR="D:/Software/developments/environments/go124"
GO_BIN="$GOROOT_DIR/bin/go"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend"
FRONTEND_DIR="$PROJECT_DIR/frontend"
BACKEND_PORT=54371
FRONTEND_PORT=31289

# ---- 颜色 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ---- 清理函数 ----
cleanup() {
    echo ""
    echo -e "${YELLOW}[INFO] 正在停止所有服务...${NC}"
    if [ -n "$BACKEND_PID" ] && kill -0 "$BACKEND_PID" 2>/dev/null; then
        kill "$BACKEND_PID" 2>/dev/null
        echo -e "${RED}[Backend] 已停止 (PID: $BACKEND_PID)${NC}"
    fi
    if [ -n "$FRONTEND_PID" ] && kill -0 "$FRONTEND_PID" 2>/dev/null; then
        kill "$FRONTEND_PID" 2>/dev/null
        echo -e "${RED}[Frontend] 已停止 (PID: $FRONTEND_PID)${NC}"
    fi
    echo -e "${GREEN}[INFO] 所有服务已停止${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# ---- 环境检查 ----
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  sub2api 本地开发环境启动${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# 检查 Go
if [ ! -f "$GO_BIN" ]; then
    echo -e "${RED}[ERROR] Go 未找到: $GO_BIN${NC}"
    echo "请修改脚本中的 GOROOT_DIR 变量"
    exit 1
fi

GO_VERSION=$("$GO_BIN" version 2>&1)
echo -e "${GREEN}[✓] Go: $GO_VERSION${NC}"

# 检查 pnpm
if ! command -v pnpm &>/dev/null; then
    echo -e "${RED}[ERROR] pnpm 未找到，请先安装: npm install -g pnpm${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] pnpm: $(pnpm --version)${NC}"

# 检查 config.yaml
if [ ! -f "$BACKEND_DIR/config.yaml" ]; then
    echo -e "${YELLOW}[WARN] 未找到 backend/config.yaml，后端将进入 Setup Wizard 模式${NC}"
fi

# ---- 端口检查 ----
check_port() {
    local port=$1
    local name=$2
    if netstat -an 2>/dev/null | grep -q ":${port}.*LISTEN"; then
        echo -e "${RED}[ERROR] 端口 $port ($name) 已被占用！${NC}"
        echo -e "${YELLOW}  请先释放端口或修改脚本中的端口配置${NC}"
        return 1
    fi
    echo -e "${GREEN}[✓] 端口 $port ($name) 可用${NC}"
    return 0
}

check_port $BACKEND_PORT "后端" || exit 1
check_port $FRONTEND_PORT "前端" || exit 1

echo ""

# ---- 启动后端 ----
echo -e "${CYAN}[Backend] 启动 Go 后端 (端口 $BACKEND_PORT)...${NC}"
export GOROOT="$GOROOT_DIR"
export PATH="$GOROOT_DIR/bin:$PATH"
# 通过环境变量强制指定端口，确保和 config.yaml 一致
export SERVER_PORT=$BACKEND_PORT
export SERVER_HOST=0.0.0.0

(cd "$BACKEND_DIR" && "$GO_BIN" run ./cmd/server/) 2>&1 | sed "s/^/[Backend] /" &
BACKEND_PID=$!
echo -e "${GREEN}[Backend] PID: $BACKEND_PID${NC}"

# ---- 安装前端依赖（如果需要）----
if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
    echo -e "${YELLOW}[Frontend] 安装依赖 (pnpm install)...${NC}"
    (cd "$FRONTEND_DIR" && pnpm install)
fi

# ---- 启动前端 ----
echo -e "${CYAN}[Frontend] 启动 Vue3 前端 (端口 $FRONTEND_PORT)...${NC}"
# 通过环境变量告诉 Vite 后端代理地址
export VITE_DEV_PROXY_TARGET="http://localhost:$BACKEND_PORT"

(cd "$FRONTEND_DIR" && pnpm dev) 2>&1 | sed "s/^/[Frontend] /" &
FRONTEND_PID=$!
echo -e "${GREEN}[Frontend] PID: $FRONTEND_PID${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  服务已启动！${NC}"
echo -e "${GREEN}  前端: http://localhost:$FRONTEND_PORT${NC}"
echo -e "${GREEN}  后端: http://localhost:$BACKEND_PORT${NC}"
echo -e "${GREEN}  按 Ctrl+C 停止所有服务${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ---- 等待子进程 ----
wait
