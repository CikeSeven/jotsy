import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../widgets/app_modal/app_modal_bottom_sheet.dart';

/// 底部面板里的一项：值、名字、图标与缩进层级（子日记本）。
class HomeWidgetChoice<T> {
  const HomeWidgetChoice({
    required this.value,
    required this.label,
    required this.icon,
    this.depth = 0,
  });

  final T value;
  final String label;
  final FaIconData icon;
  final int depth;
}

/// 工作室内容选项里“选一个”的底部面板（清单、日记本、标签）：标题加一列可点的
/// 项，当前所选打勾。划掉关闭时返回 null。
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
                contentPadding: EdgeInsetsDirectional.only(
                  start: 24.0 + choice.depth * 16,
                  end: 24,
                ),
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
