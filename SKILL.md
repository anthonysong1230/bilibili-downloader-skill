---
name: bilibili-audio-dl
version: 3.5.9
description: 下载 B站(bilibili)视频的音频或视频到本地。基于 yt-dlp+官方API直链，内置 B站反爬(HTTP 412)规避方案 + 扫码登录高清解锁 + AV1自动规避(H.264优先) + 合集秒下(561P不再卡死)。【🚨最优先·必须先给预览】收到B站链接/BV号/短链后，**第一步必须输出在线预览直链**（格式 https://www.bilibili.com/blackboard/webplayer/mbplayer.html?bvid=BVxxx&p=N，单P p=1，多P p=N；完整URL带https://协议头，禁止省略；禁止用player.bilibili.com/player.html?page=N——302跳转后mbplayer只认p不认page加载错P），**不给预览直链直接进入询问/下载 = 违反硬性规则**。【强制流程·先问再下载】再调 bilibili-parts.sh 检测分P，**多P必须停下单独发一条消息询问「下载哪个P？(数字/全部/取消)」，等用户回复后才继续，禁止不询问直接下载，禁止与音频/视频问题合并发送**；【必须每次询问·禁止记忆推断】每次收到新视频都必须单独发一条消息询问「1.音频 2.视频+音频」，禁止根据历史记忆/上次选择推断，禁止与选P/画质问题合并发送；用户要视频时必须先调 bilibili-formats.sh 查实际格式（禁止裸调yt-dlp -F会412）再问画质，分辨率也必须每次询问、禁止记忆推断，只问真实存在档位，画质问题也单独发送等回复；收到关键词（如"去B站搜XXX"）先调 bilibili-search.sh 搜索，若被风控拦截则停下提示「要扫码登录后继续吗？1.登录 2.不登录」，用户选1则运行 bilibili-login.sh 登录后重新搜索，选2则请用户提供链接；搜索出多个结果时分步依次询问，严禁合并多个问题到一条消息。【短链p参数不可信】b23.tv短链解析出的p=N是分享停留位置不代表用户要的P，用户给歌名时用 bilibili-findpart.sh(pagelist API+grep)定位分P，勿用yt-dlp flat(标题全NA)。【强制格式】所有询问和输出必须简洁：询问只列短选项，输出只给「标题+类型+大小+链接」紧凑列表且必须附可点击预览链接，禁止贴日志/长解释/客套话，每屏最多1-2个emoji。【播放链接必须可访问】minis://只认/var/minis/下目录，下载产物默认在~/B站音频下载/无法直接播放——给链接前必须cp到/var/minis/shared/bilibili/并用标准minis://shared/...链接，禁止../跨路径拼接。触发词：B站下载、bilibili下载、下载B站、B站音频、下视频、下UP主、B站登录、高清下载、B站搜索。
user-invocable: true
---

# B站音视频下载

基于 yt-dlp 下载 B站音频/视频，绕过游客 412 反爬限制，支持扫码登录解锁高清画质。

## 🚨 硬性规则（违反即失败，LLM 必须照做）

### 规则1：先问再下载（流程）
收到链接/BV号/短链：
1. **先提供在线预览直链**（**必须完整 URL，带 `https://` 协议头和完整域名，禁止省略写成 `mbplayer.html?...` 之类的相对路径**——省略协议头无法点击；**这是第一步必做动作，不做预览直接进询问/下载 = 违反规则**）：
```
在线预览: https://www.bilibili.com/blackboard/webplayer/mbplayer.html?bvid=BVxxx&p=N
```
   - 单P `p=1`；多P `p=N` 对应分P（分P定位正确）
   - 🚫 禁止用 `player.bilibili.com/player.html?page=N`（跳转后 page 被忽略，加载错P）
2. **检测分P**：调 `bilibili-parts.sh` 看是否多P。**多P时必须停下询问下载哪个P（等用户回复后再继续，禁止直接下载/直接默认P1/跳过询问）**：
```
该视频共 N 个分P:
P1 [0:54] xxx
P2 [2:09] xxx
下载哪个P？(数字/全部/取消)
```
   - 用户给歌名时先用 `bilibili-findpart.sh` 定位到具体P，再问"是 P{定位结果} 吗？下载哪个P？"
   - 🚫 多P没问清就下载 = 违反硬性规则
   - 🚫 **此步必须单独一条消息发送，等用户回复后，才允许发送下一条（音频/视频）询问**——严禁把"选P"和"音频/视频"合并进同一条消息
3. **必须询问音频/视频**，格式固定为：
```
1. 音频
2. 视频+音频
```
   - 🚫 **禁止**根据历史记忆/上次选择/用户偏好推断用户要音频还是视频——**每次收到新视频都必须重新询问**，用户未明确说"音频/声音/视频/带画面"就一定要问

- 用户回 `1`/音频 → audio 模式
- 用户回 `2`/视频 → **先用 `bilibili-formats.sh` 查看该视频实际可用格式**（禁止裸调 `yt-dlp -F`，会触发 412），**再**问画质（只问真实存在的档位）：

