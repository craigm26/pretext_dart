/// Flutter convenience layer for [pretext].
///
/// Uses [TextPainter] to implement [MeasureFn] so you don't have to wire it
/// up yourself. Requires `dart:ui` (Flutter only).
///
/// ```dart
/// import 'package:pretext/flutter/pretext_flutter.dart';
/// import 'package:pretext/pretext.dart';
///
/// final prepared = prepareWithSegmentsForStyle(text, TextStyle(fontSize: 16));
/// final result = layoutWithLines(prepared, 320, 26);
/// ```
library pretext_flutter;

import 'package:flutter/widgets.dart';
import 'package:pretext/pretext.dart';
import 'package:pretext/src/segment.dart';
import 'package:pretext/src/prepared_text.dart';

export 'package:pretext/pretext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TextPainter-based measurement helper
// ─────────────────────────────────────────────────────────────────────────────

/// Measures text segments using [TextPainter], caching results to avoid
/// redundant layout passes.
///
/// Create one instance per [TextStyle] and pass [measure] as the [MeasureFn].
///
/// ```dart
/// final measurer = TextPainterMeasure(TextStyle(fontSize: 16, fontFamily: 'Inter'));
/// final prepared = prepareWithSegments(text, measurer.measure);
/// ```
class TextPainterMeasure {
  TextPainterMeasure(this.style, {this.textScaleFactor = 1.0});

  /// The text style to measure against. Must match your widget's style.
  final TextStyle style;

  /// Scale factor (defaults to 1.0; pass [MediaQuery.textScalerOf] for
  /// accessibility-aware measurements).
  final double textScaleFactor;

  final Map<String, double> _cache = {};
  late final TextPainter _painter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  /// Returns the pixel width of [segment] for [style].
  double measure(String segment) {
    return _cache.putIfAbsent(segment, () {
      _painter.text = TextSpan(text: segment, style: style);
      _painter.layout(maxWidth: double.infinity);
      return _painter.width;
    });
  }

  /// Clear the measurement cache (e.g. after a font change).
  void clearCache() => _cache.clear();
}

// ─────────────────────────────────────────────────────────────────────────────
// Convenience entry points
// ─────────────────────────────────────────────────────────────────────────────

/// Segment, measure, and prepare [text] for use with [layout].
///
/// Internally creates a [TextPainterMeasure] for [style].
PreparedText prepareForStyle(
  String text,
  TextStyle style, {
  WhiteSpace whiteSpace = WhiteSpace.normal,
  double textScaleFactor = 1.0,
}) {
  final measurer = TextPainterMeasure(style, textScaleFactor: textScaleFactor);
  return prepare(text, measurer.measure, whiteSpace: whiteSpace);
}

/// Segment, measure, and prepare [text] for use with [layoutWithLines],
/// [layoutNextLine], or [walkLineRanges].
///
/// Internally creates a [TextPainterMeasure] for [style].
PreparedTextWithSegments prepareWithSegmentsForStyle(
  String text,
  TextStyle style, {
  WhiteSpace whiteSpace = WhiteSpace.normal,
  double textScaleFactor = 1.0,
}) {
  final measurer = TextPainterMeasure(style, textScaleFactor: textScaleFactor);
  return prepareWithSegments(text, measurer.measure, whiteSpace: whiteSpace);
}
