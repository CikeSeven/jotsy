import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/delayed_loading_indicator.dart';
import '../../controllers/diary_link_search.dart';
import '../../models/diary_link_candidate.dart';
import '../diary_editor/diary_caret_menu.dart';
import 'diary_link_candidate_item.dart';

/// 链接对话框“日记 / 日记本”一页：搜索框 + 候选列表（口径与 `@` 菜单相同，
/// 见 [searchDiaryLinkCandidates]）。列表高度固定，换词时不跳动。
class DiaryLinkSearchView extends ConsumerStatefulWidget {
  const DiaryLinkSearchView({
    super.key,
    required this.kind,
    required this.onPick,
    this.excludeDiaryId,
  });

  final DiaryLinkKind kind;
  final ValueChanged<DiaryLinkCandidate> onPick;

  /// 正在编辑的这篇，不列出。
  final String? excludeDiaryId;

  @override
  ConsumerState<DiaryLinkSearchView> createState() =>
      _DiaryLinkSearchViewState();
}

class _DiaryLinkSearchViewState extends ConsumerState<DiaryLinkSearchView> {
  final TextEditingController _input = TextEditingController();
  late final DiaryLinkSearchController _search = DiaryLinkSearchController(
    _run,
    kinds: {widget.kind},
  );

  Future<List<DiaryLinkCandidate>> _run(
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
      excludeDiaryId: widget.excludeDiaryId,
    );
  }

  @override
  void initState() {
    super.initState();
    _search.update('', force: true);
    _input.addListener(() => _search.update(_input.text));
  }

  @override
  void didUpdateWidget(DiaryLinkSearchView old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) {
      _search.kinds = {widget.kind};
      _search.update(_input.text, force: true);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _input,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.kind == DiaryLinkKind.notebook
                ? l10n.diaryLinkSearchNotebooks
                : l10n.diaryLinkSearchDiaries,
            prefixIcon: const Padding(
              padding: EdgeInsets.all(14),
              child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 16),
            ),
          ),
          onSubmitted: (_) {
            final first = _search.results?.firstOrNull;
            if (first != null) widget.onPick(first);
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 280,
          child: ListenableBuilder(
            listenable: _search,
            builder: (context, _) {
              final results = _search.results;
              if (results == null) {
                return const Center(child: DelayedLoadingIndicator());
              }
              if (results.isEmpty) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: DiaryCaretMenuEmpty(l10n.diaryLinkEmpty),
                );
              }
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final candidate in results)
                    DiaryLinkCandidateItem(
                      candidate: candidate,
                      onTap: () => widget.onPick(candidate),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
