import 'package:pretext/pretext.dart';
import 'package:test/test.dart';

// Deterministic monospace measurer: every character is exactly 8px wide.
double monoMeasure(String s) => s.length * 8.0;

void main() {
  group('layout() — simple height/lineCount', () {
    test('empty string → 0 height, 0 lines', () {
      final p = prepare('', monoMeasure);
      final r = layout(p, 100, 20);
      expect(r.lineCount, 0);
      expect(r.height, 0);
    });

    test('single word narrower than maxWidth → 1 line', () {
      final p = prepare('hello', monoMeasure); // 5*8=40px
      final r = layout(p, 100, 20);
      expect(r.lineCount, 1);
      expect(r.height, 20);
    });

    test('word wider than maxWidth stays on one line (no mid-word break)', () {
      final p = prepare('superlongword', monoMeasure); // 13*8=104px
      final r = layout(p, 80, 20);
      expect(r.lineCount, 1);
    });

    test('two words that fit on one line → 1 line', () {
      // "hello world" = 5+1+5 = 11 chars * 8 = 88px
      final p = prepare('hello world', monoMeasure);
      final r = layout(p, 100, 20);
      expect(r.lineCount, 1);
    });

    test('two words that need wrapping → 2 lines', () {
      // Each word is 40px, space is 8px. Total 88px.
      // maxWidth = 50 → "hello" fits (40px), "world" must wrap.
      final p = prepare('hello world', monoMeasure);
      final r = layout(p, 50, 20);
      expect(r.lineCount, 2);
      expect(r.height, 40);
    });

    test('hard newline always breaks', () {
      final p = prepare('a\nb', monoMeasure);
      final r = layout(p, 200, 20);
      expect(r.lineCount, 2);
    });

    test('multiple hard newlines produce blank lines', () {
      final p = prepare('a\n\nb', monoMeasure);
      final r = layout(p, 200, 20);
      expect(r.lineCount, 3); // 'a', '', 'b'
    });
  });

  group('layoutWithLines() — line strings + geometry', () {
    test('wraps paragraph into correct lines', () {
      // "one two three" at maxWidth=88 (≤11 chars)
      // "one two" = 7*8=56, "three" = 5*8=40 — both fit in 88px
      // Wait: "one two three" = 13 chars including spaces = 104px > 88px
      // "one two" = 7 chars + space = 7*8 = 56px... space is 1 char.
      // Actually: "one"=24, " "=8, "two"=24, " "=8, "three"=40 = 104 total
      // Line1: "one two" = 24+8+24 = 56px (fits in 88)
      // Adding "three" would be 56+8+40=104 > 88 → wrap
      // Line2: "three" = 40px
      final p = prepareWithSegments('one two three', monoMeasure);
      final r = layoutWithLines(p, 88, 20);
      expect(r.lineCount, 2);
      expect(r.lines[0].text, 'one two');
      expect(r.lines[1].text, 'three');
    });

    test('hard newline produces two lines', () {
      final p = prepareWithSegments('foo\nbar', monoMeasure);
      final r = layoutWithLines(p, 200, 20);
      expect(r.lineCount, 2);
      expect(r.lines[0].text, 'foo');
      expect(r.lines[1].text, 'bar');
    });

    test('line.width matches sum of segment widths', () {
      final p = prepareWithSegments('abc', monoMeasure); // 3*8=24px
      final r = layoutWithLines(p, 200, 20);
      expect(r.lines.first.width, closeTo(24, 0.001));
    });

    test('line cursors are monotonically increasing', () {
      final p = prepareWithSegments('a b c d e', monoMeasure);
      final r =
          layoutWithLines(p, 24, 20); // each word=8px, space=8px → 1 word/line
      for (var i = 1; i < r.lines.length; i++) {
        expect(
          r.lines[i].start.segmentIndex,
          greaterThanOrEqualTo(r.lines[i - 1].end.segmentIndex),
        );
      }
    });
  });

  group('walkLineRanges() — geometry without strings', () {
    test('line count matches layoutWithLines', () {
      final p = prepareWithSegments('one two three four', monoMeasure);
      const maxW = 80.0;
      int walkCount = 0;
      walkLineRanges(p, maxW, (_) => walkCount++);
      final lwlCount = layoutWithLines(p, maxW, 20).lineCount;
      expect(walkCount, lwlCount);
    });

    test('returns line widths', () {
      final p = prepareWithSegments('hello', monoMeasure); // 40px
      final widths = <double>[];
      walkLineRanges(p, 200, (l) => widths.add(l.width));
      expect(widths, [closeTo(40, 0.001)]);
    });
  });

  group('layoutNextLine() — variable-width line layout', () {
    test('returns null on empty prepared text', () {
      final p = prepareWithSegments('', monoMeasure);
      expect(layoutNextLine(p, LayoutCursor.start, 100), isNull);
    });

    test('returns null when cursor is past end', () {
      final p = prepareWithSegments('hi', monoMeasure);
      final r = layoutWithLines(p, 200, 20);
      final endCursor = r.lines.last.end;
      expect(layoutNextLine(p, endCursor, 100), isNull);
    });

    test('iterates all lines to completion', () {
      final p = prepareWithSegments('one two three four five', monoMeasure);
      var cursor = LayoutCursor.start;
      final lines = <LayoutLine>[];
      while (true) {
        final line = layoutNextLine(p, cursor, 80);
        if (line == null) break;
        lines.add(line);
        cursor = line.end;
      }
      // Should match layoutWithLines
      final expected = layoutWithLines(p, 80, 20);
      expect(lines.length, expected.lineCount);
      for (var i = 0; i < lines.length; i++) {
        expect(lines[i].text, expected.lines[i].text);
      }
    });

    test('variable maxWidth produces different wrapping per line', () {
      // First line: narrow (40px = 5 chars max), subsequent: wide (200px)
      // "one two three" → line1 narrow: "one" (24px fits, "two" would be 24+8+24=56>40)
      //                 → line2 wide: "two three" (all remaining fits)
      final p = prepareWithSegments('one two three', monoMeasure);
      var cursor = LayoutCursor.start;
      final lines = <String>[];
      final maxWidths = [40.0, 200.0, 200.0];
      int callIdx = 0;
      while (callIdx < maxWidths.length) {
        final line = layoutNextLine(p, cursor, maxWidths[callIdx]);
        if (line == null) break;
        lines.add(line.text);
        cursor = line.end;
        callIdx++;
      }
      expect(lines[0], 'one');
      expect(lines[1], 'two three');
    });

    test('consecutive end/start cursors are consistent', () {
      final p = prepareWithSegments('a b c d', monoMeasure);
      var cursor = LayoutCursor.start;
      LayoutCursor? prevEnd;
      while (true) {
        final line = layoutNextLine(p, cursor, 24);
        if (line == null) break;
        if (prevEnd != null) {
          expect(line.start.segmentIndex,
              greaterThanOrEqualTo(prevEnd.segmentIndex));
        }
        prevEnd = line.end;
        cursor = line.end;
      }
    });
  });

  group('WhiteSpace.preWrap', () {
    test('preserves multiple spaces', () {
      final p = prepareWithSegments(
        'hello  world', // two spaces
        monoMeasure,
        whiteSpace: WhiteSpace.preWrap,
      );
      final r = layoutWithLines(p, 200, 20);
      expect(r.lines.first.text, 'hello  world');
    });

    test('hard newline still breaks in preWrap mode', () {
      final p = prepareWithSegments(
        'a\nb',
        monoMeasure,
        whiteSpace: WhiteSpace.preWrap,
      );
      final r = layoutWithLines(p, 200, 20);
      expect(r.lineCount, 2);
    });
  });
}
