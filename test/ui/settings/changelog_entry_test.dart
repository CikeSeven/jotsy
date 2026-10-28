import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_update_version.dart';
import 'package:node_diary/core/services/release_notes_catalog.dart';
import 'package:node_diary/ui/settings/models/changelog_entry.dart';

void main() {
  group('splitReleaseHighlights', () {
    test('keeps the first section as highlights and the rest as details', () {
      final split = splitReleaseHighlights(
        '## 版本要点\n- 桌面版\n- 新编辑器\n\n## 新增\n### 桌面\n- 安装包\n\n## 修复\n- 闪退',
      );

      expect(split.highlights, '- 桌面版\n- 新编辑器');
      expect(split.details, '## 新增\n### 桌面\n- 安装包\n\n## 修复\n- 闪退');
    });

    test('uses text before the first heading as highlights', () {
      final split = splitReleaseHighlights('修复版本。\n\n## 修复\n- 定位');

      expect(split.highlights, '修复版本。');
      expect(split.details, '## 修复\n- 定位');
    });

    test('shows notes without headings in full', () {
      final split = splitReleaseHighlights('- 录音\n- 视频');

      expect(split.highlights, '- 录音\n- 视频');
      expect(split.details, isEmpty);
    });

    test('shows everything when the first section is empty', () {
      final split = splitReleaseHighlights('## 版本要点\n\n## 新增\n- 模板');

      expect(split.highlights, '## 版本要点\n\n## 新增\n- 模板');
      expect(split.details, isEmpty);
    });

    test('does not split on headings inside code blocks', () {
      final split = splitReleaseHighlights(
        '## Highlights\n- Code\n\n```md\n## not a heading\n```\n\n## Fixes\n- x',
      );

      expect(split.highlights, '- Code\n\n```md\n## not a heading\n```');
      expect(split.details, '## Fixes\n- x');
    });

    test('a single section has nothing to expand', () {
      final split = splitReleaseHighlights('## Highlights\n- Only');

      expect(split.highlights, '- Only');
      expect(split.details, isEmpty);
    });
  });

  test('titles drop the build number from the file name', () {
    final entry = ChangelogEntry.fromNotes(
      const BundledReleaseNotes(
        tag: 'v0.4.5+11',
        version: AppVersion(0, 4, 5, build: 11),
        markdown: '## 版本要点\n- 一\n\n## 新增\n- 二',
      ),
    );

    expect(entry.title, 'v0.4.5');
    expect(entry.highlights, '- 一');
    expect(entry.hasDetails, isTrue);
  });
}
