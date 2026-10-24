import 'package:flutter_test/flutter_test.dart';

import '../../tool/merge_lcov.dart';

void main() {
  test(
    'shared lines count once and hits from different shards are combined',
    () {
      expect(
        mergeLcov([
          'SF:lib/shared.dart\nDA:1,2\nDA:2,0\nLF:2\nLH:1\nend_of_record\n',
          'SF:lib/shared.dart\nDA:1,3\nDA:2,1\nDA:3,0\nLF:3\nLH:2\n'
              'end_of_record\n',
        ]),
        'SF:lib/shared.dart\nDA:1,5\nDA:2,1\nDA:3,0\nLF:3\nLH:2\n'
        'end_of_record\n',
      );
    },
  );

  test('files and line numbers are sorted without mixing their hit counts', () {
    expect(
      mergeLcov([
        'TN:shard-0\nSF:lib/z.dart\nDA:4,0\nDA:2,1\nend_of_record\n',
        'SF:lib/a.dart\nDA:2,3\nend_of_record\n',
      ]),
      'SF:lib/a.dart\nDA:2,3\nLF:1\nLH:1\nend_of_record\n'
      'SF:lib/z.dart\nDA:2,1\nDA:4,0\nLF:2\nLH:1\nend_of_record\n',
    );
  });

  test(
    'incomplete, invalid or unsupported reports fail instead of losing data',
    () {
      for (final report in [
        '',
        'DA:1,1\nend_of_record\n',
        'SF:\nend_of_record\n',
        'SF:lib/a.dart\nDA:1,1\n',
        'SF:lib/a.dart\nSF:lib/b.dart\nend_of_record\n',
        'SF:lib/a.dart\nDA:0,1\nend_of_record\n',
        'SF:lib/a.dart\nDA:1,-1\nend_of_record\n',
        'SF:lib/a.dart\nDA:1,no\nend_of_record\n',
        'SF:lib/a.dart\nDA:1,1,checksum\nend_of_record\n',
        'SF:lib/a.dart\nFN:1,main\nend_of_record\n',
        'SF:lib/a.dart\nBRDA:1,0,0,1\nend_of_record\n',
      ]) {
        expect(
          () =>
              mergeLcov(['SF:lib/valid.dart\nDA:1,1\nend_of_record\n', report]),
          throwsFormatException,
          reason: report,
        );
      }
    },
  );
}
