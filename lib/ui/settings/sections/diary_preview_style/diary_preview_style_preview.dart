import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/providers/diary_card_style_provider.dart';
import '../../../diaries/providers/diary_comments_provider.dart';
import '../../../diaries/providers/diary_preview_style_provider.dart';
import '../../../diaries/viewmodels/diary_preview_resolved_style.dart';
import '../../../diaries/viewmodels/diary_preview_view_data.dart';
import '../../../diaries/widgets/diary_comments/diary_comments_section.dart';
import '../../../diaries/widgets/diary_preview/diary_pager_view.dart';
import '../../../diaries/widgets/diary_preview/diary_preview_content.dart';
import '../../../diaries/widgets/diary_preview/diary_preview_neighbors.dart';
import '../../../diaries/widgets/diary_preview/diary_preview_surface.dart';
import '../../controllers/diary_preview_style_editor_controller.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import '../../widgets/style_editor/style_preview_background.dart';
import 'diary_preview_style_samples.dart';

/// 设置页的实时预览：用正式页面同一套组件（[DiaryPreviewSurface] +
/// [DiaryPreviewContent]）渲染几篇内存示例，放进与正式页面相同的翻页器
/// （[DiaryPagerView]），可以直接试滑动的灵敏度、翻页效果与到头提示。
///
/// 预览不写库：示例的待办只在本地勾选；顶栏按钮、返回与点按图片都不做事，
/// 免得在设置页里误触离开。明暗可在工具条单独切换（[previewBrightness] 为
/// null 时跟随应用）。
class DiaryPreviewStylePreview extends ConsumerWidget {
  const DiaryPreviewStylePreview({
    super.key,
    required this.controller,
    required this.samples,
    required this.page,
    this.showToolbar = true,
    this.bottomPadding = 0,
  });

  final DiaryPreviewStyleEditorController controller;
  final List<DiaryWithTags> samples;

  /// 当前显示的示例序号（与工具条的页码点共享）。
  final ValueNotifier<int> page;
  final bool showToolbar;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = Theme.of(context);
    final brightness = controller.previewBrightness ?? appTheme.brightness;
    final seed = ref.watch(appThemeSeedColorProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final previewTheme = brightness == appTheme.brightness
        ? appTheme
        : SeededThemeCache.of(seed, brightness, reduceMotion: reduceMotion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showToolbar)
          DiaryPreviewStylePreviewToolbar(
            controller: controller,
            page: page,
            count: samples.length,
          ),
        Expanded(
          child: ClipRect(
            child: Theme(
              data: previewTheme,
              // 与正式预览页一样，预览区域的背景包在翻页器外面（在预览主题
              // 之内，明暗切换时遮罩随之切换）：纸张跟随主题时各篇让位给
              // 背景、翻页器不铺“桌面”，选了纸色时仍是纸色（见
              // diaryPreviewPageColors 与 DiaryPagerView）。
              child: StylePreviewBackground(
                child: DiaryPagerView(
                  itemCount: samples.length,
                  initialPage: page.value.clamp(0, samples.length - 1),
                  navigation: controller.style.navigation,
                  behavior: controller.behavior,
                  onPageChanged: (int index) => page.value = index,
                  itemBuilder: (BuildContext context, DiaryPagerPosition at) {
                    return _SamplePage(
                      key: ValueKey<String>(samples[at.index].diary.diaryId),
                      controller: controller,
                      detail: samples[at.index],
                      appSeed: seed,
                      bottomPadding: bottomPadding,
                      paging: DiaryPreviewPaging.of(
                        context.l10n,
                        at,
                        hasMore: false,
                        titleAt: (int index) => samples[index].diary.title,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SamplePage extends ConsumerStatefulWidget {
  const _SamplePage({
    super.key,
    required this.controller,
    required this.detail,
    required this.appSeed,
    required this.bottomPadding,
    required this.paging,
  });

  final DiaryPreviewStyleEditorController controller;
  final DiaryWithTags detail;
  final Color appSeed;
  final double bottomPadding;
  final DiaryPreviewPaging paging;

  @override
  ConsumerState<_SamplePage> createState() => _SamplePageState();
}

class _SamplePageState extends ConsumerState<_SamplePage> {
  late final DiaryEditorController _body = DiaryEditorController(
    document: diaryEditorDocument(widget.detail.diary.content),
    selection: af.Selection.single(path: [0], startOffset: 0),
    readOnly: true,
  );
  final ScrollController _scroll = ScrollController();
  late final DiaryPreviewViewData _viewData = DiaryPreviewViewData.resolve(
    widget.detail.diary,
  );

  @override
  void dispose() {
    _body.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 开启留言功能时示例正文末尾的留言区（只读）：第一篇示例日记带两条示例
  /// 留言，从预览页带进来的真实日记显示它自己的留言，其余示例没有留言。
  DiaryPreviewComments? _sampleComments(Diary diary) {
    if (!ref.watch(diaryCommentsEnabledProvider)) return null;
    final List<DiaryCommentRow> comments;
    if (!isDiaryPreviewStyleSample(diary.diaryId)) {
      comments =
          ref.watch(diaryCommentsProvider(diary.diaryId)).value ??
          const <DiaryCommentRow>[];
    } else if (diary.id == -1) {
      comments = buildDiaryPreviewStyleSampleComments(
        context.l10n,
        diary,
        now: DateTime.now(),
      );
    } else {
      comments = const <DiaryCommentRow>[];
    }
    return DiaryPreviewComments(
      diaryCreatedAt: diary.createdAt,
      comments: comments,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final detail = widget.detail;
    final resolved = DiaryPreviewResolvedStyle.resolve(
      style: controller.style,
      appTheme: Theme.of(context),
      appSeed: widget.appSeed,
      screenSize: MediaQuery.sizeOf(context),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      moodOptions: ref.watch(diaryCardMoodOptionsProvider),
      moodEmoji: _viewData.moodEmoji,
      firstTagColor: detail.tags.isEmpty ? null : detail.tags.first.color,
    );
    void ignore() {}
    return DiaryPreviewSurface(
      resolved: resolved,
      scrollController: _scroll,
      content: DiaryPreviewContent(
        detail: detail,
        viewData: _viewData,
        controller: _body,
        scrollController: _scroll,
        resolved: resolved,
        behavior: controller.behavior,
        extraBottomPadding: widget.bottomPadding,
        paging: widget.paging,
        comments: _sampleComments(detail.diary),
        onOpenImage: (_, _, hero) => hero?.dispose(),
        actions: DiaryPreviewActions(
          onOpenTypography: ignore,
          onEdit: ignore,
          onShare: ignore,
          onMore: ignore,
          onBack: ignore,
        ),
      ),
    );
  }
}

/// 预览工具条：示例页码点与预览明暗。
class DiaryPreviewStylePreviewToolbar extends StatelessWidget {
  const DiaryPreviewStylePreviewToolbar({
    super.key,
    required this.controller,
    required this.page,
    required this.count,
  });

  final DiaryPreviewStyleEditorController controller;
  final ValueNotifier<int> page;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: page,
              builder: (BuildContext context, int current, Widget? child) {
                return Semantics(
                  label: l10n.diaryPreviewStyleSampleOf(current + 1, count),
                  child: ExcludeSemantics(
                    child: Row(
                      children: <Widget>[
                        for (var i = 0; i < count; i++)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: i == current
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: SizedBox(
                                width: i == current ? 18 : 6,
                                height: 6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          StylePreviewBrightnessButton(controller: controller),
        ],
      ),
    );
  }
}
