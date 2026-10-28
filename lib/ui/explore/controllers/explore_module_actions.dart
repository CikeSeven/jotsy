import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../anniversaries/controllers/anniversary_navigation.dart'
    as anniversary_navigation;
import '../../anniversaries/models/anniversary_draft.dart';
import '../../diaries/controllers/diary_create_entry_flow.dart';
import '../../diaries/controllers/diary_open_flow.dart';
import '../../diaries/pages/diary_drafts_page.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/pages/diary_search_page.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../notebooks/controllers/notebook_navigation.dart';
import '../../notebooks/pages/notebooks_page.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../widgets/image_viewer_hero.dart';
import '../../widgets/image_viewer_page.dart';
import '../models/explore_module_id.dart';
import '../models/explore_view_data.dart';
import '../pages/explore_media_gallery_page.dart';
import '../providers/explore_settings_provider.dart';
import '../viewmodels/explore_labels.dart';

/// 探索页卡片里的跳转与写入动作。
///
/// 卡片只描述“点了什么”，动作统一由这里交给各模块现成的流程（打开日记、
/// 搜索、看图、新建、纪念日、日记本……），页面经 [ExploreActionsScope] 提供；
/// 编辑页的实时预览用 [ExploreModuleActions.inert]，点按什么都不做。
abstract class ExploreModuleActions {
  const ExploreModuleActions();

  /// 预览里的卡片：不跳转、不写入，长按菜单也不出现。
  static const ExploreModuleActions inert = _InertExploreActions();

  /// 是否真的响应点按（预览为 false）。
  bool get interactive => true;

  /// 打开一篇日记；[sequence] 给出时可在这些日记里左右翻。
  void openDiary(String diaryId, {List<String>? sequence});

  void openTagSearch(int tagId);

  void openMediaGallery();

  /// 打开看图页：[cellContext] 为被点缩略图的 context（抓取共享元素画面）。
  void openImage(
    BuildContext cellContext,
    List<ExploreMediaItem> items,
    int index, {
    required Object Function(String source) heroTag,
  });

  /// 新建日记（与首页 FAB 同一条流程，有草稿时先弹草稿面板）。
  void createDiary();

  void openDrafts();

  void openAnniversary(Anniversary row);

  void openAnniversaryList();

  void addAnniversary();

  void openNotebook(NotebookView notebook);

  void openNotebooks();

  /// 打开探索页自定义（[focus] 给出时定位到这张卡）。
  void customize({ExploreModuleId? focus});

  /// 隐藏一张卡（带撤销）。
  void hideModule(ExploreModuleId id);
}

/// 把 [ExploreModuleActions] 交给探索页里的卡片。
class ExploreActionsScope extends InheritedWidget {
  const ExploreActionsScope({
    super.key,
    required this.actions,
    required super.child,
  });

  final ExploreModuleActions actions;

  static ExploreModuleActions of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ExploreActionsScope>()
          ?.actions ??
      ExploreModuleActions.inert;

  @override
  bool updateShouldNotify(ExploreActionsScope oldWidget) =>
      !identical(actions, oldWidget.actions);
}

class _InertExploreActions extends ExploreModuleActions {
  const _InertExploreActions();

  @override
  bool get interactive => false;

  @override
  void openDiary(String diaryId, {List<String>? sequence}) {}

  @override
  void openTagSearch(int tagId) {}

  @override
  void openMediaGallery() {}

  @override
  void openImage(
    BuildContext cellContext,
    List<ExploreMediaItem> items,
    int index, {
    required Object Function(String source) heroTag,
  }) {}

  @override
  void createDiary() {}

  @override
  void openDrafts() {}

  @override
  void openAnniversary(Anniversary row) {}

  @override
  void openAnniversaryList() {}

  @override
  void addAnniversary() {}

  @override
  void openNotebook(NotebookView notebook) {}

  @override
  void openNotebooks() {}

  @override
  void customize({ExploreModuleId? focus}) {}

  @override
  void hideModule(ExploreModuleId id) {}
}

/// 探索页上的真实动作。
///
/// [context] 为探索页自己的 context（页面挂载期间不变）；异步流程回来后先
/// 检查 `context.mounted`。提示一律经 [HomeHintVisibilityScope.showTrackedSnackBar]，
/// 带撤销的显式 `persist: false`。[onCustomize] 由页面提供（打开自定义页）。
class ExplorePageActions extends ExploreModuleActions {
  ExplorePageActions({
    required this.context,
    required this.ref,
    required this.onCustomize,
  });

