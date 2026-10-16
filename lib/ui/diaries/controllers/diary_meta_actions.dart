import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/diary_cover_storage_service.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
import 'package:node_diary/core/services/location_resolver_service.dart';
import 'package:node_diary/core/services/qweather_weather_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_location_preference.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/location_resolve_hint.dart';
import 'package:node_diary/ui/diaries/models/weather_resolve_hint.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/widgets/create_tag_dialog.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';

/// 元数据面板的异步动作：选封面、新建标签、改地址层级、自动定位、取天气。
///
/// 发布页与编辑页共用。输入是用户操作与调用方页面的 [BuildContext]；
/// 结果写进 [draft]，进行中的状态经 [locating] / [weatherLoading] /
/// [importingCover] 暴露给面板。副作用：文件选择与复制、写标签表、地址
/// 层级偏好、定位与天气网络请求、轻提示。
///
/// 异步约束：
/// - 每个 await 之后先看 `context.mounted`：页面已销毁时不再读 ref、不写
///   草稿、不弹提示（导入的封面文件删掉，避免孤儿文件）；
/// - 提示一律不等待关闭，loading 在 finally 里立即复位；
/// - 同一动作进行中重复触发直接忽略。
class DiaryMetaActions {
  DiaryMetaActions(
    this._ref, {
    required this.draft,
    this.autoWeatherAfterLocate = false,
    bool Function()? isBusy,
  }) : _isBusy = isBusy ?? _never;

  static bool _never() => false;

  final WidgetRef _ref;
  final DiaryMetaDraftController draft;

  /// 定位成功且天气为空时顺带静默取一次天气。只在发布页开启：编辑旧日记
  /// 时重新定位，不该把今天的天气写进去。
  final bool autoWeatherAfterLocate;

  /// 页面忙碌（如正在写库）时不接受改层级等操作。
  final bool Function() _isBusy;

  final ValueNotifier<bool> locating = ValueNotifier<bool>(false);
  final ValueNotifier<bool> weatherLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> importingCover = ValueNotifier<bool>(false);
  bool _disposed = false;

  /// 任一进行中状态变化时通知。
  late final Listenable activity = Listenable.merge(<Listenable>[
    locating,
    weatherLoading,
    importingCover,
  ]);

  /// 选择封面并拷贝到应用私有目录。
  ///
  /// 被替换的旧封面不在这里删除：它可能已写入草稿或数据库，进程在保存前
  /// 被杀会留下坏封面；无人引用后由 DiaryMediaCleanupService 回收。
  Future<void> pickCover(BuildContext context) async {
    if (importingCover.value) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || !context.mounted) return;

    final selectedPath = result.files.first.path?.trim();
    if (selectedPath == null || selectedPath.isEmpty) {
      _hint(context, context.l10n.autoT0088);
      return;
    }

    _setFlag(importingCover, true);
    try {
      final importedPath = await DiaryCoverStorageService.importCover(
        selectedPath,
      );
      if (!context.mounted) {
        await DiaryCoverStorageService.deleteManagedCover(importedPath);
        return;
      }
      draft.setCover(importedPath);
    } catch (error) {
      debugPrint('Cover import failed: $error');
      if (context.mounted) {
        _hint(context, context.l10n.publishCoverImportFailed);
      }
    } finally {
      _setFlag(importingCover, false);
      await DiaryMediaStorageService.discardPickerCopy(selectedPath);
    }
  }

  /// 清除封面；文件同样交给 DiaryMediaCleanupService 按引用回收。
  void clearCover() => draft.setCover(null);

  /// 内联新建标签，成功后自动选中。
  Future<void> createTag(BuildContext context) async {
    final tag = await showCreateTagDialog(context);
    if (tag == null || !context.mounted) return;
    try {
      final tagId = await _ref
          .read(appDatabaseProvider)
          .createTag(name: tag.name, color: tag.color);
      if (!context.mounted) return;
      draft.setTagSelected(tagId, true);
    } catch (error) {
      debugPrint('Tag creation failed: $error');
      if (context.mounted) {
        _hint(context, context.l10n.publishTagCreateFailed);
      }
    }
  }

  /// 改地址层级，同时记为新建日记的默认层级（必须在同步阶段读 ref）。
  void changePrecision(DiaryLocationPrecision precision) {
    if (locating.value || _isBusy()) return;
    unawaited(DiaryLocationPreference.remember(_ref, precision));
    draft.setPrecision(precision);
  }

  /// 自动定位并逆地理解析，按当前层级回填地点。
  Future<void> resolveLocation(BuildContext context) async {
    if (locating.value) return;
    _setFlag(locating, true);
    var located = false;
    try {
      final service = await _ref.read(locationResolverServiceProvider.future);
      if (!context.mounted) return;
      if (service == null) {
        throw LocationResolveException(
          type: LocationResolveErrorType.missingApiKey,
          message: context.l10n.autoT0204,
        );
      }
      final result = await service.resolveCurrentLocation();
      if (!context.mounted) return;
      draft.applyResolvedLocation(result);
      located = true;
    } on LocationResolveException catch (error) {
      if (context.mounted) {
        _hint(context, locationResolveHint(context.l10n, error.type));
      }
    } catch (error) {
      debugPrint('Location failed: $error');
      if (context.mounted) {
        _hint(context, context.l10n.locationUnavailable);
      }
    } finally {
      _setFlag(locating, false);
    }
    if (located &&
        autoWeatherAfterLocate &&
        draft.value.weather == null &&
        context.mounted) {
      await resolveWeather(context, silent: true);
    }
  }

  /// 按当前坐标请求实时天气并回填。
  ///
  /// [silent] 用于定位后的自动补天气：失败不打扰用户（手动点按钮时才提示）。
  Future<void> resolveWeather(
    BuildContext context, {
    bool silent = false,
  }) async {
    if (weatherLoading.value) return;
    final latitude = draft.value.locationLatitude;
    final longitude = draft.value.locationLongitude;
    if (latitude == null || longitude == null) {
      if (!silent) _hint(context, context.l10n.autoT0092);
      return;
    }

    _setFlag(weatherLoading, true);
    try {
      final service = await _ref.read(weatherServiceProvider.future);
      if (!context.mounted) return;
      if (service == null) {
        throw QWeatherException(
          type: QWeatherErrorType.missingConfig,
          message: context.l10n.autoT0205,
        );
      }
      final settings = await _ref.read(settingsServiceProvider.future);
      final weather = await service.fetchNow(
        latitude: latitude,
        longitude: longitude,
        languageCode: settings.appLocaleCode,
      );
      if (!context.mounted) return;
      draft.applyWeather(weather);
    } on QWeatherException catch (error) {
      debugPrint('Weather fetch failed: ${error.message}');
      if (!silent && context.mounted) {
        _hint(context, weatherResolveHint(context.l10n, error.type));
      }
    } catch (error) {
      debugPrint('Weather fetch failed: $error');
      if (!silent && context.mounted) {
        _hint(context, context.l10n.weatherApiError);
      }
    } finally {
      _setFlag(weatherLoading, false);
    }
  }

  /// 页面销毁后异步收尾不再写已释放的通知器。
  void _setFlag(ValueNotifier<bool> flag, bool value) {
    if (!_disposed) flag.value = value;
  }

  /// 轻提示不等待关闭：等待会把 finally 里的 loading 复位拖后约 4 秒。
  void _hint(BuildContext context, String message) {
    if (!context.mounted) return;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }

  void dispose() {
    _disposed = true;
    locating.dispose();
    weatherLoading.dispose();
    importingCover.dispose();
  }
}
