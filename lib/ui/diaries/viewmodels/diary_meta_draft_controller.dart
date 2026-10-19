import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:node_diary/core/services/location_resolver_service.dart';
import 'package:node_diary/core/services/qweather_weather_service.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/utils/optional_text.dart';

/// 元数据面板的可监听草稿：持有当前 [DiaryMetaDraft] 与地点/天气两个输入框。
///
/// 输入：面板上的用户操作（选择封面/标签/心情/精力/胶囊、改地址层级、在
/// 输入框里打字）与异步结果（定位、天气）。
/// 输出：[value] 与变化通知——只在值确实改变时通知，监听者（页面占位、
/// 编辑页自动保存）不会被光标移动、选回同一选项等无效变化触发。
/// 副作用：无（不读写数据库/设置/网络，这些在 DiaryMetaActions）。
///
/// 输入框与草稿双向同步：
/// - 用户打字经输入框监听写回草稿（比较去空白后的文本，选区变化不算）；
/// - 程序写入（恢复、定位/天气回填、层级重组）先置 [_syncingText] 再改
///   输入框，监听里跳过，避免把程序写入当成“用户手改”——那会清掉刚拿到的
///   天气图标或坐标。
class DiaryMetaDraftController extends ChangeNotifier
    implements ValueListenable<DiaryMetaDraft> {
  DiaryMetaDraftController([DiaryMetaDraft initial = const DiaryMetaDraft()])
    : _value = initial {
    _writeText(locationText, initial.location);
    _writeText(weatherText, initial.weather);
    locationText.addListener(_onLocationTextChanged);
    weatherText.addListener(_onWeatherTextChanged);
  }

  final TextEditingController locationText = TextEditingController();
  final TextEditingController weatherText = TextEditingController();

  DiaryMetaDraft _value;
  bool _syncingText = false;

  @override
  DiaryMetaDraft get value => _value;

  void _set(DiaryMetaDraft next) {
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  /// 整体替换（恢复草稿、读回已存日记、发布页带回的草稿）。
  void restore(DiaryMetaDraft draft) {
    _writeText(locationText, draft.location);
    _writeText(weatherText, draft.weather);
    _set(draft);
  }

  void setCover(String? cover) =>
      _set(_value.copyWith(cover: normalizeOptionalText(cover)));

  void setTagSelected(int tagId, bool selected) {
    final tagIds = <int>{..._value.tagIds};
    if (selected) {
      tagIds.add(tagId);
    } else {
      tagIds.remove(tagId);
    }
    _set(_value.copyWith(tagIds: Set<int>.unmodifiable(tagIds)));
  }

  /// 勾选或取消一本日记本；新勾选的排在最后（摘要按勾选先后显示）。
  void setNotebookSelected(String notebookId, bool selected) {
    if (_value.notebookIds.contains(notebookId) == selected) return;
    final notebookIds = selected
        ? <String>{..._value.notebookIds, notebookId}
        : <String>{
            for (final id in _value.notebookIds)
              if (id != notebookId) id,
          };
    _set(_value.copyWith(notebookIds: Set<String>.unmodifiable(notebookIds)));
  }

  void setMood(String? mood) =>
      _set(_value.copyWith(moodEmoji: normalizeOptionalText(mood)));

  /// 精力限制在 1~5；null 表示不记录。
  void setEnergy(double? level) =>
      _set(_value.copyWith(energyLevel: level?.clamp(1, 5).toDouble()));

  /// 胶囊按精度归一后保存（“只按日期”存当天零点）。
  void setCapsule(TimeCapsuleSchedule? schedule) => _set(
    _value.copyWith(
      capsule: schedule == null
          ? null
          : TimeCapsuleSchedule(
              unlockAt: schedule.normalizedUnlockAt,
              precision: schedule.precision,
            ),
    ),
  );

  /// 只重组已解析的地址，不触发定位。仅当前地点仍是自动文案时按新层级
  /// 改写；手动输入原样保留，用户调整下次定位的层级时不丢自己写的地名。
  void setPrecision(DiaryLocationPrecision precision) {
    final current = _value;
    var next = current.copyWith(locationPrecision: precision);
    final followsPrecision =
        current.locationFromAuto &&
        DiaryLocationLabel.isAutoLabel(
          current.location,
          current.locationAddressComponent,
          current.locationPrecision,
        );
    if (followsPrecision) {
      final label = DiaryLocationLabel.format(
        current.locationAddressComponent,
        precision,
      );
      _writeText(locationText, label);
      next = next.copyWith(location: normalizeOptionalText(label));
    }
    _set(next);
  }

  /// 自动定位成功：按当前层级生成地点文案，并记录坐标与地址组件。
  void applyResolvedLocation(ResolvedLocation result) {
    final label = DiaryLocationLabel.format(
      result.addressComponent,
      _value.locationPrecision,
    );
    _writeText(locationText, label);
    _set(
      _value.copyWith(
        location: normalizeOptionalText(label),
        locationAddressComponent: result.addressComponent,
        locationLatitude: result.latitude,
        locationLongitude: result.longitude,
        locationFromAuto: true,
      ),
    );
  }

  void applyWeather(QWeatherNow weather) {
    _writeText(weatherText, weather.displayText);
    _set(
      _value.copyWith(
        weather: normalizeOptionalText(weather.displayText),
        weatherIconCode: normalizeOptionalText(weather.iconCode),
      ),
    );
  }

  /// 手改地点不影响坐标：自动定位后补几个字仍记录在哪里写的日记。清空
  /// 地点视为不记录位置，停止保存 geo；内存坐标保留给天气查询，重新定位
  /// 后恢复保存。
  void _onLocationTextChanged() {
    if (_syncingText) return;
    final location = normalizeOptionalText(locationText.text);
    if (location == _value.location) return;
    _set(
      _value.copyWith(
        location: location,
        locationFromAuto: location == null ? false : null,
      ),
    );
  }

  /// 手改天气文案后旧图标 code 可能与文案不一致，清空后按文案兜底图标。
  void _onWeatherTextChanged() {
    if (_syncingText) return;
    final weather = normalizeOptionalText(weatherText.text);
    if (weather == _value.weather) return;
    _set(_value.copyWith(weather: weather, weatherIconCode: null));
  }

  void _writeText(TextEditingController controller, String? text) {
    final next = text ?? '';
    if (controller.text == next) return;
    _syncingText = true;
    try {
      controller.text = next;
    } finally {
      _syncingText = false;
    }
  }

  @override
  void dispose() {
    locationText.removeListener(_onLocationTextChanged);
    weatherText.removeListener(_onWeatherTextChanged);
    locationText.dispose();
    weatherText.dispose();
    super.dispose();
  }
}
