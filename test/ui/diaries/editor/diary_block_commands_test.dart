import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_editor/diary_block_commands.dart';

void main() {
  late List<DiaryBlockCommand> commands;

  setUpAll(() async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    commands = diaryBlockCommands(l10n, onMedia: (_) {}, onRecording: () {});
  });

  List<String> labels(String query) => [
    for (final command in commands)
      if (command.matches(query)) command.label,
  ];

  test('a single letter matches keyword prefixes, not every word with it', () {
    expect(labels('h'), ['一级标题', '二级标题', '三级标题', '分隔线']);
  });

  test('Chinese names match anywhere, pinyin from two letters', () {
    expect(labels('代码'), ['代码块（多行）']);
    expect(labels('biaoti'), ['一级标题', '二级标题', '三级标题']);
    expect(labels('dmk'), ['代码块（多行）']);
    expect(labels('##'), ['二级标题', '三级标题']);
    expect(labels('zzz'), isEmpty);
  });
}
