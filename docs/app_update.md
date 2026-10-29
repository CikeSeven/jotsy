# 应用内更新

设置 → 关于 → **检查更新**（软件更新页）。Android 上从 GitHub Release 检查新版本、下载适合本机处理器架构的安装包、校验后交给系统安装器；不需要跳转浏览器。Windows / Linux 用同一套检查，发现新版本后在浏览器里下载本平台的安装包（见[桌面](#桌面)）。其他平台只提供打开 Release 页面。

用户大多在国内网络下使用：`api.github.com` 常连不上或按出口 IP 限流（运营商 NAT 后很多人共用一个 IP，每小时 60 次很快用完），`github.com` 的附件下载常被限到几 KB/s。整个流程因此以镜像为主、直连为辅。

## 检查

`AppUpdateChecker` 分两段，每段内所有线路**同时**发请求、取最先成功的一条，结束时关闭其余连接：

1. **清单**：`https://github.com/CikeSeven/jotsy/releases/latest/download/jotsy-update.json`（套各镜像前缀）。一个几 KB 的请求就拿到版本号（含构建号）、各 ABI 安装包与桌面安装包的大小与 SHA-256、中英文更新说明。两条以上线路（或直连）回 404 即判定该版本没有清单，不等其余线路超时。
2. **回退**（没有清单的旧版本，或所有镜像都不可用）：同时请求
   - GitHub 接口 `releases/latest`（直连；附件带 `digest` 校验值）；
   - 各线路的 `releases/latest` 跳转页：从 Location 取 tag，再经同一线路读取 `releases/download/<tag>/SHA256SUMS.txt` 得到安装包列表与校验值。

   两边都以校验文件为安装包已就绪的标志：Release 发布后 `releases/latest` 立刻指向新 tag，签名构建却要数十分钟才上传安装包。这期间接口里没有 `SHA256SUMS.txt`、跳转页的校验文件回 404，**按没有新版本处理**（显示“已是最新”，不报检查失败），等安装包能下载了才提示新版本。两条以上回答（或全部结束时有一条）如此才这样判定，单条镜像的 404 不足为凭。

   没有清单时，更新说明按界面语言读取仓库里的 `docs/releases/<tag>.md` / `<tag>.en.md`。

版本比较按语义化版本，正式版高于预发布；只有两边都带构建号才比较构建号（tag 常省略构建号）。

## 下载与安装

`AppUpdateDownloader`：

- **测速**：所有线路同时取前 192 KB，按实测速度排序并去掉不通的线路（用户指定了线路时不测速）。
- **续传**：写入 `cacheDir/app_update/<版本>-<ABI>.apk.part`；断线、换线路都用 Range 从已下载处继续，服务器不支持 Range 才从头写。取消下载保留 `.part`。
- **失速切换**：20 秒收不到数据，或连续 15 秒平均低于 24 KB/s（且还有别的可用线路）时，续传到下一条线路。
- **校验**：大小与 SHA-256（清单或接口给出时）不符即删除并报错；通过后由原生 `AppUpdateInstaller` 核对包名与签名证书、版本号更高，才交给系统安装器（`AppUpdateFileProvider` 只暴露 `cacheDir/app_update/`）。镜像无法把安装包换成别的应用。
- **安装权限**：Android 8+ 需要用户为 Jotsy 开启“安装未知应用”；更新页说明原因并打开对应设置，用户返回后自动继续安装。
- **清理**：检查或冷启动时删除已安装版本留下的安装包与残留。

## 桌面

Windows 与 Linux 不在应用内下载安装：

- **检查**与 Android 完全相同（清单、回退、线路、偏好）。解析时 APK 与桌面安装包分开存放：`AppUpdateRelease.assets` 只有 `.apk`，`desktopAssets` 只有桌面包（三种来源都经 `addReleasePackage`），Android 的挑选永远拿不到桌面包。
- **前往下载**：`AppUpdateRelease.desktopAssetFor` 挑本平台的安装包——Windows 取安装程序 `jotsy-<tag>-windows-x64-setup.exe`（便携版 `.zip` 只在发布页提供），Linux 取 `jotsy-<tag>-linux-x64.tar.gz`；`AppUpdateController.desktopDownloadUri` 把它套上首选线路（自动时即本次检查最先响应的线路），交给浏览器下载。浏览器自己下载，所以不测速、不续传、不校验；用户可用发布页的 `SHA256SUMS.txt` 核对。
- **没有本平台安装包**（桌面版之前的版本只有 APK）：说明“没有适合本机系统的安装包”，按钮改为打开发布页面。
- 更新页与提示面板不显示下载进度、安装、安装权限与 ABI；“在 GitHub 查看”打开发布页面，“跳过此版本”与 Android 相同。
- **安装**：Windows 运行安装程序覆盖安装（AppId 固定，自动关闭正在运行的 Jotsy）；Linux 解压后运行 `install.sh`，替换 `~/.local/share/jotsy`（或 `$PREFIX/share/jotsy`）。两者的日记数据都在应用数据目录，不受影响。

## 线路

内置线路在 `AppUpdateSource.builtInSources`：ghfast.top、gh-proxy.com、gh.llkk.cc、ghproxy.net 与 GitHub 直连。镜像都是第三方公共服务、随时可能失效，所以始终多条并用；新增或替换镜像只改这个列表（形如 `https://<host>/` 的前缀，原地址直接拼在后面）。

用户可在更新页“下载线路”里选择自动（默认）、某条内置线路、直连，或填写**自定义镜像**——内置镜像都失效时的兜底。

## 偏好

只存在本机偏好 `app.update.preferences`（单个 JSON 键，见 `AppUpdatePreferences`），**不随备份导出**：自动检查开关、上次检查时间、跳过的版本、所选线路、自定义镜像、上次可用的线路。旧版的 `app.settings.release_mirror_start_index` 启动时删除。

## 自动检查

默认开启，在 Android 与桌面（Windows / Linux）进行：冷启动后约 4 秒、每次回到前台后约 1 秒各试一次（`AppUpdateAutoChecker`），距上次成功检查不足 **2 小时**不请求（`AppUpdatePreferences.autoCheckInterval`）。只靠冷启动不够：Android 进程常驻后台，可能几天才冷启动一次。清单是 Release 附件下载、只有几 KB，不占 GitHub 接口配额，每台设备一天最多十来次请求。

自动检查是静默的：过程中不切换到“检查中”，失败时不显示错误，检查期间用户开始了下载等操作时不覆盖其状态。发现未跳过的新版本且首页在栈顶时弹出提示面板（立即更新 / 跳过此版本 / 以后再说；桌面的主操作为“前往下载”，直接在浏览器里打开安装包、不进入更新页）；同一版本每次进程只提示一次，“以后再说”后要到下次冷启动才会再弹。用户在其他页面时不打断，设置页“关于”入口与“检查更新”行显示“新版本”标记。“跳过此版本”只影响自动提示，手动检查照常显示。

## 发布要求

`release-apk.yml` 过门禁后并行构建三个平台：`build-release-apk`（签名分包 APK）、`build-linux`（`jotsy-<tag>-linux-x64.tar.gz`：顶层 `jotsy/` 含 bundle、`com.jotsy.diary.desktop`、hicolor 图标与 `install.sh`）、`build-windows`（7-Zip 打包的便携版 `jotsy-<tag>-windows-x64.zip` 与 Inno Setup 编译的 `jotsy-<tag>-windows-x64-setup.exe`，脚本 `windows/packaging/jotsy.iss`）。各 job 经 workflow artifact 把安装包交给 `publish`，它：

1. 核对六个安装包齐全，生成覆盖全部安装包的 `SHA256SUMS.txt`；
2. 运行 `tool/write_update_manifest.dart` 生成 `jotsy-update.json`：版本取 `pubspec.yaml`（含构建号），说明取 `docs/releases/<tag>.md` 与 `<tag>.en.md`（中文缺失时用 Release 正文），APK 与桌面安装包都写进 `assets`（桌面版之前的应用只认 `.apk`、跳过其余；没有 APK 时拒绝生成），并用应用自己的解析器读一遍，解析不了就让发布失败；
3. 分两步上传：先传全部安装包，传完后再传校验文件与清单。应用与官网读到它们即认为安装包已就绪，同一步里的文件并发上传、顺序没有保证，所以不能放在一步里。

写 Release 的权限只在 `publish`。手动触发的测试包（`test-build`）只构建 Android，桌面 job 与 `publish` 都跳过。

所以每个版本都应在 `docs/releases/` 下写好中英文说明；开头的 `# Release vX` 标题、语言切换行和 `**Full Changelog**` 行在应用里会被去掉。

`docs/releases/` 同时登记为 pubspec 的 assets，随应用打包：设置 → 关于 → 更新日志（`ChangelogPage`）离线列出打进这个安装包的全部版本，不联网。文件名须是 `<tag>.md`（中文）/ `<tag>.en.md`（英文），tag 能解析为版本号（`release_notes_catalog.dart`），否则不会出现在更新日志里；`release_notes_catalog_test.dart` 会核对目录里的每个版本都已打包、中英文都能读到。卡片常显第一节（“版本要点 / Highlights”）的正文，其余章节点“展开全部”显示，所以新版本的说明请继续以要点一节开头。

## 实机检查清单

1. 装一个旧版本（versionCode 更小、同一签名），进入 设置 → 关于 → 检查更新：显示“发现新版本”、发布日期、大小与本机 ABI，更新内容按界面语言显示。
2. 点“下载并安装”：显示已下载 / 总大小、速度与所用线路；中途“取消下载”后按钮变为“继续下载（已完成 N%）”，再点从断点继续。
3. 未开启“安装未知应用”时：显示说明与“去设置”，在系统设置开启后返回，自动弹出系统安装器；安装后应用数据保留。
4. 下载线路选“自定义镜像”，输入不带 `https://` 的地址：提示格式错误；输入可用镜像后下载走该线路。
5. 断网检查：显示“检查更新失败”与换线路的提示，“重试”可恢复。
6. 冷启动（距上次检查超过 2 小时）：首页出现新版本提示；点“以后再说”后切到后台再回来不再弹出；超过 2 小时后回到前台会再检查（可在更新页看到“上次检查”时间变化）；“跳过此版本”后再次冷启动不再提示，但“关于”入口仍有“新版本”标记。
7. 明暗主题、320dp 宽 + 大字号下更新页与提示面板无溢出。
8. Windows / Linux 装旧版本：检查更新显示“发现新版本”、发布日期与安装包大小（不显示 ABI），主按钮“前往下载”在浏览器里开始下载安装程序 / `.tar.gz`（地址带所选镜像前缀），“在 GitHub 查看”打开发布页；没有下载、安装或安装权限界面。运行安装程序（或解压后 `./install.sh`）后再打开，版本已更新、日记仍在。
9. 桌面上冷启动（距上次检查超过 2 小时）：首页弹出提示，主按钮为“前往下载”，点按直接打开浏览器下载、不进入更新页。
