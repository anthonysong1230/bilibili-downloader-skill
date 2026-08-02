---
name: bilibili-audio-dl
version: 3.2.0
description: 下载 B站(bilibili)视频的音频或视频到本地。基于 yt-dlp，内置 B站反爬(HTTP 412)规避方案 + 扫码登录高清解锁 + AV1自动规避(H.264优先)。【强制流程】收到B站链接必须先用「1. 音频 2. 视频+音频」询问用户要什么，用户未明确时禁止直接下载；用户要视频且可能高清内容时再问「要 480P 还是 720P/1080P？」。【强制格式】所有询问和输出必须简洁：询问只列短选项，输出只给「标题+类型+大小+链接」紧凑列表，禁止贴日志/长解释/客套话，每屏最多1-2个emoji。触发词：B站下载、bilibili下载、下载B站、B站音频、下视频、下UP主、B站登录、高清下载。
user-invocable: true
---

# B站音视频下载

基于 yt-dlp 下载 B站音频/视频，绕过游客 412 反爬限制，支持扫码登录解锁高清画质。

## 🚨 硬性规则（违反即失败，LLM 必须照做）

### 规则1：先问再下载（流程）
收到链接/BV号/短链，**必须先询问**，格式固定为：

```
1. 音频
2. 视频+音频
```

- 用户回 `1`/音频 → audio 模式
- 用户回 `2`/视频 → 检查登录态，再问画质：

```
游客只能 480P，要 720P/1080P 高清吗？
```

- 用户已明确说"音频/声音"或"视频/带画面" → **跳过询问直接下载**
- 用户说"all/都要" → 音频+视频都下

### 规则2：输出必须简洁（格式）
下载完成后的回复**只允许**这种紧凑格式，禁止多余文字：

```
✅ 《标题》 | 时长 | 类型 | 大小
[音频](minis://...)
[视频](minis://...)
```

- 禁止贴完整日志、脚本输出、ffmpeg 过程
- 出错回复格式：`⚠️ 原因一句话 + 解决方案一句话`
- 全程最多 1-2 个 emoji，不用客套话、不主动推荐额外操作

## 输入识别

| 输入类型 | 示例 | 可用模式 |
|---------|------|---------|
| 视频URL | `https://www.bilibili.com/video/BVxxx` | audio / video |
| 短链接 | `https://b23.tv/xxx` | audio / video |
| BV号 | `BV1GJ411x7h7` | audio / video |
| UP主空间 | `https://space.bilibili.com/123456` 或纯 UID | list |

## 🔑 登录（解锁高清/充电视频）

### 何时需要
- 下载 720P/1080P 高清
- 下载充电专属、会员专享内容

### 扫码登录
```bash
bash <skill_dir>/scripts/bilibili-login.sh
```
流程：
1. 脚本调 B站 API 生成登录二维码
2. 生成 HTML 页面 `~/bilibili-login-qr.html`
3. 用户用 **B站 App** 扫码确认
4. 成功后 cookies 保存到 `~/.cache/bilibili-login-cookies.txt`

**验证登录**：可通过 `get_me` 或下载一个高清视频测试。

### 高清可用的提示
- 脚本自动检测登录 cookies，存在即用高清格式
- 充电/会员内容**仅在有权限时**可下载（不绕过付费墙）
- 登录 cookies 有效期约 1 个月，过期需重新登录

## 可用模式

| 模式 | 说明 |
|------|------|
| `audio`（默认） | 只下载音频流（m4a） |
| `video` | 下载视频流+音频流，ffmpeg 合并 |
| `list` | 批量下载 UP 主空间视频音频 |

## 调用方式

```bash
bash <skill_dir>/scripts/bilibili-dl.sh "<URL|BV号>" <mode> [输出目录] [容器mp4|mkv] [分辨率480|720|1080]
```

| 参数 | 说明 |
|------|------|
| `mode` | `audio` / `video` / `list` |
| `[输出目录]` | 可选，默认 `~/B站音频下载/` |
| `[容器]` | 仅 video，`mp4`(默认) / `mkv` |
| `[分辨率]` | 默认 `480`；`720`/`1080` 需登录 |

```bash
# 游客音频
bash .../bilibili-dl.sh "BV1GJ411x7h7" audio
# 游客视频 mp4
bash .../bilibili-dl.sh "BVxxx" video
# 登录后 1080P 高清
bash .../bilibili-dl.sh "BVxxx" video ~/Downloads mp4 1080
# 批量下载UP主 720P
bash .../bilibili-dl.sh "https://space.bilibili.com/123456/video" list 480 720
```

脚本自动处理：cookies 选择（登录优先）、buvid、请求头、短链解析。

## ⚠️ 重要限制

1. **游客模式视频仅 360P/480P**；720P+ 需扫码登录。
2. **不绕过版权/付费墙**：仅下载用户有权访问、已是会员/已充电的内容。
3. **B站风控**：批量勿高频，用 `list` 模式（3-6s 间隔）。
4. **HEVC/AV1 黑屏**：video 模式优先选 H.264(avc1) 流；若只剩 HEVC/AV1，自动转码 H.264（libx264 或 h264_videotoolbox）；转码失败（如 iSH 精简 ffmpeg 不支持 AV1 解码）会自动重下 avc 流免转码合并，保证 iOS 可直接播放。

## 🔧 AV1 规避机制（v3.1.0）

iSH 精简版 ffmpeg **无法解码 AV1**（报 `Decode error rate exceeds maximum`），HEVC 也仅靠 videotoolbox 硬解。因此：

- **下载阶段**：格式表达式 `bv*[height<=N][vcodec~='^avc']/bv*[height<=N]` 优先匹配 H.264 流，只有全部格式都是 HEVC/AV1 时才回落
- **合并阶段**：检测到非 h264 编码时先尝试 libx264/h264_videotoolbox 转码；失败则自动用 `-f "bv*[vcodec~='^avc']..."` 重下 H.264 流直接 copy 合并
- 手动验证命令：`yt-dlp -F <URL>` 看 `avc1.*` vs `av01.*` 后缀即可判断该视频有无 H.264 源

minis_url: minis://skills/bilibili-audio-dl/SKILL.md
