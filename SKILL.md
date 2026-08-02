---
name: bilibili-audio-dl
version: 2.0.0
description: 下载 B站(bilibili)视频的音频或视频到本地。基于 yt-dlp，内置 B站反爬(HTTP 412)规避方案——自动获取 buvid cookie、设置正确的 Referer/Origin/User-Agent、使用 player_client=web 提取器。当用户提供 B站视频链接(bilibili.com、b23.tv、BV号)、要求下载B站音频/视频、提取B站声音、或批量下载某个UP主的全部内容时使用。触发词：B站下载、bilibili下载、下载B站、B站音频、下视频、下UP主。
user-invocable: true
---

# B站音视频下载

基于 yt-dlp 下载 B站音频/视频，绕过游客模式 412 反爬限制。

## 输入识别

| 输入类型 | 示例 | 可用模式 |
|---------|------|---------|
| 视频URL | `https://www.bilibili.com/video/BVxxx` | audio / video |
| 短链接 | `https://b23.tv/xxx` | audio / video |
| BV号 | `BV1GJ411x7h7` | audio / video |
| UP主空间 | `https://space.bilibili.com/123456` 或纯 UID | list |

## 🎯 交互流程（重要：先问再下载）

**当用户发送一个视频链接时，先确认下载内容，不要直接默认下载：**

> 好的，我来下载这个视频。请问你要：
> **1. 只要音频**（提取声音，文件小）
> **2. 视频+音频**（含画面，游客可达 480P）

用户选择后再调用脚本。

- 选音频 → `audio` 模式
- 选视频 → `video` 模式

**例外**：用户已明确说"下载音频/下载这个视频的声音/提取音频"，则可直接执行 audio；明确说"下载视频/带画面/合并"，则直接执行 video。

## 可用模式

| 模式 | 说明 |
|------|------|
| `audio`（默认） | 只下载音频流（m4a），标清可用 |
| `video` | 下载视频流+音频流，用 ffmpeg 手动合并（游客 max 480p）|
| `list` | 批量下载整个 UP 主空间的所有视频音频 |

## 调用方式

```bash
bash <skill_dir>/scripts/bilibili-dl.sh "<URL|BV号>" <mode> [输出目录] [容器mp4|mkv]
```

参数：
- `mode`: `audio` | `video` | `list`
- `[输出目录]`: 可选，默认 `~/B站音频下载/`
- `[容器]`: 仅 video 模式有效，`mp4`(默认，H.264通用) | `mkv`(AV1/HEVC)

示例：
```bash
# 只要音频
bash .../scripts/bilibili-dl.sh "BV1GJ411x7h7" audio
# 视频+音频合并成 mp4
bash .../scripts/bilibili-dl.sh "https://www.bilibili.com/video/BVxxx" video
# 视频+音频合并成 mkv（保留源编码）
bash .../scripts/bilibili-dl.sh "BVxxx" video ~/Downloads mkv
# 批量下载UP主空间音频
bash .../scripts/bilibili-dl.sh "https://space.bilibili.com/123456/video" list
```

脚本自动处理：buvid cookie、请求头、b23.tv 短链解析、BV号转 URL。

## 下载后

- 默认保存到 `~/B站音频下载/`（可自定义第4参输出目录）
- audio 得到 `.m4a`（高保真 AAC）
- video 得到 `.mp4`（含画面）或 `.mkv`
- 如需转 mp3 或改命名，见 `references/后处理.md`

## ⚠️ 重要限制

1. **游客模式**：视频只能 **360P/480P**；720P+ 需登录态 cookie。
2. **不绕过版权**：仅下载用户有权访问、非会员专享的内容。
3. **B站风控**：批量下载必须用 `list` 模式（含 3-6 秒随机间隔），勿高频请求。
4. **video 合并**：脚本分两次下分流再手动 ffmpeg 合并，规避 iSH 环境 yt-dlp 自动合并 bug。
