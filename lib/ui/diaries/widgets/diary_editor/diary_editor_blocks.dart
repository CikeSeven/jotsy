import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../controllers/diary_block_language_tracker.dart';
import '../../models/diary_toolbar_preferences.dart';
import '../../viewmodels/diary_code_block_look.dart';
import '../../viewmodels/diary_text_appearance.dart';
import '../diary_image_options_menu.dart';
import 'diary_code_block_surface.dart';
import 'diary_editor_styles.dart';
import '../../controllers/diary_editor_controller.dart';
import 'diary_media_block.dart';
import 'diary_block_markers.dart';

/// 原生块组件的单一注册点：共享排版、行首标记（列表、待办、引用）、代码
/// 外壳与媒体。段落把手不在块里，见 [DiaryBlockHandleLayer]。
Map<String, af.BlockComponentBuilder> buildDiaryEditorBlocks(
  BuildContext context, {
  required DiaryEditorController controller,
  required DiaryTextAppearance appearance,
  required DiaryCodeBlockLook code,
  required DiaryBlockLanguageTracker tracker,
  required af.BlockComponentBuilder page,
  String? placeholder,
  required bool todoToggle,
  void Function(String, ImageViewerHero?)? onImageOpen,
  void Function(BuildContext, af.Node)? onImageMenu,
  required bool foldLongImages,
  Map<String, af.BlockComponentBuilder> overrides = const {},
}) {
  final text = diaryTextBlockConfiguration(
    context,
    appearance,
    placeholder: placeholder,
    editable: !controller.readOnly,
  );
  final colors = Theme.of(context).colorScheme;
  final lineExtent = diaryMarkerLineExtent(
    context,
    fontSize: appearance.typography.fontSize,
    lineHeight: appearance.typography.lineHeight,
  );
  final body = diaryEditorBodyStyle(context, appearance);
  final media = DiaryMediaBlockBuilder(
    controller: controller,
    onImageOpen: onImageOpen,
    onImageMenu:
        onImageMenu ??
        (context, node) => showDiaryImageOptions(
          context,
          controller: controller,
          node: node,
          source: node.attributes['url'] as String,
          readOnly: controller.readOnly,
        ),
    foldLongImages: foldLongImages,
  );
  final builders = <String, af.BlockComponentBuilder>{
    'page': page,
    'paragraph': af.ParagraphBlockComponentBuilder(configuration: text),
    'heading': af.HeadingBlockComponentBuilder(configuration: text),
    'bulleted_list': af.BulletedListBlockComponentBuilder(
      configuration: text,
      iconBuilder: (context, node) =>
          DiaryBulletMarker(node: node, lineExtent: lineExtent),
    ),
    'numbered_list': af.NumberedListBlockComponentBuilder(
      configuration: text,
      iconBuilder: (context, node, _) => DiaryNumberMarker(
        node: node,
        lineExtent: lineExtent,
        textStyle: body,
      ),
    ),
    'quote': af.QuoteBlockComponentBuilder(
      configuration: text,
      iconBuilder: (context, node) => const DiaryQuoteBar(),
    ),
    'todo_list': af.TodoListBlockComponentBuilder(
      configuration: text,
      // 勾选后文字转为次要色并划线，划线与文字同色、不抢眼。
      textStyleBuilder: (checked) => checked
          ? TextStyle(
              color: colors.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
              decorationColor: colors.onSurfaceVariant,
            )
          : const TextStyle(),
      iconBuilder: (context, node, onCheck) => DiaryTodoCheckbox(
        checked: node.attributes['checked'] == true,
        lineExtent: lineExtent,
        semanticLabel: DiaryToolbarItem.checkList.label(context.l10n),
        onToggle: controller.readOnly && !todoToggle
            ? null
            : () {
                final transaction = controller.state.transaction
                  ..updateNode(node, {
                    'checked': node.attributes['checked'] != true,
                  })
                  ..afterSelection = controller.selection;
                controller.apply(transaction, allowReadOnly: true);
              },
      ),
    ),
    'code': af.ParagraphBlockComponentBuilder(
      configuration: text.copyWith(
        padding: (_) => EdgeInsets.zero,
        textStyle: (_, {textSpan}) => code.codeTextStyle,
        placeholderText: (_) => ' ',
      ),
    ),
    // 独占一行的 1dp 细线，上下各留 12dp（DESIGN §3.2）。
    'divider': af.DividerBlockComponentBuilder(
      configuration: text.copyWith(padding: (_) => EdgeInsets.zero),
      lineColor: colors.outlineVariant,
      height: 24,
    ),
    for (final type in ['image', 'video', 'audio', 'attachment', 'quill_embed'])
      type: media,
    ...overrides,
  };
  return {
    for (final entry in builders.entries)
      entry.key: entry.key == 'code'
          ? _CodeBuilder(entry.value, code, tracker)
          : entry.value,
  };
}

class _CodeBuilder extends af.BlockComponentBuilder {
  _CodeBuilder(this.delegate, this.look, this.tracker);
  final af.BlockComponentBuilder delegate;
  final DiaryCodeBlockLook look;
  final DiaryBlockLanguageTracker tracker;
  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      _CodeWidget(
        node: context.node,
        look: look,
        tracker: tracker,
        child: delegate.build(context) as Widget,
      );
}

class _CodeWidget extends af.BlockComponentStatelessWidget {
  const _CodeWidget({
    required super.node,
    required this.look,
    required this.tracker,
    required this.child,
  }) : super(configuration: const af.BlockComponentConfiguration());
  final DiaryCodeBlockLook look;
  final DiaryBlockLanguageTracker tracker;
  final Widget child;
  @override
  Widget build(BuildContext context) => DiaryCodeBlockSurface(
    node: node,
    look: look,
    tracker: tracker,
    child: child,
  );
}
