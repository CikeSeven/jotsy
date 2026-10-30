import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';

import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../widgets/expressive_button_group.dart';
import '../controllers/diary_link_editing.dart';
import '../models/diary_link_candidate.dart';
import 'diary_link/diary_link_search_view.dart';

/// 编辑选区的链接：工具栏「链接」按钮与桌面的 Ctrl / ⌘ + K（见
/// `DiaryEditor`）共用这一个对话框。
///
/// 正文能插入日记链接（[DiaryEditorController.linkSource]）时，对话框顶部
/// 分“网址 / 日记 / 日记本”三页（日记本功能关闭时没有第三页），后两页点选
/// 候选即写入；否则只有网址。折叠光标在一段链接里或紧挨着它时，先把选区
/// 扩到整段链接，编辑、移除都作用于整段。确认后恢复打开前的选区再写入，
/// 空网址移除链接；取消或正文已关闭时不改动。
Future<void> editDiaryLink(
  BuildContext context,
  DiaryEditorController controller,
) async {
  var selection = controller.selection;
  if (selection == null) return;
  String? initial;
  final caretLink = diaryLinkRangeAtCaret(controller);
  if (caretLink != null) {
    selection = caretLink.range;
    initial = caretLink.href;
  } else {
    final href = controller.selectionAttributes['href'];
    initial = href is String ? href : null;
  }
  final current = DiaryLinkTarget.tryParse(initial);
  final linkSource = controller.linkSource;
  final notebooks = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(appFeaturesProvider).notebooks;
  final choice = await showAppDialog<_LinkChoice>(
    context: context,
    builder: (context) => _DiaryLinkDialog(
      initialUrl: current == null ? initial ?? '' : '',
      current: current,
      hasLink: initial != null,
      targets: linkSource == null || controller.readOnly
          ? const []
          : [DiaryLinkKind.diary, if (notebooks) DiaryLinkKind.notebook],
      excludeDiaryId: linkSource?.diaryId,
    ),
  );
  if (choice == null || controller.state.isDisposed) return;
  switch (choice) {
    case _WebLink(:final url):
      controller.select(selection);
      controller.format('href', url.isEmpty ? null : url);
    case _RemoveLink():
      controller.select(selection);
      controller.format('href', null);
    case _TargetLink(:final candidate):
      applyDiaryLinkToSelection(
        controller,
        selection,
        candidate.target,
        candidate.label,
      );
  }
}

/// 对话框的结果。
sealed class _LinkChoice {
  const _LinkChoice();
}

/// 网址（规整后；空字符串为移除链接）。
class _WebLink extends _LinkChoice {
  const _WebLink(this.url);
  final String url;
}

class _RemoveLink extends _LinkChoice {
  const _RemoveLink();
}

class _TargetLink extends _LinkChoice {
  const _TargetLink(this.candidate);
  final DiaryLinkCandidate candidate;
}

/// 对话框的一页：网址或某种日记链接。
enum _LinkPage { web, diary, notebook }

/// 链接对话框。输入框的控制器随对话框自己的生命周期释放：对话框关闭后还要
/// 播完退出动画、仍在重建输入框，在 `showAppDialog` 返回后立即释放会用到
/// 已释放的控制器。
class _DiaryLinkDialog extends StatefulWidget {
  const _DiaryLinkDialog({
    required this.initialUrl,
    required this.current,
    required this.hasLink,
    required this.targets,
    required this.excludeDiaryId,
  });

  final String initialUrl;

  /// 选区现有的日记链接；不是日记链接时为 null。
  final DiaryLinkTarget? current;

  /// 选区现有链接（网址或日记链接），有时才给“移除链接”。
  final bool hasLink;

  /// 可选的日记链接种类；为空时只有网址一页。
  final List<DiaryLinkKind> targets;
  final String? excludeDiaryId;

  @override
  State<_DiaryLinkDialog> createState() => _DiaryLinkDialogState();
}

class _DiaryLinkDialogState extends State<_DiaryLinkDialog> {
  late final TextEditingController _input = TextEditingController(
    text: widget.initialUrl,
  );
  late _LinkPage _page = switch (widget.current?.kind) {
    DiaryLinkKind.diary when widget.targets.contains(DiaryLinkKind.diary) =>
      _LinkPage.diary,
    DiaryLinkKind.notebook
        when widget.targets.contains(DiaryLinkKind.notebook) =>
      _LinkPage.notebook,
    _ => _LinkPage.web,
  };
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// 补全协议并校验：只接受 http(s)（须有主机名）、mailto 与 tel。
  void _confirm() {
    var value = _input.text.trim();
    if (value.isNotEmpty) {
      if (!(Uri.tryParse(value)?.hasScheme ?? false)) {
        value = 'https://$value';
      }
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !['https', 'http', 'mailto', 'tel'].contains(uri.scheme) ||
          (['https', 'http'].contains(uri.scheme) && uri.host.isEmpty)) {
        setState(() => _error = context.l10n.diaryEditorInvalidLink);
        return;
      }
    }
    Navigator.pop(context, _WebLink(value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final current = widget.current;
    final web = _page == _LinkPage.web;
    final body = switch (_page) {
      _LinkPage.web => TextField(
        controller: _input,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: l10n.diaryEditorLinkUrl,
          errorText: _error,
        ),
      ),
      _LinkPage.diary || _LinkPage.notebook => DiaryLinkSearchView(
        kind: _page == _LinkPage.notebook
            ? DiaryLinkKind.notebook
            : DiaryLinkKind.diary,
        excludeDiaryId: widget.excludeDiaryId,
        onPick: (candidate) => Navigator.pop(context, _TargetLink(candidate)),
      ),
    };
    return AlertDialog(
      title: Text(l10n.autoT0024),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.targets.isNotEmpty) ...[
                ExpressiveButtonGroup<_LinkPage>(
                  minSegmentWidth: 72,
                  segments: [
                    ButtonSegment(
                      value: _LinkPage.web,
                      label: Text(l10n.diaryLinkGroupWeb),
                    ),
                    ButtonSegment(
                      value: _LinkPage.diary,
                      label: Text(l10n.diaryLinkGroupDiaries),
                    ),
                    if (widget.targets.contains(DiaryLinkKind.notebook))
                      ButtonSegment(
                        value: _LinkPage.notebook,
                        label: Text(l10n.diaryLinkGroupNotebooks),
                      ),
                  ],
                  selected: {_page},
                  onSelectionChanged: (pages) =>
                      setState(() => _page = pages.single),
                ),
                const SizedBox(height: 16),
              ],
              if (current != null) ...[
                Text(
                  current.kind == DiaryLinkKind.notebook
                      ? l10n.diaryLinkCurrentNotebook
                      : l10n.diaryLinkCurrentDiary,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              body,
            ],
          ),
        ),
      ),
      actions: [
        if (widget.hasLink)
          TextButton(
            onPressed: () => Navigator.pop(context, const _RemoveLink()),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: Text(l10n.diaryLinkRemove),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
          child: Text(l10n.commonCancel),
        ),
        if (web)
          TextButton(onPressed: _confirm, child: Text(l10n.commonConfirm)),
      ],
    );
  }
}
