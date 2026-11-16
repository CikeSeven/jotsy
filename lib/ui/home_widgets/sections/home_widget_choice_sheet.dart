import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../widgets/app_modal/app_modal_bottom_sheet.dart';

/// 底部面板里的一项：值、名字与图标。
class HomeWidgetChoice<T> {
  const HomeWidgetChoice({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final FaIconData icon;
}

/// 工作室内容选项里“选一个”的底部面板（清单、标签；日记本经
/// `showNotebookChoiceSheet`，树序可收起）：标题加一列可点的项，当前所选
/// 打勾。划掉关闭时返回 null。
Future<T?> showHomeWidgetChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<HomeWidgetChoice<T>> choices,
  required T? selected,
}) {
  return showAppModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext sheetContext) {
      final theme = Theme.of(sheetContext);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final choice in choices)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: FaIcon(choice.icon, size: 16),
                title: Text(choice.label),
                trailing: choice.value == selected
                    ? FaIcon(
                        FontAwesomeIcons.check,
                        size: 14,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(choice.value),
              ),
          ],
        ),
      );
    },
  );
}
