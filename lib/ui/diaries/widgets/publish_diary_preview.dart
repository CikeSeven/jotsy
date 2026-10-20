import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/core/database/content_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_quill_styles.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';

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
  late final quill.QuillController _controller;
  late final bool _hasVisibleContent;
  late final List<quill.EmbedBuilder> _embedBuilders =
      buildDiaryQuillEmbedBuilders();

  @override
  void initState() {
    super.initState();
    // 正文不是合法 Delta 时解码器自己降级为纯文本，页面总能打开。
    final document = decodeDiaryContentToDocument(widget.draft.contentDocJson);
    _controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    // 不能只看纯文本镜像（contentText），纯图片正文在镜像里会为空。统一按
    // Quill 文档可见内容判断，图片/嵌入也算正文内容。
    _hasVisibleContent = diaryDocumentHasVisibleContent(document);
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
            DiaryQuillStylesBuilder(
              appearance: appearance,
              controller: _controller,
              builder: (BuildContext context, DiaryQuillLook look) =>
                  quill.QuillEditor.basic(
                    controller: _controller,
                    config: look.configure(
                      quill.QuillEditorConfig(
                        autoFocus: false,
                        scrollable: false,
                        padding: EdgeInsets.zero,
                        showCursor: false,
                        embedBuilders: _embedBuilders,
                      ),
                    ),
                  ),
            ),
        ],
      ),
    );
  }
}
