import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../core/services/home_widgets/home_widget_style.dart';
import '../../../l10n/app_localizations.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../settings/providers/app_features_provider.dart';
import '../viewmodels/home_widget_native_config.dart';
import '../viewmodels/home_widget_palette.dart';

/// 预览用的原生口径上下文（功能开关、界面语言、能写进去的日记本），与同步
/// 控制器构建快照时同一套判断。须在 build 期间调用。
HomeWidgetNativeContext watchHomeWidgetNativeContext(
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final features = ref.watch(appFeaturesProvider);
  final notebooks = ref.watch(notebooksProvider).value ?? const [];
  return HomeWidgetNativeContext(
    features: features,
    languageCode: l10n.localeName,
    writableNotebooks: <String, String>{
      for (final notebook in notebooks)
        if (notebook.isManual && !notebook.isPrivate && !notebook.isClosed)
          notebook.id: notebook.name,
    },
  );
}

/// 预览要额外带上的配色：草稿刚选的自选颜色还不在快照里。
Map<String, Object?> homeWidgetPreviewPalettes(HomeWidgetInstance instance) {
  final style = instance.style;
  if (style.palette != HomeWidgetPalette.seed || style.seed == null) {
    return const <String, Object?>{};
  }
  return <String, Object?>{
    style.paletteKey: homeWidgetPaletteOf(
      style.seedColor(const Color(0x00000000)),
    ),
  };
}
