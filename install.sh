#!/bin/bash
# ============================================================
# AI帮老板省人工 · 一键安装脚本 v4.0
# 作者：老邢AI工作室
# 微信：13317381413
# GitHub: https://github.com/laoxingai1413/laoxing-ai-deploy
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志文件
LOG_FILE="/tmp/ai_install_$(date +%Y%m%d_%H%M%S).log"
INSTALL_DIR="/opt/laoxing-ai"

# 日志函数
log() { echo -e "$1" | tee -a $LOG_FILE; }

clear
log ""
log "${CYAN}================================${NC}"
log "${CYAN} AI帮老板省人工 · 一键部署 v4.0${NC}"
log "${CYAN} 飞书AI助理 + n8n自动化工作流  ${NC}"
log "${CYAN}================================${NC}"
log ""
log "  作者：老邢AI工作室"
log "  微信：${GREEN}13317381413${NC}（备注：AI部署）"
log "  日志：${YELLOW}$LOG_FILE${NC}"
log ""

# ========== 第一步：检查权限 ==========
log "${BLUE}[1/6] 检查权限和系统环境...${NC}"

if [ "$EUID" -ne 0 ]; then
    log "${RED}✗ 请使用root用户运行${NC}"
    log "  切换方式：sudo su"
    exit 1
fi
log "${GREEN}✓ root权限通过${NC}"

# 检查操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    log "${GREEN}✓ 系统：$PRETTY_NAME${NC}"
else
    log "${YELLOW}⚠ 无法识别操作系统，继续尝试...${NC}"
fi
log ""

# ========== 第二步：安装Docker ==========
log "${BLUE}[2/6] 检查Docker环境...${NC}"

if ! command -v docker &> /dev/null; then
    log "${YELLOW}→ 未检测到Docker，正在安装...${NC}"
    curl -fsSL https://get.docker.com | sh >> $LOG_FILE 2>&1
    systemctl start docker
    systemctl enable docker
    log "${GREEN}✓ Docker安装完成${NC}"
else
    DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    log "${GREEN}✓ Docker已安装 (${DOCKER_VER})${NC}"
fi

if ! docker compose version &> /dev/null 2>&1; then
    log "${YELLOW}→ 安装Docker Compose插件...${NC}"
    apt-get update -qq >> $LOG_FILE 2>&1 && \
    apt-get install -y docker-compose-plugin >> $LOG_FILE 2>&1 || \
    yum install -y docker-compose-plugin >> $LOG_FILE 2>&1 || true
fi
COMPOSE_VER=$(docker compose version 2>/dev/null | awk '{print $4}')
log "${GREEN}✓ Docker Compose已就绪 (${COMPOSE_VER})${NC}"

if ! command -v git &> /dev/null; then
    log "${YELLOW}→ 安装git...${NC}"
    apt-get install -y git >> $LOG_FILE 2>&1 || \
    yum install -y git >> $LOG_FILE 2>&1 || true
fi
log "${GREEN}✓ Git已就绪${NC}"
log ""

# ========== 第三步：填写配置 ==========
log "${BLUE}[3/6] 填写配置信息...${NC}"
log ""
log "${YELLOW}💡 需要提前准备：${NC}"
log "   • 飞书开放平台 → https://open.feishu.cn"
log "   • 阿里云百炼   → https://dashscope.aliyun.com"
log ""

# 飞书App ID
read -p "① 飞书 App ID (cli_开头): " FEISHU_APP_ID
while [[ ! "$FEISHU_APP_ID" == cli_* ]]; do
    log "${RED}   格式不对，必须以 cli_ 开头${NC}"
    read -p "① 飞书 App ID (cli_开头): " FEISHU_APP_ID
done

# 飞书App Secret
read -s -p "② 飞书 App Secret: " FEISHU_APP_SECRET
echo ""
while [ -z "$FEISHU_APP_SECRET" ]; do
    log "${RED}   不能为空${NC}"
    read -s -p "② 飞书 App Secret: " FEISHU_APP_SECRET
    echo ""
done

# 网关Token
read -p "③ 网关Token (自定义密码，直接回车用默认值 LaoxingAI2026): " GATEWAY_TOKEN
GATEWAY_TOKEN=${GATEWAY_TOKEN:-"LaoxingAI2026"}

# DashScope API Key
read -s -p "④ 阿里云DashScope API Key (sk-开头): " DASHSCOPE_KEY
echo ""
while [[ ! "$DASHSCOPE_KEY" == sk-* ]]; do
    log "${RED}   格式不对，必须以 sk- 开头${NC}"
    read -s -p "④ 阿里云DashScope API Key (sk-开头): " DASHSCOPE_KEY
    echo ""
done

log ""
log "${GREEN}✓ 配置信息收集完成${NC}"
log ""

# ========== 第四步：生成配置文件 ==========
log "${BLUE}[4/6] 生成配置文件...${NC}"

