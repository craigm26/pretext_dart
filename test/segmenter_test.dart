import 'package:pretext/src/segment.dart';
import 'package:test/test.dart';

double trivialMeasure(String s) => s.length.toDouble();

void main() {
  group('segmentAndMeasure — normal mode', () {
    test('empty string → empty list', () {
      final segs = segmentAndMeasure('', trivialMeasure);
      expect(segs, isEmpty);
    });

    test('single word', () {
      final segs = segmentAndMeasure('hello', trivialMeasure);
      expect(segs.length, 1);
      expect(segs[0].kind, SegmentKind.word);
      expect(segs[0].text, 'hello');
    });

    test('two words produce word/space/word', () {
      final segs = segmentAndMeasure('hi there', trivialMeasure);
      expect(segs.map((s) => s.kind).toList(), [
        SegmentKind.word,
        SegmentKind.space,
        SegmentKind.word,
      ]);
      expect(segs[0].text, 'hi');
      expect(segs[2].text, 'there');
    });

    test('collapses multiple spaces into one space segment', () {
      final segs = segmentAndMeasure('a   b', trivialMeasure);
      expect(segs.length, 3);
      expect(segs[1].kind, SegmentKind.space);
      expect(segs[1].text, ' ');
    });

    test('hard newline produces a hardBreak segment', () {
      final segs = segmentAndMeasure('a\nb', trivialMeasure);
      expect(segs.length, 3);
      expect(segs[1].kind, SegmentKind.hardBreak);
    });

    test('double newline produces two hardBreak segments', () {
      final segs = segmentAndMeasure('a\n\nb', trivialMeasure);
      expect(segs.where((s) => s.kind == SegmentKind.hardBreak).length, 2);
    });

    test('widths are measured via callback', () {
      double called = 0;
      double countingMeasure(String s) {
        called += s.length;
        return s.length.toDouble();
      }

      segmentAndMeasure('foo bar', countingMeasure);
      // "foo"=3, " "=1, "bar"=3 → total = 7
      expect(called, 7);
    });

    test('hardBreak segment has width 0', () {
      final segs = segmentAndMeasure('a\nb', trivialMeasure);
      final hb = segs.firstWhere((s) => s.kind == SegmentKind.hardBreak);
      expect(hb.width, 0);
    });
  });

  group('segmentAndMeasure — preWrap mode', () {
    test('preserves multiple spaces as space segment', () {
      final segs = segmentAndMeasure(
        'a   b',
        trivialMeasure,
        whiteSpace: WhiteSpace.preWrap,
      );
      final spaceSegs = segs.where((s) => s.kind == SegmentKind.space).toList();
      expect(spaceSegs.length, 1);
      expect(spaceSegs[0].text.length, 3); // three spaces preserved
    });

    test('tab is normalised to a single space', () {
      final segs = segmentAndMeasure(
        'a\tb',
        trivialMeasure,
        whiteSpace: WhiteSpace.preWrap,
      );
      final sp = segs.firstWhere((s) => s.kind == SegmentKind.space);
      expect(sp.text, ' ');
    });
  });
}
