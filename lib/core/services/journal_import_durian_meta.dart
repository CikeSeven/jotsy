import 'package:sqlite3/sqlite3.dart';

import 'journal_import_support.dart';

/// 榴莲日记的心情、天气、位置与其他元数据（依据应用 0.14x 的逆向分析，
/// 名称取应用的简体中文文案，顺序即数据库里的下标）。

/// 36 种预设心情（`diary.mood` 为 0~35）。
const List<String> durianMoodNames = [
  '开心', '兴奋', '暖心', '甜蜜', '幸福', '感动', '得意', '平静', '纠结', //
  '无语', '尴尬', '惊讶', '同情', '怀念', '期待', '放松', '恐惧', '紧张',
  '焦虑', '困惑', '委屈', '难受', '生气', '担心', '郁闷', '伤心', '愧疚',
  '后悔', '失望', '孤独', '疲惫', '低落', '泄气', '鄙视', '烦闷', '生病',
];

/// 预设心情的表情（应用的 `getMoodEmoji`，“怀念”与“幸福”原本就相同）。
const List<String> durianMoodEmojis = [
  '😄', '🤩', '🥰', '😊', '😍', '🥺', '😏', '😌', '😣', //
  '🙄', '😅', '😲', '🤗', '🥲', '😍', '😎', '😱', '😰',
  '😬', '🤔', '😢', '😖', '😡', '😟', '😔', '😭', '😳',
  '😓', '😞', '🤐', '😫', '😪', '😕', '😒', '😑', '🤒',
];

/// 预设心情的默认心情指数（0~100，应用的 `getMoodDefaultValue`）。
const List<int> durianMoodDefaultValues = [
  85, 90, 80, 85, 95, 75, 70, 60, 35, 30, 30, 55, 45, 40, 70, 75, 15, 25, //
  20, 35, 25, 20, 10, 25, 20, 10, 15, 20, 15, 20, 25, 20, 15, 25, 30, 15,
];

/// 21 种天气（`diary.weather` 为 0~20，-1 为没有天气）。
const List<String> durianWeatherNames = [
  '晴天', '阴', '多云', '小雨', '中雨', '大雨', '雷阵雨', '雨夹雪', '小雪', //
  '中雪', '大雪', '冰雹', '阵雨', '阵雪', '龙卷风', '沙尘暴', '雾', '雾霾',
  '扬尘', '台风', '阵风',
];

/// 毫秒时间戳（UTC）→ 本地时间；0、负数与越界值视为没有。
DateTime? durianTime(Object? value) {
  final number = journalNumber(value);
  return number == null || number <= 0 ? null : journalEpochTime(number);
}

/// 心情 → 1（最差）~ 5（最好），按应用自己的分档（`MoodLevelConfig`：
/// 80~100 极好、60~79 好、40~59 一般、20~39 差、0~19 很差）：
/// - 有心情指数（`mood_value`，应用只认 1~100）时按指数；
/// - 没有指数的预设心情按该心情的默认指数；
/// - -1 没有心情；-2 自定义心情没有指数时无法定级，返回 null（名称与表情
///   仍记在 [durianDetails] 里）。
int? durianMoodLevel(Object? mood, Object? moodValue) {
  final index = journalNumber(mood)?.toInt();
  if (index == null || index == -1) return null;
  final value = journalNumber(moodValue);
  final score = value != null && value >= 1 && value <= 100
      ? value
      : index >= 0 && index < durianMoodDefaultValues.length
      ? durianMoodDefaultValues[index]
      : null;
  if (score == null) return null;
  if (score >= 80) return 5;
  if (score >= 60) return 4;
  if (score >= 40) return 3;
  if (score >= 20) return 2;
  return 1;
}

/// 天气 → `<天气> <温度>℃`：温度是摄氏度、可能单独存在，与应用一样截去
/// 小数（25.7 显示为 25℃）。
String? durianWeather(Object? weather, Object? temperature) {
  final index = journalNumber(weather)?.toInt();
  final name = index != null && index >= 0 && index < durianWeatherNames.length
      ? durianWeatherNames[index]
      : null;
  return journalWeatherText(name, journalNumber(temperature)?.truncate());
}

/// `location` 为 `纬度,经度`；早期数据可能经纬颠倒，与应用的
/// `getLocationCompat` 一样，第一个数超出纬度范围而第二个没有时交换。
({double latitude, double longitude})? durianCoordinate(String location) {
  final parts = location.split(',');
  if (parts.length != 2) return null;
  var latitude = double.tryParse(parts[0].trim());
  var longitude = double.tryParse(parts[1].trim());
  if (latitude == null || longitude == null) return null;
  if (latitude.abs() > 90 && latitude.abs() <= 180 && longitude.abs() <= 90) {
    (latitude, longitude) = (longitude, latitude);
  }
  return isJournalCoordinate(latitude, longitude)
      ? (latitude: latitude, longitude: longitude)
      : null;
}

/// 本应用没有直接对应字段的原始信息，随日记的 import metadata 保留：心情
/// 原名与表情（导入后只剩 1~5 级）、心情指数、评分（0.5~5 星；0 与 -1 为
/// 未评）、
/// 收藏与单篇上锁标记。
Map<String, Object?> durianDetails(Row row) {
  final index = journalNumber(row['mood'])?.toInt();
  final preset = index != null && index >= 0 && index < durianMoodNames.length;
  final mood = preset
      ? durianMoodNames[index]
      : journalString(row['mood_desc']);
  final emoji =
      journalString(row['mood_emoji']) ??
      (preset ? durianMoodEmojis[index] : null);
  final value = journalNumber(row['mood_value']);
  final score = journalNumber(row['score']);
  return {
    if (index != null && index != -1) ...{
      'mood': ?mood,
      'moodEmoji': ?emoji,
      if (value != null && value >= 1 && value <= 100) 'moodValue': value,
    },
    if (score != null && score > 0) 'score': score,
    if (journalNumber(row['favorite']) == 1) 'favorite': true,
    if (journalNumber(row['lock']) == 1) 'locked': true,
  };
}
