# 分享与导出

> 专题约束，与 AGENTS.md 同等效力；改动本主题前先读本文件，新规则写在这里。界面规格见 DESIGN.md §5.9 / §5.10。

## 分享
- 必须：面板只挑选、`DiaryShareController` 执行；分享文字只经 `DiaryShareContent.composeText` 组装成纯文本。
- 必须：内容开关只存于单个 JSON 设置键 `app.settings.diary_share_options`（随备份导出）；地点默认不带。
- 必须：分享到指定应用只经 `DiaryShareChannel`；图片先暂存到缓存再交出，禁止交出日记原图路径。
- 必须：新增目标应用在 `DiaryShareTarget` 登记，并同步 `AndroidManifest.xml` 的 `<queries>`。
- 必须：长图只经 `DiaryPreviewExportController` 截取预览页，截取范围内禁止常驻或浮动导航（拼接后会重复）；去处只经 `DiaryLongImageDelivery`。
- 必须：存相册失败的提示只经 `imageExportErrorMessage`。

## 导出流程
- 必须：面板只挑选、`DiaryExportController` 执行；新增格式只加写出器并在 `DiaryExportFormat` 登记。
- 必须：导出选项只存于单个 JSON 设置键 `app.settings.diary_export_options`（随备份导出）；“包含留言”关闭时产物与原来逐字节一致。
- 必须：未解封的时间胶囊在任何导出格式中都不导出（完整备份除外）。
- 必须：导出文件不得写出设备私有路径；媒体按文件流式打包，禁止全部读进内存；PDF 设图片总量上限。

## 正文写出
- 必须：正文先经 `ExportBlockParser` 解析为块再交给写出器；提示块、折叠块与表格必须正式写出，禁止退化为段落。
- 必须：日记链接只留文字（见 `diary_links.md`），思维导图按大纲导出（见 `mind_maps.md`）。
- 必须：PDF 与 Word 的半透明颜色只经 `flattenDiaryColors` 叠到纸面再写入。
- 必须：段落对齐、首行缩进与列表标记与应用一致，口径只经 `ExportBlock`（取导出时的排版快照）。
- 必须：图片尺寸只经 `ExportImageBox` 换算（从不放大）；小图分排只在解析时算出，写出器禁止自行分组。
- 必须：导出字体跟随 `DiaryTypography`，导入字体只经 `DiaryExportFont.load`：PDF 嵌入（嵌不进整份回落内置字体），其余格式只引用字族名。

## PDF
- 禁止：写入内置字体没有的符号字形（画成矢量）；把可能含 emoji 的用户文字直接交给 `pw.Text`（经 `DiaryPdfEmoji` 画成图片）。
- 必须：中日韩文字经 `diaryPdfLineSplitter` 逐字断行；表格逐行成块以便跨页。

## 网页与 EPUB
- 必须：正文只经 `DiaryHtmlBody` 与 `DiaryHtmlMarkup` 写出，新增块或行内样式只改这两处；只为 EPUB 加的写法不得改变网页产物。
- 必须：EPUB 包骨架只经 `DiaryEpubPackage`，样式表只经 `DiaryEpubStyle`；图片只收 JPEG / PNG / GIF，其余转码或不写。
- 必须：改动 EPUB 时 `diary_export_epub_test.dart` 通过，并用 W3C epubcheck 校验 0 错误 0 警告。

## 导出成书
- 必须：经 `exportNotebookAsBook` 组装后传入 `runDiaryExportFlow`：整本含归档、不含回收站，按书序（智能日记本按发表时间旧→新、不分章）。
- 必须：“书籍结构”开关默认开、只对本次有效、不写进导出选项；CSV 与 Jotsy 日记文件不提供。
