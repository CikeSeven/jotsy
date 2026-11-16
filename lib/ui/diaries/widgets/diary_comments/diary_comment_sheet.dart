import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../../core/database/rich_text/inline_rich_text.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_card_surface.dart';
import '../../../settings/providers/app_features_provider.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../../widgets/keyboard_visibility.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../controllers/diary_comment_images_controller.dart';
import '../../controllers/diary_comment_text_editing.dart';
import '../../controllers/diary_link_search.dart';
import '../../models/diary_link_candidate.dart';
import '../diary_link/diary_link_candidate_list.dart';
import 'diary_comment_format_bar.dart';
import 'diary_comment_image_strip.dart';
import 'diary_comment_sheet_parts.dart';
import 'diary_comment_text.dart';

/// 写留言面板的结果：去掉首尾空白的文字与格式、可选心情与图片。
@immutable
class DiaryCommentDraft {
  const DiaryCommentDraft({
    required this.content,
    this.runs,
    this.mood,
    this.images = const <String>[],
    this.freshImages = const <String>[],
  });

  final String content;

  /// [content] 按格式分好的段（与它同样去掉了首尾空白）；null 为没有格式。
  final List<InlineTextRun>? runs;
  final String? mood;

  /// 保存后这条留言的全部图片（托管路径），按添加顺序。
  final List<String> images;

  /// 其中本次面板里新复制进来的：写库失败时由调用方删掉（见
  /// [DiaryCommentImagesController.handOff]）。
  final List<String> freshImages;
}

/// 打开写留言 / 编辑留言面板；取消返回 null。
///
/// [title] 由调用方给出（新写时带“写下后 N 天”，编辑时为“编辑留言”）；
/// [moodOptions] 是用户的日记心情选项（与写日记时同一组）；[initial] 为要
/// 编辑的留言，内容、格式、心情与图片原样带入，没有改动时“保存”不可点。
/// [initialDraft] 为新留言预填完整内容，仍须用户确认，不受“没有改动”限制。
/// [diaryId] 为留言所属的日记：日记链接的候选里不列出它。
/// [imagesController] 只供测试注入（替换选图与复制），由注入方释放。
Future<DiaryCommentDraft?> showDiaryCommentSheet(
  BuildContext context, {
  required String title,
  required List<String> moodOptions,
  String? diaryId,
  DiaryCommentRow? initial,
  DiaryCommentDraft? initialDraft,
  @visibleForTesting DiaryCommentImagesController? imagesController,
}) {
  return showAppModalBottomSheet<DiaryCommentDraft>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => DiaryCommentSheet(
      title: title,
      moodOptions: moodOptions,
      diaryId: diaryId,
      initial: initial,
      initialDraft: initialDraft,
      imagesController: imagesController,
    ),
  );
}

/// 写留言面板：标题、心情一行（可不选）、多行输入框、格式条、已添加的
/// 图片，底部左边“添加图片”、右边“取消 / 保存”。
///
/// 输入框用普通文字键盘、自动获得焦点；面板自己按键盘高度垫底
/// （`showAppModalBottomSheet` 不处理键盘）。字数上限
/// [kDiaryCommentMaxLength]，接近上限时才显示计数。文字与图片至少有一样
/// 才能保存；图片最多 [kDiaryCommentMaxImages] 张，选图与复制经
/// [DiaryCommentImagesController]，复制期间不能保存。选图的结果（多选被截掉、
/// 失败、没有权限）写在按钮上方的一行小字里：提示条在面板下面，看不见。
///
/// 格式与链接（[DiaryCommentTextEditing]）：输入框下方的格式条设粗体、
/// 斜体、下划线、删除线，链接按钮打开正文同款的链接对话框（网址 / 日记 /
/// 日记本）；打 `@` 或 `[[`（`【【`）在输入框下方列出日记与日记本候选，
/// 点选（或回车）即写成日记链接。候选开着时返回键先结束候选。
class DiaryCommentSheet extends ConsumerStatefulWidget {
  const DiaryCommentSheet({
    super.key,
    required this.title,
    required this.moodOptions,
    this.diaryId,
    this.initial,
    this.initialDraft,
    this.imagesController,
  });

  final String title;
  final List<String> moodOptions;

  /// 留言所属的日记；日记链接的候选里不列出它。
  final String? diaryId;
  final DiaryCommentRow? initial;

  /// 测试注入；为 null 时面板自己创建（并在关闭时释放）。
  final DiaryCommentImagesController? imagesController;

