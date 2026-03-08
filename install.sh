#!/bin/bash
# ============================================================
# AI帮老板省人工 · 一键安装脚本 v3.0
# 作者：老邢AI工作室
# 微信：13317381413
# GitHub: https://github.com/laoxingai1413/laoxing-ai-deploy
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     🦞 AI帮老板省人工 · 一键部署 v3.0          ║${NC}"
echo -e "${CYAN}║     飞书AI助理 + n8n自动化工作流                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  作者：老邢AI工作室"
echo -e "  微信：${GREEN}13317381413${NC}（备注：AI部署）"
echo ""

# ============ 检查root权限 ============
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ 请使用root用户运行此脚本${NC}"
    echo "   切换方式：sudo su"
    exit 1
fi

# ============ 第一步：检查环境 ============
echo -e "${BLUE}━━━ [1/5] 检查环境 ━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 检查Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}📦 Docker未安装，正在自动安装...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    echo -e "${GREEN}✅ Docker安装完成${NC}"
else
    DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    echo -e "${GREEN}✅ Docker已安装 (${DOCKER_VER})${NC}"
fi

# 检查Docker Compose
if ! docker compose version &> /dev/null 2>&1; then
    echo -e "${YELLOW}📦 安装Docker Compose插件...${NC}"
    apt-get update -qq && apt-get install -y docker-compose-plugin 2>/dev/null || \
    yum install -y docker-compose-plugin 2>/dev/null || true
fi
echo -e "${GREEN}✅ Docker Compose已就绪${NC}"

# 检查git
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}📦 安装git...${NC}"
    apt-get install -y git 2>/dev/null || yum install -y git 2>/dev/null || true
fi
echo -e "${GREEN}✅ Git已就绪${NC}"
echo ""

# ============ 第二步：填写配置 ============
echo -e "${BLUE}━━━ [2/5] 填写配置信息 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}💡 需要提前准备：${NC}"
echo "   • 飞书开放平台账号 → https://open.feishu.cn"
echo "   • 阿里云DashScope账号 → https://dashscope.aliyun.com"
echo ""

read -p "① 飞书 App ID (cli_开头): " FEISHU_APP_ID
while [[ ! "$FEISHU_APP_ID" == cli_* ]]; do
    echo -e "${RED}   格式不对，必须以 cli_ 开头${NC}"
    read -p "① 飞书 App ID (cli_开头): " FEISHU_APP_ID
done

read -s -p "② 飞书 App Secret: " FEISHU_APP_SECRET
echo ""
while [ -z "$FEISHU_APP_SECRET" ]; do
    echo -e "${RED}   不能为空${NC}"
    read -s -p "② 飞书 App Secret: " FEISHU_APP_SECRET
    echo ""
done

read -p "③ 网关访问Token (自定义密码，如 MyAI2026): " GATEWAY_TOKEN
GATEWAY_TOKEN=${GATEWAY_TOKEN:-"LaoxingAI2026"}

read -s -p "④ 阿里云DashScope API Key (sk-开头): " DASHSCOPE_KEY
echo ""
while [[ ! "$DASHSCOPE_KEY" == sk-* ]]; do
    echo -e "${RED}   格式不对，必须以 sk- 开头${NC}"
    read -s -p "④ 阿里云DashScope API Key (sk-开头): " DASHSCOPE_KEY
    echo ""
done

echo ""
echo -e "${GREEN}✅ 配置信息已收集${NC}"
echo ""

# ============ 第三步：创建目录和配置文件 ============
echo -e "${BLUE}━━━ [3/5] 生成配置文件 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

INSTALL_DIR=/opt/laoxing-ai
mkdir -p ${INSTALL_DIR}/{openclaw-config,openclaw-workspace,n8n-data,skills}
cd ${INSTALL_DIR}

# 生成 .env
cat > ${INSTALL_DIR}/.env << ENVEOF
OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}
OPENCLAW_CONFIG_DIR=./openclaw-config
OPENCLAW_WORKSPACE_DIR=./openclaw-workspace
OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest
ENVEOF

# 下载 docker-compose.yml
curl -fsSL -o ${INSTALL_DIR}/docker-compose.yml \
  https://raw.githubusercontent.com/laoxingai1413/laoxing-ai-deploy/main/docker-compose.yml
echo -e "${GREEN}✅ docker-compose.yml 下载完成${NC}"

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

echo -e "${GREEN}✅ 配置文件生成完成${NC}"
echo ""

# ============ 第四步：启动服务 ============
echo -e "${BLUE}━━━ [4/5] 启动服务 ━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}⏳ 首次启动需要下载镜像，约3-5分钟，请耐心等待...${NC}"
echo ""

cd ${INSTALL_DIR}
docker compose up -d

# 等待服务健康
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
for i in {1..12}; do
    sleep 5
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' openclaw-gateway 2>/dev/null || echo "starting")
    echo -ne "   检查中... ${i}/12 (状态: ${STATUS})\r"
    if [ "$STATUS" = "healthy" ]; then
        echo ""
        echo -e "${GREEN}✅ OpenClaw网关启动成功！${NC}"
        break
    fi
done
echo ""

# ============ 第五步：安装技能 ============
echo -e "${BLUE}━━━ [5/5] 安装核心技能 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd ${INSTALL_DIR}/skills
git clone --depth=1 https://github.com/openclaw/openclaw.git /tmp/oc-repo 2>/dev/null || true

if [ -d "/tmp/oc-repo/skills" ]; then
    for SKILL in xurl summarize healthcheck weather nano-pdf; do
        if [ -d "/tmp/oc-repo/skills/$SKILL" ]; then
            cp -r /tmp/oc-repo/skills/$SKILL ${INSTALL_DIR}/skills/
            echo -e "   ${GREEN}✅ ${SKILL}${NC}"
        fi
    done
else
    echo -e "${YELLOW}   ⚠️ 技能仓库获取失败，可稍后手动安装${NC}"
fi
rm -rf /tmp/oc-repo

cd ${INSTALL_DIR}
docker compose restart > /dev/null 2>&1
echo ""

# ============ 安装完成 ============
SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 安装完成！                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  📱 ${YELLOW}OpenClaw控制台：${NC}"
echo -e "     http://${SERVER_IP}:18789?token=${GATEWAY_TOKEN}"
echo ""
echo -e "  ⚙️  ${YELLOW}n8n工作流（先建SSH隧道）：${NC}"
echo -e "     ssh -L 5678:127.0.0.1:5678 root@${SERVER_IP}"
echo -e "     然后访问 http://localhost:5678"
echo ""
echo -e "  ✅ ${YELLOW}已安装技能：${NC}xurl、summarize、healthcheck、weather、nano-pdf"
echo ""
echo -e "  📌 ${YELLOW}测试方法：${NC}去飞书给机器人发消息"
echo -e "     发送：${CYAN}你好，介绍一下你自己${NC}"
echo ""
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  🔧 遇到问题 / 需要私有化部署支持？"
echo -e "     加微信：${GREEN}13317381413${NC}（备注：AI部署）"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
