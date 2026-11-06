import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 设置首页分组里的导航行：圆角色块图标 + 标题 + 可选副标题，行尾可带
/// 当前值（如语言）或标记（如“新版本”），最后是 `angleRight`。
///
/// 放在 `SettingsCardGroup` 里使用，卡片表面（经典 / 玻璃）由分组负责，这
/// 里不画背景。标题与副标题取 listTileTheme，与分组里的开关行同一字阶。
/// 副标题只写当前状态或内容概括（DESIGN.md §5.3），只是进入一个列表的行
/// 不写副标题。
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.value,
    this.badge,
    required this.onTap,
  });

  final FaIconData icon;
  final String title;
  final String? subtitle;

  /// 副标题的强调色（如局域网同步有待确认的同步时用 `error`），为空时取
  /// listTileTheme 的副标题颜色。
  final Color? subtitleColor;

  /// 行尾显示的当前值（灰色小字，在箭头之前）。
  final String? value;

  /// 行尾显示在箭头之前的标记（如“新版本”胶囊），在 [value] 之后。
  final Widget? badge;

  /// 设置服务等依赖还没就绪时可以为空：行照常显示，只是点了没有反应。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final subtitle = this.subtitle;
    final value = this.value;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: FaIcon(icon, size: 16, color: colors.onPrimaryContainer),
      ),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: subtitleColor == null
                  ? null
                  : TextStyle(color: subtitleColor),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (value != null) ...<Widget>[
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
          ],
          if (badge != null) ...<Widget>[badge!, const SizedBox(width: 8)],
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
