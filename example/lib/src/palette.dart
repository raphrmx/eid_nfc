import 'package:flutter/material.dart';

/// The demo colours, shared with the other COMAPPS package demos.
abstract final class Palette {
  static const paper = Color(0xFFF6F1EA);
  static const sand = Color(0xFFEDE4D8);
  static const white = Color(0xFFFFFDFB);
  static const ink = Color(0xFF1D1712);
  static const muted = Color(0xFF6F665E);
  static const line = Color(0xFFE4DACD);
  static const accent = Color(0xFF3355D6);
  static const success = Color(0xFF2FA36B);
  static const warning = Color(0xFFD99A1E);
  static const danger = Color(0xFFE0446B);

  /// The reader's light while it waits or works.
  static const readerBlue = Color(0xFF3D8BFF);

  /// The reader's body.
  static const device = Color(0xFF2A2724);
  static const deviceEdge = Color(0xFF3C3833);

  /// The card's mint green, its paler title band and navy print.
  static const cardMint = Color(0xFFD7ECD9);
  static const cardPale = Color(0xFFEFF6EA);
  static const cardSky = Color(0xFFE2ECEF);
  static const cardLine = Color(0xFF86B993);
  static const cardInk = Color(0xFF1E2A38);
  static const cardLabel = Color(0xFF4D5E57);
  static const euBlue = Color(0xFF1F4BA5);

  static const shadow = [
    BoxShadow(color: Color(0x1F3B2A1A), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const softShadow = [
    BoxShadow(color: Color(0x143B2A1A), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

/// A white rounded card, the building block of the page.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = 20});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    // A Material carries the white so the tiles' ink shows.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: Palette.softShadow,
      ),
      child: Material(
        color: Palette.white,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: EdgeInsets.all(padding), child: child),
      ),
    );
  }
}

/// The small upper case label above a value.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.color = Palette.muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
