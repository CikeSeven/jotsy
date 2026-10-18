import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_style.dart';

void main() {
  group('journalTextColor', () {
    test('normalises CSS colour syntaxes to #AARRGGBB', () {
      expect(journalTextColor('#FA2A2D'), '#FFFA2A2D');
      expect(journalTextColor('#f00'), '#FFFF0000');
      expect(journalTextColor('#00aaee80'), '#8000AAEE');
      expect(journalTextColor('rgb(71, 204, 71)'), '#FF47CC47');
      expect(journalTextColor('rgba(63,86,234,0.5)'), '#803F56EA');
      expect(journalTextColor('rgb(0 170 238 / 50%)'), '#8000AAEE');
      expect(journalTextColor('rgb(100%, 0%, 0%)'), '#FFFF0000');
      expect(journalTextColor('Purple'), '#FF800080');
      expect(journalTextColor('#808080'), '#FF808080');
    });

    test('drops default ink and colours it cannot read', () {
      for (final css in [
        '#191919',
        '#000000',
        'black',
        'rgb(51, 51, 51)',
        '#ffffff',
        '#eeeeee',
        'rgba(250, 42, 45, 0.1)',
        'inherit',
        'var(--text)',
        '#12',
        'hsl(0, 100%, 50%)',
        '',
        null,
      ]) {
        expect(journalTextColor(css), isNull, reason: '$css');
      }
      expect(journalIsColor('black'), isTrue);
      expect(journalIsColor('currentColor'), isFalse);
    });
  });

  group('journalBackgroundColor', () {
    test('keeps tinted highlights and drops paper colours', () {
      expect(journalBackgroundColor('#FFBF0061'), '#61FFBF00');
      expect(journalBackgroundColor('yellow'), '#FFFFFF00');
      expect(journalBackgroundColor('#333333'), '#FF333333');
      for (final css in ['transparent', '#fff', 'rgb(246, 248, 250)', '#000']) {
        expect(journalBackgroundColor(css), isNull, reason: css);
      }
    });

    test('reads Android ARGB only when asked to', () {
      expect(journalArgbToCss('#9affe8af'), '#ffe8af9a');
      expect(
        journalBackgroundColor(journalArgbToCss('#9affe8af')),
        '#9AFFE8AF',
      );
      expect(journalArgbToCss('ffe8af'), '#ffe8af');
      expect(journalArgbToCss('red'), isNull);
    });
  });

  group('font sizes', () {
    test('ratios from CSS units and keywords map onto three levels', () {
      String? level(String css, {double base = 16}) {
        final ratio = journalFontSizeRatio(css, base: base);
        return ratio == null ? 'unknown' : journalFontSizeForRatio(ratio);
      }

      expect(level('12px'), 'small');
      expect(level('14px'), isNull);
      expect(level('16px'), isNull);
      expect(level('18px'), 'large');
      expect(level('24px'), 'huge');
      expect(level('18pt'), 'huge');
      expect(level('1.25em'), 'large');
      expect(level('80%'), 'small');
      expect(level('x-small'), 'small');
      expect(level('medium'), isNull);
      expect(level('x-large'), 'huge');
      expect(level('14px', base: 14), isNull);
      expect(level('inherit'), 'unknown');
      expect(level('calc(1em + 2px)'), 'unknown');
    });

    test('legacy <font size> levels', () {
      expect(journalFontSizeForLegacyLevel('1'), 'small');
      expect(journalFontSizeForLegacyLevel('3'), isNull);
      expect(journalFontSizeForLegacyLevel('4'), 'large');
      expect(journalFontSizeForLegacyLevel('7'), 'huge');
      expect(journalFontSizeForLegacyLevel('+1'), 'large');
      expect(journalFontSizeForLegacyLevel('-2'), 'small');
      expect(journalFontSizeForLegacyLevel('big'), isNull);
    });
  });

  test('alignment and inline style lookup', () {
    expect(journalAlign('center'), 'center');
    expect(journalAlign(' END '), 'right');
    expect(journalAlign('justify'), 'justify');
    expect(journalAlign('left'), isNull);
    expect(journalAlign('start'), isNull);
    expect(
      journalStyleValue(
        'color: red; Text-Align : center !important; color:#00f',
        'text-align',
      ),
      'center',
    );
    expect(journalStyleValue('color: red; color:#00f', 'color'), '#00f');
    expect(journalStyleValue('color: red', 'background'), isNull);
    expect(journalStyleValue(null, 'color'), isNull);
  });
}
