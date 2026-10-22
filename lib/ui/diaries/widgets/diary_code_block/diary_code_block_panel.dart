import 'package:flutter/material.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    as editor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_editing.dart';
import 'package:node_diary/ui/diaries/controllers/diary_block_language_tracker.dart';
import 'package:node_diary/ui/diaries/models/diary_code_block/diary_code_language.dart';
import 'package:node_diary/ui/diaries/providers/diary_code_block_style_provider.dart';
import 'package:node_diary/ui/diaries/widgets/diary_code_block/diary_code_language_chips.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

/// 表头一行高度：与颜色面板表头、工具栏 40dp 一格同高。
const double _kHeaderHeight = 40;
const double _kHeaderGap = 4;

/// 语言选项与操作按钮之间的间距。
const double _kActionsGap = 12;
const double _kActionsHeight = 40;

/// 操作按钮与面板外框底部分隔线之间的留白（外框只留 2dp，按钮是实心的，
/// 贴得太近会显得挤）。
const double _kBottomGap = 4;

/// 标题、选项滚动区两端与操作按钮一排的左右缩进，三者左缘对齐。
const double _kInset = 4;

/// 代码块面板内容的自然高度（不含面板外框）。工具栏据此直接算出面板目标
/// 高度，不必等测量；与语言多少、选中哪个无关。
const double kDiaryCodeBlockPanelHeight =
    _kHeaderHeight +
    _kHeaderGap +
    kDiaryCodeLanguageChipsHeight +
    _kActionsGap +
    _kActionsHeight +
    _kBottomGap;

/// 悬浮工具栏卡片内的代码块面板：表头、两行语言选项、复制 / 退出 / 转为正文。
///
/// - 输入：正文控制器、工具栏给的内容高度 [bodyHeight]（小于自然高度时面板
///   内纵向滚动）、收起回调 [onClose]；
/// - 输出：选语言经 [setDiaryCodeBlockLanguage] 改写选区触及的每个代码块的
///   每一行（面板保持打开）；复制经 [copyDiaryCodeBlock] 写剪贴板并提示；
///   退出与转为正文改写正文后经 [onClose] 收起（从「更多」打开的回到
///   「更多」，由工具栏决定）；
/// - 自动识别开关读 [diaryCodeBlockStyleProvider]，识别结果读同一控制器的
///   [DiaryBlockLanguageTracker]（与正文高亮同一份），两者变化时只重建选项区；
/// - 不走路由、对话框或底部面板，按钮也不请求焦点：那些都会抢走正文焦点、
///   收起键盘，而工具栏跟着键盘显示，会连同面板一起消失。
class DiaryCodeBlockPanel extends ConsumerWidget {
  const DiaryCodeBlockPanel({
    super.key,
    required this.controller,
    required this.bodyHeight,
    required this.onClose,
  });

  final editor.DiaryEditorController controller;
  final double bodyHeight;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoDetect = ref.watch(
      diaryCodeBlockStyleProvider.select((style) => style.autoDetect),
    );
    final tracker = DiaryBlockLanguageTracker.of(controller);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: _kHeaderHeight, child: _buildHeader(context)),
        const SizedBox(height: _kHeaderGap),
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[controller, tracker]),
          builder: (BuildContext context, Widget? child) =>
              _buildChips(context, autoDetect, tracker),
        ),
        const SizedBox(height: _kActionsGap),
        SizedBox(height: _kActionsHeight, child: _buildActions(context)),
        const SizedBox(height: _kBottomGap),
      ],
    );
    return SizedBox(
      height: bodyHeight,
      child: bodyHeight < kDiaryCodeBlockPanelHeight
          ? SingleChildScrollView(primary: false, child: content)
          : content,
    );
  }

  /// 标题字号与字重同颜色面板表头。
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: _kInset),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          context.l10n.codeBlockPanelTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildChips(
    BuildContext context,
    bool autoDetect,
    DiaryBlockLanguageTracker tracker,
  ) {
    final l10n = context.l10n;
    final blocks = _touchedBlocks();
    // 选区跨了取值不同的代码块时不选中任何一项。
    final choices = blocks
        .map(
          (block) => DiaryCodeLanguageChoice.fromAttributeValue(
            block.attributes['language'],
          ),
        )
        .toSet();
    final selected = choices.length == 1 ? choices.single : null;

    final String autoLabel;
    if (!autoDetect) {
      autoLabel = l10n.codeBlockLanguageNone;
    } else {
      final detected = blocks.length == 1
          ? tracker.lastDetected(blocks.single)
          : null;
      autoLabel = detected == null
          ? l10n.codeBlockLanguageAuto
          : l10n.codeBlockLanguageAutoDetected(
              diaryCodeLanguageById(detected)?.name ?? detected,
            );
    }

    return DiaryCodeLanguageChips(
      horizontalInset: _kInset,
      selected: selected,
      onSelected: (DiaryCodeLanguageChoice choice) =>
          setDiaryCodeBlockLanguage(controller, choice.attributeValue),
      options: <DiaryCodeLanguageOption>[
        (choice: DiaryCodeLanguageChoice.auto, label: autoLabel),
        (
          choice: DiaryCodeLanguageChoice.plain,
          label: l10n.codeBlockLanguagePlain,
        ),
        for (final language in kDiaryCodeLanguages)
          (
            choice: DiaryCodeLanguageChoice.explicit(language.id),
            label: language.name,
          ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kInset),
      child: Row(
        children: <Widget>[
          _action(
            context,
            icon: FontAwesomeIcons.copy,
            label: l10n.codeBlockCopy,
            onPressed: () => _copy(context),
          ),
          const SizedBox(width: kDiaryCodeLanguageChipGap),
          _action(
            context,
            icon: FontAwesomeIcons.arrowTurnDown,
            label: l10n.codeBlockExit,
            onPressed: () {
              exitDiaryCodeBlock(controller);
              onClose();
            },
          ),
          const SizedBox(width: kDiaryCodeLanguageChipGap),
          _action(
            context,
            icon: FontAwesomeIcons.paragraph,
            label: l10n.codeBlockToText,
            onPressed: () {
              convertDiaryCodeBlockToText(controller);
              onClose();
            },
          ),
        ],
      ),
    );
  }

  /// 三个等宽的 tonal 按钮；放不下（窄屏英文）时图标与文字一起缩小，不出现
  /// 半截的省略文字。
  Widget _action(
    BuildContext context, {
    required FaIconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, _kActionsHeight),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FaIcon(icon, size: 14),
              const SizedBox(width: 6),
              Text(label, maxLines: 1, softWrap: false),
            ],
          ),
        ),
      ),
    );
  }

  /// 复制光标所在的代码块（选区跨块时取第一块），面板保持打开。
  Future<void> _copy(BuildContext context) async {
    final block = _touchedBlocks().firstOrNull;
    if (block == null) return;
    await copyDiaryCodeBlock(block);
    if (!context.mounted) return;
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(context.l10n.codeBlockCopied),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<editor.Node> _touchedBlocks() => selectedDiaryCodeBlocks(controller);
}
