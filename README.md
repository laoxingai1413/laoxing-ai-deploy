# 🦞 AI帮老板省人工 · 飞书AI助理一键部署

> 5分钟搭建你自己的AI自动化团队，飞书直接对话，24小时待命

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 🎯 能做什么？

| 功能 | 说明 |
|------|------|
| 🤖 飞书AI助理 | 在飞书直接对话，下达任何指令 |
| 🌐 联网搜索 | 实时搜索行业资讯、竞品信息 |
| 📄 文档摘要 | 长文档自动压缩成要点 |
| ⚙️ n8n自动化 | 定时任务、工作流全自动执行 |
| 🖥️ 服务器监控 | 随时检查服务器健康状态 |

---

## 🚀 一键安装

SSH连接你的服务器，执行一条命令：

```bash
curl -fsSL https://raw.githubusercontent.com/laoxingai1413/laoxing-ai-deploy/main/install.sh | bash
```

按提示填写4个配置，等待5分钟自动完成。

---

## 📋 安装前准备

### 服务器要求
- Linux系统（Ubuntu 20.04+ 推荐）
- 最低：2核 4G内存 50G硬盘
- 需要能访问外网

### 需要准备4个信息

| 信息 | 获取方式 |
|------|---------|
| 飞书 App ID | https://open.feishu.cn → 创建企业自建应用 |
| 飞书 App Secret | 同上 |
| 网关Token | 自定义密码，如 `MyAI2026` |
| 阿里云DashScope Key | https://dashscope.aliyun.com → API密钥管理 |

### 飞书应用配置要点
1. 创建企业自建应用
2. 开通权限：`im:message`、`im:message:send_as_bot`、`cardkit:card:write`
3. 事件订阅 → 选择**长连接**模式
4. 发布应用

---

## 📁 文件说明

```
laoxing-ai-deploy/
├── install.sh            # 一键安装脚本 v4.0
├── docker-compose.yml    # Docker服务编排
├── .env.example          # 环境变量模板
└── README.md             # 说明文档
```

---

## 🔧 常用命令

```bash
# 查看服务状态
cd /opt/laoxing-ai && docker compose ps

# 查看日志
docker logs openclaw-gateway --tail 50

# 重启服务
cd /opt/laoxing-ai && docker compose restart

# 访问n8n（需先建SSH隧道）
ssh -L 5678:127.0.0.1:5678 root@你的服务器IP
# 浏览器打开 http://localhost:5678
```

---

## ❓ 常见问题

**飞书没有回复？**
- 检查飞书权限是否全部开通
- 确认事件订阅选择了"长连接"模式
- 查看安装日志：`/tmp/ai_install_*.log`

**安装中途失败？**
- 确认服务器能访问外网
- 确认使用root用户运行
- 把日志文件发给微信客服

---

## 📞 技术支持 & 私有化部署

遇到问题或需要定制化部署：

**加微信：13317381413**（备注：AI部署）

---

⭐ 觉得有用请点Star支持一下！
