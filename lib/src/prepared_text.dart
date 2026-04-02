import 'segment.dart';

/// Opaque result of [prepare]. Pass to [layout].
class PreparedText {
  /// Creates a [PreparedText] from a list of segments.
  PreparedText.fromSegments(List<Segment> segments) : _segments = segments;
  final List<Segment> _segments;

  /// Internal segment list. Not part of the public API — use [layout] instead.
  List<Segment> get segments => _segments;
}

/// Opaque result of [prepareWithSegments]. Pass to [layoutWithLines],
/// [layoutNextLine], or [walkLineRanges].
class PreparedTextWithSegments {
  /// Creates a [PreparedTextWithSegments] from a list of segments.
  PreparedTextWithSegments.fromSegments(this.segments);

  /// Ordered list of segments (words, spaces, hard breaks) with cached widths.
  final List<Segment> segments;

  /// Promotes to [PreparedText] for use with [layout].
  PreparedText get asPrepared => PreparedText.fromSegments(segments);
}

// ── Factory helpers (used by lib/pretext.dart) ────────────────────────────

/// Segment, measure, and wrap into a [PreparedText].
PreparedText buildPrepared(
  String text,
  double Function(String) measure,
  WhiteSpace whiteSpace,
) {
  final segs = segmentAndMeasure(text, measure, whiteSpace: whiteSpace);
  return PreparedText.fromSegments(segs);
}

/// Segment, measure, and wrap into a [PreparedTextWithSegments].
PreparedTextWithSegments buildPreparedWithSegments(
  String text,
  double Function(String) measure,
  WhiteSpace whiteSpace,
) {
  final segs = segmentAndMeasure(text, measure, whiteSpace: whiteSpace);
  return PreparedTextWithSegments.fromSegments(segs);
}
