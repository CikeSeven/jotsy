import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/keyboard_visibility.dart';

/// 待办的底部面板统一经这里弹出：按内容高度展开（矮屏在面板内滚动）、
/// 带拖动条、减少动态效果时直接出现。面板本身经 [showAppModalBottomSheet]，
/// 经典 / 玻璃材质随设置。
Future<T?> showTodoSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showAppModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: builder,
  );
}

/// 待办面板的版式：标题行（可带右侧按钮）+ 可滚动的内容；有输入框时为
/// 软键盘留白（[KeyboardInsetPadding]，不逐帧重建大组件）。
class TodoSheetBody extends StatelessWidget {
  const TodoSheetBody({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyboardInsetPadding(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s,
            0,
            AppSpacing.s,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  0,
                  AppSpacing.s,
                  AppSpacing.s,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// 面板里的一个选项行：主色图标 + 文字（+ 右侧说明 / 选中对勾）。
class TodoSheetOption extends StatelessWidget {
  const TodoSheetOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
    this.selected = false,
    this.destructive = false,
  });

  final FaIconData icon;
  final String label;
  final String? detail;
  final bool selected;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = destructive ? scheme.error : scheme.primary;
    final detail = this.detail;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: FaIcon(icon, size: 18, color: color),
      title: Text(
        label,
        style: destructive ? TextStyle(color: scheme.error) : null,
      ),
      selected: selected,
      trailing: selected
          ? FaIcon(FontAwesomeIcons.check, size: 16, color: scheme.primary)
          : detail == null
          ? null
          : Text(
              detail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
      onTap: onTap,
    );
  }
}