  /// 新留言的预填内容（例如 AI 回应），不是编辑已有留言。保留完整文字，
  /// 超出上限时由用户缩短后保存，不在打开面板时静默截断。
  final DiaryCommentDraft? initialDraft;

  @override
  ConsumerState<DiaryCommentSheet> createState() => _DiaryCommentSheetState();
}

class _DiaryCommentSheetState extends ConsumerState<DiaryCommentSheet> {
  late final DiaryCommentTextEditing _editing = DiaryCommentTextEditing(
    runs: _initialRuns,
    search: _searchCandidates,
    kinds: () => <DiaryLinkKind>{
      DiaryLinkKind.diary,
      if (ref.read(appFeaturesProvider).notebooks) DiaryLinkKind.notebook,
    },
    excludeDiaryId: widget.diaryId,
    onOpenLinkDialog: () => _editing.editLink(context),
  );
  late String? _mood = widget.initial?.mood ?? widget.initialDraft?.mood;
  late final DiaryCommentImagesController _images =
      (widget.imagesController ??
            DiaryCommentImagesController(
              initial:
                  widget.initial?.imagePaths ??
                  widget.initialDraft?.images ??
                  const <String>[],
            ))
        ..addListener(_handleChanged);

  /// 上一次选图的结果提示（只留需要说明的几种）；再选一次或移除图片时清掉。
  DiaryCommentImagePickResult? _pickNotice;

  /// 计数在剩下不到一成时才出现，平时不分散注意力。
  static const int _counterFrom = kDiaryCommentMaxLength * 9 ~/ 10;

  List<InlineTextRun> get _initialRuns {
    final initial = widget.initial;
    if (initial != null) return initial.textRuns;
    final draft = widget.initialDraft;
    if (draft?.runs case final runs?) return runs;
    final content = draft?.content ?? '';
    return content.isEmpty
        ? const <InlineTextRun>[]
        : <InlineTextRun>[InlineTextRun(content)];
  }

  @override
  void initState() {
    super.initState();
    _editing.text.addListener(_handleChanged);
    _editing.mention.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _editing.text.removeListener(_handleChanged);
    _editing.mention.removeListener(_handleChanged);
    _editing.dispose();
    _images.removeListener(_handleChanged);
    // 注入的控制器由注入方释放；自己创建的在这里释放——没保存就关掉面板时，
    // 它会删掉本次新复制进来的图片。
    if (widget.imagesController == null) _images.dispose();
    super.dispose();
  }

  void _handleChanged() => setState(() {});

  /// `@` / `[[` 的候选：与正文、链接对话框同一口径。
  Future<List<DiaryLinkCandidate>> _searchCandidates(
    String query,
    Set<DiaryLinkKind> kinds,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final l10n = context.l10n;
    final tree = await readDiaryLinkNotebookTree(ref, kinds);
    return searchDiaryLinkCandidates(
      db: db,
      tree: tree,
      l10n: l10n,
      query: query,
      kinds: kinds,
      excludeDiaryId: widget.diaryId,
    );
  }

  /// 去掉首尾空白后的文字与格式。
  ({String content, List<InlineTextRun>? runs}) get _trimmed =>
      trimDiaryCommentText(_editing.text.text, runs: _editing.text.runs);

  bool get _canSave {
    final text = _editing.text;
    final trimmed = _trimmed;
    final images = _images.images;
    if ((trimmed.content.isEmpty && images.isEmpty) ||
        _images.isBusy ||
        text.text.characters.length > kDiaryCommentMaxLength) {
      return false;
    }
    final initial = widget.initial;
    if (initial == null) return true;
    final delta = trimmed.runs == null
        ? null
        : encodeDiaryCommentDelta(trimmed.runs!);
    return trimmed.content != initial.content ||
        delta != normalizeDiaryCommentDelta(initial.delta, initial.content) ||
        _mood != initial.mood ||
        !listEquals(images, initial.imagePaths);
  }

  void _save() {
    if (!_canSave) return;
    final trimmed = _trimmed;
    final fresh = _images.handOff();
    Navigator.of(context).pop(
      DiaryCommentDraft(
        content: trimmed.content,
        runs: trimmed.runs,
        mood: _mood,
        images: _images.images,
        freshImages: fresh,
      ),
    );
  }

