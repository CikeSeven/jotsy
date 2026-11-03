import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_media_storage_service.dart';
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
    expect(labels('h'), [
      '一级标题',
      '二级标题',
      '三级标题',
      '四级标题',
      '五级标题',
      '六级标题',
      '分隔线',
    ]);
  });

  test('Chinese names match anywhere, pinyin from two letters', () {
    expect(labels('代码'), ['代码块（多行）']);
    expect(labels('biaoti'), ['一级标题', '二级标题', '三级标题', '四级标题', '五级标题', '六级标题']);
    expect(labels('dmk'), ['代码块（多行）']);
    expect(labels('##'), ['二级标题', '三级标题', '四级标题', '五级标题', '六级标题']);
    expect(labels('zzz'), isEmpty);
  });

  test(
    'take photo and record video follow video only when capture works',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      final captured = <DiaryMediaKind>[];
      final withCamera = diaryBlockCommands(
        l10n,
        onMedia: (_) {},
        onCamera: captured.add,
      );
      final names = [for (final command in withCamera) command.label];
      expect(names.indexOf('拍照'), names.indexOf('插入视频') + 1);
      expect(names.indexOf('录像'), names.indexOf('拍照') + 1);
      List<String> find(String query) => [
        for (final command in withCamera)
          if (command.matches(query)) command.label,
      ];
      expect(find('camera'), ['拍照', '录像']);
      expect(find('paizhao'), ['拍照']);
      expect(find('luxiang'), ['录像']);
      for (final command in withCamera) {
        if (command.label == '拍照' || command.label == '录像') command.action!();
      }
      expect(captured, [DiaryMediaKind.image, DiaryMediaKind.video]);

      expect([
        for (final command in commands) command.label,
      ], isNot(anyOf(contains('拍照'), contains('录像'))));
    },
  );
}
