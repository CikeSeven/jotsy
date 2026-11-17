# 平台门控、宽窗口与桌面键鼠

> 专题约束，与 AGENTS.md 同等效力；改动本主题前先读本文件，新规则写在这里。界面规格见 DESIGN.md §5.22。

## 平台能力与桌面替代

- 必须：测试经 `debugDefaultTargetPlatformOverride` 切换平台。
- 必须：桌面的保存到相册与导出改为“另存为…”（`DesktopSaveService`）；Linux 分享面板改为复制文字与保存图片；附件交给系统打开。
- 必须：Linux / Windows 正文视频改为交给系统播放器的封面卡；非手机的长图拼接在 Dart 中完成。
- 必须：只在手机：自动定位与天气、这天的照片、云端笔记登录、选中文字分享；应用内安装只在 Android，桌面去浏览器下载。
- 必须：Linux 无录音；熄屏 / 后台继续录音只在 Android。局域网同步不支持 iOS；扫码配对与其他应用的文字操作只在 Android。
- 必须：Linux 应用锁只能用应用密码（见 `app_lock.md`）；生物识别只在 Android / iOS / macOS；锁屏时上锁与防截屏只在 Android，桌面改为闲置时上锁。
- 必须：待办提醒在桌面只在应用运行期间弹出、锁屏隐藏通知内容只在 Android（见 `todos.md`）；屏幕圆角只在 Android 读取；桌面小组件只在 Android（见 `home_widgets.md`）。

## 宽窗口

- 必须：滚动内容以 `AppContentWidth.gutter` 作左右内边距居中，不滚动的内容用 `CenteredContent`；禁止散写最大宽度。
- 必须：新增二级页经 `FormWidth` + `AppTopBar(contentMaxWidth:)` 限宽；首页各 Tab 页头禁止随内容列内收（#308）。
- 必须：跨 600 切换底栏 / 侧栏时保留各 Tab 页面状态；`DiariesListSection` 的调用方必须传 `availableWidth`。
- 必须：日记双栏的选中只在页面内存、不持久化、与多选互不影响。

## 键鼠

- 必须：预览页与看图页翻页只经 `DesktopPageArrows` / `DesktopPageKeys`；页面快捷键包在 `DesktopPageKeys` 外面，否则正文没焦点时收不到。
- 必须：正文的复制 / 粘贴菜单在桌面只在右键时弹出，手机为选中后自动浮出。
- 必须：桌面关闭卡片左滑归档；手机列表左滑只经 `DiarySwipeActionItem`，禁止改回 `Dismissible`。
- 必须：文件拖放插入只在编辑页正文；“始终显示工具栏”开关在桌面隐藏（桌面常显）。

## Android 返回

- 禁止：Android 预测性返回；页面转场只经主题 `appPageTransitionsTheme`，manifest 的 `enableOnBackInvokedCallback` 保持 false（`android_no_predictive_back_test.dart` 兜底）。
- 例外：从卡片点开日记的容器转场不用于 iOS / macOS，那两个平台保留左缘侧滑返回（见 `diary_list_preview.md`）。
- 必须：Android 任务根的首个路由按返回只退到桌面、保留进程与页面状态；禁止在 Dart 里用 `SystemNavigator.pop` / `exit` 退出应用（#196）。
