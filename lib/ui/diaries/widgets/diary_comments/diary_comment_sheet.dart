import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../../widgets/keyboard_visibility.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../controllers/diary_comment_images_controller.dart';
import 'diary_comment_image_strip.dart';

/// 写留言面板的结果：去掉首尾空白的文字、可选心情与图片。
@immutable
class DiaryCommentDraft {
  const DiaryCommentDraft({
    required this.content,
    this.mood,
    this.images = const <String>[],
    this.freshImages = const <String>[],
  });

  final String content;
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
/// 编辑的留言，内容、心情与图片原样带入，没有改动时“保存”不可点。
/// [initialDraft] 为新留言预填完整内容，仍须用户确认，不受“没有改动”限制。
/// [imagesController] 只供测试注入（替换选图与复制），由注入方释放。
Future<DiaryCommentDraft?> showDiaryCommentSheet(
  BuildContext context, {
  required String title,
  required List<String> moodOptions,
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
      initial: initial,
      initialDraft: initialDraft,
      imagesController: imagesController,
    ),
  );
}

/// 写留言面板：标题、心情一行（可不选）、多行输入框、已添加的图片，底部
/// 左边“添加图片”、右边“取消 / 保存”。
///
/// 输入框用普通文字键盘、自动获得焦点；面板自己按键盘高度垫底
/// （`showAppModalBottomSheet` 不处理键盘）。字数上限
/// [kDiaryCommentMaxLength]，接近上限时才显示计数。文字与图片至少有一样
/// 才能保存；图片最多 [kDiaryCommentMaxImages] 张，选图与复制经
/// [DiaryCommentImagesController]，复制期间不能保存。选图的结果（多选被截掉、
/// 失败、没有权限）写在按钮上方的一行小字里：提示条在面板下面，看不见。
class DiaryCommentSheet extends StatefulWidget {
  const DiaryCommentSheet({
    super.key,
    required this.title,
    required this.moodOptions,
    this.initial,
    this.initialDraft,
    this.imagesController,
  });

  final String title;
  final List<String> moodOptions;
  final DiaryCommentRow? initial;

  /// 测试注入；为 null 时面板自己创建（并在关闭时释放）。
  final DiaryCommentImagesController? imagesController;

  /// 新留言的预填内容（例如 AI 回应），不是编辑已有留言。保留完整文字，
  /// 超出上限时由用户缩短后保存，不在打开面板时静默截断。
  final DiaryCommentDraft? initialDraft;

  @override
  State<DiaryCommentSheet> createState() => _DiaryCommentSheetState();
}

