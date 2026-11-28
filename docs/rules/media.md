# 图片、看图与媒体

> 专题约束，与 AGENTS.md 同等效力；改动本主题前先读本文件，新规则写在这里。界面规格见 DESIGN.md §5.11 / §5.12。

## 解码与长图
- 必须：封面与各处缩略图（含正文小图）经 `boundedImageProvider(cover: true)` 按显示尺寸铺满解码，cover 裁切只经 `CoverCroppedImage`（长图顶部对齐）。
- 必须：长图（高 ≥ 宽 × 3）只经 `isLongImageSize` 判定，解码前的尺寸只经 `ImageDimensions` 读文件头。
- 必须：长图分片只经 `LongImageTileService`（Android），缓存不随备份导出、原图只读。

## 看图
- 必须：看图页的图片操作只经操作面板 `showImageViewerActionsSheet`，分享复用 `DiaryShareController`；禁止在顶栏加保存 / 分享按钮或另写分享链路。
- 必须：“打开日记”只在入口给出日记 id 时出现（目前只有探索页媒体画廊）。
- 必须：看图与看视频的缩放只经 `DoubleTapZoomViewer`；禁止另写缩放手势或调大翻页 / 下拉阈值；正文视频卡片不可缩放。

## 正文媒体与小图
- 必须：正文图片点按菜单只经 `showDiaryImageOptions`，禁止回退到上游 `ImageOptionsMenu`。
- 必须：小图只存于图片 / 视频块的 `data.thumbnail`（只认 `true`，取消删键，缩放宽高保留）；只读正文不提供切换。
- 必须：正文顶层连续小图（图片与视频可混排）三张一排只是显示分组，每张仍是独立块；分排只经 `diaryThumbnailRows`。
- 必须：编辑页长按小图只在它所在的那一串连续小图里拖动排序，经 `DiaryThumbnailReorderLayer`；写入只经 `moveDiaryThumbnail`（一步撤销、不把页面拉向光标）；只读正文与独自一张的小图不能拖。
- 必须：紧跟小图插入的图片与视频也设为小图（附件除外）；编辑器设置开启“插入图片和视频时默认小图”时，新插入的图片、视频与粘贴的外部图片默认设为小图（复制正文已有图片保留原状态）；导出、分享与复制出去的仍是原图。
- 必须：视频宽度上限只存于 `data.width`；小图与未播放卡片的封面帧只经 `VideoPosterCache`，禁止为小图或尚未点按播放的正文视频卡片提前创建原生播放器。
- 必须：正文内嵌图片与视频经 `DiaryMediaViewportGate` 按视口距离与 `TickerMode` 门控解码与原生播放器；正文图片在尺寸探测前、解码前与离屏时保留非零占位高度；同一时刻全局至多持有一个懒加载正文视频的原生播放器（经 `DiaryVideoPlayerController` 租约释放后再新建）。
- 必须：导出视频只经 `runDiaryVideoExport`，全屏只经 `openDiaryVideoFullscreen`。

## 这天的照片
- 必须：相册只经 `DayPhotoLibrary` 读取（按拍摄时间筛选），状态只经 `DiaryDayPhotosController`。
- 必须：“自动显示当天照片”存于编辑器设置（默认开，本机偏好、不随备份），只控制提示条自动出现。
- 必须：系统权限框只由用户点按触发；只申请图片与视频读取，只授权图片时照常列出照片。
- 必须：插入只复制进日记私有目录，禁止改动相册原文件；勾选状态只在本次编辑页内存。
- 必须：预览页 `openDiaryDayPhotoPreview` 只负责查看、勾选与插入，不提供分享 / 保存。
- 必须：设为封面只限图片，经 `DiaryMetaActions.setCoverFromFile` 拷贝（新建写草稿，编辑写这篇日记；已插入正文的同一张图直接共用那份文件）；禁止引用相册原图路径。

## 拍照 / 录像
- 必须：只在 `AppPlatform.supportsCameraCapture`（Android）交给系统相机，经 `DiaryMediaImportController.captureAndInsert` 插入；禁止引入相机插件；文件不存系统相册。
- 必须：入口只有工具栏图片 / 视频按钮的来源菜单、`/` 菜单与桌面小组件“拍照记”；附件与留言没有拍摄入口。界面见 DESIGN.md §5.6。

## HEIF 与托管文件
- 必须：托管图片入库经 `HeifImageConverter.convertImported`；新增图片入库路径须经 `DiaryMediaStorageService` / `DiaryCoverStorageService` / `AppBackgroundStorageService` 之一。
- 必须：HEIF 只按文件头判断；转码只在 `AppPlatform.supportsHeifToJpeg`，失败时保留原文件，禁止因此丢图。
- 必须：旧 HEIF 图只经 `HeifMediaRepairService` 修复（等编辑会话全部关闭），引用一次事务改写，原 HEIC 交给媒体回收。
- 必须：桌面 HEIF 图解码失败时，占位说明原因与补救（在手机上打开后再同步）。
- 禁止：原地覆盖托管文件，重编码一律写新路径再改引用，以免同步对端拿不到；压缩与删除见 `storage.md`。

## 重复的图片与视频
- 必须：`DiaryMediaStorageService.importFile` 与 `DiaryCoverStorageService.importCover` 复制、转码后经 `ManagedMediaDedup.adopt`：可共用目录里已有逐字节相同的文件就改用它、删掉新副本；可共用的目录与存储管理合并同一份规则（`storage.md`「重复文件」），显示名仍按这次导入。
- 必须：复用前把那份文件的修改时间设为现在，再等正在进行的媒体回收结束、确认文件还在；有托管媒体写入者（压缩、HEIC 修复、同步）时不复用；任何失败都退回用新副本。
- 必须：导入失败、取消或移除还没保存的图片时，回滚只经 `deleteManagedDiaryFile` / `deleteManagedCover`，只删本进程刚导入、没被复用过的文件（`FreshManagedFiles`）；禁止另写直接删除托管文件的回滚。
- 例外：第三方笔记导入与备份合并导入不在入库时复用，留下的重复由存储管理合并。

## 导入音频
- 必须：导入的音频经 `probeAudioDuration` 读得出时长才做成录音块，否则当附件。
- 禁止：录音块指向 `diary_recordings/` 以外的目录（备份恢复只在该目录重绑路径）。
