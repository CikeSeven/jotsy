import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_note/core/database/app_database.dart';
import 'package:node_note/core/services/app_service.dart';
import 'package:node_note/ui/notes/pages/edit_note.dart';

class NotesFilterState {
  const NotesFilterState({
    this.keyword = '',
    this.selectedTagIds = const <int>{},
  });

  final String keyword;
  final Set<int> selectedTagIds;

  NotesFilterState copyWith({String? keyword, Set<int>? selectedTagIds}) {
    return NotesFilterState(
      keyword: keyword ?? this.keyword,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
    );
  }
}

class NotesFilterNotifier extends Notifier<NotesFilterState> {
  @override
  NotesFilterState build() {
    return const NotesFilterState();
  }

  void setKeyword(String value) {
    state = state.copyWith(keyword: value);
  }

  void toggleTag(int tagId, bool selected) {
    final next = <int>{...state.selectedTagIds};
    if (selected) {
      next.add(tagId);
    } else {
      next.remove(tagId);
    }
    state = state.copyWith(selectedTagIds: next);
  }
}

final notesFilterProvider =
    NotifierProvider<NotesFilterNotifier, NotesFilterState>(
      NotesFilterNotifier.new,
    );

final filteredDiariesProvider = StreamProvider<List<DiaryWithTags>>((Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final filter = ref.watch(notesFilterProvider);
  final tagIds = filter.selectedTagIds.toList()..sort();
  return db.watchDiaries(keyword: filter.keyword, requiredTagIds: tagIds);
});

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagListProvider);
    final diariesAsync = ref.watch(filteredDiariesProvider);
    final selectedTagIds = ref.watch(notesFilterProvider).selectedTagIds;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '搜索标题或正文',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) {
              ref.read(notesFilterProvider.notifier).setKeyword(value);
            },
          ),
        ),
        tagsAsync.when(
          data: (List<Tag> tags) {
            if (tags.isEmpty) {
              return const SizedBox.shrink();
            }
            return SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children:
                    tags.map((Tag tag) {
                      final selected = selectedTagIds.contains(tag.id);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          selected: selected,
                          avatar: CircleAvatar(
                            radius: 8,
                            backgroundColor: Color(tag.color),
                          ),
                          label: Text(tag.name),
                          onSelected: (bool value) {
                            ref
                                .read(notesFilterProvider.notifier)
                                .toggleTag(tag.id, value);
                          },
                        ),
                      );
                    }).toList(),
              ),
            );
          },
          loading:
              () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          error:
              (Object error, StackTrace stackTrace) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('标签加载失败: $error'),
              ),
        ),
        Expanded(
          child: diariesAsync.when(
            data: (List<DiaryWithTags> items) {
              if (items.isEmpty) {
                return const Center(child: Text('暂无日记'));
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final item = items[index];
                  final title =
                      item.diary.title.trim().isEmpty
                          ? '未命名日记'
                          : item.diary.title;
                  final preview = item.diary.contentText.replaceAll('\n', ' ');
                  final updatedAt = _formatDateTime(item.diary.updatedAt);

                  return ListTile(
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          updatedAt,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (item.tags.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: -8,
                            children:
                                item.tags.map((Tag tag) {
                                  return Chip(
                                    avatar: CircleAvatar(
                                      radius: 7,
                                      backgroundColor: Color(tag.color),
                                    ),
                                    label: Text(tag.name),
                                  );
                                }).toList(),
                          ),
                        ],
                      ],
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EditNotePage(diaryId: item.diary.id),
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (Object error, StackTrace stackTrace) =>
                    Center(child: Text('日记加载失败: $error')),
          ),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final yyyy = local.year.toString().padLeft(4, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd $hh:$min';
}
