# 应用内更新、官网、打赏与发布流程

> 专题约束，与 AGENTS.md 同等效力；改动本主题前先读本文件，新规则写在这里。界面规格见 DESIGN.md §5.13 / §5.18；机制见 `docs/app_update.md`。

## 应用内更新
- 必须：更新只经 `AppUpdateController`；线路只在 `AppUpdateSource.builtInSources` 登记（官网下载线路与之同步），禁止别处拼镜像地址；读不到 `SHA256SUMS.txt` 不提示新版本。
- 禁止：Android 以跳转浏览器为主更新路径；桌面只检查、在浏览器打开本平台安装包，不显示下载、安装与进度。
- 禁止：让 Android 挑到桌面包，或发布没有 APK 的清单（旧版应用会判为无效）。
- 必须：安装包交给系统安装器前须过大小 / SHA-256 与包名 / 签名 / 版本校验，不通过即删除。
- 必须：自动检查只在冷启动与回到前台、每 2 小时最多一次、静默可关；同一版本每个进程只提示一次。
- 必须：偏好只存 `AppUpdatePreferences`，本机偏好不随备份；更新日志只读随应用打包的 `docs/releases/`，不联网。

## 发布
- 必须：经 GitHub Release 触发 `release-apk.yml`：tag 与 `pubspec.yaml` 版本一致，先过 CI 门禁；先传全部安装包，再传 `SHA256SUMS.txt`，最后传 `jotsy-update.json`；写权限只给 publish job。
- 必须：每个版本在 `docs/releases/` 写中英文说明 `<tag>.md` / `<tag>.en.md`。
- 禁止：更改 Windows 安装程序的 AppId。
- 必须：APK 同时带 v1 / v2 / v3 签名（鸿蒙只认 v1），禁止关闭任一方案或删掉签名校验步骤。
- 必须：原生库压缩存放（`useLegacyPackaging = true`），以免包体从约 46MB 涨到约 74MB。
- 例外：装机测试用 `gh workflow run release-apk.yml --ref <分支> -f test-build=true`（只出 arm64、签名同正式版、只传 workflow artifact），禁止用于发布。

## 官网与下载统计
- 必须：官网在 `docs/`，纯静态 HTML / CSS / 原生 JS，禁止构建步骤与外部 CDN；颜色只用 `--c-*` 色槽，主题配色经 `site_theme_export_test.dart` 与应用保持一致。
- 必须：中英文写在同一元素，两种语言一起改；`privacy.html` 禁止改路径（OAuth 引用），联网或权限变化时同步更新。
- 必须：累计下载只统计 `.apk`，优先读 GitHub 接口，兜底读 `download-stats.yml` 传到 Release 的统计；该 job 只授 `contents: write`，口径与 `download.js` 一起改。

## 打赏
- 必须：只在设置 → 关于提供入口，禁止弹窗催促；收款码只取 `assets/img/support/`（与 README 共用），换码时链接一起改。
- 禁止：打赏与任何功能、设置或数据挂钩；不联网、不记录打赏信息。
