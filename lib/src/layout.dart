import 'cursor.dart';
import 'prepared_text.dart';
import 'segment.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Internal line-wrapping core
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [segments] into lines, calling [onLine] for each line.
///
/// Returns the total number of lines emitted.
///
/// [maxWidthForLine] is called with the 0-based line index to support
/// variable-width lines (the key feature over TextPainter).
int _wrapLines(
  List<Segment> segments,
  double Function(int lineIndex) maxWidthForLine, {
  required void Function(
    int lineIndex,
    double lineWidth,
    int startSeg,
    int endSeg, // exclusive
    String text,
  ) onLine,
}) {
  if (segments.isEmpty) return 0;

  int lineIndex = 0;
  int lineStart = 0; // segment index where current line starts
  double lineWidth = 0;
  final lineBuffer = StringBuffer();

  void emitLine(int endSeg) {
    // Trim trailing space from line text (and its width).
    var text = lineBuffer.toString();
    var width = lineWidth;
    if (text.endsWith(' ')) {
      text = text.trimRight();
      // Subtract the widths of trimmed trailing space segments.
      var j = endSeg - 1;
      while (j >= lineStart && segments[j].kind == SegmentKind.space) {
        width -= segments[j].width;
        j--;
      }
    }
    onLine(lineIndex, width, lineStart, endSeg, text);
    lineIndex++;
    lineStart = endSeg;
    lineWidth = 0;
    lineBuffer.clear();
  }

  int i = 0;
  while (i < segments.length) {
    final seg = segments[i];
    final maxW = maxWidthForLine(lineIndex);

    // Hard break: flush current line (even if empty — preserves blank lines)
    // then advance past the hard-break segment.
    if (seg.kind == SegmentKind.hardBreak) {
      emitLine(i); // emit up to (not including) the hard break
      i++; // skip the hard-break segment itself
      lineStart = i;
      continue;
    }

    // Leading space on a new line (normal mode): skip silently.
    if (seg.kind == SegmentKind.space && lineWidth == 0) {
      i++;
      lineStart = i;
      continue;
    }

    final segW = seg.width;

    // Would adding this segment overflow the line?
    final wouldOverflow = lineWidth > 0 && (lineWidth + segW) > maxW;

    if (wouldOverflow) {
      // Flush current line (without this segment).
      emitLine(i);
      lineStart = i;

      // If the segment itself (a word) is wider than maxWidth: emit it alone.
      if (seg.kind == SegmentKind.word && segW > maxW) {
        lineBuffer.write(seg.text);
        lineWidth = segW;
        i++;
        emitLine(i);
        lineStart = i;
        continue;
      }

      // Skip leading space at new line start.
      if (seg.kind == SegmentKind.space) {
        i++;
        lineStart = i;
        continue;
      }

      // Otherwise start new line with this segment.
      lineBuffer.write(seg.text);
      lineWidth += segW;
      i++;
      continue;
    }

    // Normal case: add segment to current line.
    // Single word wider than maxWidth on an otherwise empty line → allow it.
    lineBuffer.write(seg.text);
    lineWidth += segW;
    i++;
  }

  // Flush any remaining content as the final line.
  if (lineBuffer.isNotEmpty || lineStart < segments.length) {
    // Only emit a trailing line if there's actual content.
    if (lineBuffer.isNotEmpty) {
      emitLine(segments.length);
    }
  }

  return lineIndex;
}

// ─────────────────────────────────────────────────────────────────────────────
// Use-case 1: simple layout (height + lineCount)
// ─────────────────────────────────────────────────────────────────────────────

