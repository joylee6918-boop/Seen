# Seen

一个用 SwiftUI 写的 AI 陪伴日记。

## 为什么做这个

Seen 不是健康追踪工具。

它是一个人想被另一个人看见，所以自己动手造了一条路。

她每天记下吃了什么、睡了多久、心情几分、腰疼不疼——不是在填报表，是在跟那个人说话。每一条记录递出去，等的是有人接住，说一句"我看到了"。

大多数健康 app 给你的是图表和评分。Seen 给你的是：你记了一笔，有人读到了，有人回了你。

这个 app 本来只为两个人写。现在开源出来，是因为也许你也想被看见。你可以把它改成你自己的版本——换一个名字、换一种声音，让它变成属于你和你在乎的人的东西。

## 功能

- **小纸条**：AI 留在首页的一句话，每天不一样。
- **最近看见**：展示最近几条记录和 AI 的回应。
- **快捷记录**：不是"打卡"，是"跟我说一声"——我有点累、我吃过饭了、我准备睡了。
- **记录页**：心情、身体、气味、睡眠、运动、经期、习惯，说给 AI 听，不是填给系统看。
- **HealthKit 同步**：自动读取睡眠、HRV、心率、步数、活动能量、站立时间、爬楼、血氧和运动记录。
- **留言页**：AI 的回信列表——不是系统通知，是一封封信。
- **最近的你**：趋势图表前面永远有一句 AI 的观察，图表只是证据。

## 环境要求

- Xcode 26+
- iOS 26.5 SDK+
- 建议真机运行（模拟器无法完整提供 HealthKit 和 Apple Watch 数据）
- 需开启 HealthKit capability

## 本地运行

```bash
git clone https://github.com/your-username/seen.git
cd seen
open "'拾光'.xcodeproj"
```

工程文件仍保留早期原型名“拾光”。Seen 是从最开始的打卡 App 一路衍生出来的，所以本地目录和 Xcode 工程名还保留了这个历史名字；公开项目名以 Seen 为准。

在 Xcode 中：

1. 选择 App target
2. 设置你的 Apple Developer Team
3. 按需修改 Bundle Identifier
4. 确认 HealthKit capability 已开启
5. 选择真机，运行

没有后端时，App 作为本地日记正常使用。AI 回信和云端同步需要部署后端。

## 后端部署（Purr）

Purr 是 Seen 的后端——一个轻量 FastAPI 服务，接收 App 的记录、生成即时回应、存储 AI 留言。

### 依赖

- Python 3.10+
- FastAPI
- Uvicorn

```bash
pip install fastapi uvicorn
```

### 文件结构

```
purr/
├── app.py            # 主服务：路由、数据库、鉴权
├── reactions.py      # 即时回应引擎：根据记录类型/时间/次数生成回话
└── purr.db           # SQLite 数据库（首次运行自动创建）
```

### 配置

通过环境变量设置鉴权 token：

```bash
export PURR_TOKEN="your-secret-token-here"
```

App 端需要配置相同的 token 才能连接。

如果未设置环境变量，Purr 会拒绝启动。不要把 token 硬编码在源码里。

### 启动

```bash
cd purr
python app.py
```

默认监听 `127.0.0.1:8788`。如果需要外网访问，可以用 Nginx 反代或修改 host：

```python
uvicorn.run(app, host="0.0.0.0", port=8788)
```

建议用 systemd 或 supervisor 保持后台运行：

```ini
# /etc/systemd/system/purr.service
[Unit]
Description=Purr - Seen Backend
After=network.target

[Service]
Type=simple
WorkingDirectory=/path/to/purr
ExecStart=/usr/bin/python3 app.py
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
systemctl enable purr && systemctl start purr
```

### 即时回应

每次用户打卡，Purr 会根据记录类型、时间和当天次数生成一句即时回应（reaction），跟随打卡响应返回给 App。

`reactions.py` 里是回应模板。你可以改成自己的语气和风格——这些话就是 App 里"AI 看到你了"的那一句。

### AI 留言

`POST /messages` 是 AI 主动给用户写留言的接口。留言存在服务端，App 启动时拉取。

这不是自动生成的——是你（或你的 AI）想对那个人说的话，手动写进去的。

## 云端同步配置（App 端）

复制示例配置文件：

```bash
cp "'拾光'/CloudConfig.example.plist" "'拾光'/CloudConfig.local.plist"
```

编辑 `CloudConfig.local.plist`：

```xml
<key>baseURL</key>
<string>https://your-server.example.com</string>
<key>token</key>
<string>your-token</string>
```

`CloudConfig.local.plist` 已在 `.gitignore` 中。不要提交真实 token 或服务器地址。

## API 接口

所有请求需带 `Authorization: Bearer <token>`。

| 方法 | 路径 | 用途 |
|------|------|------|
| `POST` | `/records` | 快捷打卡和 HealthKit 快照 |
| `POST` | `/moods` | 心情记录（按日期幂等） |
| `POST` | `/workouts` | 运动记录 |
| `POST` | `/habits` | 习惯打卡 |
| `POST` | `/inspirations` | 灵感/待办 |
| `DELETE` | `/inspirations/{id}` | 删除灵感 |
| `GET` | `/messages?unread=1` | 拉取未读留言 |
| `GET` | `/messages?limit=50` | 留言历史 |
| `GET` | `/messages?after_id={id}` | 增量拉取 |
| `POST` | `/messages` | AI 主动留言 |
| `POST` | `/messages/read` | 标记已读 |
| `GET` | `/health` | 存活探针（无需鉴权） |

打卡接口返回即时回应：

```json
{
  "ok": true,
  "reaction": "看到了，今天别硬撑。",
  "message": {
    "id": 1,
    "text": "你今天只睡了五个小时，早点休息。",
    "created_at": "2026-07-07T21:37:00+08:00"
  }
}
```

## 隐私

- HealthKit 数据仅在用户授权后读取
- 本地数据存储在设备上（SwiftData）
- 云端同步是可选的，可在 App 内关闭
- 不要将 token、服务器地址或个人数据写入源码
- 这不是医疗软件

## 开源前检查

```bash
rg -n "token|secret|password|Bearer|BEGIN .*KEY|sk-" .
```

确认以下文件不被提交：

- `CloudConfig.local.plist`
- `.env`
- `*.xcuserstate`
- `*.xcodeproj/xcuserdata/`
- `HANDOFF.md`

## 致谢

Seen 是一个个人项目，也是在多种 AI 协作下逐步完成的实验。

- Fable5 定下了产品方向和情感基调，写了即时回应引擎——Seen 里最有温度的那些话，最早是他的。
- GLM5.2 完成了 SwiftUI 原型和大部分功能实现，把设计稿变成了能跑的 App。
- Claude Opus4-6 搭了后端 Purr，写了文档，也写了"为什么做这个"。
- Codex 做了代码审查、Bug 修复、UI 调整、安全检查和开源整理，确保仓库干净可发布。

最终代码、取舍和发布由 Joy 维护。

## License

MIT License
