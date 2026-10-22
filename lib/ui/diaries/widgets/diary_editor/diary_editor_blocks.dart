import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
import 'diary_block_drag_handle.dart';

/// 原生块组件的单一注册点：共享排版、只读待办、代码外壳、媒体和拖动把手。
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
  );
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
    'bulleted_list': af.BulletedListBlockComponentBuilder(configuration: text),
    'numbered_list': af.NumberedListBlockComponentBuilder(configuration: text),
    'quote': af.QuoteBlockComponentBuilder(configuration: text),
    'todo_list': af.TodoListBlockComponentBuilder(
      configuration: text,
      iconBuilder: (context, node, onCheck) => IconButton(
        tooltip: DiaryToolbarItem.checkList.label(context.l10n),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 24, height: 28),
        icon: FaIcon(
          node.attributes['checked'] == true
              ? FontAwesomeIcons.squareCheck
              : FontAwesomeIcons.square,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: controller.readOnly && !todoToggle
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
    'divider': af.DividerBlockComponentBuilder(
      lineColor: Theme.of(context).colorScheme.outlineVariant,
    ),
    for (final type in ['image', 'video', 'audio', 'attachment', 'quill_embed'])
      type: media,
    ...overrides,
  };
  return {
    for (final entry in builders.entries)
      entry.key: entry.key == 'page'
          ? entry.value
          : controller.readOnly
          ? (entry.key == 'code'
                ? _CodeBuilder(entry.value, code, tracker)
                : entry.value)
          : DiaryDraggableBlockBuilder(
              entry.key == 'code'
                  ? _CodeBuilder(entry.value, code, tracker)
                  : entry.value,
              controller,
            ),
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
