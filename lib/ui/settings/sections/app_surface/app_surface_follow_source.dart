import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/models/app_surface_settings.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../../widgets/expressive_choice_tile.dart';
import '../../controllers/app_surface_editor_controller.dart';
import 'app_surface_labels.dart';

/// 区域单独设置的图片背景顶部的“跟随来源”行：副标题为当前来源（全局或
/// 某个页面），点按打开来源面板（[showAppSurfaceSourceSheet]），选中即写入。
///
/// 来源只决定“图片”“参数”两块打开跟随时取谁的值；两块是否跟随由各自
/// 分组里的开关决定（见 `AppSurfaceImageSection`）。
class AppSurfaceFollowSourceTile extends StatelessWidget {
  const AppSurfaceFollowSourceTile({
    super.key,
    required this.controller,
    required this.area,
  });

  final AppSurfaceEditorController controller;
  final AppBackgroundArea area;

  Future<void> _pick(BuildContext context) async {
    final picked = await showAppSurfaceSourceSheet(
      context,
      settings: controller.style,
      area: area,
    );
    if (picked != null) await controller.commitFollowSource(area, picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final source = controller.style.areaOf(area).source;
    return ListTile(
      key: const ValueKey<String>('appSurfaceFollowSource'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(l10n.appSurfaceFollowSource),
      subtitle: Text(appSurfaceSourceLabel(l10n, source)),
      trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
      onTap: () => _pick(context),
    );
  }
}

/// 打开跟随来源面板；取消返回 null。
///
/// 列出全局与除 [area] 自己以外的各区域，说明为它当前显示的背景类型；会让
/// 来源链绕回 [area] 的区域（`AppSurfaceSettings.canFollow`）停用并写明原因。
/// 项目多且带说明，按规范用底部面板而不是弹出菜单；点按即选中并关闭。
Future<AppBackgroundSource?> showAppSurfaceSourceSheet(
  BuildContext context, {
  required AppSurfaceSettings settings,
  required AppBackgroundArea area,
}) {
  return showAppModalBottomSheet<AppBackgroundSource>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) =>
        _AppSurfaceSourceSheet(settings: settings, area: area),
  );
}

class _AppSurfaceSourceSheet extends StatelessWidget {
  const _AppSurfaceSourceSheet({required this.settings, required this.area});

  final AppSurfaceSettings settings;
  final AppBackgroundArea area;

  String _description(AppLocalizations l10n, AppBackgroundSource source) {
    if (!settings.canFollow(area, source)) return l10n.appSurfaceSourceLoop;
    final shown = settings.backgroundOfSource(source);
    return l10n.appSurfaceSourceShows(
      appSurfaceKindLabel(
        l10n,
        shown.isVisible ? shown.kind : AppBackgroundKind.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final current = settings.areaOf(area).source;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.appSurfaceFollowSource,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.appSurfaceFollowSourceHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              0,
              AppSpacing.m,
              AppSpacing.l,
            ),
            children: <Widget>[
              for (final source in AppBackgroundSource.all)
                if (source.area != area)
                  ExpressiveChoiceTile(
                    key: ValueKey<String>('appSurfaceSource.${source.name}'),
                    label: appSurfaceSourceLabel(l10n, source),
                    description: _description(l10n, source),
                    selected: source == current,
                    onTap: settings.canFollow(area, source)
                        ? () => Navigator.of(context).pop(source)
                        : null,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
