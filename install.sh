#!/bin/bash
# ============================================================
# AI帮老板省人工 · 一键安装脚本 v2.0
# 作者：老邢AI工作室
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   AI帮老板省人工 · 自动化系统一键安装 v2.0${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# ============ 第一步：检查环境 ============
echo -e "${BLUE}[1/6] 检查环境...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ 未检测到Docker，正在自动安装...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
fi
echo -e "${GREEN}✅ Docker已就绪${NC}"

if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}安装docker-compose插件...${NC}"
    apt-get update -qq && apt-get install -y docker-compose-plugin
fi
echo -e "${GREEN}✅ Docker Compose已就绪${NC}"

# ============ 第二步：收集配置 ============
echo ""
echo -e "${YELLOW}[2/6] 请填写配置信息（填完按回车）：${NC}"
echo ""

read -p "① 飞书 App ID (cli_开头): " FEISHU_APP_ID
read -s -p "② 飞书 App Secret: " FEISHU_APP_SECRET
echo ""
read -p "③ 网关Token (自定义密码，如 MyAI2026): " GATEWAY_TOKEN
read -s -p "④ 阿里云DashScope API Key (sk-开头): " DASHSCOPE_KEY
echo ""
echo ""

# ============ 第三步：创建目录 ============
echo -e "${BLUE}[3/6] 创建目录结构...${NC}"
mkdir -p ~/ai-system/openclaw-config
mkdir -p ~/ai-system/openclaw-workspace
mkdir -p ~/ai-system/n8n-data
mkdir -p ~/ai-system/skills

# ============ 第四步：生成配置文件 ============
echo -e "${BLUE}[4/6] 生成配置文件...${NC}"

# openclaw.json
cat > ~/ai-system/openclaw-config/openclaw.json << JSONEOF
{
  "meta": {
    "lastTouchedVersion": "2026.3.2"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "dashscope/qwen3.5-plus"
      },
      "workspace": "/home/node/.openclaw/workspace",
      "compaction": { "mode": "safeguard" },
      "maxConcurrent": 4,
      "subagents": { "maxConcurrent": 8 }
    }
  },
  "tools": {
    "profile": "full"
  },
  "bindings": [
    {
      "agentId": "main",
      "match": { "channel": "feishu", "accountId": "default" }
    }
  ],
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true
  },
  "session": {
    "dmScope": "per-channel-peer"
  },
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "${FEISHU_APP_ID}",
      "appSecret": "${FEISHU_APP_SECRET}",
      "connectionMode": "websocket",
      "domain": "feishu",
      "groupPolicy": "open"
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "${GATEWAY_TOKEN}"
    },
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true,
      "dangerouslyDisableDeviceAuth": true,
      "allowInsecureAuth": true
    },
    "trustedProxies": ["0.0.0.0/0"],
    "remote": { "token": "${GATEWAY_TOKEN}" }
  },
  "plugins": {
    "entries": {
      "feishu": { "enabled": true }
    },
    "installs": {
      "feishu": {
        "source": "npm",
        "spec": "@openclaw/feishu",
        "installPath": "/home/node/.openclaw/extensions/feishu",
        "version": "2026.3.2",
        "resolvedName": "@openclaw/feishu",
        "resolvedVersion": "2026.3.2"
      }
    }
  },
  "models": {
    "providers": {
      "dashscope": {
        "baseUrl": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "apiKey": "${DASHSCOPE_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "qwen3.5-plus",
            "name": "Qwen3.5 Plus",
            "input": ["text"],
            "contextWindow": 1000000,
            "maxTokens": 8192
          }
        ]
      }
    }
  }
}
JSONEOF

# .env文件
cat > ~/ai-system/.env << ENVEOF
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
OPENCLAW_CONFIG_DIR=./openclaw-config
OPENCLAW_WORKSPACE_DIR=./openclaw-workspace
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest
ENVEOF

# docker-compose.yml（包含gateway + cli 两个容器）
cat > ~/ai-system/docker-compose.yml << 'COMPOSEEOF'
version: "3.8"

