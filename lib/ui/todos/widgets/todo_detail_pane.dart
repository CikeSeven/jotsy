import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../sections/todo_detail_body.dart';

/// 宽窗口待办页的右栏（384 宽）：上、右、下各留 12，24 圆角、1dp
/// `outlineVariant` 描边并裁切的卡片表面，顶部一行关闭按钮，下面是
/// [TodoDetailBody]（按 [todoId] 换 key：换一条时上一条的防抖输入先写掉）。
class TodoDetailPane extends StatelessWidget {
  const TodoDetailPane({
    super.key,
    required this.todoId,
    required this.onClose,
    required this.onDelete,
  });

  /// 栏宽。
  static const double width = 384;

  final String todoId;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        0,
        AppSpacing.m,
        AppSpacing.m,
        AppSpacing.m,
      ),
      child: Material(
        color: ExpressiveSurfaces.cardColor(scheme),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: IconButton(
                  tooltip: context.l10n.commonClose,
                  onPressed: onClose,
                  icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                ),
              ),
            ),
            Expanded(
              child: TodoDetailBody(
                key: ValueKey<String>('todo_detail_$todoId'),
                todoId: todoId,
                onDelete: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
