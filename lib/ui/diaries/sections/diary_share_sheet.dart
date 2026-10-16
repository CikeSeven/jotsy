import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../models/diary_share_content.dart';
import '../models/diary_share_options.dart';
import '../models/diary_share_target.dart';
import '../viewmodels/diary_share_messages.dart';
import '../widgets/diary_share_widgets.dart';
import '../widgets/diary_sheet_controls.dart';

/// 打开分享面板，返回用户选定的分享动作；关闭面板返回 null。
///
/// 面板只负责挑选：内容开关、勾选图片、选目标。真正的暂存图片、复制文字
/// 与拉起应用由预览页交给 `DiaryShareController` 执行，并在执行期间显示
/// 动作等待遮罩——面板关闭后才开始，遮罩与提示都落在预览页上。
///
/// [availableTargets] 为已安装的应用目标（检测完成前只显示系统分享与
/// 复制）；内容开关变化经 [onOptionsChanged] 交给调用方保存。
Future<DiaryShareRequest?> showDiaryShareSheet(
  BuildContext context, {
  required DiaryShareContent content,
  required DiaryShareOptions initialOptions,
  required ValueChanged<DiaryShareOptions> onOptionsChanged,
  required Future<Set<DiaryShareTarget>> availableTargets,
}) {
  return showModalBottomSheet<DiaryShareRequest>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 预览、开关、图片条与目标加起来常超过默认 9/16 屏高，按内容撑高，
    // 仍放不下时面板内滚动。
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => DiaryShareSheet(
      content: content,
      initialOptions: initialOptions,
      onOptionsChanged: onOptionsChanged,
      availableTargets: availableTargets,
    ),
  );
}

class DiaryShareSheet extends StatefulWidget {
  const DiaryShareSheet({
    super.key,
    required this.content,
    required this.initialOptions,
    required this.onOptionsChanged,
    required this.availableTargets,
  });

  final DiaryShareContent content;
  final DiaryShareOptions initialOptions;
  final ValueChanged<DiaryShareOptions> onOptionsChanged;
  final Future<Set<DiaryShareTarget>> availableTargets;

  @override
  State<DiaryShareSheet> createState() => _DiaryShareSheetState();
}

class _DiaryShareSheetState extends State<DiaryShareSheet> {
  late DiaryShareOptions _options = widget.initialOptions;

  /// 默认勾选前 9 张：正好是微博等应用的单次上限，多数情况下不用再调。
  late final Set<int> _selectedImages = <int>{
    for (var i = 0; i < widget.content.images.length && i < 9; i++) i,
  };

  DiaryShareContent get _content => widget.content;

  List<String> get _imagesToSend => !_options.includeImages
      ? const <String>[]
      : <String>[
          for (var i = 0; i < _content.images.length; i++)
            if (_selectedImages.contains(i)) _content.images[i],
        ];

  String _composeText(DiaryShareTagStyle tagStyle) {
    final l10n = context.l10n;
    return _content.composeText(
      _options,
      dateLabel: DateFormat.yMMMEd(
        l10n.localeName,
      ).format(_content.createdAt.toLocal()),
      tagStyle: tagStyle,
    );
  }

  void _updateOptions(DiaryShareOptions next) {
    if (next == _options) {
      return;
    }
    setState(() => _options = next);
    widget.onOptionsChanged(next);
  }

  void _toggleImage(int index) {
    setState(() {
      if (!_selectedImages.remove(index)) {
        _selectedImages.add(index);
      }
    });
  }

