# 🎵 Bilibili Audio/Video Downloader Skill

> **B站(bilibili) 音视频下载技能**，**v4.0.0 起套壳 [bilidown CLI](https://github.com/menghuanshiguang/bilibili-downloader-cli)**——所有功能通过 `bilidown` 命令执行，本仓库的 `scripts/` 目录保留同名脚本作为兜底（参数一致）。

内置 **HTTP 412 反爬规避** + **扫码登录解锁高清** + **官方 API 直链秒下（561P 大合集不再卡死）** + **片段截取**。

在 iSH / Alpine Linux / 任何类 Unix 环境里，`yt-dlp` 直接下载 B 站视频时很容易遭遇：

```
ERROR: [BiliBili] xxx: Unable to download JSON metadata: HTTP Error 412: Precondition Failed
```

这是 B 站对「非浏览器 / 游客请求」的风控拦截。本技能把这些绕坑参数**打包成 CLI**，你只要给出视频链接 / BV 号 / 歌名，就能下载音频、视频、批量下载整个 UP 主空间。

---

## 🖥️ 使用环境

| 环境 | 支持 | 说明 |
|------|:---:|------|
| **iSH (iOS)** | ✅ | 本项目的原生开发环境（Alpine Linux on iPhone/iPad） |
| **Android (Termux)** | ✅ | `pkg install bash ffmpeg python curl` + `pip install yt-dlp` |
| **Alpine / Debian / Ubuntu** | ✅ | 原生支持 |
| **macOS** | ✅ | 终端直接运行（libx264 编码器可用） |
| **Windows + WSL** | ✅ | **推荐**：`wsl --install` 后 clone 即用，零改动 |
| **Windows + Git Bash / MSYS2** | ✅ | 需确保 `yt-dlp`、`ffmpeg`、`python3`、`curl` 在 PATH 中 |
| Windows 原生 CMD / PowerShell | ❌ | 脚本为 bash 编写，不兼容（不建议重写） |

> 💡 **Windows 用户首选 WSL**：完整模拟 Linux 环境，clone 仓库 + 安装依赖即可，无需任何代码改动。

### 环境依赖

| 工具 | 用途 | 安装示例 |
|------|------|---------|
| `bash` | 脚本运行 | 各平台自带 / WSL 自带 |
| `yt-dlp` | 核心下载引擎 | `pip install -U yt-dlp` / `apk add yt-dlp` |
| `curl` | API 请求、获取 cookies | 各平台自带 / `apk add curl` |
| `python3` | JSON 解析 | 各平台自带 / `apk add python3` |
| `ffmpeg` | 视频合并 / 音频转码 | `apk add ffmpeg` / `brew install ffmpeg` / winget |
| `ffprobe` | 编码检测 | 随 ffmpeg 一起安装 |

> ⚠️ **iSH 注意事项**：iSH 的 ffmpeg 为精简版，无法解码 AV1，脚本已内置 **AV1 自动规避**（优先选择 H.264 流，转码失败自动重下 avc 流），保证 iOS 可直接播放。其他平台 ffmpeg 完整版无此问题，该逻辑自动无害跳过。

---

## 🚀 安装 bilidown CLI

```bash
git clone https://github.com/menghuanshiguang/bilibili-downloader-cli.git
cd bilibili-downloader-cli
bash install.sh          # 软链到 /usr/local/bin/bilidown
bilidown --version       # 验证
```

> 不想装 CLI？直接用本仓库 `scripts/` 下同名脚本，参数一致：
> `bash scripts/bilibili-dl.sh "BV1GJ411x7h7" audio`

---

## 📖 用法（bilidown）

```
bilidown dl <URL|BV号> [audio|video|list] [输出目录] [容器] [分辨率] [分P号] [截取区间]
```

| 子命令 | 说明 |
|--------|------|
| `dl` (download/d) | 下载音频/视频/批量 |
| `search` (s) | 搜索视频：`bilidown search <关键词> [条数]` |
| `login` (l) | 扫码登录解锁 720P/1080P 高清 |
| `formats` (fmt) | 查询可用格式/最高分辨率 |
| `parts` (p) | 查询分P列表（561P 秒出） |
| `find` (f) | 按关键词定位合集分P |
| `preview` (v) | 生成预览页（封面+标题+播放） |

### dl 参数详解

| 参数 | 说明 |
|------|------|
| `<URL或BV号>` | 视频链接 / 短链 / BV号 / 空间链接 / UID |
| `audio`(默认) | 只下载音频 |
| `video` | 下载视频并合并 |
| `list` | 批量下载作品集合 / 空间 |
| `[输出目录]` | 可选，默认 `~/B站音频下载/`，相对路径自动转绝对 |
| `[容器]` | 仅 video，`mp4`(默认) / `mkv`，可省略 |
| `[分辨率]` | 默认 `480`；`720`/`1080` 需登录，可省略 |
| `[分P号]` | 多P视频：P号 / `all` 全部 / 空=第1P，可省略 |
| `[截取区间]` | 可选，片段截取，格式 `开始-结束`（如 `1:30-2:45` / `90-165`）；不支持 `all` |

> 参数可省略：`bilidown dl "BVxxx"` 即可下载默认配置（音频、480P、第1P）。

### 快速示例

```bash
# 下载音频
bilidown dl "BV1GJ411x7h7" audio
# 1080P 视频
bilidown dl "BV1GJ411x7h7" video ~/Downloads mp4 1080
# 多P第2P
bilidown dl "BV1GV4y1W7vh" video ~/Downloads mp4 1080 2
# 截取片段 1:30-2:45
bilidown dl "BV1GJ411x7h7" audio ~/Downloads mp4 480 1 "1:30-2:45"
# 搜索
bilidown search "卓依婷 萍聚"
# 561P合集中按歌名定位
bilidown find "BV16v411L7js" "小草"
```

---

## 🔑 扫码登录（解锁 720P+/1080P 高清、充电/会员内容）

游客模式只能下载 **360P/480P**。要高清画质，需登录你的 B站账号：

```bash
bilidown login
```

1. 脚本调用 B站官方 API 生成**登录二维码**
2. 生成一个 HTML 页面（`~/bilibili-login-qr.html`），在浏览器打开
3. 用 **B站 App** 扫码确认
4. 成功后 cookies 自动保存，后续下载自动启用高清格式

> ⚠️ 充电/会员视频**仅在你已购买且有权限时**才能下载，脚本不绕过付费墙。
> cookies 有效期约 1 个月，过期重跑登录脚本即可。

---

## ✨ 特性

- 🛡️ **内置 412 反爬规避**：自动获取 buvid cookie + 正确的 Referer / Origin / User-Agent + `player_client=web`
- ⚡ **官方 API 直链下载**：pagelist + playurl API 拿直链，**561P 大合集 2 秒内定位分P**，不再被 yt-dlp 遍历播放列表卡死
- 🎵 **音频模式**：只提取音频（AAC/m4a），最快
- 🎬 **视频模式**：视频+音频合并，**自动转 H.264 保证不黑屏**（AV1 自动规避）
- ✂️ **片段截取**：`-ss/-t` 流复制，下载即截取不浪费带宽
- 🔑 **扫码登录**：解锁 **720P/1080P 高清**、充电/会员内容
- 📚 **多P支持**：指定分P下载（`P号` / `all` 全部），按歌名在合集中定位分P
- 🧩 **智能输入**：支持完整 URL、`b23.tv` 短链、纯 BV 号、`BVxxx?p=N`、UP 主 UID / 空间链接
- 🧠 **智能参数解析**：`[容器] [分辨率] [分P号] [截取区间]` 可省略，只传链接也能跑

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

其中最重要的是 **`buvid3` cookie**（脚本自动访问 bilibili.com 主页获取）和 **`player_client=web`**。缺了 `player_client=web` 或 buvid cookie，即使有 UA 和 Referer 也大概率 412。

**分P查询 / 格式查询 / 搜索** 同样内置完整反爬参数（登录 cookies 优先、buvid 兜底），裸调官方 API 也会被风控拦截。

---

## 📁 仓库结构

- **本仓库**（skill）：`SKILL.md` 交互流程 + `scripts/` 兜底脚本 + `references/` 文档
- **[bilibili-downloader-cli](https://github.com/menghuanshiguang/bilibili-downloader-cli)**（CLI 主仓库）：`bin/bilidown` 统一入口 + `lib/` 功能实现 + `install.sh` 安装

| scripts/ 文件 | 对应 CLI 命令 |
|------|------|
| `bilibili-dl.sh` | `bilidown dl` |
| `bilibili-login.sh` | `bilidown login` |
| `bilibili-search.sh` | `bilidown search` |
| `bilibili-formats.sh` | `bilidown formats` |
| `bilibili-parts.sh` | `bilidown parts` |
| `bilibili-findpart.sh` | `bilidown find` |
| `bilibili-preview.sh` | `bilidown preview` |

---

## ⚠️ 注意事项

1. **游客模式分辨率限制**：免费游客只能下载 **360P / 480P**。720P+ / 1080P 高清需登录态 cookie。
2. **版权声明**：请仅下载你有权访问的内容，不绕过会员付费墙、不破解会员专享。
3. **风控友好**：批量模式已内置随机间隔，仍请勿高频调用。
4. **短链 p 参数不可信**：b23.tv 短链分享参数 `p=N` 是分享时停留位置，不代表目标分P；合集找歌请用 `bilidown find`。
5. **Minis 播放链接**：minis:// 只认 `/var/minis/` 下目录，下载产物默认在 `~/B站音频下载/` 无法直接播放——给链接前先 `cp` 到 `/var/minis/shared/bilibili/`。

---

## 📄 许可证

MIT License