services:
  openclaw-gateway:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: openclaw-gateway
    environment:
      HOME: /home/node
      TERM: xterm-256color
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}
    volumes:
      - ${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw
      - ${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace
      - ./skills:/app/skills
    ports:
      - "18789:18789"
      - "18790:18790"
    init: true
    restart: unless-stopped
    command: ["node", "dist/index.js", "gateway", "--bind", "lan", "--port", "18789"]
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 20s

  openclaw-cli:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: openclaw-cli
    network_mode: "service:openclaw-gateway"
    cap_drop:
      - NET_RAW
      - NET_ADMIN
    security_opt:
      - no-new-privileges:true
    environment:
      HOME: /home/node
      TERM: xterm-256color
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}
      BROWSER: echo
    volumes:
      - ${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw
      - ${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace
      - ./skills:/app/skills
    stdin_open: true
    tty: true
    init: true
    entrypoint: ["node", "dist/index.js"]
    restart: unless-stopped
    depends_on:
      openclaw-gateway:
        condition: service_healthy

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    environment:
      - N8N_BASIC_AUTH_ACTIVE=false
      - WEBHOOK_URL=http://localhost:5678
      - GENERIC_TIMEZONE=Asia/Shanghai
    volumes:
      - ./n8n-data:/home/node/.n8n
    ports:
      - "127.0.0.1:5678:5678"
    restart: unless-stopped
    networks:
      - ai-internal

networks:
  ai-internal:
    name: ai-internal
COMPOSEEOF

echo -e "${GREEN}✅ 配置文件生成完成${NC}"

# ============ 第五步：启动服务 ============
echo -e "${BLUE}[5/6] 启动服务（首次需要下载镜像，约3-5分钟）...${NC}"
cd ~/ai-system
docker compose up -d

echo -e "${YELLOW}等待服务启动...${NC}"
sleep 30

# 检查服务状态
GATEWAY_STATUS=$(docker inspect --format='{{.State.Health.Status}}' openclaw-gateway 2>/dev/null || echo "unknown")
if [ "$GATEWAY_STATUS" = "healthy" ]; then
    echo -e "${GREEN}✅ OpenClaw网关启动成功${NC}"
else
    echo -e "${YELLOW}⏳ 服务仍在启动中，继续等待...${NC}"
    sleep 20
fi

# ============ 第六步：安装核心技能 ============
echo -e "${BLUE}[6/6] 安装核心技能...${NC}"

# 从GitHub直接安装技能（绕过ClawHub限速）
SKILLS_DIR=~/ai-system/skills
cd $SKILLS_DIR

echo "安装 xurl（联网搜索）..."
git clone --depth=1 https://github.com/openclaw/openclaw.git /tmp/oc-repo 2>/dev/null
if [ -d "/tmp/oc-repo/skills" ]; then
  for SKILL in xurl summarize healthcheck weather nano-pdf; do
    if [ -d "/tmp/oc-repo/skills/$SKILL" ]; then
      cp -r /tmp/oc-repo/skills/$SKILL $SKILLS_DIR/
      echo -e "${GREEN}  ✅ $SKILL${NC}"
    fi
  done
else
  echo -e "${YELLOW}  ⚠️ 技能仓库克隆失败，稍后可手动安装${NC}"
fi
rm -rf /tmp/oc-repo

# 重启让技能生效
docker compose restart openclaw-gateway openclaw-cli

# ============ 安装完成 ============
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   🎉 安装完成！${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "📱 OpenClaw控制台："
echo -e "   ${BLUE}http://${SERVER_IP}:18789?token=${GATEWAY_TOKEN}${NC}"
echo ""
echo -e "⚙️  n8n工作流（需SSH隧道）："
echo -e "   ${BLUE}http://localhost:5678${NC}"
echo -e "   SSH隧道命令：ssh -L 5678:127.0.0.1:5678 root@${SERVER_IP}"
echo ""
echo -e "✅ 已安装技能：xurl、summarize、healthcheck、weather"
echo ""
echo -e "${YELLOW}下一步：去飞书给机器人发消息测试！${NC}"
echo -e "发送：你好，介绍一下你自己"
echo ""
