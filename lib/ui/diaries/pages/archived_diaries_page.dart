import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';

import '../../../core/database/app_database.dart';

/// 归档日记页面。
///
/// 本页仅展示已归档列表，并支持点击进入编辑页。
class ArchivedDiariesPage extends ConsumerWidget {
  const ArchivedDiariesPage({super.key});

  // 归档页不提供新建入口，传空实现用于复用列表组件。
  void _noopCreate() {}

  // 归档页不启用多选交互。
  void _noopToggleSelection(String _, bool __) {}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedDiariesProvider);
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(title: const Text('归档日记')),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (Object error, StackTrace stackTrace) =>
                Center(child: Text('归档加载失败: $error')),
        data: (List<DiaryWithTags> diaries) {
          if (diaries.isEmpty) {
            return const Center(child: Text('暂无归档日记'));
          }

          return CustomScrollView(
            slivers: <Widget>[
              DiariesListSection(
                themeBrightness: brightness,
                diaries: diaries,
                layoutMode: DiaryLayoutMode.list,
                selectedDiaryIds: const <String>{},
                isSelectionMode: false,
                onCreate: _noopCreate,
                onOpenEditor: (diaryId) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder:
                          (BuildContext context) => EditDiaryPage(
                            diaryId: diaryId,
                            entryMode: EditDiaryEntryMode.edit,
                        ),
                    ),
                  );
                },
                onToggleSelection: _noopToggleSelection,
              ),
            ],
          );
        },
      ),
    );
  }
}
