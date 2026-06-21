import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/webdav_settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/pages/webdav_sync_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WebDAV 配置表单 prefixIcon 对齐回归测试。
///
/// 修复点：四个配置编辑框的 prefixIcon 此前用裸 FaIcon，受字形宽度差异影响
/// 在列布局中左右漂移、观感参差。改为固定宽度居中盒子后，
/// 四个图标应共享同一水平中心线。
void main() {
  testWidgets('config field prefix icons share one horizontal center', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await WebDavSettingsService.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webDavSettingsServiceProvider.overrideWith((ref) async => settings),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WebDavSyncPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 四个配置字段的 prefix 图标。
    const prefixIcons = <IconData>[
      FontAwesomeIcons.link,
      FontAwesomeIcons.user,
      FontAwesomeIcons.lock,
      FontAwesomeIcons.folder,
    ];

    final centers = <double>[];
    for (final icon in prefixIcons) {
      final finder = find.byWidgetPredicate(
        (Widget w) => w is FaIcon && w.icon == icon,
      );
      expect(finder, findsOneWidget, reason: '应能找到 $icon 的 prefix 图标');
      centers.add(tester.getCenter(finder).dx);
    }

    // 所有图标的水平中心线应一致（容差 0.5px，排除浮点误差）。
    final first = centers.first;
    for (final dx in centers.skip(1)) {
      expect(
        (dx - first).abs() < 0.5,
        isTrue,
        reason: 'prefix 图标水平中心未对齐：$centers',
      );
    }
  });
}