  final BuildContext context;
  final WidgetRef ref;
  final void Function(ExploreModuleId? focus) onCustomize;

  @override
  void openDiary(String diaryId, {List<String>? sequence}) =>
      unawaited(_openDiary(diaryId, sequence));

  /// 打开预览页（“打开日记时直接编辑”开启时为编辑页，见 [openDiaryPage]）；
  /// 在里面删除时给 4 秒撤销，撤销即从回收站恢复。
  Future<void> _openDiary(String diaryId, List<String>? sequence) async {
    final database = ref.read(appDatabaseProvider);
    final result = await openDiaryPage(
      context,
      ref,
      diaryId: diaryId,
      sequence: sequence == null || sequence.length < 2
          ? null
          : DiaryPreviewSequence(ids: sequence),
    );
    final deletedId = result?.diaryId;
    if (deletedId == null || !context.mounted) return;
    final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(context.l10n.autoT0075),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: context.l10n.commonUndo,
          onPressed: () {},
        ),
      ),
    );
    if (reason == SnackBarClosedReason.action) {
      await database.restoreDiary(deletedId, touchUpdatedAt: false);
    }
  }

  @override
  void openTagSearch(int tagId) {
    unawaited(
      Navigator.of(
        context,
      ).push(DiarySearchPage.buildRoute(initialTagIds: <int>{tagId})),
    );
  }

  @override
  void openMediaGallery() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ExploreMediaGalleryPage(),
        ),
      ),
    );
  }

  @override
  void openImage(
    BuildContext cellContext,
    List<ExploreMediaItem> items,
    int index, {
    required Object Function(String source) heroTag,
  }) {
    // 媒体卡与媒体画廊一样是“日记不在下层”的入口，看图页可直接打开日记。
    openImageViewer(
      context,
      items: <ImageViewerItem>[
        for (final item in items)
          ImageViewerItem(source: item.source, diaryId: item.diaryId),
      ],
      initialIndex: index,
      hero: ImageViewerHero.capture(
        cellContext,
        tag: heroTag(items[index].source),
      ),
      onOpenDiary: (String diaryId) => unawaited(_openDiary(diaryId, null)),
    );
  }

  @override
  void createDiary() => unawaited(runDiaryCreateEntryFlow(context, ref));

  @override
  void openDrafts() {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const DiaryDraftsPage())),
    );
  }

  @override
  void openAnniversary(Anniversary row) {
    unawaited(
      anniversary_navigation.openAnniversaryDetail(
        context,
        anniversaryId: row.anniversaryId,
        initial: row,
      ),
    );
  }

  @override
  void openAnniversaryList() =>
      unawaited(anniversary_navigation.openAnniversaryList(context));

  @override
  void addAnniversary() {
    final now = DateTime.now();
    unawaited(
      anniversary_navigation.openAnniversaryEditor(
        context,
        database: ref.read(appDatabaseProvider),
        draft: AnniversaryDraft.forDay(now, today: now),
      ),
    );
  }

  @override
  void openNotebook(NotebookView notebook) =>
      unawaited(openNotebookFromAnywhere(context, ref, notebook));

  @override
  void openNotebooks() {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const NotebooksPage())),
    );
  }

  @override
  void customize({ExploreModuleId? focus}) => onCustomize(focus);

  @override
  void hideModule(ExploreModuleId id) => unawaited(_hideModule(id));

  /// 隐藏后给 4 秒撤销：撤销时在当时最新的布局上把这张卡改回显示（期间
  /// 别处改了布局也不会被覆盖）。
  Future<void> _hideModule(ExploreModuleId id) async {
    final service = ref.read(settingsServiceProvider).asData?.value;
    if (service == null) return;
    Future<void> setVisible(bool visible) {
      final settings = ref.read(exploreSettingsProvider);
      final layout = settings.current;
      return saveExploreSettings(
        service,
        settings.withCurrent(
          layout.withModule(layout.module(id).copyWith(visible: visible)),
        ),
      );
    }

    await setVisible(false);
    if (!context.mounted) return;
    final l10n = context.l10n;
    final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(
          l10n.exploreModuleHidden(ExploreLabels.moduleName(l10n, id)),
        ),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(label: l10n.commonUndo, onPressed: () {}),
      ),
    );
    if (reason == SnackBarClosedReason.action) await setVisible(true);
  }
}