class _DiaryCommentSheetState extends State<DiaryCommentSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial?.content ?? widget.initialDraft?.content ?? '',
  )..addListener(_handleTextChanged);
  late String? _mood = widget.initial?.mood ?? widget.initialDraft?.mood;
  late final DiaryCommentImagesController _images =
      (widget.imagesController ??
            DiaryCommentImagesController(
              initial:
                  widget.initial?.imagePaths ??
                  widget.initialDraft?.images ??
                  const <String>[],
            ))
        ..addListener(_handleImagesChanged);

  /// 上一次选图的结果提示（只留需要说明的几种）；再选一次或移除图片时清掉。
  DiaryCommentImagePickResult? _pickNotice;

  /// 计数在剩下不到一成时才出现，平时不分散注意力。
  static const int _counterFrom = kDiaryCommentMaxLength * 9 ~/ 10;

  @override
  void dispose() {
    _text
      ..removeListener(_handleTextChanged)
      ..dispose();
    _images.removeListener(_handleImagesChanged);
    // 注入的控制器由注入方释放；自己创建的在这里释放——没保存就关掉面板时，
    // 它会删掉本次新复制进来的图片。
    if (widget.imagesController == null) _images.dispose();
    super.dispose();
  }

  void _handleTextChanged() => setState(() {});

  void _handleImagesChanged() => setState(() {});

  bool get _canSave {
    final content = _text.text.trim();
    final images = _images.images;
    if ((content.isEmpty && images.isEmpty) ||
        _images.isBusy ||
        _text.text.characters.length > kDiaryCommentMaxLength) {
      return false;
    }
    final initial = widget.initial;
    return initial == null ||
        content != initial.content ||
        _mood != initial.mood ||
        !listEquals(images, initial.imagePaths);
  }

  void _save() {
    if (!_canSave) return;
    final fresh = _images.handOff();
    Navigator.of(context).pop(
      DiaryCommentDraft(
        content: _text.text.trim(),
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
    return KeyboardInsetPadding(
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
                  _MoodChoice(
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
              controller: _text,
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
            // 图片一行出现 / 消失时高度补间，下方按钮不在一帧内跳动。
            AnimatedSize(
              duration: ExpressiveMotion.durationNonZero(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.effects,
              alignment: Alignment.topCenter,
              child: _images.images.isEmpty && _images.pending == 0
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.m),
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
                child: _PickNotice(result: notice),
              ),
            const SizedBox(height: AppSpacing.m),
            Row(
              children: <Widget>[
                // 按钮按自身宽度靠起始边，剩下的宽度留白；极窄时才省略文字。
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _AddImagesButton(
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
    );
  }
}

/// 底部左边的“添加图片”：色调按钮（玻璃时经 [AppGlassField.tonalButtonStyle]），
/// 已有图片时文字后面接“张数/上限”；满了或正在复制时不可点，满了时长按 /
/// 悬停给出上限说明。
class _AddImagesButton extends StatelessWidget {
  const _AddImagesButton({
    required this.count,
    required this.enabled,
    required this.onPressed,
  });

  final int count;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = count == 0
        ? l10n.diaryCommentAddImages
        : '${l10n.diaryCommentAddImages} $count/$kDiaryCommentMaxImages';
    final button = FilledButton.tonalIcon(
      style: AppGlassField.tonalButtonStyle(context),
      onPressed: enabled ? onPressed : null,
      icon: const FaIcon(FontAwesomeIcons.image, size: 15),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    if (count < kDiaryCommentMaxImages) return button;
    return Tooltip(
      message: l10n.diaryCommentImagesFull(kDiaryCommentMaxImages),
      child: button,
    );
  }
}

/// 选图结果的一行小字：多选被截掉为次要色，失败与没有权限为 error 色。
class _PickNotice extends StatelessWidget {
  const _PickNotice({required this.result});

  final DiaryCommentImagePickResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (String text, Color color) = switch (result) {
      DiaryCommentImagePickResult.truncated => (
        l10n.diaryCommentImagesTruncated(kDiaryCommentMaxImages),
        scheme.onSurfaceVariant,
      ),
      DiaryCommentImagePickResult.permissionDenied => (
        l10n.diaryCommentImagePermissionDenied,
        scheme.error,
      ),
      _ => (l10n.diaryCommentImageAddFailed, scheme.error),
    };
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}

/// 一个可选的心情：选中时为主色容器底 + 主色描边的圆，选中态经
/// [ExpressiveStateBlend] 补间。未选中的底色与描边按 [AppGlassField] 跟随
/// “控件”材质（经典时透明底 + outlineVariant 细描边），选中色不变。
class _MoodChoice extends StatelessWidget {
  const _MoodChoice({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  final String mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glassField = AppGlassField.of(context);
    final restingFill =
        glassField?.fill ?? scheme.primaryContainer.withValues(alpha: 0);
    final restingSide =
        glassField?.border ?? BorderSide(color: scheme.outlineVariant);
    final selectedSide = BorderSide(color: scheme.primary, width: 1.5);
    return Semantics(
      button: true,
      selected: selected,
      label: mood,
      excludeSemantics: true,
      child: ExpressiveStateBlend(
        active: selected,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                mood,
                style: const TextStyle(fontSize: 20, height: 1),
              ),
            ),
          ),
        ),
        builder: (BuildContext context, double t, Widget? child) => Material(
          color: Color.lerp(restingFill, scheme.primaryContainer, t),
          shape: CircleBorder(
            side: BorderSide.lerp(restingSide, selectedSide, t),
          ),
          child: child,
        ),
      ),
    );
  }
}
