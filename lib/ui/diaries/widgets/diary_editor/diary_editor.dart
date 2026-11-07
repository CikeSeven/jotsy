import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../../core/services/app_platform.dart';
import '../../../../core/services/app_service.dart';
import '../../../../core/services/diary_media_storage_service.dart';
import '../../../settings/providers/app_features_provider.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../controllers/diary_block_language_tracker.dart';
import '../../controllers/diary_block_editing.dart';
import '../../controllers/diary_editor_clipboard.dart';
import '../../controllers/diary_link_open_flow.dart';
import '../../controllers/diary_link_search.dart';
import '../../models/diary_link_candidate.dart';
import '../../controllers/diary_text_style_editing.dart';
import '../../models/diary_code_block/diary_code_block_style.dart';
import '../../models/diary_text_style_options.dart';
import '../../models/diary_thumbnail_rows.dart';
import '../../providers/diary_code_block_style_provider.dart';
import '../../providers/diary_typography_provider.dart';
import '../../viewmodels/diary_code_block_look.dart';
import '../../viewmodels/diary_text_appearance.dart';
import 'diary_block_marker_metrics.dart';
import 'diary_editor_blocks.dart';
import 'diary_editor_globals.dart';
import 'diary_embed_keys.dart';
import 'diary_markdown_input_interceptor.dart';
import 'diary_mention_menu.dart';
import 'diary_slash_commands.dart';
import 'diary_slash_menu.dart';
import 'diary_table_keyboard_interceptor.dart';
import 'diary_table_shortcuts.dart';
import 'diary_block_commands.dart';
import '../../controllers/diary_editor_controller.dart';
import 'diary_editor_spans.dart';
import 'diary_editor_styles.dart';
import 'diary_editor_interaction_layer.dart';
import 'diary_editor_selection_toolbar.dart';
import 'diary_inline_page.dart';
import 'diary_scroll_page.dart';
import '../diary_link_dialog.dart';

/// 让页面滚动编辑器的虚拟列表（[DiaryEditor.scrollHandle]）：编辑器挂着时由
/// 它接上，没挂（或是嵌在页面滚动里的只读正文）时什么也不做。
///
/// 为什么需要：编辑页的页头、正文与页尾都在 AppFlowy 的虚拟列表里，滚出视口
/// 的项不会构建，`Scrollable.ensureVisible` 找不到它们；只能按列表下标滚。
class DiaryEditorScrollHandle {
  Future<void> Function()? _revealFooter;

  /// 把页尾（footer）的顶边滚到视口顶部，动画时长与曲线取 [ExpressiveMotion]
  /// （减少动画时直接跳过去）。阅读式编辑页点信息栏里的“N 条留言”时先经它
  /// 让页尾构建出来，再对齐到留言区。
  Future<void> revealFooter() => _revealFooter?.call() ?? Future<void>.value();
}

/// 所有正文位置共用 AppFlowy 渲染与主题。编辑页使用原生虚拟滚动，标题等
/// 非正文 UI 经 header/footer 装配；只读正文可嵌在预览页的现有滚动视图中。
class DiaryEditor extends ConsumerStatefulWidget {
  const DiaryEditor({
    super.key,
    required this.controller,
    required this.appearance,
    this.focusNode,
    this.scrollController,
    this.shrinkWrap = false,
    this.header,
    this.footer,
    this.placeholder,
    this.padding = EdgeInsets.zero,
    this.codeBlockStyle,
    this.onMediaCommand,
    this.onCameraCommand,
    this.blockComponentOverrides = const {},
    this.onRecordingCommand,
    this.onAiCommand,
    this.aiPrompts = false,
    this.onImageOpen,
    this.onImageMenu,
    this.foldLongImages = true,
    this.todoToggle = false,
    this.textSelection = true,
    this.autoScrollEdgeOffset = 80,
    this.scrollHandle,
  });
  final DiaryEditorController controller;
  final DiaryTextAppearance appearance;
  final FocusNode? focusNode;
  final ScrollController? scrollController;
  final bool shrinkWrap;
  final Widget? header;
  final Widget? footer;
  final String? placeholder;
  final EdgeInsets padding;
  final DiaryCodeBlockStyle? codeBlockStyle;
  final void Function(String source, ImageViewerHero? hero)? onImageOpen;
  final void Function(BuildContext context, af.Node node)? onImageMenu;
  final bool foldLongImages;
  final void Function(DiaryMediaKind)? onMediaCommand;