/// Calculate text height and line count for a fixed [maxWidth].
///
/// [lineHeight] is the per-line height in pixels (matching CSS `line-height`).
LayoutResult layout(
  PreparedText prepared,
  double maxWidth,
  double lineHeight,
) {
  int count = 0;
  _wrapLines(
    prepared.segments,
    (_) => maxWidth,
    onLine: (_, __, ___, ____, _____) => count++,
  );
  return LayoutResult(
    height: count * lineHeight,
    lineCount: count,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Use-case 2: per-line layout
// ─────────────────────────────────────────────────────────────────────────────

/// Calculate height, line count, and per-line [LayoutLine] list.
///
/// All lines use the same [maxWidth]. For variable-width lines use
/// [layoutNextLine] instead.
LayoutResultWithLines layoutWithLines(
  PreparedTextWithSegments prepared,
  double maxWidth,
  double lineHeight,
) {
  final lines = <LayoutLine>[];

  _wrapLines(
    prepared.segments,
    (_) => maxWidth,
    onLine: (lineIdx, lineW, startSeg, endSeg, text) {
      lines.add(LayoutLine(
        text: text,
        width: lineW,
        start: LayoutCursor(segmentIndex: startSeg, graphemeIndex: 0),
        end: LayoutCursor(segmentIndex: endSeg, graphemeIndex: 0),
      ));
    },
  );

  return LayoutResultWithLines(
    height: lines.length * lineHeight,
    lineCount: lines.length,
    lines: lines,
  );
}

/// Walk all lines at a fixed [maxWidth], calling [onLine] for each without
/// building text strings. Returns line count.
///
/// Useful for binary-searching container widths or building masonry layouts
/// without the allocation cost of full [LayoutLine] objects.
int walkLineRanges(
  PreparedTextWithSegments prepared,
  double maxWidth,
  void Function(LayoutLineRange line) onLine,
) {
  return _wrapLines(
    prepared.segments,
    (_) => maxWidth,
    onLine: (_, lineW, startSeg, endSeg, __) {
      onLine(LayoutLineRange(
        width: lineW,
        start: LayoutCursor(segmentIndex: startSeg, graphemeIndex: 0),
        end: LayoutCursor(segmentIndex: endSeg, graphemeIndex: 0),
      ));
    },
  );
}

/// Lay out the next single line starting at [start], using [maxWidth] for
/// *this line only*.
///
/// Returns `null` when [start] is past the end of the text.
///
/// This is the core API for variable-width line layout — call it in a loop
/// and supply a different [maxWidth] each time to flow text around shapes,
/// images, or other obstacles.
///
/// ```dart
/// var cursor = LayoutCursor.start;
/// while (true) {
///   final lineWidth = cursor.segmentIndex < imageBottomLine ? narrowW : fullW;
///   final line = layoutNextLine(prepared, cursor, lineWidth);
///   if (line == null) break;
///   canvas.drawText(line.text, ...);
///   cursor = line.end;
/// }
/// ```
LayoutLine? layoutNextLine(
  PreparedTextWithSegments prepared,
  LayoutCursor start,
  double maxWidth,
) {
  final segs = prepared.segments;
  final startIdx = start.segmentIndex;

  if (startIdx >= segs.length) return null;

  double lineWidth = 0;
  final lineBuffer = StringBuffer();
  int i = startIdx;

  // Skip leading spaces at line start.
  while (i < segs.length && segs[i].kind == SegmentKind.space) {
    i++;
  }

  if (i >= segs.length) return null;

  final lineStartIdx = i;

  while (i < segs.length) {
    final seg = segs[i];

    // Hard break: emit current content then return.
    if (seg.kind == SegmentKind.hardBreak) {
      return LayoutLine(
        text: lineBuffer.toString().trimRight(),
        width: lineWidth,
        start: LayoutCursor(segmentIndex: lineStartIdx, graphemeIndex: 0),
        end: LayoutCursor(segmentIndex: i + 1, graphemeIndex: 0),
      );
    }

    final segW = seg.width;
    final wouldOverflow = lineWidth > 0 && (lineWidth + segW) > maxWidth;

    if (wouldOverflow) {
      // Word is too wide — break before it.
      return LayoutLine(
        text: lineBuffer.toString().trimRight(),
        width: lineWidth,
        start: LayoutCursor(segmentIndex: lineStartIdx, graphemeIndex: 0),
        end: LayoutCursor(segmentIndex: i, graphemeIndex: 0),
      );
    }

    // Oversized single word: emit alone.
    if (lineWidth == 0 && seg.kind == SegmentKind.word && segW > maxWidth) {
      return LayoutLine(
        text: seg.text,
        width: segW,
        start: LayoutCursor(segmentIndex: i, graphemeIndex: 0),
        end: LayoutCursor(segmentIndex: i + 1, graphemeIndex: 0),
      );
    }

    lineBuffer.write(seg.text);
    lineWidth += segW;
    i++;
  }

  // Reached end of segments.
  if (lineBuffer.isEmpty) return null;

  return LayoutLine(
    text: lineBuffer.toString().trimRight(),
    width: lineWidth,
    start: LayoutCursor(segmentIndex: lineStartIdx, graphemeIndex: 0),
    end: LayoutCursor(segmentIndex: segs.length, graphemeIndex: 0),
  );
}