```
该视频最高 480P，确认下载 480P 吗？
```
```
该视频最高 1080P，要 1080P 吗？（登录后可用）
```

- **必须询问分辨率**：即使之前下过 1080P、即使已登录，**每次都要问**；🚫 禁止根据历史记忆/上次选择推断分辨率，用户未明确说"1080/720/高清"就必须问
- **禁止**在没查看原视频参数的情况下凭空问"要 1080P 吗"——先查格式再问，最高只有 480P 就不许问 1080P。
- **查格式失败（412/风控）时：停下，告知用户"查询被风控，请先登录或稍后重试"，禁止跳过查询直接下载**；已登录则等 30s 后重试一次。

- 用户已明确说"音频/声音"或"视频/带画面" → **跳过询问直接下载**
- 用户说"all/都要" → 音频+视频都下

**⚠️ 一次只问一个问题**：搜索出现多个结果时，先问选哪个版本，**等用户选定后**再问音频/视频，**再**问画质——严禁把多个问题合并成一条消息发送（如"选哪个版本？另外要音频还是视频？"）。

### 规则2：输出必须简洁（格式）
下载完成后的回复**只允许**这种紧凑格式，禁止多余文字：

```
✅ 《标题》 | 时长 | 类型 | 大小
[音频](minis://...)
[视频](minis://...)
```

- **必须提供可点击的预览链接**（`minis://` 或文件路径 Markdown 链接），音频/视频各一行，否则视为未完成任务
- 禁止贴完整日志、脚本输出、ffmpeg 过程
- 出错回复格式：`⚠️ 原因一句话 + 解决方案一句话`
- 全程最多 1-2 个 emoji，不用客套话、不主动推荐额外操作

## 📁 输出路径与播放链接（v3.5.9·必须遵守）

**⚠️ 关键限制：`minis://` 协议只认 `/var/minis/` 下的目录（workspace/attachments/shared/mounts），访问不到 `/root/`、`/home/` 等系统目录。**

下载脚本默认输出到 `~/B站音频下载/`（即 `/root/B站音频下载/`）——**该路径 Minis 无法访问，直接给链接会播放失败**。

**给用户播放链接前必须执行：**

1. **复制文件到 `/var/minis/` 下的目录**（建议 `/var/minis/shared/bilibili/`）：
```bash
mkdir -p /var/minis/shared/bilibili/
cp "/root/B站音频下载/BVxxx/P121_小草.m4a" /var/minis/shared/bilibili/
```
2. **用标准 minis:// 链接**，禁止用 `../` 跨目录拼接：
```
[音频](minis://shared/bilibili/P121_小草.m4a)
```
3. 文件名含中文/空格时用 **percent-encoding**（或用工具返回的 minis_url 直接引用）

🚫 **禁止**：`minis://workspace/../root/B站音频下载/...` 这类路径拼接——必失效。

## 输入识别

| 输入类型 | 示例 | 可用模式 |
|---------|------|---------|
| 视频URL | `https://www.bilibili.com/video/BVxxx` | audio / video |
| 短链接 | `https://b23.tv/xxx` | audio / video |
| BV号 | `BV1GJ411x7h7` | audio / video |
| UP主空间 | `https://space.bilibili.com/123456` 或纯 UID | list |
| 搜索关键词 | `卓依婷 萍聚`、`Beyond 岁月无声`（用户说"去B站搜XXX下载"） | 先搜索 → 再 audio/video |

## 🔍 搜索（v3.2.1）

**当用户给的是关键词而非链接**（如"去B站搜《兰花草》下载"），用搜索脚本找 BV 号，再把结果列给用户选，按规则1询问。

```bash
bash <skill_dir>/scripts/bilibili-search.sh "<关键词>" [条数]
```

### 搜索登录流程（必须按此执行）

1. 先调 `bilibili-search.sh` 搜索（脚本自动用登录 cookies 或 buvid）。
2. **若被风控拦截**（返回"出错啦!"/非 JSON/空结果）→ **停下，向用户提示**：

```
⚠️ 未登录无法搜索（B站风控）。要扫码登录后继续吗？
1. 登录
2. 不登录（改用链接直接下载）
```

3. **用户选 1 登录** → 运行 `bilibili-login.sh` 扫码登录 → 登录成功后再重新搜索。
4. **用户选 2 不登录** → 不再搜索，请用户直接提供视频链接/BV号再下载。

⚠️ 游客 buvid 搜索**大概率被拦**，不要反复重试（会加重风控）。

### 搜索结果分步询问（必须按此执行）

搜索出多个结果时，**分三步依次询问，每步等用户回复后再问下一步**：

**第1步（选版本）**：只列结果，问选哪个：
```
找到这些，选哪个？
1. 【4K超清】兰花草 — BV1YE421w7rK
2. 兰花草-卓依婷 — BV1BW411i7vH
3. ...
```

**第2步（音频/视频）**：用户选定版本后，再问：
```
1. 音频
2. 视频+音频
```