  /// `/` 菜单里的“拍照 / 录像”（图片 / 视频）；null 时不出现（不支持拍摄的
  /// 平台、只读正文、模板编辑页）。
  final void Function(DiaryMediaKind)? onCameraCommand;
  final Map<String, af.BlockComponentBuilder> blockComponentOverrides;
  final VoidCallback? onRecordingCommand;

  /// `/` 菜单里的 AI 命令；null 时不出现 AI 组（AI 不可用、只读正文、模板
  /// 编辑页）。[aiPrompts] 为 true 时组里多出“写作灵感”。
  final void Function(DiaryAiSlashCommand)? onAiCommand;
  final bool aiPrompts;
  final bool todoToggle;
  final bool textSelection;
  final double autoScrollEdgeOffset;

  /// 页面按列表下标滚动编辑器（见 [DiaryEditorScrollHandle]）；不需要时为 null。
  final DiaryEditorScrollHandle? scrollHandle;

  @override
  ConsumerState<DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends ConsumerState<DiaryEditor> {
  double _inlineHeight = 1;
  af.AppFlowyEditor? _native;
  Object? _nativeInputs;
  late final ValueNotifier<Widget?> _headerSlot = ValueNotifier(widget.header);
  final ValueNotifier<Widget?> _footerSlot = ValueNotifier(null);
  late final Widget _headerHost = ValueListenableBuilder<Widget?>(
    valueListenable: _headerSlot,
    builder: (_, child, _) => child ?? const SizedBox.shrink(),
  );
  late final Widget _footerHost = ValueListenableBuilder<Widget?>(
    valueListenable: _footerSlot,
    builder: (_, child, _) => child ?? const SizedBox.shrink(),
  );
  late af.EditorScrollController _scroll;
  late DiaryBlockLanguageTracker _tracker;
  late DiarySlashMenuController _slashMenu;
  late DiaryMentionMenuController _mentionMenu;

  /// 表格里的软键盘规则（见 [DiaryTableKeyboardInterceptor]）：上游的键盘
  /// 服务在编辑器挂载后才有，首帧之后再登记；只读正文没有键盘服务。
  final DiaryTableKeyboardInterceptor _tableInterceptor =
      DiaryTableKeyboardInterceptor();

  /// 软键盘在嵌入块旁的退格（见 [DiaryEmbedKeyboardInterceptor]），排在
  /// 表格拦截器之后。
  final DiaryEmbedKeyboardInterceptor _embedInterceptor =
      DiaryEmbedKeyboardInterceptor();

  /// 输入法剪贴板一次上屏的多行 Markdown（见 [DiaryMarkdownInputInterceptor]），
  /// 排在表格拦截器之后；随控制器在 [_bind] 里重建。
  late DiaryMarkdownInputInterceptor _markdownInterceptor;
  @override
  void initState() {
    super.initState();
    widget.scrollHandle?._revealFooter = _revealFooter;
    // 上游的行内属性登记是全局的，必须先于任何编辑器构建（见该函数）。
    ensureDiaryEditorGlobals();
    _bind();
  }

  void _bind() {
    widget.controller.attachView();
    _markdownInterceptor = DiaryMarkdownInputInterceptor(widget.controller);
    _slashMenu = DiarySlashMenuController(widget.controller);
    _mentionMenu = DiaryMentionMenuController(
      widget.controller,
      search: _searchLinks,
    );
    // `/` 与 `@` 两个会话同一时刻只开一个：开一个就收起另一个。
    _slashMenu.addListener(() {
      if (_slashMenu.isOpen) _mentionMenu.close();
    });
    _mentionMenu.addListener(() {
      if (_mentionMenu.isOpen) _slashMenu.close();
    });
    widget.focusNode?.addListener(_onFocus);
    _scroll = af.EditorScrollController(
      editorState: widget.controller.state,
      shrinkWrap: widget.shrinkWrap,
      scrollController: widget.scrollController,
    );
    _tracker = DiaryBlockLanguageTracker.of(widget.controller)
      ..addListener(_rebuild);
    final state = widget.controller.state;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !state.isDisposed && state == widget.controller.state) {
        state.service.keyboardService
          ?..registerInterceptor(_tableInterceptor)
          ..registerInterceptor(_embedInterceptor)
          ..registerInterceptor(_markdownInterceptor);
      }
    });
  }

  void _unregisterInterceptor(DiaryEditorController controller) {
    if (!controller.state.isDisposed) {
      controller.state.service.keyboardService
        ?..unregisterInterceptor(_tableInterceptor)
        ..unregisterInterceptor(_embedInterceptor)
        ..unregisterInterceptor(_markdownInterceptor);
    }
  }

  /// `@` 菜单的候选（口径见 [searchDiaryLinkCandidates]）。查询时才读库与
  /// 书架（会话只在编辑器挂载期间存在）；书架还没加载时等它第一次推送，
  /// 不让第一次 `@` 漏掉日记本。
  Future<List<DiaryLinkCandidate>> _searchLinks(
    String query,
    Set<DiaryLinkKind> kinds,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final l10n = context.l10n;
    final tree = await readDiaryLinkNotebookTree(ref, kinds);
    return searchDiaryLinkCandidates(
      db: db,
      tree: tree,
      l10n: l10n,
      query: query,
      kinds: kinds,
      excludeDiaryId: widget.controller.linkSource?.diaryId,
    );
  }

  /// 打开日记链接（行内链接与卡片共用）；编辑态不打开日记本，见
  /// [openDiaryLinkTarget]。
  void _openLink(DiaryLinkTarget target) => unawaited(
    openDiaryLinkTarget(
      context,
      ref,
      target,
      fromEditor: !widget.controller.readOnly,
    ),
  );

  /// 能链接的种类：日记本功能关闭时只有日记。
  Set<DiaryLinkKind> _linkKinds() => {
    DiaryLinkKind.diary,
    if (ref.read(appFeaturesProvider).notebooks) DiaryLinkKind.notebook,
  };

  void _onFocus() {
    if (widget.focusNode?.hasFocus != true || widget.controller.readOnly) {
      return;
    }
    final controller = widget.controller;
    final selection =
        controller.selection ??
        af.Selection.collapsed(
          af.Position(
            path: walkDiaryEditorNodes(controller.document)
                .firstWhere(
                  (node) => node.delta != null,
                  orElse: () => controller.document.root.children.first,
                )
                .path,
          ),
        );
    controller.select(selection);
    // 上游只在选区变化时连接 IME；首次获得焦点时选区常与初始化值相同。
    // 显式连接也覆盖从标题、颜色输入框或系统选择器回到正文的交接。
    controller.state.service.keyboardService?.enableKeyBoard(selection);
  }

  /// 页头/页尾只借用正文的滚动，焦点仍属于页面。上游把它们放在键盘服务的
  /// Focus 下面，标题输入框聚焦时正文的 hasFocus 因而仍为 true：选区不清空，
  /// 键盘升高又按旧光标把页面拉回正文。把插槽接到编辑器外的焦点父节点，
  /// 由上游正常处理正文失焦、断开输入连接；控制器仍记住原选区以便回来续写。
  Widget? _slotOutsideBodyFocus(Widget? child) => child == null
      ? null
      : Focus(
          parentNode: Focus.maybeOf(context) ?? FocusScope.of(context),
          canRequestFocus: false,
          skipTraversal: true,
          child: child,
        );

  void _rebuild() {
    if (mounted) {
      _native = null;
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(DiaryEditor old) {
    super.didUpdateWidget(old);
    if (old.scrollHandle != widget.scrollHandle) {
      _detachScrollHandle(old.scrollHandle);
      widget.scrollHandle?._revealFooter = _revealFooter;
    }
    if (old.controller != widget.controller ||
        old.shrinkWrap != widget.shrinkWrap ||
        old.scrollController != widget.scrollController ||
        old.focusNode != widget.focusNode) {
      _scroll.dispose();
      _slashMenu.dispose();
      _mentionMenu.dispose();
      _unregisterInterceptor(old.controller);
      old.controller.detachView();
      old.focusNode?.removeListener(_onFocus);
      _tracker.removeListener(_rebuild);
      _bind();
    }
  }

  @override
  void dispose() {
    _detachScrollHandle(widget.scrollHandle);
    widget.focusNode?.removeListener(_onFocus);
    _scroll.dispose();
    _slashMenu.dispose();
    _mentionMenu.dispose();
    _unregisterInterceptor(widget.controller);
    widget.controller.detachView();
    _tracker.removeListener(_rebuild);
    _headerSlot.dispose();
    _footerSlot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DiaryCodeBlockStyle style =
        widget.codeBlockStyle ?? ref.watch(diaryCodeBlockStyleProvider);
    final family = style.usesImportedFont
        ? ref.watch(diaryImportedFontFamilyProvider(style.fontId)).asData?.value
        : null;
    final code = DiaryCodeBlockLook.resolve(
      context,
      style: style,
      appearance: widget.appearance,
      importedFontFamily: family,
    );
    final notebooksEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.notebooks),
    );
    final linking =
        !widget.controller.readOnly && widget.controller.linkSource != null;
    _headerSlot.value = _slotOutsideBodyFocus(widget.header);
    _footerSlot.value = _slotOutsideBodyFocus(
      widget.controller.readOnly
          ? widget.footer
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.footer != null) widget.footer!,
                SizedBox(
                  height:
                      widget.appearance.typography.fontSize *
                      widget.appearance.typography.lineHeight,
                ),
              ],
            ),
    );
    // 正文基础样式（颜色取所在位置的 DefaultTextStyle）：上游编辑器把它连同
    // EditorStyle 一起存进 EditorState，只在换上新的编辑器 widget 时更新。
    final body = diaryEditorBodyStyle(context, widget.appearance);
    // 键盘动画只改变约束，保持上游编辑器 widget 实例以复用其服务子树；
    // 页头与末尾占位通过独立槽更新，避免为小片布局重建整篇正文。
    //
    // 正文样式必须单独作为输入，不能指望 Theme 代劳：Scaffold 的 Material 用
    // AnimatedDefaultTextStyle 把文字样式补间到新主题（kThemeChangeDuration，
    // 不受减少动画影响），主题换掉的那一帧它还是旧主题的墨色，之后几帧只有
    // DefaultTextStyle 在变。只看 Theme 时缓存的编辑器停在那一帧：应用切换
    // 明暗、预览页换纸色或配色基调（墨色纸、设置页实时预览）后，正文仍是
    // 上一种主题的字色，深纸深字 / 浅纸浅字。补间期间每帧换上新的上游编辑器
    // widget：key 与 EditorState 不变，上游就地更新（服务 State 由 GlobalKey
    // 保住），光标、输入法连接与撤销记录都不受影响（见
    // diary_editor_theme_change_test）。只发生在换主题后的几百毫秒里：应用
    // 切换明暗为主题补间加上随后约 200ms 的正文样式补间。
    final inputs = (
      widget.controller,
      Theme.of(context),
      body,
      widget.appearance,
      style,
      family,
      MediaQuery.textScalerOf(context),
      widget.focusNode,
      widget.shrinkWrap,
      widget.padding,
      widget.placeholder,
      widget.controller.readOnly,
      widget.textSelection,
      widget.todoToggle,
      widget.foldLongImages,
      widget.onImageOpen != null,
      widget.header != null,
      widget.blockComponentOverrides,
      notebooksEnabled,
    );
    if (_native != null && _nativeInputs == inputs) {
      return _decorateNative(_native!);
    }
    final controller = widget.controller;
    final page = widget.shrinkWrap
        ? DiaryInlinePageBuilder(
            state: controller.state,
            padding: widget.padding,
            onHeight: (height) {
              if (mounted &&
                  height.isFinite &&
                  (height - _inlineHeight).abs() > 0.1) {
                setState(
                  () => _inlineHeight = height.clamp(1, double.infinity),
                );
              }
            },
          )
        // 键盘升降逐帧改变视口高度时不重建可见的段落块（见该类）。
        : DiaryScrollPageBuilder(state: controller.state, scroll: _scroll);
    final builders = buildDiaryEditorBlocks(
      context,
      controller: controller,
      appearance: widget.appearance,
      code: code,
      tracker: _tracker,
      page: page,
      placeholder: widget.placeholder,
      todoToggle: widget.todoToggle,
      onImageOpen: widget.onImageOpen,
      onImageMenu: widget.onImageMenu,
      foldLongImages: widget.foldLongImages,
      onOpenLink: _openLink,
      overrides: widget.blockComponentOverrides,
    );
    // 上游只在编辑器首次挂载时装入块组件，之后传入新的 builders 不生效：
    // 排版（段间距、首行缩进、标题字号）与代码块样式这类块级输入变化时，
    // 打开着的编辑页、预览与设置预览仍按旧块组件渲染。这里换上新的渲染器，
    // 上游随后重建页面即按新块组件排版（同类型的块就地更新，换了类型的块
    // 重新创建）。
    controller.state.renderer = af.BlockComponentRenderer(
      builders: {...builders},
    );
    final editor = af.AppFlowyEditor(
      key: ValueKey(controller.state),
      editorState: controller.state,
      characterShortcutEvents: [
        // `@` 菜单开着时回车确认候选，先于一切回车规则。
        if (linking) ...[
          diaryMentionEnterCommand(_mentionMenu),
          diaryMentionCommand(
            controller: controller,
            menu: _mentionMenu,
            kinds: _linkKinds,
          ),
        ],
        diarySlashCommand(
          controller: controller,
          context: context,
          menu: _slashMenu,
          commands: diaryBlockCommands(
            context.l10n,
            onMedia: widget.onMediaCommand,
            onCamera: widget.onCameraCommand,
            onRecording: widget.onRecordingCommand,
            onAi: widget.onAiCommand,
            aiPrompts: widget.aiPrompts,
            onLinkCard: linking
                ? (kind) => unawaited(_mentionMenu.openCardAtCaret({kind}))
                : null,
            notebookCards: notebooksEnabled,
          ),
        ),
        // 表格里的回车与 Markdown 原文先于其他块规则。
        ...diaryTableCharacterShortcuts(),
        ...diaryBlockCharacterShortcuts(),
      ],
      editorStyle: buildDiaryEditorStyle(
        context,
        widget.appearance,
        code,
        padding: widget.padding,
        decorator: diaryEditorSpanDecorator(
          code,
          _tracker,
          widget.appearance.typography.fontSize,
          links: DiaryLinkSpanOptions(
            state: controller.state,
            notebooksEnabled: notebooksEnabled,
            plainColor: body.color,
            onOpen: _openLink,
          ),
        ),
      ),
      commandShortcutEvents: [
        // `@` 菜单开着时 ↑ / ↓ / Tab 操作候选，先于表格与上游的同键事件。
        if (linking) ...diaryMentionCommandShortcuts(_mentionMenu),
        // 表格里的退格 / Delete / Tab / 方向键先于上游（见该文件）。
        ...diaryTableCommandShortcuts(),
        for (final command in ['copy', 'cut', 'paste'])
          af.CommandShortcutEvent(
            key: 'diary_$command',
            getDescription: () => command,
            command:
                'ctrl+${command == 'copy'
                    ? 'c'
                    : command == 'cut'
                    ? 'x'
                    : 'v'}',
            macOSCommand:
                'cmd+${command == 'copy'
                    ? 'c'
                    : command == 'cut'
                    ? 'x'
                    : 'v'}',
            handler: (_) {
              unawaited(
                command == 'copy'
                    ? DiaryEditorClipboard.copy(controller)
                    : command == 'cut'
                    ? DiaryEditorClipboard.cut(controller)
                    : DiaryEditorClipboard.paste(controller),
              );
              return KeyEventResult.handled;
            },
          ),
        // 桌面的 Ctrl / ⌘ + Shift + V 只粘贴原文（不转换 HTML 与
        // Markdown），排在上游同键的“粘贴为纯文本”之前。手机保持上游行为。
        if (AppPlatform.isDesktop)
          af.CommandShortcutEvent(
            key: 'diary_paste_plain_text',
            getDescription: () => 'paste as plain text',
            command: 'ctrl+shift+v',
            macOSCommand: 'cmd+shift+v',
            handler: (_) {
              if (controller.readOnly) return KeyEventResult.ignored;
              unawaited(
                DiaryEditorClipboard.paste(controller, plainText: true),
              );
              return KeyEventResult.handled;
            },
          ),
        // 桌面上 Esc 交给页面（与返回按钮相同，见各编辑页）：上游的
        // “退出编辑”会吞掉 Esc、只清掉选区；`/` 或 `@` 菜单开着时先收起菜单。手机
        // 保持上游行为。
        if (AppPlatform.isDesktop)
          af.CommandShortcutEvent(
            key: 'diary_escape',
            getDescription: () => 'escape',
            command: 'escape',
            handler: (_) {
              if (!_slashMenu.isOpen && !_mentionMenu.isOpen) {
                return KeyEventResult.ignored;
              }
              _slashMenu.close();
              _mentionMenu.close();
              return KeyEventResult.handled;
            },
          ),
        // 高亮写应用自己的颜色格式（见 toggleDiaryDefaultHighlight）。
        af.CommandShortcutEvent(
          key: 'diary_toggle_highlight',
          getDescription: () => 'toggle highlight',
          command: 'ctrl+shift+h',
          macOSCommand: 'cmd+shift+h',
          handler: (_) => toggleDiaryDefaultHighlight(controller)
              ? KeyEventResult.handled
              : KeyEventResult.ignored,
        ),
        // 桌面的 Ctrl / ⌘ + . 与 Ctrl / ⌘ + , 切换上标 / 下标，与工具栏同一
        // 动作；上游与应用都没有占用这两个组合。代码块里不处理（交还按键）。
        if (AppPlatform.isDesktop)
          for (final (name, key, script) in [
            ('superscript', 'period', DiaryScript.superscript),
            ('subscript', 'comma', DiaryScript.subscript),
          ])
            af.CommandShortcutEvent(
              key: 'diary_toggle_$name',
              getDescription: () => 'toggle $name',
              command: 'ctrl+$key',
              macOSCommand: 'cmd+$key',
              handler: (_) {
                if (controller.readOnly ||
                    diaryTextStyleTargets(controller).isEmpty) {
                  return KeyEventResult.ignored;
                }
                toggleDiaryScript(controller, script);
                return KeyEventResult.handled;
              },
            ),
        // 桌面的 Ctrl / ⌘ + K 打开与工具栏「链接」相同的对话框，取代上游的
        // 链接浮层（样式与校验都与应用不一致）。手机保持上游行为。
        if (AppPlatform.isDesktop)
          af.CommandShortcutEvent(
            key: 'diary_edit_link',
            getDescription: () => 'edit link',
            command: 'ctrl+k',
            macOSCommand: 'cmd+k',
            handler: (_) {
              if (!mounted || controller.readOnly) {
                return KeyEventResult.ignored;
              }
              unawaited(editDiaryLink(context, controller));
              return KeyEventResult.handled;
            },
          ),
        for (final event in af.standardCommandShortcutEvents)
          if (!kUpstreamTableCommandKeys.contains(event.key) &&
              !identical(event, af.toggleHighlightCommand) &&
              !(AppPlatform.isDesktop &&
                  (identical(event, af.exitEditingCommand) ||
                      identical(event, af.showLinkMenuCommand)))) ...[
            // 嵌入块旁的退格 / Delete 紧排在上游同键命令之前：上游会越过
            // 嵌入块合并文字（见 diary_embed_editing.dart）。“段首转正文”
            // 排在上游退格之前，仍先于这里。
            if (identical(event, af.backspaceCommand))
              diaryEmbedBackspaceCommand,
            if (identical(event, af.deleteCommand)) diaryEmbedDeleteCommand,
            event,
          ],
      ],
      // 桌面的复制 / 粘贴菜单只在右键时出现（手机为选中后自动浮出，见
      // DiaryEditorSelectionToolbar）。
      contextMenuBuilder: AppPlatform.isDesktop
          ? diaryEditorContextMenuBuilder(controller)
          : null,
      contentInsertionConfiguration: ContentInsertionConfiguration(
        allowedMimeTypes: const [
          'image/png',
          'image/jpeg',
          'image/webp',
          'image/gif',
        ],
        onContentInserted: (content) {
          if (content.data != null) {
            unawaited(
              DiaryEditorClipboard.insertImageBytes(controller, content.data!),
            );
          }
        },
      ),
      editorScrollController: _scroll,
      shrinkWrap: widget.shrinkWrap,
      focusNode: widget.focusNode,
      header: widget.header == null ? null : _headerHost,
      footer: _footerHost,
      editable: !controller.readOnly,
      disableSelectionService: !widget.textSelection,
      disableKeyboardService: controller.readOnly,
      autoScrollEdgeOffset: widget.autoScrollEdgeOffset,
      disableAutoScroll: !widget.shrinkWrap && !controller.readOnly,
      blockComponentBuilders: builders,
    );
    _native = editor;
    _nativeInputs = inputs;
    return _decorateNative(editor);
  }

  Widget _decorateNative(af.AppFlowyEditor editor) {
    final layer = _interactionLayer(editor);
    return widget.controller.readOnly
        ? layer
        : DiarySlashMenuHost(
            menu: _slashMenu,
            coveredHeight: widget.autoScrollEdgeOffset,
            child: DiaryMentionMenuHost(
              menu: _mentionMenu,
              coveredHeight: widget.autoScrollEdgeOffset,
              child: layer,
            ),
          );
  }

  void _detachScrollHandle(DiaryEditorScrollHandle? handle) {
    if (handle != null && handle._revealFooter == _revealFooter) {
      handle._revealFooter = null;
    }
  }

  /// 页尾在虚拟列表里是最后一项：下标 = 页头（有时）+ 顶层块数。
  Future<void> _revealFooter() async {
    final items = _scroll.itemScrollController;
    if (widget.shrinkWrap || !items.isAttached) return;
    final index =
        widget.controller.document.root.children.length +
        (widget.header == null ? 0 : 1);
    final duration = ExpressiveMotion.duration(context);
    if (duration == Duration.zero) {
      items.jumpTo(index: index);
      return;
    }
    await items.scrollTo(
      index: index,
      duration: duration,
      curve: ExpressiveMotion.effects,
    );
  }

  /// 第 [block] 个顶层块在页面列表里的下标：并排的小图都画在这一排第一张
  /// 那一项里（DiaryScrollPage），跳到它们时跳到那一项。
  int _itemIndexOf(int block) =>
      diaryThumbnailRowLeader(widget.controller.document.root, block) +
      (widget.header == null ? 0 : 1);

  Widget _interactionLayer(af.AppFlowyEditor editor) =>
      DiaryEditorInteractionLayer(
        controller: widget.controller,
        editor: editor,
        shrinkWrap: widget.shrinkWrap,
        textSelection: widget.textSelection,
        inlineHeight: _inlineHeight,
        focusNode: widget.focusNode,
        coveredHeight: widget.autoScrollEdgeOffset,
        contentLeft: widget.padding.left,
        childIndent: DiaryMarkerMetrics.columnWidth(
          widget.appearance.typography.fontSize,
          diaryEditorTextScaler(context),
        ),
        revealPath: (path) {
          if (path.isNotEmpty &&
              widget.controller.document.nodeAtPath(path) != null &&
              _scroll.itemScrollController.isAttached) {
            _scroll.itemScrollController.jumpTo(
              index: _itemIndexOf(path.first),
              alignment: 0.2,
            );
          }
        },
        // 拖动段落的预览移动后改以不受影响的块为锚点、停在原处，见
        // `diaryBlockDragAnchor`。同一帧内生效：jumpTo 只改锚点与偏移，
        // 随后的布局就按新锚点排。
        pinPath: (path, alignment) {
          if (path.isNotEmpty &&
              alignment >= 0 &&
              alignment <= 1 &&
              _scroll.itemScrollController.isAttached) {
            _scroll.itemScrollController.jumpTo(
              index: _itemIndexOf(path.first),
              alignment: alignment,
            );
          }
        },
      );
}
