import 'dart:async';

import '../../../core/services/feature_tips.dart';
import '../../../core/services/settings_service.dart';

/// 首页标签栏“长按可以多选”的一次性提示（#196）。
///
/// 背景：单击标签以前是增减，现在只切换一个、多选改为长按（桌面上也可以
/// 按住 Ctrl / ⌘ 点击）。用惯了单击多选的人第一次看到已选的标签被换掉时，
/// 不知道多选去了哪里，于是在单击把已选的标签换掉、且用户还没长按过时用
/// 提示条说一次。
///
/// - 输入：[SettingsService]（还没加载出来时为 null，那次不提示）；
/// - 输出：[takeHint] 告诉调用方这次要不要显示提示条（显示由调用方负责）；
/// - 副作用：出现与学会时经 `SettingsService.updateFeatureTips` 只改
///   [FeatureTip.tagFilterMultiSelect] 这一条（本机偏好，不随备份）。
///
/// 频率：每次启动最多一次（同一次启动里接连换几次不重复打扰），累计
/// [FeatureTip.maxShows] 次后不再出现；长按过一次即学会，之后永不出现。
/// 写失败只会让提示多出现一次，吞掉错误。
class TagFilterMultiSelectTip {
  TagFilterMultiSelectTip(this._settings);

  final SettingsService? Function() _settings;

  static const FeatureTip _tip = FeatureTip.tagFilterMultiSelect;

  bool _shownThisRun = false;

  /// 单击把已选的标签换掉了：该提示时记一次出现并返回 true。
  bool takeHint() {
    if (_shownThisRun) return false;
    final settings = _settings();
    if (settings == null) return false;
    if (!FeatureTips.decode(settings.featureTipsRaw).shouldShow(_tip)) {
      return false;
    }
    _shownThisRun = true;
    _update(settings, (latest) => latest.markShown(_tip));
    return true;
  }

  /// 用户长按（或 Ctrl / ⌘ 点击）多选过：之后不再提示。已学会时不写。
  void markLearned() {
    final settings = _settings();
    if (settings == null) return;
    _update(settings, (latest) => latest.markLearned(_tip));
  }

  static void _update(
    SettingsService settings,
    FeatureTips Function(FeatureTips latest) change,
  ) {
    unawaited(settings.updateFeatureTips(change).catchError((Object _) {}));
  }
}