**第3步（画质）**：用户选了视频后，**先用 `bilibili-formats.sh` 查看该视频实际格式**，再问（只问真实存在的档位）：
```
该视频最高 1080P，要 1080P 吗？（登录后可用）
```
```
该视频最高 480P，确认下载 480P 吗？
```

🚫 **禁止**将第1步和第2步合并成一条消息询问；**禁止**不查看实际格式就问"要 1080P 吗"；**查格式失败(412)时禁止跳过直接下载**，停下提示登录或稍后重试。

## 📋 格式查询（v3.3.2）

问画质前**必须**用此脚本查格式（内含完整反爬参数，裸 `yt-dlp -F` 会 412）：

```bash
bash <skill_dir>/scripts/bilibili-formats.sh "<URL|BV号>"
```

输出：视频格式列表（标 H.264/HEVC）+ 最高分辨率 + H.264 最高档。据此决定询问的档位。

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
bash <skill_dir>/scripts/bilibili-dl.sh "<URL|BV号>" <mode> [输出目录] [容器mp4|mkv] [分辨率480|720|1080] [分P号]
```

| 参数 | 说明 |
|------|------|
| `mode` | `audio` / `video` / `list` |
| `[输出目录]` | 可选，默认 `~/B站音频下载/` |
| `[容器]` | 仅 video，`mp4`(默认) / `mkv` |
| `[分辨率]` | 默认 `480`；`720`/`1080` 需登录 |
| `[分P号]` | 多P视频指定P号（如 `2` 下第2P）；`all` 下全部分P；空=第1P |

```bash
# 游客音频
bash .../bilibili-dl.sh "BV1GJ411x7h7" audio
# 游客视频 mp4
bash .../bilibili-dl.sh "BVxxx" video
# 登录后 1080P 高清
bash .../bilibili-dl.sh "BVxxx" video ~/Downloads mp4 1080
# 批量下载UP主 720P
bash .../bilibili-dl.sh "https://space.bilibili.com/123456/video" list 480 720
# 多P视频下载第2P
bash .../bilibili-dl.sh "BV1GV4y1W7vh" video ~/Downloads mp4 1080 2
# 多P视频下载全部P
bash .../bilibili-dl.sh "BV1GV4y1W7vh" video ~/Downloads mp4 1080 all
```

## 📺 在线预览（v3.5.4）

下载前**必须**先给用户在线预览**直链**（B站移动端嵌入式播放器 mbplayer，点开直接播放视频，不跳转B站页面）。**必须是完整 URL**——带 `https://` 协议头 + 完整域名 `www.bilibili.com/blackboard/webplayer/mbplayer.html`，**禁止省略协议头/域名**（如 `mbplayer.html?bvid=...` 这种相对路径无法点击打开）：

```
在线预览: https://www.bilibili.com/blackboard/webplayer/mbplayer.html?bvid=BVxxx&p=N
```

- 单P视频：`p=1`
- 多P视频：`p=N` 对应第N个分P，**分P定位正确**（实测 P353 → 加载对应 cid=331867867《谢谢你的爱》）
- 🚫 **禁止**用 `player.bilibili.com/player.html?bvid=...&page=N`——它 302 跳转 mbplayer 后保留 `page` 参数，而 **mbplayer 只认 `p` 不认 `page`**，page 被忽略导致加载错P（实测加载成 P1）
- 若用户预览后想换视频，重新搜索或让用户给新链接。

## 📑 分P查询（v3.4.0）

检测/列出多P视频用：

```bash
bash <skill_dir>/scripts/bilibili-parts.sh "<URL|BV号>"
```

输出：`分P数: N` + 每P的 `P号 [时长] 标题 (ID)`。单P显示"单P视频(无分P)"。

## 🔎 按歌名找合集分P（v3.5.1）

**当用户给的短链自带 `p=N` 参数（如 b23.tv 分享链接解析出 p=139）时，该参数是分享时停留位置，不代表用户要的内容**——用户说歌名就以歌名为准，用此脚本在合集中定位：

```bash
bash <skill_dir>/scripts/bilibili-findpart.sh "<URL|BV号>" "<关键词>"
```

原理：调官方 API `api.bilibili.com/x/player/pagelist` 一次性拉全部分P标题，再 grep 关键词定位。

⚠️ **已知坑（不要踩）**：
- yt-dlp `--flat-playlist` 打印分P标题全是 `NA`，**不能用**
- 嵌入播放器 `player.html?page=N` 分P定位有 bug（会跳转 mbplayer 显示总时长），**不能用来验证分P**
- ✅ 可靠路径：**findpart 脚本定位 P号 → 下载时带 `?p=N` 或第6参数 `N`**

### 合集定位示例
```bash
# 用户: "下载《小草》，链接是b23.tv分享的"
bash .../bilibili-findpart.sh "https://b23.tv/iEGonVr" "小草"
# → P121: 小草
bash .../bilibili-dl.sh "BV16v411L7js" video ~/Downloads mp4 1080 121
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
