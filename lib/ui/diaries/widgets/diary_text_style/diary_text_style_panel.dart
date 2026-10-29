import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    as editor;
import 'package:node_diary/ui/diaries/controllers/diary_text_style_editing.dart';
import 'package:node_diary/ui/widgets/expressive_button_group.dart';

/// 表头一行高度：与代码块、列表、颜色面板的表头同高。
const double _kHeaderHeight = 40;
const double _kHeaderGap = 4;

/// 按钮组一排的高度：手机上按钮带 48dp 点按区；桌面的紧凑密度下按钮矮一些，
/// 在这一排里竖直居中，面板高度不随平台变化。
const double _kGroupHeight = 48;
const double _kBottomGap = 4;

/// 标题与按钮组的左右缩进，两者左缘对齐（同代码块、列表面板）。
const double _kInset = 4;

/// 段内标签的最大高度：大字号的标签（字号面板的“特大”）与放大的系统字体
/// 都按比例缩进这个高度，不把按钮撑高。
const double _kLabelHeight = 32;

/// 各段的内边距：标题面板 7 段要在 320dp 宽的手机上排成一行（每段约 35dp），
/// 按钮组默认的横向 12dp 会把标签挤没。
const EdgeInsets _kSegmentPadding = EdgeInsets.symmetric(horizontal: 4);

/// 文字样式面板（标题、对齐、字号）内容的自然高度（不含面板外框）。三块
/// 面板同高，工具栏据此直接算出面板目标高度，不必等测量。
const double kDiaryTextStylePanelHeight =
    _kHeaderHeight + _kHeaderGap + _kGroupHeight + _kBottomGap;

/// 文字样式面板的一个选项。
class DiaryTextStyleOption<T extends Object> {
  const DiaryTextStyleOption({
    required this.value,
    required this.label,
    required this.child,
  });

  final T value;

  /// 读屏与长按提示用的全名。
  final String label;

  /// 段内显示的内容（文字或图标）；会按段的大小等比缩小。
  final Widget child;
}

/// 悬浮工具栏卡片内的文字样式面板外壳：40dp 表头（标题 + 收起按钮）+ 一排
/// 单选按钮组。标题、对齐、字号三块面板共用（见 `diary_text_style_panels.dart`）。
///
/// - 输入：正文控制器、标题、选项、读出当前取值的 [selectedOf]、写入取值的
///   [onSelected]、工具栏给的内容高度 [bodyHeight]（小于自然高度时面板内纵向
///   滚动）与收起回调 [onClose]；
/// - 选中哪一段只看正文（随选区与撤销变化）：[selectedOf] 返回 null（选区跨了
///   不同取值）时不选中任何一段；选区里没有能改的文字块（光标在代码块里）时
///   整排停用，面板保持打开；
/// - 点按写入后面板保持打开，选区换到别处时跟着显示那里的取值；
/// - 不走路由、对话框或底部面板，按钮也不请求焦点：那些都会抢走正文焦点、
///   收起键盘，而工具栏跟着键盘显示，会连同面板一起消失。
class DiaryTextStylePanel<T extends Object> extends StatelessWidget {
  const DiaryTextStylePanel({
    super.key,
    required this.controller,
    required this.title,
    required this.options,
    required this.selectedOf,
    required this.onSelected,
    required this.bodyHeight,
    required this.onClose,
  });

  final editor.DiaryEditorController controller;
  final String title;
  final List<DiaryTextStyleOption<T>> options;
  final T? Function(editor.DiaryEditorController controller) selectedOf;
  final void Function(editor.DiaryEditorController controller, T value)
  onSelected;
  final double bodyHeight;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: _kHeaderHeight, child: _buildHeader(context)),
        const SizedBox(height: _kHeaderGap),
        SizedBox(
          height: _kGroupHeight,
          child: ListenableBuilder(
            listenable: controller,
            builder: (BuildContext context, Widget? child) =>
                _buildGroup(context),
          ),
        ),
        const SizedBox(height: _kBottomGap),
      ],
    );
    return SizedBox(
      height: bodyHeight,
      child: bodyHeight < kDiaryTextStylePanelHeight
          ? SingleChildScrollView(primary: false, child: content)
          : content,
    );
  }

  /// 标题字号与字重同代码块、列表面板表头；右侧是收起按钮。
  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: _kInset),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.commonClose,
            onPressed: onClose,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            color: colors.onSurfaceVariant,
            icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context) {
    final enabled = diaryTextStyleEditable(controller);
    final group = ExpressiveButtonGroup<T?>(
      // 不论多窄都横排一行：面板高度按一排算，按钮组改成纵向会撑破面板。
      minSegmentWidth: 0,
      segmentPadding: _kSegmentPadding,
      segments: <ButtonSegment<T?>>[
        for (final option in options)
          ButtonSegment<T?>(
            value: option.value,
            label: Tooltip(
              message: option.label,
              excludeFromSemantics: true,
              child: Semantics(
                label: option.label,
                excludeSemantics: true,
                child: SizedBox(
                  height: _kLabelHeight,
                  child: FittedBox(fit: BoxFit.scaleDown, child: option.child),
                ),
              ),
            ),
          ),
      ],
      // 选区跨了不同取值（null）时不选中任何一段。
      selected: <T?>{selectedOf(controller)},
      onSelectionChanged: enabled
          ? (Set<T?> values) {
              final value = values.single;
              if (value != null) onSelected(controller, value);
            }
          : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kInset),
      child: Align(
        // 按钮组在系统字体放大到 20sp 以上时会改为纵向连接；这一排的高度
        // 是固定的，所以在这里把字体放大夹在横排的上限之内，标签再按段的
        // 大小等比缩小（见 [_kLabelHeight]）。
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.4,
          child: group,
        ),
      ),
    );
  }
}
