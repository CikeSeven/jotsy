import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../core/services/home_widgets/home_widget_style.dart';
import '../../../l10n/app_localizations.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../settings/providers/app_features_provider.dart';
import '../viewmodels/home_widget_native_config.dart';
import '../viewmodels/home_widget_palette.dart';

/// 预览用的原生口径上下文（功能开关、界面语言、能写 / 能看的日记本与标签），
/// 与同步控制器构建快照时同一套判断。须在 build 期间调用。
HomeWidgetNativeContext watchHomeWidgetNativeContext(
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final features = ref.watch(appFeaturesProvider);
  final notebooks = ref.watch(notebooksProvider).value ?? const [];
  final tags = ref.watch(tagListProvider).value ?? const [];
  return HomeWidgetNativeContext(
    features: features,
    languageCode: l10n.localeName,
    writableNotebooks: <String, String>{
      for (final notebook in notebooks)
        if (notebook.isManual && !notebook.isPrivate && !notebook.isClosed)
          notebook.id: notebook.name,
    },
    readableNotebooks: <String, String>{
      for (final notebook in notebooks)
        if (!notebook.isPrivate) notebook.id: notebook.name,
    },
    tagNames: <String>{for (final tag in tags) tag.name},
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
