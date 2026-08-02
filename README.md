# 🎵 Bilibili Audio/Video Downloader Skill

> 基于 `yt-dlp` 的 **B站(bilibili) 音视频下载技能**，内置 **HTTP 412 反爬规避方案**，开箱即用。

在 iSH / Alpine Linux / 任何类 Unix 环境（甚至 macOS/Linux 终端）里，`yt-dlp` 直接下载 B 站视频时，很容易遭遇：

```
ERROR: [BiliBili] xxx: Unable to download JSON metadata: HTTP Error 412: Precondition Failed
```

这是 B 站对「非浏览器 / 游客请求」的风控拦截。本技能把这些绕坑参数**打包成一个脚本**，你只要给出视频链接或 BV 号，就能下载音频 / 视频 / 批量下载整个 UP 主空间。

---

## 🔑 扫码登录（解锁 720P+/1080P 高清、充电/会员内容）

游客模式只能下载 **360P/480P**。要高清画质，需登录你的 B站账号：

```bash
bash scripts/bilibili-login.sh
```

1. 脚本调用 B站官方 API 生成**登录二维码**
2. 生成一个 HTML 页面（`~/bilibili-login-qr.html`），在浏览器打开
3. 用 **B站 App** 扫码确认
4. 成功后 cookies 自动保存，后续下载自动启用高清格式

然后指定分辨率下载即可：

```bash
# 登录后下载 1080P 高清
bash scripts/bilibili-dl.sh "https://www.bilibili.com/video/BVxxx" video ~/Downloads mp4 1080
# 720P
bash scripts/bilibili-dl.sh "BVxxx" video 480 720
```

> ⚠️ 充电/会员视频**仅在你已购买且有权限时**才能下载，脚本不绕过付费墙。
> cookies 有效期约 1 个月，过期重跑登录脚本即可。

## ✨ 特性

- 🛡️ **内置 412 反爬规避**：自动获取 buvid cookie + 正确的 Referer / Origin / User-Agent + `player_client=web`
- 🎵 **音频模式**：只提取音频（高保真 AAC/m4a），最快
- 🎬 **视频模式**：视频+音频合并，**自动转 H.264 保证不黑屏**
- 🔑 **扫码登录**：解锁 **720P/1080P 高清**、充电/会员内容
- 📚 **批量模式**：下载整个 UP 主空间的所有视频音频，内置 3-6 秒随机间隔防封禁
- 🔗 **智能输入**：支持完整 URL、`b23.tv` 短链、纯 BV 号、UP 主 UID / 空间链接
- 🧩 **即插即用**：一个 bash 脚本，无其他外部服务依赖

---

## 📦 依赖

| 工具 | 用途 | 安装 |
|------|------|------|
| `yt-dlp` | 核心下载引擎 | `pip install -U yt-dlp` 或 `brew install yt-dlp` / `apk add yt-dlp` |
| `curl` | 获取 buvid cookie | 自带 |
| `ffmpeg` (可选) | 视频合并 / 音频转码 | `brew install ffmpeg` / `apk add ffmpeg` |

---

## 🚀 快速开始

### 1. 获取脚本

```bash
git clone https://github.com/menghuanshiguang/bilibili-audio-dl-skill.git
cd bilibili-audio-dl-skill
chmod +x scripts/bilibili-dl.sh   # 可能需要
```

### 2. 下载单个视频的音频

```bash
bash scripts/bilibili-dl.sh "BV1GJ411x7h7" audio
# 或
bash scripts/bilibili-dl.sh "https://www.bilibili.com/video/BV1GJ411x7h7"
```

### 3. 下载视频（含画面）

```bash
bash scripts/bilibili-dl.sh "BV1GJ411x7h7" video
```

### 4. 批量下载整个 UP 主空间

```bash
bash scripts/bilibili-dl.sh "https://space.bilibili.com/3546568888159133/video" list
# 或直接给 UID
bash scripts/bilibili-dl.sh "3546568888159133" list
```

---

## 📖 用法

```
bilibili-dl.sh <URL|BV号> [audio|video|list] [输出目录]
```

| 参数 | 说明 |
|------|------|
| `<URL或BV号>` | 视频链接 / 短链 / BV号 / 空间链接 / UID |
| `audio`(默认) | 只下载音频 |
| `video` | 下载视频并合并 |
| `list` | 批量下载作品集合 / 空间 |
| `[输出目录]` | 可选，默认 `~/B站音频下载/` |

---

## 🧠 它是怎么绕开 412 的

B 站会对游客请求返回 `412 Precondition Failed`。实测有效的关键参数组合：

```bash
yt-dlp \
  --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ...Chrome/120.0" \
  --add-header "Referer:https://www.bilibili.com/" \
  --add-header "Origin:https://www.bilibili.com" \
  --cookies <buvid-cookie.txt> \
  --extractor-args "bilibili:player_client=web"
```

其中最重要的是 **`buvid3` cookie**（脚本自动访问 bilibili.com 主页获取）和 **`player_client=web`**。缺了 `player_client=web` 或 cuvid cookie，即使有 UA 和 Referer 也大概率 412。

---

## ⚠️ 注意事项

1. **游客模式分辨率限制**：免费游客只能下载 **360P / 480P**。720P+ / 1080P 高清需登录态 cookie（见进阶文档）。
2. **版权声明**：请仅下载你有权访问的内容，不绕过会员付费墙、不破解会员专享。
3. **风控友好**：批量模式已内置随机间隔，仍请勿高频调用。

---

## 🔧 进阶

- 转 mp3、自定义命名、强制覆盖等见 [`references/后处理.md`](references/后处理.md)
- 高清（720P+/登录态）方法见同一文档

---

## 📄 许可证

MIT License
