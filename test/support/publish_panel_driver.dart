import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_meta_actions.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_panel_summary_bar.dart';

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

  BuildContext get _context => tester.element(panelFinder);

  DiaryMetaDraftController get draft => _panel.draft;

  DiaryMetaActions get actions => _panel.actions;

  AppLocalizations get l10n => _context.l10n;

  /// 收起态摘要栏（点按展开、也是拖拽起点）。
  Finder get collapsedHeader => find.byKey(PublishPanelSummaryBar.summaryKey);

  /// 收起栏上的发表按钮（编辑页没有）。
  Finder get collapsedPublishButton =>
      find.byKey(PublishPanelSummaryBar.actionKey);

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

  bool get saving => _panel.busy;

  // ==================== 此时此地 ====================

  String get locationText => draft.locationText.text;

  Finder get locationField => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.controller == draft.locationText,
  );

  /// 模拟用户在地点输入框里输入（不经键盘，直接改文本）。
  void typeLocation(String text) => draft.locationText.text = text;

  DiaryLocationPrecision get precision => draft.value.locationPrecision;

  void changePrecision(DiaryLocationPrecision precision) =>
      _panel.actions.changePrecision(precision);

  void resolveLocation() => _panel.actions.resolveLocation(_context);

  bool get locating => _panel.actions.locating.value;

  String get weatherText => draft.weatherText.text;

  void resolveWeather() => _panel.actions.resolveWeather(_context);

  bool get weatherLoading => _panel.actions.weatherLoading.value;

  // ==================== 其余元数据 ====================

  void setMood(String? mood) => draft.setMood(mood);

  void setEnergy(double? level) => draft.setEnergy(level);

  void toggleTag(int tagId, bool selected) =>
      draft.setTagSelected(tagId, selected);

  bool get showsPublishTime => _panel.publishTime != null;

  String? get publishTimeLabel => _panel.publishTime?.label;

  void pickPublishTime() => _panel.publishTime!.onPick!();
}

/// 单独挂载面板的宿主：英文、亮色 Expressive 主题，面板贴底；标签为空、
/// 心情为默认候选，不触碰数据库与设置。
///
/// [draft] 不传时宿主自建一个（精力 4）。[keyboardLayout] 为 true 时按
/// 发布/编辑页的真实摆放（铺满 body、左右 16、贴底对齐），用于验证键盘
/// 弹出时的位置与展开高度。
Widget publishPanelHost({
  DiaryMetaDraftController? draft,
  bool capsuleEnabled = false,
  PublishTimeOption? publishTime,
  bool keyboardLayout = false,
  List<Tag> tags = const <Tag>[],
  bool publishAction = true,
  VoidCallback? onPublish,
  Brightness brightness = Brightness.light,
  String locale = 'en',
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      tagListProvider.overrideWith((ref) => Stream.value(tags)),
      moodOptionsProvider.overrideWith(
        (ref) => Stream.value(SettingsService.defaultMoodOptions),
      ),
    ],
    child: MaterialApp(
      theme: expressiveTestTheme(brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(locale),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: child!,
      ),
      home: Scaffold(
        body: _PanelHost(
          draft: draft,
          capsuleEnabled: capsuleEnabled,
          publishTime: publishTime,
          keyboardLayout: keyboardLayout,
          onPublish: publishAction ? (onPublish ?? () {}) : null,
        ),
      ),
    ),
  );
}

class _PanelHost extends ConsumerStatefulWidget {
  const _PanelHost({
    required this.draft,
    required this.capsuleEnabled,
    required this.publishTime,
    required this.keyboardLayout,
    required this.onPublish,
  });

  final DiaryMetaDraftController? draft;
  final bool capsuleEnabled;
  final PublishTimeOption? publishTime;
  final bool keyboardLayout;
  final VoidCallback? onPublish;

  @override
  ConsumerState<_PanelHost> createState() => _PanelHostState();
}

class _PanelHostState extends ConsumerState<_PanelHost> {
  DiaryMetaDraftController? _ownDraft;
  late final DiaryMetaDraftController _draft;
  late final DiaryMetaActions _actions;

  @override
  void initState() {
    super.initState();
    _draft =
        widget.draft ??
        (_ownDraft = DiaryMetaDraftController(
          const DiaryMetaDraft(energyLevel: 4),
        ));
    _actions = DiaryMetaActions(ref, draft: _draft);
  }

  @override
  void dispose() {
    _actions.dispose();
    _ownDraft?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panel = PublishDiaryPanel(
      draft: _draft,
      actions: _actions,
      capsuleEnabled: widget.capsuleEnabled,
      publishTime: widget.publishTime,
      onPublish: widget.onPublish,
    );
    return Stack(
      fit: widget.keyboardLayout ? StackFit.expand : StackFit.loose,
      children: <Widget>[
        if (widget.keyboardLayout)
          Positioned.fill(
            left: 16,
            right: 16,
            child: Align(alignment: Alignment.bottomCenter, child: panel),
          )
        else
          Align(alignment: Alignment.bottomCenter, child: panel),
      ],
    );
  }
}
