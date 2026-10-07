import 'package:flutter/material.dart';

/// The NFC mark, where a phone reads a tag: a rounded square in [color],
/// the icon colour by default, with an N cut out of it.
class NfcMark extends StatelessWidget {
  const NfcMark({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? IconTheme.of(context).color ?? Colors.black;
    return CustomPaint(
      size: Size.square(size),
      painter: _NfcMarkPainter(ink),
    );
  }
}

class _NfcMarkPainter extends CustomPainter {
  const _NfcMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = size.shortestSide;
    final bounds = Offset.zero & Size.square(s);

    // One half of the N: a bar up the left, bowed out a little, to a
    // point, then a diagonal down towards the middle. The other half is the
    // same, turned half a turn, its diagonal a gap away.
    final half = Path()
      ..moveTo(0.17 * s, 0.94 * s)
      ..quadraticBezierTo(0.14 * s, 0.5 * s, 0.20 * s, 0.06 * s)
      ..lineTo(0.59 * s, 0.67 * s)
      ..lineTo(0.515 * s, 0.67 * s)
      ..lineTo(0.26 * s, 0.271 * s)
      ..quadraticBezierTo(0.235 * s, 0.6 * s, 0.26 * s, 0.94 * s)
      ..close();
    // Half a turn about the centre: (x, y) to (s - x, s - y).
    final turned = half.transform(
      (Matrix4.diagonal3Values(-1, -1, 1)..setTranslationRaw(s, s, 0)).storage,
    );
    final cut = Paint()..blendMode = BlendMode.clear;

    canvas
      ..saveLayer(bounds, Paint())
      ..drawRRect(
        RRect.fromRectAndRadius(bounds, Radius.circular(s * 0.13)),
        Paint()..color = color,
      )
      ..drawPath(half, cut)
      ..drawPath(turned, cut)
      ..restore();
  }

  @override
  bool shouldRepaint(_NfcMarkPainter oldDelegate) => oldDelegate.color != color;
}
