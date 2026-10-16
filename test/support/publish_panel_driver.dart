import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';

import 'expressive_test_theme.dart';

/// 发布/编辑页元数据面板的测试驱动。
///
/// 页面测试只经这里读取面板状态、触发面板动作，不直接依赖
/// [PublishDiaryPanel] 的构造参数；面板接口重构时只改本文件。
class PublishPanelDriver {
  PublishPanelDriver(this.tester);

  final WidgetTester tester;

  Finder get panelFinder => find.byType(PublishDiaryPanel);

  PublishDiaryPanel get _panel => tester.widget<PublishDiaryPanel>(panelFinder);

  AppLocalizations get l10n => tester.element(panelFinder).l10n;

  /// 收起态表头（点按展开、也是拖拽起点）。
  Finder get collapsedHeader => find.text(l10n.autoT0158);

  /// 展开态表头。
  Finder get expandedHeader => find.text(l10n.autoT0159);

  /// 点按收起态表头展开面板；已展开时不做任何事。
  Future<void> expand() async {
    final header = collapsedHeader;
    if (header.evaluate().isEmpty) return;
    await tester.tap(header);
    await tester.pumpAndSettle();
  }

  /// 面板是否带“发表”主操作（编辑页自动保存时没有）。
  bool get hasPublishAction => _panel.onPublish != null;

  /// 直接触发发表，不依赖按钮当前是否在可视区域内。
  void triggerPublish() => _panel.onPublish!();

  bool get saving => _panel.saving;

  // ==================== 此时此地 ====================

  String get locationText => _panel.locationController.text;

  Finder get locationField => find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.controller == _panel.locationController,
  );

  /// 模拟用户在地点输入框里输入（不经键盘，直接改文本并通知面板）。
  void typeLocation(String text) {
    _panel.locationController.text = text;
    _panel.onLocationChanged(text);
  }

  DiaryLocationPrecision get precision => _panel.locationPrecision;

  void changePrecision(DiaryLocationPrecision precision) =>
      _panel.onLocationPrecisionChanged!(precision);

  void resolveLocation() => _panel.onResolveLocation();

  bool get locating => _panel.locating;

  String get weatherText => _panel.weatherController.text;

  void resolveWeather() => _panel.onResolveWeather();

  bool get weatherLoading => _panel.weatherLoading;

  // ==================== 其余元数据 ====================

  void setMood(String? mood) => _panel.onMoodChanged(mood);

  void toggleTag(int tagId, bool selected) =>
      _panel.onToggleTag(tagId, selected);

  bool get showsPublishTime => _panel.showPublishTimeOption;

  String? get publishTimeLabel => _panel.publishTimeLabel;

  void pickPublishTime() => _panel.onPickPublishTime!();
}

/// 单独挂载面板的宿主：英文、亮色 Expressive 主题，面板贴底。
///
/// [keyboardLayout] 为 true 时按发布/编辑页的真实摆放（`Positioned`
/// 左右 16、贴 body 底边），用于验证键盘弹出时的位置。
Widget publishPanelHost({
  double? energyLevel = 4,
  ValueChanged<double?>? onEnergyChanged,
  bool showTimeCapsuleOption = false,
  ValueChanged<TimeCapsuleSchedule>? onTimeCapsuleChanged,
  bool keyboardLayout = false,
}) {
  final panel = PublishDiaryPanel(
    saving: false,
    hasCover: false,
    coverLabel: null,
    locating: false,
    weatherLoading: false,
    locationController: TextEditingController(),
    weatherController: TextEditingController(),
    weatherIconCode: null,
    moodEmoji: null,
    energyLevel: energyLevel,
    tags: const <Tag>[],
    tagsLoading: false,
    tagsError: null,
    selectedTagIds: const <int>{},
    onPickCover: () {},
    onResolveLocation: () {},
    onResolveWeather: () {},
    onLocationChanged: (_) {},
    onWeatherChanged: (_) {},
    onCreateTag: () {},
    onToggleTag: (_, _) {},
    onMoodChanged: (_) {},
    onEnergyChanged: onEnergyChanged ?? (_) {},
    onPublish: () {},
    showTimeCapsuleOption: showTimeCapsuleOption,
    timeCapsuleLabel: showTimeCapsuleOption ? 'Not sealed' : null,
    onTimeCapsuleChanged: onTimeCapsuleChanged,
  );
  return MaterialApp(
    theme: expressiveTestTheme(Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: Stack(
        fit: keyboardLayout ? StackFit.expand : StackFit.loose,
        children: <Widget>[
          if (keyboardLayout)
            Positioned(left: 16, right: 16, bottom: 0, child: panel)
          else
            Align(alignment: Alignment.bottomCenter, child: panel),
        ],
      ),
    ),
  );
}
