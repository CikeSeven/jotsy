import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/notebooks/models/notebook_pick_selection.dart';

void main() {
  group('notebookPickStatesFor', () {
    test('marks notebooks holding every diary as all, others as some', () {
      final states = notebookPickStatesFor(<String, Set<String>>{
        'd1': <String>{'travel', 'food'},
        'd2': <String>{'travel'},
        'd3': <String>{'travel'},
      });
      expect(states, <String, NotebookPickState>{
        'travel': NotebookPickState.all,
        'food': NotebookPickState.some,
      });
    });

    test('is empty when no diary is in any notebook', () {
      expect(
        notebookPickStatesFor(<String, Set<String>>{
          'd1': <String>{},
          'd2': <String>{},
        }),
        isEmpty,
      );
    });
  });

  group('NotebookPickSelection', () {
    test('tapping cycles some → all → none → all', () {
      final selection = NotebookPickSelection(<String, NotebookPickState>{
        'food': NotebookPickState.some,
      });
      expect(selection.stateOf('food'), NotebookPickState.some);
      selection.toggle('food');
      expect(selection.stateOf('food'), NotebookPickState.all);
      selection.toggle('food');
      expect(selection.stateOf('food'), NotebookPickState.none);
      selection.toggle('food');
      expect(selection.stateOf('food'), NotebookPickState.all);
    });

    test('the result only holds changed notebooks', () {
      final selection = NotebookPickSelection(<String, NotebookPickState>{
        'travel': NotebookPickState.all,
        'food': NotebookPickState.some,
        'work': NotebookPickState.some,
      });
      expect(selection.result.isEmpty, isTrue);

      selection
        ..toggle('travel') // all → none：移出
        ..toggle('food') // some → all：收进
        ..toggle('reading'); // none → all：收进
      expect(
        selection.result,
        const NotebookPickerResult(
          add: <String>{'food', 'reading'},
          remove: <String>{'travel'},
        ),
      );
      // 没点过的 “部分在” 不出现在结果里。
      expect(selection.result.add.contains('work'), isFalse);
      expect(selection.result.remove.contains('work'), isFalse);
    });

    test('toggling back to the initial state is no change', () {
      final selection = NotebookPickSelection(<String, NotebookPickState>{
        'travel': NotebookPickState.all,
      });
      selection
        ..toggle('travel')
        ..toggle('travel');
      expect(selection.result.isEmpty, isTrue);
    });

    test('select marks a freshly created notebook as added', () {
      final selection = NotebookPickSelection()..select('new');
      expect(selection.result.add, <String>{'new'});
    });
  });

  group('NewDiaryDraft notebooks', () {
    test('round-trips notebook ids and chapters through JSON', () {
      const draft = NewDiaryDraft(
        title: '标题',
        contentDocJson: '',
        contentText: '',
        notebookIds: <String>['travel', 'food'],
        notebookChapterIds: <String, String>{'travel': 'ch1'},
      );
      final restored = NewDiaryDraft.fromJson(draft.toJson());
      expect(restored.notebookIds, <String>['travel', 'food']);
      expect(restored.notebookChapterIds, <String, String>{'travel': 'ch1'});
    });

    test('old drafts without notebooks decode to empty', () {
      final restored = NewDiaryDraft.fromJson(<String, Object?>{
        'title': '旧草稿',
        'contentDocJson': '',
        'contentText': '',
      });
      expect(restored.notebookIds, isEmpty);
      expect(restored.notebookChapterIds, isEmpty);
    });

    test('malformed notebook fields are ignored', () {
      final restored = NewDiaryDraft.fromJson(<String, Object?>{
        'title': '',
        'notebookIds': <Object?>['a', 3, null, '', 'a'],
        'notebookChapterIds': <String, Object?>{'a': 'c', 'b': 1},
      });
      expect(restored.notebookIds, <String>['a']);
      expect(restored.notebookChapterIds, <String, String>{'a': 'c'});
    });
  });
}
