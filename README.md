# pretext

[![pub.dev](https://img.shields.io/pub/v/pretext.svg)](https://pub.dev/packages/pretext)
[![CI](https://github.com/craigm26/pretext_dart/actions/workflows/ci.yml/badge.svg)](https://github.com/craigm26/pretext_dart/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Dart port of [chenglou/pretext](https://github.com/chenglou/pretext) — pure-arithmetic multiline text layout with **variable per-line widths**.

The killer feature is `layoutNextLine()`: wrap text with a *different* `maxWidth` per line, enabling text to flow around images, shapes, or any obstacle. Flutter's `TextPainter` cannot do this — it takes a single `maxWidth` for the whole paragraph.

## Why?

Flutter's `TextPainter` is great for fixed-width paragraphs. But some layouts need per-line control:

- Text flowing around a floated image (magazine-style)
- Masonry / variable-column layouts
- Custom text editors with inline widgets
- "Shrinkwrap" containers (find the minimum width that still wraps to N lines)

## Getting started

```yaml
dependencies:
  pretext: ^0.1.0
```

## Usage

### Pure Dart (no Flutter dependency)

Provide your own font-measurement function:

```dart
import 'package:pretext/pretext.dart';

// Your measurement callback — called once per unique segment, cached by you.
double myMeasure(String seg) => seg.length * 8.5; // monospace example

// Use-case 1: just height + line count
final prepared = prepare('AGI 春天到了. بدأت الرحلة 🚀', myMeasure);
final result = layout(prepared, maxWidth: 320, lineHeight: 26);
print('${result.lineCount} lines, ${result.height}px tall');

// Use-case 2: per-line strings
final preparedWS = prepareWithSegments(text, myMeasure);
final result2 = layoutWithLines(preparedWS, 320, 26);
for (final line in result2.lines) {
  print('${line.text}  (${line.width}px)');
}

// Use-case 3: variable-width lines (flows around an image)
var cursor = LayoutCursor.start;
while (true) {
  final isNarrow = cursor.segmentIndex < 5; // first few lines beside image
  final line = layoutNextLine(preparedWS, cursor, isNarrow ? 150.0 : 320.0);
  if (line == null) break;
  canvas.drawText(line.text, x: 0, y: y);
  cursor = line.end;
  y += 26;
}

// Use-case 4: widths without strings (binary-search optimal container width)
double maxW = 0;
walkLineRanges(preparedWS, 320, (line) {
  if (line.width > maxW) maxW = line.width;
});
// maxW = tightest container that still fits all text
```

### Flutter (TextPainter-based measurement)

```dart
import 'package:pretext/flutter/pretext_flutter.dart';

const style = TextStyle(fontSize: 16, fontFamily: 'Inter');
final prepared = prepareWithSegmentsForStyle(text, style);

// Simple layout
final result = layoutWithLines(prepared, maxWidth: 320, lineHeight: 24);

// Variable-width (CustomPainter example)
var cursor = LayoutCursor.start;
double y = 0;
while (true) {
  final lineMaxW = y < imageBottom ? canvasW - imageW - 8 : canvasW;
  final line = layoutNextLine(prepared, cursor, lineMaxW);
  if (line == null) break;
  tp.text = TextSpan(text: line.text, style: style);
  tp.layout(maxWidth: lineMaxW);
  tp.paint(canvas, Offset(0, y));
  cursor = line.end;
  y += 24;
}
```

#### Reusing a measurer

For hot paths (virtualized lists, frequent repaints), create one `TextPainterMeasure` and reuse it:

```dart
final measurer = TextPainterMeasure(style);
// measurer.measure() is called once per unique segment then cached
final p1 = prepareWithSegments(text1, measurer.measure);
final p2 = prepareWithSegments(text2, measurer.measure);
```

## API reference

### Core (pure Dart — `package:pretext/pretext.dart`)

```dart
typedef MeasureFn = double Function(String segment);
enum WhiteSpace { normal, preWrap }

// Use-case 1
PreparedText prepare(String text, MeasureFn measure, {WhiteSpace whiteSpace});
LayoutResult layout(PreparedText prepared, double maxWidth, double lineHeight);
// LayoutResult: { double height, int lineCount }

// Use-case 2
PreparedTextWithSegments prepareWithSegments(String text, MeasureFn measure, {WhiteSpace whiteSpace});
LayoutResultWithLines layoutWithLines(PreparedTextWithSegments, double maxWidth, double lineHeight);
// LayoutResultWithLines: { double height, int lineCount, List<LayoutLine> lines }

LayoutLine? layoutNextLine(PreparedTextWithSegments, LayoutCursor start, double maxWidth);
// → null when exhausted

int walkLineRanges(PreparedTextWithSegments, double maxWidth, void Function(LayoutLineRange) onLine);
// → line count
```

### Cursor types

```dart
class LayoutCursor {
  final int segmentIndex;
  final int graphemeIndex; // reserved; always 0 in v0.1
  static const start = LayoutCursor(segmentIndex: 0, graphemeIndex: 0);
}

class LayoutLine   { String text; double width; LayoutCursor start, end; }
class LayoutLineRange { double width; LayoutCursor start, end; } // no text string
```

### Flutter (`package:pretext/flutter/pretext_flutter.dart`)

```dart
PreparedText prepareForStyle(String text, TextStyle style, {WhiteSpace, double textScaleFactor});
PreparedTextWithSegments prepareWithSegmentsForStyle(String text, TextStyle style, {WhiteSpace, double textScaleFactor});

class TextPainterMeasure {
  TextPainterMeasure(TextStyle style, {double textScaleFactor = 1.0});
  double measure(String segment); // cached
  void clearCache();
}
```

## Credits

This package is a Dart port of [pretext](https://github.com/chenglou/pretext) by [@chenglou](https://github.com/chenglou). All the core ideas — measurement-once, cursor-based layout, variable-width lines — are from the original JS library. Go star it.

## License

MIT
