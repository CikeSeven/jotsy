import 'package:flutter/foundation.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/utils/optional_text.dart';

/// 日记元数据面板的草稿值（不可变）。
///
/// 发布页与编辑页的底部面板编辑同一组字段：封面、标签、所在日记本、此时此地
/// （地点 + 地址层级 + 坐标）、天气、心情、精力，以及（仅发布页）时间胶囊。
///
/// 所在日记本（[notebookIds]）不在 metadata 里，而是日记与日记本的关联表；
/// 编辑页只在用户改过时才写回（见 `EditDiarySnapshot.notebookIds`）。两页
/// 以前各自用十几个状态字段镜像这组值；收拢为一个值对象后：
/// - 草稿往返（编辑页 ↔ 发布页）经 [fromNewDiaryDraft] / [applyTo] 一处换算；
/// - 写 metadata 经 PublishMetadataComposer.composeDraft，读 metadata 经
///   PublishMetadataComposer.parse，两边对称；
/// - 值相等（[==]）可用来判断“确实变了”，只在变化时通知与自动保存。
///
/// 发表时间不在这里：它是日记的 created_at 列而不是 metadata，编辑页只改
/// 时间时不该重组 metadata。
@immutable
class DiaryMetaDraft {
  const DiaryMetaDraft({
    this.cover,
    this.tagIds = const <int>{},
    this.notebookIds = const <String>{},
    this.location,
    this.locationAddressComponent,
    this.locationLatitude,
    this.locationLongitude,
    this.locationFromAuto = false,
    this.locationPrecision = DiaryLocationPrecision.township,
    this.weather,
    this.weatherIconCode,
    this.moodEmoji,
    this.energyLevel,
    this.capsule,
  });

  /// 从编辑页 ↔ 发布页传递的草稿中取出元数据部分。
  ///
  /// 空白文本归一为 null；历史草稿里越界的精力值限制到 1~5。
  factory DiaryMetaDraft.fromNewDiaryDraft(NewDiaryDraft draft) {
    final capsuleUnlockAt = draft.capsuleUnlockAt;
    return DiaryMetaDraft(
      cover: normalizeOptionalText(draft.cover),
      tagIds: Set<int>.unmodifiable(draft.selectedTagIds),
      notebookIds: Set<String>.unmodifiable(draft.notebookIds),
      location: normalizeOptionalText(draft.location),
      locationAddressComponent: draft.locationAddressComponent,
      locationLatitude: draft.locationLatitude,
      locationLongitude: draft.locationLongitude,
      locationFromAuto: draft.locationFromAuto,
      locationPrecision: draft.locationPrecision,
      weather: normalizeOptionalText(draft.weather),
      weatherIconCode: normalizeOptionalText(draft.weatherIconCode),
      moodEmoji: normalizeOptionalText(draft.moodEmoji),
      energyLevel: draft.energyLevel?.clamp(1, 5).toDouble(),
      capsule: capsuleUnlockAt == null
          ? null
          : TimeCapsuleSchedule(
              unlockAt: capsuleUnlockAt,
              precision: TimeCapsuleSchedule.parsePrecision(
                draft.capsulePrecision,
              ),
            ),
    );
  }

  static const Object _unchanged = Object();

  final String? cover;
  final Set<int> tagIds;

  /// 所在的日记本（业务 id），按加入的先后（摘要里先显示先选的）。
  final Set<String> notebookIds;
  final String? location;

  /// 自动定位得到的地址组件，用于按层级重组地点文案与层级菜单预览。
  final Map<String, Object?>? locationAddressComponent;
  final double? locationLatitude;
  final double? locationLongitude;

  /// 坐标是否随 metadata 保存（geo）：自动定位后为 true，清空地点后为 false。
  final bool locationFromAuto;
  final DiaryLocationPrecision locationPrecision;
  final String? weather;
  final String? weatherIconCode;
  final String? moodEmoji;
  final double? energyLevel;
  final TimeCapsuleSchedule? capsule;

  bool get hasCoordinates =>
      locationLatitude != null && locationLongitude != null;

