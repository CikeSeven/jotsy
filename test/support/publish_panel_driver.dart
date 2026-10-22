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
import 'package:node_diary/ui/diaries/models/tag_picker_sort.dart';
import 'package:node_diary/ui/diaries/providers/tag_picker_sort_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_panel_summary_bar.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_tag_search_bar.dart';
import 'package:node_diary/ui/notebooks/providers/notebook_providers.dart';
import 'package:node_diary/ui/notebooks/viewmodels/notebook_view.dart';

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

  /// 展开态表头。
  Finder get expandedHeader => find.text(l10n.autoT0159);

  /// 点按收起态表头展开面板；已展开时不做任何事。
  Future<void> expand() async {
    final header = collapsedHeader;
    if (header.evaluate().isEmpty) return;
    await tester.tap(header);
    await tester.pumpAndSettle();
  }

  /// 面板是否锁住（发布页写库前后、退场中，编辑页保存中）。
  bool get busy => _panel.busy;

  /// 发布页进入即发表：等写库完成、面板解锁。写库是真实异步，离开假时钟
  /// 推进；期间每次推进 50ms，路由转场随之播完。
  Future<void> waitUntilPublished() async {
    for (var i = 0; i < 30 && (panelFinder.evaluate().isEmpty || busy); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(busy, isFalse, reason: 'the diary should be published by now');
  }

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

  /// 展开面板并进入标签子页。
  Future<void> openTags() async {
    await expand();
    await tester.tap(find.text(l10n.autoT0109));
    await tester.pumpAndSettle();
  }

  /// 标签子页的搜索框。
  Finder get tagSearchField => find.descendant(
    of: find.byType(PublishTagSearchBar),
    matching: find.byType(TextField),
  );

  /// 标签子页的排序按钮（按提示文字找）。
  Finder get tagSortButton => find.byTooltip(l10n.tagPickerSortTooltip);

  /// 在排序菜单里选一种排序方式。
  Future<void> chooseTagSort(TagPickerSort sort) async {
    await tester.tap(tagSortButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(switch (sort) {
        TagPickerSort.custom => l10n.tagPickerSortCustom,
        TagPickerSort.alphabetical => l10n.tagPickerSortAlphabetical,
      }),
    );
    await tester.pumpAndSettle();
  }

  bool get showsPublishTime => _panel.publishTime != null;

  String? get publishTimeLabel => _panel.publishTime?.label;

  void pickPublishTime() => _panel.publishTime!.onPick!();
}

/// 单独挂载面板的宿主：英文、亮色 Expressive 主题，面板贴底；标签与日记本
/// 为空、心情为默认候选，不触碰数据库与设置（标签子页的排序方式从
/// [tagPickerSort] 开始、只记在内存里）。
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
  Brightness brightness = Brightness.light,
  String locale = 'en',
  double textScale = 1,
  TagPickerSort tagPickerSort = TagPickerSort.custom,
}) {
  return ProviderScope(
    overrides: [
      tagListProvider.overrideWith((ref) => Stream.value(tags)),
      tagPickerSortProvider.overrideWith(
        () => _MemoryTagPickerSort(tagPickerSort),
      ),
      moodOptionsProvider.overrideWith(
        (ref) => Stream.value(SettingsService.defaultMoodOptions),
      ),
      notebooksProvider.overrideWith(
        (ref) => Stream.value(const <NotebookView>[]),
      ),
      notebookEntryCountsProvider.overrideWith(
        (ref) => Stream.value(const <String, int>{}),
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
        ),
      ),
    ),
  );
}

/// 只在内存里记住选择的排序方式，不读写设置。
class _MemoryTagPickerSort extends TagPickerSortNotifier {
  _MemoryTagPickerSort(this._initial);

  final TagPickerSort _initial;

  @override
  TagPickerSort build() => _initial;

  @override
  void select(TagPickerSort sort) => state = sort;
}

class _PanelHost extends ConsumerStatefulWidget {
  const _PanelHost({
    required this.draft,
    required this.capsuleEnabled,
    required this.publishTime,
    required this.keyboardLayout,
  });

  final DiaryMetaDraftController? draft;
  final bool capsuleEnabled;
  final PublishTimeOption? publishTime;
  final bool keyboardLayout;

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