  Future<void> _pickImages() async {
    setState(() => _pickNotice = null);
    final result = await _images.pick();
    if (!mounted) return;
    setState(
      () => _pickNotice = switch (result) {
        DiaryCommentImagePickResult.truncated ||
        DiaryCommentImagePickResult.permissionDenied ||
        // 留言只从相册 / 文件选图，拍照的两种结果不会出现，按失败提示。
        DiaryCommentImagePickResult.cameraPermissionDenied ||
        DiaryCommentImagePickResult.cameraUnavailable ||
        DiaryCommentImagePickResult.failed => result,
        DiaryCommentImagePickResult.added ||
        DiaryCommentImagePickResult.cancelled ||
        DiaryCommentImagePickResult.busy => null,
      },
    );
  }

  void _removeImage(String path) {
    _images.remove(path);
    setState(() => _pickNotice = null);
  }

  /// 心情选项里没有、但这条留言原来记着的心情（用户后来改了心情选项）也
  /// 列出来，编辑时不会悄悄丢掉。
  List<String> get _moods {
    final initial = widget.initial?.mood ?? widget.initialDraft?.mood;
    return <String>[
      ...widget.moodOptions,
      if (initial != null && !widget.moodOptions.contains(initial)) initial,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mention = _editing.mention;
    final expand = ExpressiveMotion.durationNonZero(
      context,
      ExpressiveMotion.medium,
    );
    // 输入框里的格式按留言的外观画（与时间线一致）。
    _editing.text.runStyle = (marks) => diaryCommentRunStyle(scheme, marks);
    return PopScope(
      // 候选开着时返回键先结束候选，再按一次才关面板。
      canPop: !mention.isOpen,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) mention.close();
      },
      child: KeyboardInsetPadding(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: l10n.diaryCommentMoodLabel),
                    TextSpan(
                      text: ' · ${l10n.diaryCommentMoodOptional}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.s),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final mood in _moods)
                    DiaryCommentMoodChoice(
                      mood: mood,
                      selected: mood == _mood,
                      // 再点一次已选的心情即取消：心情可以不选。
                      onTap: () =>
                          setState(() => _mood = mood == _mood ? null : mood),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              TextField(
                controller: _editing.text,
                focusNode: _editing.focus,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                maxLength: kDiaryCommentMaxLength,
                // 允许完整编辑超长预填文字；超过上限时禁用保存，由用户决定
                // 删掉哪部分，避免第一次改动就被输入格式器截断尾部。
                maxLengthEnforcement: MaxLengthEnforcement.none,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                buildCounter:
                    (
                      BuildContext context, {
                      required int currentLength,
                      required bool isFocused,
                      required int? maxLength,
                    }) => currentLength < _counterFrom
                    ? null
                    : Text('$currentLength/$maxLength'),
                decoration: InputDecoration(hintText: l10n.diaryCommentHint),
                contextMenuBuilder: appTextContextMenuBuilder,
              ),
              // `@` / `[[` 的候选：出现 / 消失时高度补间。
              AnimatedSize(
                duration: expand,
                curve: ExpressiveMotion.effects,
                alignment: Alignment.topCenter,
                child: !mention.isOpen
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s),
                        child: TextFieldTapRegion(
                          child: AppCardSurface(
                            color: scheme.surfaceContainerHigh,
                            shadow: false,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(20),
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240),
                              child: DiaryLinkCandidateList(
                                menu: mention,
                                padding: const EdgeInsets.all(4),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.xs),
              DiaryCommentFormatBar(
                text: _editing.text,
                onLink: () => _editing.editLink(context),
              ),
              // 图片一行出现 / 消失时高度补间，下方按钮不在一帧内跳动。
              AnimatedSize(
                duration: expand,
                curve: ExpressiveMotion.effects,
                alignment: Alignment.topCenter,
                child: _images.images.isEmpty && _images.pending == 0
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s),
                        child: DiaryCommentImageStrip(
                          images: _images.images,
                          pending: _images.pending,
                          onRemove: _removeImage,
                        ),
                      ),
              ),
              if (_pickNotice case final notice?)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s),
                  child: DiaryCommentPickNotice(result: notice),
                ),
              const SizedBox(height: AppSpacing.m),
              Row(
                children: <Widget>[
                  // 按钮按自身宽度靠起始边，剩下的宽度留白；极窄时才省略文字。
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DiaryCommentAddImagesButton(
                        count: _images.images.length + _images.pending,
                        enabled: _images.canAdd,
                        onPressed: _pickImages,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: Text(l10n.commonSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