  /// 层级菜单预览用的地址组件：只有自动定位的地点才按层级重组。
  Map<String, Object?>? get autoAddressComponent =>
      locationFromAuto ? locationAddressComponent : null;

  /// 把元数据写回草稿：标题、正文、发表时间、metadataJson 等沿用 [base]。
  NewDiaryDraft applyTo(NewDiaryDraft base) {
    final schedule = capsule;
    return base.copyWith(
      cover: cover,
      selectedTagIds: <int>{...tagIds},
      notebookIds: notebookIds.toList(growable: false),
      location: location,
      locationAddressComponent: locationAddressComponent,
      locationLatitude: locationLatitude,
      locationLongitude: locationLongitude,
      locationFromAuto: locationFromAuto,
      locationPrecision: locationPrecision,
      weather: weather,
      weatherIconCode: weatherIconCode,
      moodEmoji: moodEmoji,
      energyLevel: energyLevel,
      capsuleUnlockAt: schedule?.normalizedUnlockAt,
      capsulePrecision: schedule == null
          ? null
          : TimeCapsuleSchedule.encodePrecision(schedule.precision),
    );
  }

  /// 可空字段传入 null 表示清空；不传表示沿用旧值。
  DiaryMetaDraft copyWith({
    Object? cover = _unchanged,
    Set<int>? tagIds,
    Set<String>? notebookIds,
    Object? location = _unchanged,
    Object? locationAddressComponent = _unchanged,
    Object? locationLatitude = _unchanged,
    Object? locationLongitude = _unchanged,
    bool? locationFromAuto,
    DiaryLocationPrecision? locationPrecision,
    Object? weather = _unchanged,
    Object? weatherIconCode = _unchanged,
    Object? moodEmoji = _unchanged,
    Object? energyLevel = _unchanged,
    Object? capsule = _unchanged,
  }) {
    T? pick<T>(Object? next, T? current) =>
        identical(next, _unchanged) ? current : next as T?;
    return DiaryMetaDraft(
      cover: pick<String>(cover, this.cover),
      tagIds: tagIds ?? this.tagIds,
      notebookIds: notebookIds ?? this.notebookIds,
      location: pick<String>(location, this.location),
      locationAddressComponent: pick<Map<String, Object?>>(
        locationAddressComponent,
        this.locationAddressComponent,
      ),
      locationLatitude: pick<double>(locationLatitude, this.locationLatitude),
      locationLongitude: pick<double>(
        locationLongitude,
        this.locationLongitude,
      ),
      locationFromAuto: locationFromAuto ?? this.locationFromAuto,
      locationPrecision: locationPrecision ?? this.locationPrecision,
      weather: pick<String>(weather, this.weather),
      weatherIconCode: pick<String>(weatherIconCode, this.weatherIconCode),
      moodEmoji: pick<String>(moodEmoji, this.moodEmoji),
      energyLevel: pick<double>(energyLevel, this.energyLevel),
      capsule: pick<TimeCapsuleSchedule>(capsule, this.capsule),
    );
  }

  /// 地址组件按引用比较：它只会整体替换（重新定位），从不原地修改。
  @override
  bool operator ==(Object other) =>
      other is DiaryMetaDraft &&
      other.cover == cover &&
      setEquals(other.tagIds, tagIds) &&
      setEquals(other.notebookIds, notebookIds) &&
      other.location == location &&
      identical(other.locationAddressComponent, locationAddressComponent) &&
      other.locationLatitude == locationLatitude &&
      other.locationLongitude == locationLongitude &&
      other.locationFromAuto == locationFromAuto &&
      other.locationPrecision == locationPrecision &&
      other.weather == weather &&
      other.weatherIconCode == weatherIconCode &&
      other.moodEmoji == moodEmoji &&
      other.energyLevel == energyLevel &&
      other.capsule == capsule;

  @override
  int get hashCode => Object.hash(
    cover,
    Object.hashAllUnordered(tagIds),
    Object.hashAllUnordered(notebookIds),
    location,
    identityHashCode(locationAddressComponent),
    locationLatitude,
    locationLongitude,
    locationFromAuto,
    locationPrecision,
    weather,
    weatherIconCode,
    moodEmoji,
    energyLevel,
    capsule,
  );
}