  void _shareTo(DiaryShareTarget target) {
    Navigator.of(context).pop(
      DiaryShareRequest.toTarget(
        target,
        text: _composeText(target.tagStyle),
        images: _imagesToSend,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final previewText = _composeText(DiaryShareTagStyle.hashtag);
    final images = _imagesToSend;
    final hasText = previewText.isNotEmpty;
    final hasImages = images.isNotEmpty;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.diaryShareSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            DiaryShareTextPreview(text: previewText),
            const SizedBox(height: AppSpacing.l),
            DiarySheetSectionHeader(
              icon: FontAwesomeIcons.sliders,
              label: l10n.diaryShareContentSection,
            ),
            const SizedBox(height: AppSpacing.s),
            _buildOptionChips(l10n),
            AnimatedSize(
              duration: ExpressiveMotion.durationNonZero(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.effects,
              alignment: Alignment.topCenter,
              child: _options.includeImages && _content.images.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.m),
                      child: DiaryShareImagePicker(
                        images: _content.images,
                        selected: _selectedImages,
                        onToggle: _toggleImage,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: AppSpacing.xl),
            DiarySheetSectionHeader(
              icon: FontAwesomeIcons.shareNodes,
              label: l10n.diaryShareTargetsSection,
            ),
            const SizedBox(height: AppSpacing.m),
            FutureBuilder<Set<DiaryShareTarget>>(
              future: widget.availableTargets,
              builder: (context, snapshot) => _buildTargets(
                l10n,
                installed: snapshot.data ?? const <DiaryShareTarget>{},
                hasText: hasText,
                hasImages: hasImages,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            DiarySheetSectionHeader(
              icon: FontAwesomeIcons.ellipsis,
              label: l10n.diaryShareMoreSection,
            ),
            const SizedBox(height: AppSpacing.xs),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s,
              ),
              leading: const FaIcon(FontAwesomeIcons.image, size: 16),
              title: Text(l10n.diaryShareLongImage),
              subtitle: Text(l10n.diaryShareLongImageSubtitle),
              onTap: () => Navigator.of(
                context,
              ).pop(const DiaryShareRequest.longImage()),
            ),
          ],
        ),
      ),
    );
  }

  /// 只列出这篇日记里有内容的开关：没有标签就不显示“标签”，避免点了没反应。
  Widget _buildOptionChips(AppLocalizations l10n) {
    Widget chip(String label, bool value, DiaryShareOptions Function(bool) on) {
      return FilterChip(
        label: Text(label),
        selected: value,
        onSelected: (bool selected) => _updateOptions(on(selected)),
      );
    }

    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: <Widget>[
        if (_content.title.isNotEmpty)
          chip(
            l10n.diaryShareOptionTitle,
            _options.includeTitle,
            (v) => _options.copyWith(includeTitle: v),
          ),
        if (_content.body.isNotEmpty)
          chip(
            l10n.diaryShareOptionBody,
            _options.includeBody,
            (v) => _options.copyWith(includeBody: v),
          ),
        chip(
          l10n.diaryShareOptionDate,
          _options.includeDate,
          (v) => _options.copyWith(includeDate: v),
        ),
        if (_content.hasMoodWeather)
          chip(
            l10n.diaryShareOptionMoodWeather,
            _options.includeMoodWeather,
            (v) => _options.copyWith(includeMoodWeather: v),
          ),
        if (_content.location != null)
          chip(
            l10n.diaryShareOptionLocation,
            _options.includeLocation,
            (v) => _options.copyWith(includeLocation: v),
          ),
        if (_content.tagNames.isNotEmpty)
          chip(
            l10n.diaryShareOptionTags,
            _options.includeTags,
            (v) => _options.copyWith(includeTags: v),
          ),
        if (_content.images.isNotEmpty)
          chip(
            l10n.diaryShareOptionImages,
            _options.includeImages,
            (v) => _options.copyWith(includeImages: v),
          ),
      ],
    );
  }

  Widget _buildTargets(
    AppLocalizations l10n, {
    required Set<DiaryShareTarget> installed,
    required bool hasText,
    required bool hasImages,
  }) {
    final hasContent = hasText || hasImages;
    VoidCallback? tapFor(DiaryShareTarget target) {
      if (!hasContent || (target.requiresImages && !hasImages)) {
        return null;
      }
      return () => _shareTo(target);
    }

    final appTargets = DiaryShareTarget.appTargets.where(installed.contains);
    final needsImage = appTargets
        .where((DiaryShareTarget target) => target.requiresImages)
        .firstOrNull;
    // 一行说明，按优先级取一条：为什么全部不可点 > 为什么某个目标不可点 >
    // 带图分享时文字去哪了。
    final String? hint;
    if (!hasContent) {
      hint = l10n.diaryShareNothingSelected;
    } else if (needsImage != null && !hasImages) {
      hint = l10n.diaryShareRequiresImage(
        diaryShareTargetLabel(l10n, needsImage),
      );
    } else if (hasText && hasImages) {
      hint = l10n.diaryShareClipboardHint;
    } else {
      hint = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.m,
          children: <Widget>[
            for (final target in appTargets)
              DiaryShareTargetButton(
                label: diaryShareTargetLabel(l10n, target),
                icon: _targetIcon(target),
                glyph: target == DiaryShareTarget.xiaohongshu
                    ? l10n.diaryShareTargetXiaohongshu
                    : null,
                onTap: tapFor(target),
              ),
            DiaryShareTargetButton(
              label: l10n.diaryShareTargetSystem,
              icon: FontAwesomeIcons.shareFromSquare,
              onTap: tapFor(DiaryShareTarget.system),
            ),
            DiaryShareTargetButton(
              label: l10n.diaryShareCopyText,
              icon: FontAwesomeIcons.copy,
              onTap: hasText
                  ? () => Navigator.of(context).pop(
                      DiaryShareRequest.copyText(
                        _composeText(DiaryShareTagStyle.hashtag),
                      ),
                    )
                  : null,
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          child: hint == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  key: ValueKey<String>(hint),
                  padding: const EdgeInsets.only(top: AppSpacing.m),
                  child: Text(
                    hint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

FaIconData? _targetIcon(DiaryShareTarget target) {
  return switch (target) {
    DiaryShareTarget.weibo => FontAwesomeIcons.weibo,
    DiaryShareTarget.wechat => FontAwesomeIcons.weixin,
    DiaryShareTarget.qq => FontAwesomeIcons.qq,
    DiaryShareTarget.system => FontAwesomeIcons.shareFromSquare,
    // 图标库没有小红书的图形，按钮里直接写名称。
    DiaryShareTarget.xiaohongshu => null,
  };
}
