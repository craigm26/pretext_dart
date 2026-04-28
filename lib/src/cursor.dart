/// Position within a [PreparedTextWithSegments]'s segment stream.
class LayoutCursor {
  /// Creates a [LayoutCursor] pointing to a specific segment and grapheme.
  const LayoutCursor({
    required this.segmentIndex,
    required this.graphemeIndex,
  });

  /// Index into [PreparedTextWithSegments.segments].
  final int segmentIndex;

  /// Grapheme index within the segment at [segmentIndex].
  /// Always 0 at segment boundaries; non-zero only for oversized single words
  /// that were split mid-character (reserved for future use; currently always 0).
  final int graphemeIndex;

  /// Cursor pointing to the very start of the prepared text.
  static const LayoutCursor start =
      LayoutCursor(segmentIndex: 0, graphemeIndex: 0);

  @override
  String toString() => 'LayoutCursor(seg=$segmentIndex, gph=$graphemeIndex)';

  @override
  bool operator ==(Object other) =>
      other is LayoutCursor &&
      segmentIndex == other.segmentIndex &&
      graphemeIndex == other.graphemeIndex;

  @override
  int get hashCode => Object.hash(segmentIndex, graphemeIndex);
}

/// A laid-out line with its full text string, width, and cursor range.
class LayoutLine {
  /// Creates a [LayoutLine] with the given text, width, and cursor range.
  const LayoutLine({
    required this.text,
    required this.width,
    required this.start,
    required this.end,
  });

  /// Full text content of the line (e.g. `'hello world'`).
  final String text;

  /// Measured pixel width of the line.
  final double width;

  /// Inclusive start cursor.
  final LayoutCursor start;

  /// Exclusive end cursor (points to the first segment of the *next* line).
  final LayoutCursor end;

  @override
  String toString() => 'LayoutLine("$text", w=$width, $start→$end)';
}

/// A laid-out line *without* its text string — width and cursor range only.
///
/// Returned by [walkLineRanges]; avoids building string copies when you only
/// need geometry (e.g. binary-searching optimal container width).
class LayoutLineRange {
  /// Creates a [LayoutLineRange] with the given width and cursor range.
  const LayoutLineRange({
    required this.width,
    required this.start,
    required this.end,
  });

  /// Measured pixel width of the line.
  final double width;

  /// Inclusive start cursor.
  final LayoutCursor start;

  /// Exclusive end cursor.
  final LayoutCursor end;

  @override
  String toString() => 'LayoutLineRange(w=$width, $start→$end)';
}

/// Result of [layout].
class LayoutResult {
  /// Creates a [LayoutResult] with the given height and line count.
  const LayoutResult({required this.height, required this.lineCount});

  /// Total pixel height of the laid-out text.
  final double height;

  /// Number of lines.
  final int lineCount;
}

/// Result of [layoutWithLines].
class LayoutResultWithLines {
  /// Creates a [LayoutResultWithLines] with the given height, line count, and lines.
  const LayoutResultWithLines({
    required this.height,
    required this.lineCount,
    required this.lines,
  });

  /// Total pixel height of the laid-out text.
  final double height;

  /// Number of lines.
  final int lineCount;

  /// All laid-out lines in order.
  final List<LayoutLine> lines;
}
