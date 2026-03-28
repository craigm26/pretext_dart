/// Controls how whitespace is handled during segmentation and layout.
enum WhiteSpace {
  /// Collapse runs of whitespace into a single space; trim leading/trailing;
  /// wrap at word boundaries. Matches CSS `white-space: normal`.
  normal,

  /// Preserve spaces, tabs (as single space), and hard newlines.
  /// Matches CSS `white-space: pre-wrap` / HTML `<textarea>` behaviour.
  preWrap,
}

/// The role of a [Segment] in the text stream.
enum SegmentKind {
  /// A run of non-whitespace characters (a "word").
  word,

  /// A run of whitespace between words (space or tab in pre-wrap mode).
  space,

  /// A hard line break (`\n`). Width is always 0.
  hardBreak,
}

/// An atomic unit of text with its pre-measured pixel width.
class Segment {
  const Segment({
    required this.text,
    required this.kind,
    required this.width,
  });

  /// The text content of this segment.
  final String text;

  /// What kind of segment this is.
  final SegmentKind kind;

  /// Pre-measured pixel width (0 for [SegmentKind.hardBreak]).
  final double width;

  @override
  String toString() => 'Segment(${kind.name}, "$text", w=$width)';
}

/// Splits [text] into [Segment]s, measuring each via [measure].
///
/// [whiteSpace] controls whether whitespace is preserved or collapsed.
List<Segment> segmentAndMeasure(
  String text,
  double Function(String) measure, {
  WhiteSpace whiteSpace = WhiteSpace.normal,
}) {
  if (text.isEmpty) return const [];

  final segments = <Segment>[];

  // ── Step 1: split on hard newlines ─────────────────────────────────────
  final lines = text.split('\n');

  for (var li = 0; li < lines.length; li++) {
    final chunk = lines[li];

    if (whiteSpace == WhiteSpace.preWrap) {
      _segmentPreWrap(chunk, measure, segments);
    } else {
      _segmentNormal(chunk, measure, segments);
    }

    // Insert hard break between lines (but not after the last chunk)
    if (li < lines.length - 1) {
      segments.add(
        const Segment(text: '\n', kind: SegmentKind.hardBreak, width: 0),
      );
    }
  }

  return segments;
}

// ── Normal mode: collapse whitespace ────────────────────────────────────────

final _wsRunRe = RegExp(r'\s+');

void _segmentNormal(
  String chunk,
  double Function(String) measure,
  List<Segment> out,
) {
  // Trim, then split on whitespace runs.
  final trimmed = chunk.trim();
  if (trimmed.isEmpty) return;

  // Find alternating word/space runs preserving original positions.
  // Does the original chunk start with whitespace?
  bool startsWithSpace = chunk.isNotEmpty && _wsRunRe.hasMatch(chunk[0]);

  // We walk the trimmed string — spaces between words become single spaces.
  final parts = trimmed.split(_wsRunRe);
  for (var i = 0; i < parts.length; i++) {
    final word = parts[i];
    if (word.isEmpty) continue;

    // Emit a space segment before each word (except the very first word if
    // the chunk started with whitespace — that leading space is collapsed).
    if (i > 0 || (i == 0 && startsWithSpace && out.isNotEmpty)) {
      // Inter-word space: single space character.
      out.add(Segment(
        text: ' ',
        kind: SegmentKind.space,
        width: measure(' '),
      ));
    }

    out.add(Segment(
      text: word,
      kind: SegmentKind.word,
      width: measure(word),
    ));
  }
}

// ── Pre-wrap mode: preserve whitespace ──────────────────────────────────────

void _segmentPreWrap(
  String chunk,
  double Function(String) measure,
  List<Segment> out,
) {
  if (chunk.isEmpty) return;

  // Alternate between non-space and space runs.
  final re = RegExp(r'(\S+)|( +|\t)');
  for (final m in re.allMatches(chunk)) {
    final raw = m.group(0)!;
    if (raw.trim().isEmpty) {
      // Space run or tab: normalise tab to a single space, measure.
      final spaceText = raw.replaceAll('\t', ' ');
      out.add(Segment(
        text: spaceText,
        kind: SegmentKind.space,
        width: measure(spaceText),
      ));
    } else {
      out.add(Segment(
        text: raw,
        kind: SegmentKind.word,
        width: measure(raw),
      ));
    }
  }
}
