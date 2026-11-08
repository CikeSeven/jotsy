# CI 耗时、缓存与测试分片

工作流在 `.github/workflows/ci.yml`（门禁）与 `release-apk.yml`（发布），共用的
安装步骤在 `.github/actions/setup-flutter`，只在 main 写入的缓存在
`.github/actions/main-cache`。门禁的检查项见 AGENTS.md §7。

## 2026-11-08 重写的起因

**网络下载失败。** #188 合并后 main 上的运行
[42468469456](https://github.com/CikeSeven/jotsy/actions/runs/42468469456) 中，
Android、Windows 与 3 个测试分片在构建钩子处失败：sqlite3 的构建钩子从
GitHub Releases 下载预编译库，下载服务返回 504，钩子把 92 字节的错误页当作
库校验（`Hash of downloaded file libsqlite3.x64.linux.so is bef140a1…`）。
actionlint 也从 GitHub Releases 下载，同样失败。15 分钟后重跑，仍有三个 job
因此失败。这两样下载此前都没有缓存，每次运行都要联网。

**缓存配额超限。** 仓库的 Actions 缓存共 10.33 GB，超过 10 GB 上限，超出后
GitHub 按最近使用时间淘汰。其中 setup-java 整份缓存 `~/.gradle/caches` 占
3.65 GB，恢复要 66 秒；Flutter SDK 缓存 Linux 1.64 GB、Windows 1.84 GB；PR
上也会写入 pub 与 Robolectric 缓存，但这些缓存只有该 PR 自己能读。

**耗时。** 上一次全绿的运行
[42382898252](https://github.com/CikeSeven/jotsy/actions/runs/42382898252)（#188 的 PR）：

| job | 总耗时 | 主要步骤 |
| --- | --- | --- |
| 测试分片 ×4 | 7 分 25 秒～9 分 36 秒 | 运行测试 409～536 秒，各片不均 |
| Tests（合并覆盖率） | 48 秒 | 等最慢的分片结束后才开始 |
| Android release | 8 分 43 秒 | 安装 110 秒（其中 Gradle 缓存恢复 66 秒）、构建 329 秒、原生测试 73 秒 |
| Windows release | 7 分 16 秒 | 安装 123 秒（SDK 缓存解压 55 秒、pub 缓存解压 36 秒）、构建 300 秒 |
| 静态检查 | 3 分 5 秒 | 生成代码一致性 96 秒、analyze 49 秒 |
| Linux release | 2 分 47 秒 | 构建 121 秒 |

关键路径是测试分片再加合并覆盖率，约 10.5 分钟。

## 缓存

每样从网络下载的东西都有缓存：

| 内容 | 路径 | 键 | 何时保存 |
| --- | --- | --- | --- |
| Flutter SDK 与引擎产物 | flutter-action 给出的 SDK 目录 | `flutter-<os>-stable-<版本>-<arch>-<hash>-artifacts-v1` | 安装与 precache 之后立即保存 |
| pub 包 | `PUB_CACHE` | `flutter-pub-…-<版本>-…-<pubspec.lock 哈希>`，未命中时退回同一 Flutter 版本的最近缓存 | `pub get` 之后立即保存 |
| 构建钩子下载（sqlite3 预编译库） | `.dart_tool/hooks_runner/shared` | `hook-downloads-<os>-<android\|host>-<job>-<pubspec.lock 哈希>` | job 成功结束时 |
| Gradle 发行版 | `~/.gradle/wrapper/dists` | `gradle-wrapper-<os>-<gradle-wrapper.properties 哈希>` | job 成功结束时 |
| Gradle 依赖 | `~/.gradle/caches/modules-2` | `gradle-<os>-<Flutter 版本>-<Gradle 脚本与 pubspec.lock 哈希>` | job 成功结束时 |
| Robolectric 的 Android jar | `~/.m2/repository/org/robolectric` | `robolectric-<os>-<build.gradle.kts 与原生测试源码哈希>` | job 成功结束时 |
| actionlint | `~/.cache/actionlint` | `actionlint-<版本>-linux-amd64` | job 成功结束时 |

**只有 main 写入缓存。** 缓存只能被同一 ref 及其基准分支读取。PR 写下的缓存
main 和其他 PR 都用不上，却照样计入配额，还会按最近使用时间把 main 的大缓存
挤掉。所以 PR、tag（发布）与其他分支的手动运行只恢复不保存：
`main-cache` 在 main 上用 `actions/cache`，其他 ref 用 `actions/cache/restore`；
SDK 与 pub 缓存由 `setup-flutter` 在 main 上显式 `actions/cache/save`。
flutter-action 自带的缓存引用浮动 tag，且任何 ref 都会写入，所以它只用来
解析版本与路径（`dry-run`），缓存改由固定 SHA 的 `actions/cache` 管理。

**SDK 与 pub 缓存在安装后立即保存。** 缓存键一旦写入就不能覆盖。若在 job
结束时保存，先结束的 job 会决定缓存内容：静态检查 job 存下的 SDK 不含 Android
与 Linux 桌面的引擎产物，此后 Android 与 Linux 构建每次都要临时下载。现在
`setup-flutter` 先 `flutter precache`（Linux 取 `--android_gen_snapshot --linux`，
Windows 取 `--windows`）再保存，缓存内容与哪个 job 先存无关。`--android`
还会跑一遍 Gradle 依赖解析，那部分已在 Gradle 缓存里，所以不用。

**钩子下载缓存按 job 区分键。** 这份缓存只有跑过构建或测试才有内容。若共用
一个键，静态检查 job 先结束时会存下一份空的或旧的缓存，测试分片之后每次都要
重新下载。sqlite3 按内容哈希命名下载目录（`download-<SHA-256 前 8 位>`），
复用前校验哈希，所以退回旧缓存不会用错版本，同一版本的库照样复用。发布工作流
的 job 在 tag 上只读，按 `hook-downloads-<os>-android-` / `-host-` 前缀退回
CI 里同类 job 的缓存。

**Gradle 只缓存下载来的东西。** transforms、构建缓存等是本机生成的产物，体积是
依赖的数倍，恢复比重新生成还慢。依赖缓存的键带 Flutter 版本（引擎以 maven 包
形式提供），只在同一 Flutter 版本内退回旧缓存，避免旧版本的依赖一代代累积；
Robolectric 的键也不设回退，原因相同。发行版单独缓存、只随 Gradle 版本变：
services.gradle.org 会跳转到 GitHub Releases 下载，同样会遇到 504，升级 Flutter
时不必跟着重新下载。

**缓存未命中时，sqlite3 库先带重试预取。** 钩子自己下载时不重试，失败的 job
又不写缓存，下载服务故障期间冷缓存的运行每次都从头失败（#197 第一次 CI 运行
的 6 个测试分片、静态检查与 Linux 构建都因此失败）。`setup-flutter` 在钩子运行前，从锁定版本的 sqlite3
包里读出文件名、release tag 与 SHA-256（`lib/src/hook/asset_hashes.dart`），
用 curl 带重试下载，校验后放进钩子会找的 `download-<哈希前 8 位>/libsqlite3.so`
（Windows 为 `sqlite3.dll`）。这依赖 sqlite3 钩子的内部布局，所以只是尽力而为：
包里找不到哈希、或下载失败时只告警，交给钩子照常下载；布局变了时预取的文件
不会被用上，构建结果不受影响。2026-11-08 在本地删掉缓存、断网（代理指向无效
地址）并清掉钩子的输出记录，钩子重新运行后直接用了预取的文件，测试通过。

**其余下载有重试。** pub get 最多 3 次，apt 最多重试 3 次。actionlint 与 sqlite3
预取的 curl 单次限 30 秒、重试总时长限 3 分钟：故障时下载服务常挂起约 130 秒
才回 504，不限单次时长时，#197 一次运行里 Windows 的预取就等了 4.5 分钟。
2026-11-08 本地复现时，actionlint 的下载连续 5 次 504 后第 6 次成功。

**没有缓存的部分：**

- NDK：AGP 每次从 dl.google.com 下载并解压，约 25 秒。缓存它要占约 700 MB
  配额，省下的时间有限。
- apt 包：约 19 秒，来自 runner 所在的 Azure 镜像。
- `.dart_tool`、`build/` 与 Gradle 构建缓存：都是与源码相关的产物，体积大，
  失效条件复杂。

**仍有的风险：** 缓存未命中又遇上 GitHub 下载服务长时间故障时，预取重试完仍会
失败；Gradle 升级版本后的第一次运行会下载新发行版，这一步不重试。遇到时等服务
恢复后重跑失败的 job。

## 测试分片

`test-shards` 将 `git ls-files` 列出的 `test/*_test.dart` 排序后轮流分给 6 个
runner，每个文件完整运行一次。分片索引从 0 开始，片数取 `strategy.job-total`，
新增测试提交到 Git 后自动参与分片。当前锁定的 test_core 的 `--total-shards`
在 suite 加载后才筛选测试，直接使用它会让每个 runner 仍编译所有测试文件，
所以在启动 Flutter 前就分配好文件。每片上传各自的 LCOV，`Tests` job 等所有
分片成功、核对报告数量后用 `tool/merge_lcov.dart` 合并：按源文件与行号累加
命中次数，重新计算 LF / LH。直接拼接或平均百分比会重复计算共享代码。
`merge_lcov.dart` 只支持行覆盖率，启用函数或分支覆盖率时须同步扩展。

**为什么是 6 片、轮流分配。** 2026-11-08 在本地用 JSON 报告器跑了一遍全量测试
（757 个文件，6046 个通过、3 个跳过，`-j 8`），按每个文件的执行时间加 2 秒
编译开销模拟各种分法（单位秒，本地耗时只用来比较分法，不代表 runner 上的
绝对值）：

| 片数 | 轮流分配（最慢片 / 均值） | 按文件大小 LPT | 按实测耗时 LPT |
| --- | --- | --- | --- |
| 4 | 724 / 702（+3%） | 742（+6%） | 703（0%） |
| 6 | 521 / 468（+11%） | 510（+9%） | 469（0%） |
| 8 | 379 / 351（+8%） | 371（+6%） | 352（0%） |

每个文件编译的中位数 1.4 秒，执行的中位数 0.5 秒，但最重的几个日记本与样式页
测试单个就要 13～24 秒。按实测耗时分配能把不均降到 0，但在 runner 上只比轮流
分配快约 35 秒，代价是要多一个规划 job（所有分片必须用同一份分配）和一份
耗时缓存，因此不做。按文件大小分配并不比轮流分配好。

#197 在 PR 上的运行
[42473065082](https://github.com/CikeSeven/jotsy/actions/runs/42473065082)：6 片的
运行测试步骤为 269～422 秒（4 片时 409～536 秒）。这次是冷缓存，又赶上下载服务
故障，安装步骤与 Android、Windows 构建的耗时不能代表合并后的情况；合并后 main
的第一次运行写入缓存，之后的运行才是热缓存的耗时。

片数增加时，每片固定的安装与首次编译开销不变。4 片时运行测试共约 1900 秒
机时，6 片时每片约 5～6 分钟，与 Android、Windows 构建相当；再加片不会缩短
整体耗时，同时运行的 job 也会更多（账号同时运行的 job 数有上限，main 与 PR
的运行同时进行时会排队）。测试进程并发数保持 Flutter 默认值。

## 测试清理（2026-10-22）

日记本、模板、纪念日、卡片样式和预览样式原来为每个源码文件注册一个重复的
规则测试。现在统一到 `test/ui/source_rules_test.dart`，每个源码文件只读一次，
每条规则只注册一个用例，失败时列出所有违规文件与行号。原有 241 个源码文件
仍全部包含在检查范围内，控制器防抖计时的例外也保留。日历与网盘界面的相同
规则一并复用。删除了四个功能各自重复维护的规则测试文件。

| 删除或合并的检查 | 保留的验证 |
| --- | --- |
| 各模块重复的 UI 规则与任意文件数量断言 | 共用源码规则；每个目录须非空，显式文件必须可读取 |
| 编辑页是否含某段 PopScope 源码 | 已有录音面板交互测试直接检查开关面板前后编辑器 Element 不变 |
| 网盘表单是否用了指定的图标构建器 | 已有 widget 测试测量四个图标的横向中心是否对齐 |
| 关于页与网盘界面的局部 ARB key / metadata 检查 | `tool/check_arb.dart` 对中英文全部 2283 条文案检查，编译同时验证生成 getter |
| 仅检查目录存在、源码文件数量或特定注释文字的用例 | 对应功能与架构规则检查；不再固定文件组织或注释写法 |

全应用菜单约束、渐变白名单、禁止导入完整高亮库、代码块编辑钩子等独有规则
继续保留。数据库迁移、备份恢复、私密日记、录音、明暗主题和窄屏矩阵的行为
测试均保留。删减前全量带覆盖率测试 3498 项通过、2 项手动基准跳过；删减后
3253 项通过、2 项跳过，净减少的 245 个用例都是源码检查。四片覆盖率合并后与
删减前逐行对比，已覆盖的行集合完全相同。
