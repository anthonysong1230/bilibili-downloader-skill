---
name: bilibili-audio-dl
version: 1.0.0
description: 下载 B站(bilibili)视频的音频或视频到本地。基于 yt-dlp，内置 B站反爬(HTTP 412)规避方案——自动获取 buvid cookie、设置正确的 Referer/Origin/User-Agent、使用 player_client=web 提取器。当用户提供 B站视频链接(bilibili.com、b23.tv、BV号)、要求下载B站音频/视频、提取B站声音、或批量下载某个UP主的全部音频时使用。触发词：B站下载、bilibili下载、下载B站、B站音频、下视频、下UP主。
user-invocable: true
---

# B站音视频下载

基于 yt-dlp 下载 B站音频/视频，绕过游客模式 412 反爬限制。

## 输入识别

| 输入类型 | 示例 | 模式 |
|---------|------|------|
| 视频URL | `https://www.bilibili.com/video/BVxxx` | audio |
| 短链接 | `https://b23.tv/xxx` | audio |
| BV号 | `BV1GJ411x7h7` | audio |
| UP主空间 | `https://space.bilibili.com/123456` 或纯 UID | list |

## 可用模式

| 模式 | 说明 |
|------|------|
| `audio`（默认） | 只下载音频流（m4a），标清可用 |
| `video` | 下载视频+音频并合并（游客 max 480p） |
| `list` | 批量下载整个 UP 主空间的所有视频音频 |

## 调用方式

```bash
bash <skill_dir>/scripts/bilibili-dl.sh "<URL|BV号>" <mode> [输出目录]
```

示例：
```bash
# 下载单个视频的音频
bash .../scripts/bilibili-dl.sh "BV1GJ411x7h7" audio
# 下载视频(标清)
bash .../scripts/bilibili-dl.sh "https://www.bilibili.com/video/BVxxx" video
# 批量下载UP主全部音频
bash .../scripts/bilibili-dl.sh "https://space.bilibili.com/123456/video" list
```

脚本自动处理：buvid cookie 获取、请求头、player_client、b23.tv 短链解析、BV号转 URL。

## 下载后

- 默认保存到 `~/B站音频下载/`（可自定义第3参输出目录）
- 音频是 `.m4a` 格式（高质量 AAC）
- 如需转 mp3 或改变命名，见 `references/后处理.md`

## ⚠️ 重要限制

1. **游客模式**：只能下载 **360P/480P**（默认 audio 模式不受影响，音质无损）。720P+ 需登录态 cookie。
2. **不绕过版权**：仅下载用户有权访问、非会员专享的内容。
3. **B站风控**：批量下载必须用 `list` 模式（含 3-6 秒随机间隔），勿高频请求。
