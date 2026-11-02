import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/form_width.dart';

/// AI 模块各二级页共用的外壳：设置区域背景、`<` 返回、按表单宽度居中的
/// 滚动列表（滚动视图铺满，留白在两侧，见 AGENTS.md §6 宽窗口规则）。
///
/// [area] 默认为设置区域；对话、回顾等不在设置里的页面传
/// [AppBackgroundArea.other]。
class AiPageScaffold extends StatelessWidget {
  const AiPageScaffold({
    super.key,
    required this.title,
    this.children = const <Widget>[],
    this.bodyBuilder,
    this.actions = const <Widget>[],
    this.area = AppBackgroundArea.settings,
    this.floatingActionButton,
    this.onWillPopGuard,
  });

  final String title;
  final List<Widget> children;

  /// 自定义主体（如需要整页可拖动排序的列表）；给出时忽略 [children]。
  /// [padding] 是按表单宽度算好的内边距。
  final Widget Function(BuildContext context, EdgeInsets padding)? bodyBuilder;
  final List<Widget> actions;
  final AppBackgroundArea area;
  final Widget? floatingActionButton;

  /// 返回前的拦截（如“放弃未保存的修改？”）；返回 true 才离开。
  final Future<bool> Function()? onWillPopGuard;

  @override
  Widget build(BuildContext context) {
    final guard = onWillPopGuard;
    Widget page = AppPageBackground(
      area: area,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          floatingActionButton: floatingActionButton,
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(title),
            actions: actions,
            leading: IconButton(
              tooltip: context.l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final side = FormWidth.extra(constraints.maxWidth);
              final padding = EdgeInsets.fromLTRB(side, 12, side, 32);
              final builder = bodyBuilder;
              if (builder != null) return builder(context, padding);
              return ListView(padding: padding, children: children);
            },
          ),
        ),
      ),
    );
    if (guard != null) {
      page = PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          if (await guard()) navigator.pop(result);
        },
        child: page,
      );
    }
    return page;
  }
}

/// 设置分组里通往下一级的一行：前置 16 的图标、标题、可选副标题、`>`。
class AiNavTile extends StatelessWidget {
  const AiNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final FaIconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      titleAlignment: ListTileTitleAlignment.center,
      leading: FaIcon(icon, size: 16, color: colors.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ?trailing,
          if (trailing != null) const SizedBox(width: 8),
          FaIcon(
            FontAwesomeIcons.angleRight,
            size: 14,
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 行尾的小标记胶囊（“已停用”“已改写”等）。
class AiBadge extends StatelessWidget {
  const AiBadge(this.label, {super.key, this.error = false});

  final String label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = error
        ? colors.onErrorContainer
        : colors.onSurfaceVariant;
    final background = error
        ? colors.errorContainer
        : colors.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
