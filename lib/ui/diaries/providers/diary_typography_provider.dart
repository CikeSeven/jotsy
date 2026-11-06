import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_fonts.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/diary_font_storage_service.dart';
import '../../../core/services/settings_service.dart';
import '../viewmodels/diary_text_appearance.dart';

/// 正文排版偏好。
///
/// 同步 Provider 而不是 StreamProvider：设置服务在启动门控里就已加载，这里
/// 首次读取即得到真实偏好，打开日记的第一帧不会先按默认排版再跳变。设置
/// 变化时经 `invalidateSelf` 重算，监听随重算重新挂接、随销毁移除。
final diaryTypographyProvider = Provider<DiaryTypography>((Ref ref) {
  final settings = ref.watch(settingsServiceProvider).asData?.value;
  if (settings == null) {
    return const DiaryTypography();
  }
  final notifier = settings.diaryTypographyNotifier;
  void listener() => ref.invalidateSelf();
  notifier.addListener(listener);
  ref.onDispose(() => notifier.removeListener(listener));
  return notifier.value;
});

/// 已导入的字体；导入或删除后由调用方 invalidate 刷新。
final diaryImportedFontsProvider = FutureProvider<List<DiaryImportedFont>>(
  (Ref ref) => ref.watch(diaryFontStorageServiceProvider).listFonts(),
);

/// 导入字体在引擎中的字族名；字体不在清单里或注册失败时为 null。
///
/// 失败返回 null 而不是抛出：正文回落到内置字体即可，不需要错误态，也避免
/// FutureProvider 对失败的自动重试反复读取大字体文件。
final _importedFontFamilyProvider = FutureProvider.family<String?, String>((
  Ref ref,
  String fontId,
) async {
  final fonts = await ref.watch(diaryImportedFontsProvider.future);
  final font = fonts.where((font) => font.id == fontId).firstOrNull;
  if (font == null) {
    return null;
  }
  try {
    return await ref.read(diaryFontStorageServiceProvider).loadFontFamily(font);
  } catch (error, stack) {
    debugPrint('Diary font $fontId failed to load: $error\n$stack');
    return null;
  }
});

/// 按字体 id 取导入字体的字族名（同上：不在清单或注册失败时为 null）。
///
/// 公开给正文以外同样可选导入字体的地方（如代码块字体），与正文共用同一份
/// 缓存与注册结果，不重复读取字体文件。
final diaryImportedFontFamilyProvider = _importedFontFamilyProvider;

/// 当前正文的可渲染外观：编辑、预览、发布页与设置预览都从这里取样式。
///
/// 导入字体首次注册期间（大字体约数百毫秒）先按内置字体排版，注册完成后
/// 自动换上；应用启动时已提前监听本 provider 预热，通常打开日记前就已就绪。
final diaryTextAppearanceProvider = Provider<DiaryTextAppearance>((Ref ref) {
  final typography = ref.watch(diaryTypographyProvider);
  final importedFamily = typography.usesImportedFont
      ? ref.watch(_importedFontFamilyProvider(typography.fontId)).asData?.value
      : null;
  return DiaryTextAppearance.resolve(
    typography,
    importedFontFamily: importedFamily,
    platform: defaultTargetPlatform,
  );
});

/// 主题携带的字体（见 [AppFonts]）：日记字体始终是正文字体，界面字体只在
/// 开启“用于整个界面”时才换。应用外壳据此装配主题。
///
/// 导入字体注册完成前字族名为 null，主题先按内置字体装配；启动时由
/// [appFontsStartupReadyProvider] 等它就绪，首页不会先用内置字体排一遍。
final appFontsProvider = Provider<AppFonts>((Ref ref) {
  final appearance = ref.watch(diaryTextAppearanceProvider);
  final family = appearance.fontFamily;
  return AppFonts(
    interface: appearance.typography.applyFontToApp ? family : null,
    diary: family,
  );
});

/// 启动门控用：所选导入字体是否已注册（成功、失败或超时都算就绪）。
///
/// 日记卡片（以及开启“用于整个界面”时的整个界面）在首页第一帧就用到导入
/// 字体；不等它注册完，首页会先按内置字体排版、几百毫秒后整体换字体重排，
/// 瀑布流卡片高度随之跳动。上限 [_startupFontWait]：大字体或读盘慢时不让
/// 启动无限等待，超时后照常进入首页，字体就绪时再换上。内置字体与系统字体
/// 不需要注册，立即就绪。
final appFontsStartupReadyProvider = FutureProvider<void>((Ref ref) async {
  final typography = ref.watch(diaryTypographyProvider);
  if (!typography.usesImportedFont) {
    return;
  }
  await ref
      .watch(_importedFontFamilyProvider(typography.fontId).future)
      .timeout(_startupFontWait, onTimeout: () => null);
});

const Duration _startupFontWait = Duration(milliseconds: 1500);
