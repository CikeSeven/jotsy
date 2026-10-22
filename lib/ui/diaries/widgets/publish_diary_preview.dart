import 'package:flutter/material.dart';
import '../controllers/diary_editor_controller.dart';
import 'diary_editor/diary_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';

/// 发布页的标题与正文预览（只读），与编辑页、预览页同一套正文排版，所见即
/// 发布后的样子。
///
/// 正文在发布页不会变：文档解析、“有无可见内容”的判断与嵌入渲染器都只在
/// 创建时算一次；只有正文排版设置变化（监听 diaryTextAppearanceProvider）
/// 才重建。面板上的任何操作都不会重建这里。
class PublishDiaryPreview extends ConsumerStatefulWidget {
  const PublishDiaryPreview({super.key, required this.draft});

  final NewDiaryDraft draft;

  @override
  ConsumerState<PublishDiaryPreview> createState() =>
      _PublishDiaryPreviewState();
}

class _PublishDiaryPreviewState extends ConsumerState<PublishDiaryPreview> {
  late final DiaryEditorController _controller;
  late final bool _hasVisibleContent;
  @override
  void initState() {
    super.initState();
    _controller = DiaryEditorController.fromContent(
      widget.draft.contentDocJson,
      readOnly: true,
    );
    _hasVisibleContent = _controller.hasContent;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(diaryTextAppearanceProvider);
    final theme = Theme.of(context);
    final title = widget.draft.title.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.isEmpty ? context.l10n.autoT0095 : title,
            style: appearance.titleStyle(
              theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_hasVisibleContent)
            Text(context.l10n.autoT0139, style: theme.textTheme.bodyMedium)
          else
            DiaryEditor(
              controller: _controller,
              appearance: appearance,
              shrinkWrap: true,
            ),
        ],
      ),
    );
  }
}
