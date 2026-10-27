import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_settings.dart';
import '../pages/app_surface_page.dart';
import 'app_surface/app_surface_labels.dart';

/// 外观与语言页的“背景与材质”入口。
///
/// 副标题概括当前状态（“默认”“图片背景 · 玻璃组件”“经典组件 · 3 个区域
/// 单独设置”等，见 [appSurfaceEntrySummary]），跟随 raw notifier 实时更新
/// （从编辑页返回、恢复备份后都会刷新）。
class SettingsAppSurfaceTile extends StatelessWidget {
  const SettingsAppSurfaceTile({super.key, required this.settingsAsync});

  final AsyncValue<SettingsService> settingsAsync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    return settingsAsync.when(
      data: (SettingsService settings) => ValueListenableBuilder<String?>(
        valueListenable: settings.appSurfaceRawNotifier,
        builder: (BuildContext context, String? raw, Widget? child) {
          return ListTile(
            contentPadding: padding,
            title: Text(l10n.appSurfaceTitle),
            subtitle: Text(
              appSurfaceEntrySummary(l10n, AppSurfaceSettings.decode(raw)),
            ),
            trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    AppSurfacePage(settingsService: settings),
              ),
            ),
          );
        },
      ),
      loading: () => ListTile(
        enabled: false,
        contentPadding: padding,
        title: Text(l10n.appSurfaceTitle),
      ),
      error: (Object error, StackTrace stackTrace) => ListTile(
        enabled: false,
        contentPadding: padding,
        title: Text(l10n.appSurfaceTitle),
      ),
    );
  }
}
