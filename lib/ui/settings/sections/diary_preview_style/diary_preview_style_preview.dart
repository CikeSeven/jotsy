import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/seeded_theme_cache.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/content_codec.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../diaries/providers/diary_card_style_provider.dart';
import '../../../diaries/providers/diary_preview_style_provider.dart';
import '../../../diaries/viewmodels/diary_preview_resolved_style.dart';
import '../../../diaries/viewmodels/diary_preview_view_data.dart';
import '../../../diaries/widgets/diary_preview/diary_preview_content.dart';
import '../../../diaries/widgets/diary_preview/diary_preview_surface.dart';
import '../../controllers/diary_preview_style_editor_controller.dart';

/// 设置页的实时预览：用正式页面同一套组件（[DiaryPreviewSurface] +
/// [DiaryPreviewContent]）渲染几篇内存示例，左右滑动切换示例。
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
              child: PageView.builder(
                itemCount: samples.length,
                onPageChanged: (int index) => page.value = index,
                itemBuilder: (BuildContext context, int index) => _SamplePage(
                  key: ValueKey<String>(samples[index].diary.diaryId),
                  controller: controller,
                  detail: samples[index],
                  appSeed: seed,
                  bottomPadding: bottomPadding,
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
  });

  final DiaryPreviewStyleEditorController controller;
  final DiaryWithTags detail;
  final Color appSeed;
  final double bottomPadding;

  @override
  ConsumerState<_SamplePage> createState() => _SamplePageState();
}

class _SamplePageState extends ConsumerState<_SamplePage> {
  late final quill.QuillController _quill = quill.QuillController(
    document: decodeDiaryContentToDocument(widget.detail.diary.content),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: true,
  );
  final ScrollController _scroll = ScrollController();
  late final DiaryPreviewViewData _viewData = DiaryPreviewViewData.resolve(
    widget.detail.diary,
  );

  @override
  void dispose() {
    _quill.dispose();
    _scroll.dispose();
    super.dispose();
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
        controller: _quill,
        scrollController: _scroll,
        resolved: resolved,
        behavior: controller.behavior,
        extraBottomPadding: widget.bottomPadding,
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
    final brightness =
        controller.previewBrightness ?? Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
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
          IconButton.filledTonal(
            tooltip: isLight
                ? l10n.styleEditorPreviewDark
                : l10n.styleEditorPreviewLight,
            onPressed: () => controller.previewBrightness = isLight
                ? Brightness.dark
                : Brightness.light,
            icon: FaIcon(
              isLight ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}
