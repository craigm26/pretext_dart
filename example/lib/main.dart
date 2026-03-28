import 'package:flutter/material.dart';
import 'package:pretext/flutter/pretext_flutter.dart';
import 'package:pretext/pretext.dart';

void main() => runApp(const PretextExampleApp());

class PretextExampleApp extends StatelessWidget {
  const PretextExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'pretext example',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF1a1a2e),
        body: SafeArea(child: _ExampleView()),
      ),
    );
  }
}

const _kText =
    'The quick brown fox jumps over the lazy dog. '
    'Pack my box with five dozen liquor jugs. '
    'How vexingly quick daft zebras jump! '
    'The five boxing wizards jump quickly.';

const _kStyle = TextStyle(
  fontSize: 16,
  color: Colors.white,
  fontFamily: 'monospace',
  height: 1.5,
);

const _kLineHeight = 24.0;
const _kImageW = 100.0;
const _kImageH = 80.0;
const _kPadding = 16.0;

class _ExampleView extends StatelessWidget {
  const _ExampleView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(_kPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'pretext — variable-width line layout',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Text flows around the image placeholder below.\n'
            'Lines beside the image are narrower — impossible with TextPainter alone.',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              return _FloatAroundDemo(canvasWidth: constraints.maxWidth);
            },
          ),
        ],
      ),
    );
  }
}

/// Demonstrates [layoutNextLine] flowing text around a floating image.
class _FloatAroundDemo extends StatelessWidget {
  const _FloatAroundDemo({required this.canvasWidth});
  final double canvasWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FloatAroundPainter(canvasWidth: canvasWidth),
      size: Size(canvasWidth, _estimateHeight(canvasWidth)),
    );
  }

  double _estimateHeight(double w) {
    // rough upper bound so the CustomPaint reserves enough space
    return 400;
  }
}

class _FloatAroundPainter extends CustomPainter {
  _FloatAroundPainter({required this.canvasWidth});
  final double canvasWidth;

  @override
  void paint(Canvas canvas, Size size) {
    const innerW = canvasWidth - _kPadding * 2;

    // ── 1. Prepare text with Flutter TextPainter measurement ─────────────
    final prepared = prepareWithSegmentsForStyle(_kText, _kStyle);

    // ── 2. Draw image placeholder (top-right corner) ────────────────────
    final imgRect = Rect.fromLTWH(
      innerW - _kImageW,
      0,
      _kImageW,
      _kImageH,
    );
    canvas.drawRect(
      imgRect,
      Paint()
        ..color = const Color(0xFF533483)
        ..style = PaintingStyle.fill,
    );
    final imgLabel = TextPainter(
      text: const TextSpan(
        text: '📷 image',
        style: TextStyle(color: Colors.white70, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _kImageW);
    imgLabel.paint(
      canvas,
      Offset(innerW - _kImageW + 8, _kImageH / 2 - 8),
    );

    // ── 3. Flow text using layoutNextLine with variable widths ──────────
    var cursor = LayoutCursor.start;
    double y = 0;

    while (true) {
      // Lines beside the image use a narrower width
      final isNarrowLine = y < _kImageH;
      final lineMaxW = isNarrowLine ? innerW - _kImageW - 8 : innerW;

      final line = layoutNextLine(prepared, cursor, lineMaxW);
      if (line == null) break;

      // Draw text
      final tp = TextPainter(
        text: TextSpan(text: line.text, style: _kStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: lineMaxW);
      tp.paint(canvas, Offset(0, y));

      // Debug: draw line-width indicator
      canvas.drawRect(
        Rect.fromLTWH(0, y + _kLineHeight - 2, line.width, 1),
        Paint()..color = const Color(0x4400E5FF),
      );

      y += _kLineHeight;
      cursor = line.end;

      if (y > size.height - _kLineHeight) break;
    }

    // ── 4. Also show layoutWithLines output as comparison below ──────────
    final dividerY = y + 20;
    canvas.drawLine(
      Offset(0, dividerY),
      Offset(innerW, dividerY),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1,
    );

    final label = TextPainter(
      text: const TextSpan(
        text: 'layoutWithLines() — fixed width for comparison',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: innerW);
    label.paint(canvas, Offset(0, dividerY + 8));

    final fixedResult = layoutWithLines(prepared, innerW, _kLineHeight);
    for (var i = 0;
        i < fixedResult.lines.length && i < 3; // show first 3 lines only
        i++) {
      final line = fixedResult.lines[i];
      final tp = TextPainter(
        text: TextSpan(
          text: line.text,
          style: _kStyle.copyWith(color: Colors.white38),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: innerW);
      tp.paint(canvas, Offset(0, dividerY + 28 + i * _kLineHeight));
    }
  }

  @override
  bool shouldRepaint(_FloatAroundPainter old) =>
      old.canvasWidth != canvasWidth;
}