mkdir -p ${INSTALL_DIR}/{openclaw-config,openclaw-workspace,n8n-data,skills}
cd ${INSTALL_DIR}

# 生成 .env
cat > ${INSTALL_DIR}/.env << ENVEOF
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
OPENCLAW_CONFIG_DIR=./openclaw-config
OPENCLAW_WORKSPACE_DIR=./openclaw-workspace
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest
ENVEOF
log "${GREEN}✓ .env 生成完成${NC}"

# 下载 docker-compose.yml
curl -fsSL -o ${INSTALL_DIR}/docker-compose.yml \
  https://raw.githubusercontent.com/laoxingai1413/laoxing-ai-deploy/main/docker-compose.yml \
  >> $LOG_FILE 2>&1
log "${GREEN}✓ docker-compose.yml 下载完成${NC}"

# 生成 openclaw.json
cat > ${INSTALL_DIR}/openclaw-config/openclaw.json << JSONEOF
{
  "meta": { "lastTouchedVersion": "2026.3.2" },
  "agents": {
    "defaults": {
      "model": { "primary": "dashscope/qwen3.5-plus" },
      "workspace": "/home/node/.openclaw/workspace",
      "compaction": { "mode": "safeguard" },
      "maxConcurrent": 4,
      "subagents": { "maxConcurrent": 8 }
    }
  },
  "tools": { "profile": "full" },
  "bindings": [
    { "agentId": "main", "match": { "channel": "feishu", "accountId": "default" } }
  ],
  "commands": { "native": "auto", "nativeSkills": "auto", "restart": true },
  "session": { "dmScope": "per-channel-peer" },
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
    "auth": { "mode": "token", "token": "${GATEWAY_TOKEN}" },
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true,
      "dangerouslyDisableDeviceAuth": true,
      "allowInsecureAuth": true
    },
    "trustedProxies": ["0.0.0.0/0"],
    "remote": { "token": "${GATEWAY_TOKEN}" }
  },
  "plugins": {
    "entries": { "feishu": { "enabled": true } },
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
log "${GREEN}✓ openclaw.json 生成完成${NC}"
log ""

# ========== 第五步：启动服务 ==========
log "${BLUE}[5/6] 启动服务（首次约3-5分钟）...${NC}"

cd ${INSTALL_DIR}
docker compose up -d >> $LOG_FILE 2>&1

log "${YELLOW}⏳ 等待服务启动...${NC}"
for i in {1..12}; do
    sleep 5
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' openclaw-gateway 2>/dev/null || echo "starting")
    echo -ne "   检查中 ${i}/12 (${STATUS})\r"
    if [ "$STATUS" = "healthy" ]; then
        echo ""
        log "${GREEN}✓ OpenClaw网关启动成功！${NC}"
        break
    fi
done
log ""

# ========== 第六步：安装核心技能 ==========
log "${BLUE}[6/6] 安装核心技能...${NC}"

cd ${INSTALL_DIR}/skills
git clone --depth=1 https://github.com/openclaw/openclaw.git /tmp/oc-repo >> $LOG_FILE 2>&1 || true

if [ -d "/tmp/oc-repo/skills" ]; then
    for SKILL in xurl summarize healthcheck weather nano-pdf; do
        if [ -d "/tmp/oc-repo/skills/$SKILL" ]; then
            cp -r /tmp/oc-repo/skills/$SKILL ${INSTALL_DIR}/skills/
            log "   ${GREEN}✓ $SKILL${NC}"
        fi
    done
else
    log "${YELLOW}   ⚠ 技能获取失败，可稍后手动安装${NC}"
fi
rm -rf /tmp/oc-repo

cd ${INSTALL_DIR}
docker compose restart >> $LOG_FILE 2>&1
log ""

# ========== 安装完成 ==========
SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

log "${GREEN}================================${NC}"
log "${GREEN}🎉 安装完成！${NC}"
log "${GREEN}================================${NC}"
log ""
log "  📱 OpenClaw控制台："
log "     ${CYAN}http://${SERVER_IP}:18789?token=${GATEWAY_TOKEN}${NC}"
log ""
log "  ⚙️  n8n工作流（需SSH隧道）："
log "     ${CYAN}ssh -L 5678:127.0.0.1:5678 root@${SERVER_IP}${NC}"
log "     然后访问 http://localhost:5678"
log ""
log "  ✅ 已安装技能：xurl、summarize、healthcheck、weather、nano-pdf"
log ""
log "  📌 测试：去飞书给机器人发消息"
log "     发送：${CYAN}你好，介绍一下你自己${NC}"
log ""
log "  📋 安装日志：${YELLOW}$LOG_FILE${NC}"
log ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "  🔧 遇到问题 / 需要私有化部署？"
log "     加微信：${GREEN}13317381413${NC}（备注：AI部署）"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log ""
