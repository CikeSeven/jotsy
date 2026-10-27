<div align="center">

<img src="assets/app_icon/mingcute_icon.png" width="96" alt="Jotsy 图标"/>

# Jotsy

**一本只属于你的本地日记**

免费 · 开源 · 无广告 · 无需注册 · 数据只存在你自己的设备里

[![Release](https://img.shields.io/github/v/release/CikeSeven/jotsy?style=flat-square&color=1E6586&label=Release)](https://github.com/CikeSeven/jotsy/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/CikeSeven/jotsy/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/CikeSeven/jotsy/actions/workflows/ci.yml)
[![Downloads](https://img.shields.io/github/downloads/CikeSeven/jotsy/total?style=flat-square&color=4F7FAF&label=Downloads)](https://github.com/CikeSeven/jotsy/releases)
[![Android](https://img.shields.io/badge/Android-7.0%2B-3DDC84?style=flat-square&logo=android&logoColor=white)](#-下载安装)
[![Windows](https://img.shields.io/badge/Windows-10%2B%20x64-0078D4?style=flat-square)](#windows)
[![Linux](https://img.shields.io/badge/Linux-x64%20%C2%B7%20GTK%203-E95420?style=flat-square&logo=linux&logoColor=white)](#linux)
[![License](https://img.shields.io/github/license/CikeSeven/jotsy?style=flat-square&color=7E6BB0)](LICENSE)

简体中文 | [English](docs/README.en.md)

</div>

<p align="center">
  <img src="assets/img/screenshots/zh/banner.webp" alt="Jotsy 预览：日记详情、日记列表与日历"/>
</p>

Jotsy 想做一个纯粹的记录工具：打开就能写，不用登录，没有广告。心情、灵感、一日三餐、出门旅行，连同照片、视频和录音，都安安静静地留在你自己的手机里。

## ✨ 为什么选择 Jotsy

| | |
| :-- | :-- |
| 🔒 **私密** | 数据全部存在本机，没有账号和服务器；支持应用锁，备份可加密 |
| ✍️ **好写** | 富文本编辑，图片、视频、附件、录音随手插入；补写旧日记时还能找到那天拍的照片 |
| 🌤️ **有温度** | 每篇日记都能记下心情、精力、天气和地点 |
| 📅 **好回顾** | 农历与节假日日历、纪念日与倒数日、年度热力图、那年今日、时间胶囊 |
| 📦 **不锁定** | ZIP 备份、网盘备份（WebDAV / 对象存储 / 主流网盘），导出 PDF / Word / Markdown / 网页 / TXT / CSV；支持从 18 款应用导入 |
| 🎨 **随你定** | Material 3 Expressive 设计，80 种主题色；日记卡片、阅读页和正文字体都能自定义 |

## 📱 功能一览

<table>
  <tr>
    <td align="center"><img src="assets/img/screenshots/zh/editor.webp" width="180" alt="富文本编辑"/><br/><sub>富文本编辑</sub></td>
    <td align="center"><img src="assets/img/screenshots/zh/waterfall.webp" width="180" alt="瀑布流视图"/><br/><sub>瀑布流视图</sub></td>
    <td align="center"><img src="assets/img/screenshots/zh/dark.webp" width="180" alt="暗色主题"/><br/><sub>暗色主题</sub></td>
    <td align="center"><img src="assets/img/screenshots/zh/calendar_photo.webp" width="180" alt="照片日历"/><br/><sub>农历与照片日历</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/img/screenshots/zh/year.webp" width="180" alt="年视图"/><br/><sub>年度热力图</sub></td>
    <td align="center"><img src="assets/img/screenshots/zh/explore.webp" width="180" alt="探索页"/><br/><sub>统计与那年今日</sub></td>
    <td align="center"><img src="assets/img/screenshots/zh/gallery.webp" width="180" alt="媒体画廊"/><br/><sub>媒体画廊</sub></td>
    <td align="center"><img src="assets/img/screenshots/zh/capsule.webp" width="180" alt="时间胶囊"/><br/><sub>时间胶囊</sub></td>
  </tr>
</table>

### ✍️ 写作：富文本、多媒体与"此时此地"

- **23 种编辑工具**：标题、加粗 / 斜体 / 下划线 / 删除线、文字颜色与背景色、有序 / 无序 / 待办清单、引用、代码块、链接、插入当前时间……工具栏的顺序和显隐都能自定义。
- **多媒体**：一次插入多张图片或多段视频，添加任意类型的附件；录音支持暂停与继续，回放时可以拖动波形。长截图这类长图在正文里自动折叠，点开后按屏幕宽度上下滚动阅读。
- **此时此地**：自动定位并获取天气，也可以手动填写；地址精度可选城市、区县、街道或门牌号。
- **心情与精力**：10 个心情 Emoji（可在设置里替换）和 5 档精力值，发表时间也可以随时修改。
- **补写有照片**：给过去某天补写日记时，编辑页会列出那天拍的照片，勾选几张就能插入正文，或者直接设为封面。只有你点"允许访问"后才会读取相册，原图不会被改动。
- **不怕丢稿**：新建时自动保存草稿，编辑已有日记时自动保存。
- **日记模板**：8 个内置模板（每日记录、晨间日记、晚间复盘、感恩日记、每日一问、周回顾、情绪梳理、读书笔记），也能自己做或把一篇日记存为模板。新建空白日记时标题下会按时段推荐模板，点一下就套用，也能按时间段自动套用；`{{日期}}`、`{{农历}}`、`{{今日一问}}` 等变量按日记的日期自动填好，还能顺带设好标签、心情和时间胶囊。模板可以生成模板码分享。

### 🗂️ 浏览与阅读

- 列表、瀑布流两种布局，可按更新时间、发表时间或标题排序。
- 按标签筛选（可以记住上次的筛选），搜索标题和正文时也能叠加标签条件。
- **日记本**：把日记收进不同的本子，一篇可以同时放进几本，移出也不会删除日记；在首页标签栏最前面就能切换。本子里可以分章节、按目录手动排列，设写作目标、看统计，还能整本导出成带扉页和目录的 PDF、Word、网页、Markdown 或纯文本。智能日记本按标签、心情、日期等条件自动收录；也可以让一本不在全部日记里显示，或者上锁，打开时验证身份。
- 置顶、归档（左滑即可）、多选批量操作；删除的日记进入回收站，并且可以立即撤销。
- 在日记详情页左右滑动，按进入时所在列表的顺序切换上一篇、下一篇。
- 字数统一计算：每个汉字算 1 字，英文和数字按单词计，在详情页点字数，还能看到段落、图片数量和预计阅读时间。

### 🎨 外观随你定

- **日记卡片**：8 种内置风格（经典、紧凑、杂志、极简、画廊、便签、手账、心情色），布局、封面、日期、字体、色彩、质感都能逐项细调。
- **日记详情页**：8 种预设（经典、纸书、杂志、极简、夜读、手账、心情色、沉浸），头图、标题、信息栏和正文分别可调。
- **我的样式**：卡片和详情页各能保存 12 份自己的样式，也可以复制成样式码分享给别人，或者导入别人的样式码。
- **正文字体与排版**：内置 HarmonyOS Sans，也可以跟随系统字体或导入 TTF / OTF / TTC 字体；字号、行距、字间距、段间距都能调整，编辑、阅读和发布页统一生效。
- **主题**：10 个色系共 80 种主题色，明暗主题，可调界面字号，支持中文和 English。
- **功能管理**：日历、探索两个页面，以及日记本、纪念日、日记模板、时间胶囊都可以在设置里关掉，只留下你要用的；关掉的功能不会再出现在任何地方，数据也不会丢，重新打开就回来了。

### 📅 日历：农历、节假日与纪念日

- 月视图和周视图都能显示农历、节气与节日，日历下方汇总本月的篇数、记录天数、字数、最常见心情和最长连续记录。
- **法定节假日**：标出放假的"休"和调休上班的"班"。
- **纪念日与倒数日**：可以按公历或农历每年重复，也可以只记一天。日历上会标出这些日子，并显示第几周年、还有几天；纪念日可以关联一篇日记，还会汇总历年这一天写下的日记。
- 日期格有 5 种样式：圆点、心情、热力、照片、标签；还可以按心情或标签筛选。
- 先选起点、再点终点，就能看这段日期的统计；年视图可以按心情、篇数或字数生成全年热力图，并分享为图片。
- 长按某一天可以补写日记、给未来写一颗时间胶囊，或者添加纪念日。

### 🧭 探索与回忆

- 总记录数、连续打卡天数、本月字数一目了然。
- **那年今日**：自动翻出往年同一天写下的日记。
- **趋势与标签云**：近 30 天的心情、近 7 天的精力，以及最常用的标签。
- **媒体画廊**：所有封面和正文里的图片汇集在一起，可以放大浏览、保存或分享。
- **时间胶囊**：写给未来的日记会一直封存，到了解封日期才能打开。

### 🔐 数据与隐私

- **应用锁**：用系统的生物识别或设备密码解锁。
- **完整备份**：导出为一个 ZIP，包含日记、标签、纪念日、设置和全部图片、录音、视频与附件；可以设密码，使用 AES-256 加密。
- **两种导入方式**：恢复时可以选择"合并"或"覆盖"，覆盖本机数据前会有醒目的二次确认。
- **网盘备份**：备份到 WebDAV（坚果云、NAS、Alist 等）、S3 兼容对象存储（阿里云 OSS、腾讯云 COS、R2 等）或 Google Drive / OneDrive / Dropbox / 百度网盘 / 阿里云盘，也能从远端直接恢复，详见 [docs/cloud_backup.md](docs/cloud_backup.md)。
- **导出**：单篇、多选或按日期与标签批量导出为 PDF、Word、Markdown（带 front matter，可导入 Obsidian）、网页、纯文本、CSV，或者生成可以在另一台设备上合并导入的日记文件。
- **分享**：生成长图，或一键分享到微博、小红书、微信、朋友圈、QQ、QQ 空间。正文会自动复制，日记里的图片也一起带上。

## 🔁 从其他应用搬家

先在原应用里导出数据，再到 Jotsy 的 **设置 › 数据与隐私 › 数据管理 › 从其他日记应用导入** 中选择文件。导入前会先预检内容，同样可以选择合并或覆盖。

| 类型 | 支持的应用 |
| :-- | :-- |
| 日记应用 | Day One · Journey · Diarium · Daylio · Apple 手记 · Diaro |
| 笔记应用 | 印象笔记 / Evernote · Google Keep · Joplin · Memos · Markdown / 纯文本（Obsidian、Bear、Notion 导出等） |
| 云端笔记 | 小米笔记 · 华为备忘录 · OPPO 笔记 · vivo 笔记 · 荣耀笔记 · 魅族笔记 · WPS 便签 |

> 云端笔记需要在应用内打开对应厂商的官方网页登录，Jotsy 只读取笔记内容。登录 Cookie 只存在于本次导入的内存中，导入结束就会清除，不会写入存储，也不会用于其他请求。

## 📥 下载安装

| 平台 | 系统要求 | 安装包 |
| :-- | :-- | :-- |
| Android | Android 7.0 及以上 | `jotsy-<版本>-<架构>.apk` |
| Windows | Windows 10 及以上，x64 | 安装程序 `jotsy-<版本>-windows-x64-setup.exe`，或便携版 `jotsy-<版本>-windows-x64.zip` |
| Linux | x64，GTK 3 | `jotsy-<版本>-linux-x64.tar.gz` |

所有安装包都在 [Releases 页面](https://github.com/CikeSeven/jotsy/releases/latest)，同一页的 `SHA256SUMS.txt` 可用来核对文件是否完整。国内网络下也可以在[官网](https://cikeseven.github.io/jotsy/)经镜像线路下载。

### Android

1. 根据设备下载对应的安装包：
   - `arm64-v8a`：绝大多数手机都选这个，不确定时也选它
   - `armeabi-v7a`：较老的 32 位设备
   - `x86_64`：模拟器
2. 安装后即可使用。

之后有新版本时，Jotsy 会在应用里提示，可以直接下载并安装，不用再回到网页。下载会同时尝试多条国内镜像线路并自动选最快的一条，断线后从断点继续；安装前会核对文件校验值和应用签名。也可以在 **设置 › 关于 › 检查最新版本** 中手动检查，或者在那里关闭自动检查。

### Windows

- **安装程序**（推荐）：运行 `…-setup.exe`，可以为所有用户安装（需要管理员权限），也可以只为自己安装；会创建开始菜单快捷方式，桌面快捷方式可选。卸载在系统的“已安装的应用”里进行。
- **便携版**：把 `.zip` 解压到任意文件夹，运行其中的 `jotsy.exe`。

安装程序与 `jotsy.exe` 暂未做代码签名，首次运行时 SmartScreen 可能提示“未知发布者”，点 **更多信息 › 仍要运行** 即可；介意的话可以先用 `SHA256SUMS.txt` 核对文件。

### Linux

```bash
tar -xzf jotsy-<版本>-linux-x64.tar.gz
cd jotsy
./install.sh              # 装到 ~/.local，无需 root；不安装的话 ./jotsy 也能直接运行
./install.sh --uninstall  # 卸载
```

`install.sh` 把应用放到 `~/.local/share/jotsy`，并把图标和启动入口加进应用菜单；想装给所有用户可以用 `sudo PREFIX=/usr/local ./install.sh`。运行需要 GTK 3；播放录音需要 GStreamer 及常见插件（如 `gstreamer1.0-plugins-good`、`gstreamer1.0-libav`）。

### 桌面版说明

Windows 与 Linux 版重复启动会唤起已有窗口，并保留当前编辑内容。关闭窗口时会先保存日记、草稿和发布面板的改动，以及阅读时的待办勾选；保存失败会提示并保留窗口，方便重试。阅读时选中文字可按 Ctrl+C 复制、Ctrl+A 全选。

Windows 与 Linux 上有新版本时 Jotsy 同样会提示，点 **前往下载** 会在浏览器里经镜像线路下载新的安装包（Windows 为安装程序，Linux 为压缩包），按上面的方式覆盖安装即可，日记数据会保留。卸载或更新都不会删除日记。

以下功能目前只在手机上提供：分享到指定应用（微信、QQ 等）、导入手机厂商与 WPS 的云端笔记（需要应用内网页登录）、补写日记时的“这天拍的照片”、自动获取地点与天气（可以手动填写）。另外，Windows 与 Linux 上正文里的视频不在页内播放，点按后用系统播放器打开；Linux 版暂不支持录音（可以播放）和应用锁 / 上锁日记本。

## 🛡️ 隐私说明

Jotsy 没有账号体系，也没有自己的服务器。日记保存在应用私有目录下的 SQLite 数据库里，图片、录音、视频和附件也放在同一目录，设置保存在本机。

只有下面这些情况会联网：

| 场景 | 访问对象 | 发送内容 |
| :-- | :-- | :-- |
| 自动获取地点和天气 | 高德地图、和风天气 | 当前坐标（不想用的话可以手动填写） |
| 网盘备份 / 恢复 | 你自己填写的服务器或授权的网盘 | 备份文件 |
| 检查与下载更新 | GitHub Releases 及其镜像 | 不含任何日记数据 |
| 导入云端笔记 | 对应厂商的官方网站 | 你在官网完成的登录 |

检查更新默认在打开或回到应用时自动进行，每 2 小时最多一次，可以在 **设置 › 关于 › 检查最新版本** 中关闭；其他几项只在你使用对应功能时才会联网。

用到的权限：网络、麦克风（录音）、位置（可选，用于自动定位）、相册图片（可选，用于补写时列出那天拍的照片）、安装应用（用于应用内更新）。完整说明见[隐私政策](https://cikeseven.github.io/jotsy/privacy.html)。

## ❓ 常见问题

<details>
<summary><b>换手机了，日记怎么迁移？</b></summary>

在旧手机的 **数据管理 › 导出数据** 中生成备份 ZIP，传到新手机后用 **导入数据** 恢复即可；也可以用网盘备份在两台设备之间中转。

</details>

<details>
<summary><b>为什么获取不到天气和定位？</b></summary>

请确认已经授予位置权限，并且网络正常。即使获取不到，也可以手动填写地点和天气。

</details>

<details>
<summary><b>卸载应用会丢数据吗？</b></summary>

会。数据只存在本机，卸载或清除应用数据都会把它删掉。建议定期导出备份，或者使用网盘备份。

</details>

<details>
<summary><b>有 iOS 版吗？</b></summary>

暂时没有，目前发布 Android、Windows 与 Linux 版本。

</details>

## 💬 反馈与交流

- 遇到 Bug 或想提建议，欢迎提交 [Issue](https://github.com/CikeSeven/jotsy/issues)
- QQ 交流群：678136434

## ☕ 支持开发者

Jotsy 免费开源，没有广告。如果它对你有帮助，欢迎扫码打赏支持开发者；打赏完全自愿，不会解锁任何功能。给项目点个 Star 也是很大的鼓励。

<table>
  <tr>
    <td align="center"><img src="assets/img/support/wechat.png" width="200" alt="微信赞赏码"/><br/><sub>微信扫一扫</sub></td>
    <td align="center"><img src="assets/img/support/alipay.png" width="200" alt="支付宝收款码"/><br/><sub>支付宝扫一扫</sub></td>
  </tr>
</table>

### 💝 感谢打赏

感谢以下朋友的支持：

ParadiseGrass · 氢妹Ti · MR.CHEN · 白禹和Kamiko Kristo · Hongda · AXID · \*\*民 · 泽墨 · 霖

## 📄 开源许可

Jotsy 以 [GPL-3.0](LICENSE) 协议开源。

<sub>截图中的日记、照片和地点均为演示数据。</sub>
