/// Dart port of [pretext](https://github.com/chenglou/pretext) — pure-arithmetic
/// multiline text layout with variable per-line widths.
///
/// ## Quick start (pure Dart)
///
/// ```dart
/// import 'package:pretext/pretext.dart';
///
/// // Provide your own font-measurement callback:
/// double myMeasure(String seg) => seg.length * 8.5; // simplified example
///
/// final prepared = prepareWithSegments('Hello, world!', myMeasure);
/// final result = layoutWithLines(prepared, maxWidth: 200, lineHeight: 24);
/// print(result.lineCount); // number of lines
///
/// // Variable-width lines (the killer feature — impossible with TextPainter):
/// var cursor = LayoutCursor.start;
/// while (true) {
///   final lineW = cursor.segmentIndex < 3 ? 120.0 : 240.0; // narrow then wide
///   final line = layoutNextLine(prepared, cursor, lineW);
///   if (line == null) break;
///   print(line.text);
///   cursor = line.end;
/// }
/// ```
///
/// ## Flutter convenience
///
/// ```dart
/// import 'package:pretext/flutter/pretext_flutter.dart';
///
/// final prepared = prepareWithSegmentsForStyle(text, TextStyle(fontSize: 16));
/// ```
library pretext;

export 'src/cursor.dart';
export 'src/prepared_text.dart' show PreparedText, PreparedTextWithSegments;
export 'src/segment.dart' show WhiteSpace;
export 'src/layout.dart';

import 'src/prepared_text.dart';
import 'src/segment.dart';

/// A function that returns the pixel width of [segment] using a specific font.
typedef MeasureFn = double Function(String segment);

// ── Use-case 1 ────────────────────────────────────────────────────────────

/// Segment and measure [text] for use with [layout].
PreparedText prepare(
  String text,
  MeasureFn measure, {
  WhiteSpace whiteSpace = WhiteSpace.normal,
}) =>
    buildPrepared(text, measure, whiteSpace);

// ── Use-case 2 ────────────────────────────────────────────────────────────

/// Segment and measure [text] for use with [layoutWithLines], [layoutNextLine],
/// or [walkLineRanges].
PreparedTextWithSegments prepareWithSegments(
  String text,
  MeasureFn measure, {
  WhiteSpace whiteSpace = WhiteSpace.normal,
}) =>
    buildPreparedWithSegments(text, measure, whiteSpace);
