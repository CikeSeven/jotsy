import 'package:flutter/material.dart';

import '../../../../core/database/rich_text/inline_rich_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/rich_text/inline_format_button.dart';
import '../../../widgets/rich_text/inline_rich_text_controller.dart';
import '../../models/diary_toolbar_preferences.dart';

/// 写留言面板的格式条：粗体、斜体、下划线、删除线 | 链接。图标与名称取正文
/// 工具栏的同一项（[DiaryToolbarItem]），外观与导图格式条同一种按钮
/// （[InlineFormatButton]）。
///
/// - 开关作用于输入框 [text]：有选区时改选中的字，没有时设“接下来打的字”
///   （见 [InlineRichTextController]），按钮状态随选区与格式实时刷新；
/// - 链接按钮在选区或光标处有链接时为选中态，点按交给 [onLink]（面板打开
///   链接对话框）；
/// - 整条包在 [TextFieldTapRegion] 里：桌面上用鼠标点它不会让输入框失焦
///   （手机上触摸本就不会），按钮本身不抢焦点，键盘不收起。
class DiaryCommentFormatBar extends StatelessWidget {
  const DiaryCommentFormatBar({
    super.key,
    required this.text,
    required this.onLink,
  });

  /// 每个按钮的点按区域。
  static const Size buttonSize = Size(44, 40);

  final InlineRichTextController text;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    Widget button(DiaryToolbarItem item, bool selected, VoidCallback onTap) =>
        SizedBox.fromSize(
          size: buttonSize,
          child: InlineFormatButton(
            icon: item.iconData,
            label: item.label(l10n),
            selected: selected,
            onTap: onTap,
          ),
        );
    Widget toggle(DiaryToolbarItem item, InlineMark mark) =>
        button(item, text.isActive(mark), () => text.toggle(mark));
    return TextFieldTapRegion(
      child: ListenableBuilder(
        listenable: text,
        builder: (context, _) => Row(
          children: <Widget>[
            toggle(DiaryToolbarItem.bold, InlineMark.bold),
            toggle(DiaryToolbarItem.italic, InlineMark.italic),
            toggle(DiaryToolbarItem.underline, InlineMark.underline),
            toggle(DiaryToolbarItem.strikeThrough, InlineMark.strike),
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            button(DiaryToolbarItem.link, text.linkRange != null, onLink),
          ],
        ),
      ),
    );
  }
}
