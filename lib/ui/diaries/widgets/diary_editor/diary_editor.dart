import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../providers/diary_code_block_style_provider.dart';
import '../../providers/diary_typography_provider.dart';
import '../../viewmodels/diary_code_block_look.dart';
import '../../viewmodels/diary_text_appearance.dart';
import 'diary_block_marker_metrics.dart';
import 'diary_editor_blocks.dart';
import 'diary_editor_globals.dart';
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
import '../diary_link_dialog.dart';

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
    this.blockComponentOverrides = const {},
    this.onRecordingCommand,
    this.onImageOpen,
    this.onImageMenu,
    this.foldLongImages = true,
    this.todoToggle = false,
    this.textSelection = true,
    this.autoScrollEdgeOffset = 80,
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
  final Map<String, af.BlockComponentBuilder> blockComponentOverrides;
  final VoidCallback? onRecordingCommand;
  final bool todoToggle;
  final bool textSelection;
  final double autoScrollEdgeOffset;
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
  @override
  void initState() {
    super.initState();
    // 上游的行内属性登记是全局的，必须先于任何编辑器构建（见该函数）。
    ensureDiaryEditorGlobals();
    _bind();
  }

  void _bind() {
    widget.controller.attachView();
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
        state.service.keyboardService?.registerInterceptor(_tableInterceptor);
      }
    });
  }

  void _unregisterInterceptor(DiaryEditorController controller) {
    if (!controller.state.isDisposed) {
      controller.state.service.keyboardService?.unregisterInterceptor(
        _tableInterceptor,
      );
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
    // 键盘动画只改变约束，保持上游编辑器 widget 实例以复用其服务子树；
    // 页头与末尾占位通过独立槽更新，避免为小片布局重建整篇正文。
    final inputs = (
      widget.controller,
      Theme.of(context),
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
        : af.PageBlockComponentBuilder();
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
            onRecording: widget.onRecordingCommand,
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
            plainColor: diaryEditorBodyStyle(context, widget.appearance).color,
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
                      identical(event, af.showLinkMenuCommand))))
            event,
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
              index: path.first + (widget.header == null ? 0 : 1),
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
              index: path.first + (widget.header == null ? 0 : 1),
              alignment: alignment,
            );
          }
        },
      );
}
