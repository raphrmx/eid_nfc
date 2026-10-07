import 'package:eid_nfc_example/src/palette.dart';
import 'package:eid_nfc_example/src/session.dart';
import 'package:eid_nfc_example/src/widgets/id_card.dart';
import 'package:eid_nfc_example/src/widgets/nfc_mark.dart';
import 'package:flutter/material.dart';

/// A phone, and the card that goes behind it, against its NFC antenna,
/// while a read waits for it and runs.
class PhoneStage extends StatelessWidget {
  const PhoneStage({super.key, required this.session});

  final ReadSession session;

  static const _slide = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final phoneWidth = width * 0.46;
        final phoneHeight = phoneWidth * 1.95;
        final cardWidth = width * 0.7;
        final cardHeight = cardWidth / cardAspectRatio;
        final phoneTop = cardHeight * 0.72;
        // Against the phone, the card sits behind its upper half.
        final placedTop = phoneTop + phoneHeight * 0.14;
        final placed = session.reading;

        return SizedBox(
          height: phoneTop + phoneHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Only the move animates; resizes apply at once.
              TweenAnimationBuilder<double>(
                tween: Tween(end: placed ? 1 : 0),
                duration: _slide,
                curve: Curves.easeInOutCubic,
                builder: (context, depth, card) => Positioned(
                  left: (width - cardWidth) / 2,
                  width: cardWidth,
                  top: placedTop * depth,
                  child: card!,
                ),
                // The card as printed: what the chip holds shows below.
                child: IdCard(printedPhoto: session.printedPhoto),
              ),
              Positioned(
                left: (width - phoneWidth) / 2,
                width: phoneWidth,
                top: phoneTop,
                height: phoneHeight,
                child: _Phone(session: session, width: phoneWidth),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Phone extends StatelessWidget {
  const _Phone({required this.session, required this.width});

  final ReadSession session;
  final double width;

  static Color _color(ReaderLight light) => switch (light) {
        ReaderLight.waiting || ReaderLight.working => Palette.readerBlue,
        ReaderLight.success => Palette.success,
        ReaderLight.warning => _Display._amber,
        ReaderLight.failure => Palette.danger,
      };

  @override
  Widget build(BuildContext context) {
    final light = session.light;
    final color = _color(light);
    final simulated = session.source == DocumentSource.simulated;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.deviceEdge, Palette.device, Color(0xFF1C1A18)],
        ),
        boxShadow: Palette.shadow,
      ),
      child: Padding(
        padding: EdgeInsets.all(width * 0.045),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0C0B),
            borderRadius: BorderRadius.circular(width * 0.12),
          ),
          child: Column(
            children: [
              SizedBox(height: width * 0.07),
              // The camera.
              Container(
                width: width * 0.06,
                height: width * 0.06,
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1F1E),
                  shape: BoxShape.circle,
                ),
              ),
              const Spacer(flex: 3),
              // The contactless mark lights up with the read.
              _Glow(
                color: color,
                blinking: light == ReaderLight.working,
                builder: (context, color, glow) => DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45 * glow),
                        blurRadius: width * 0.15,
                      ),
                    ],
                  ),
                  child: NfcMark(
                    color:
                        Color.lerp(color.withValues(alpha: 0.3), color, glow),
                    size: width * 0.3,
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: width * 0.07),
                // The progress changes many times a read: only the display
                // follows it, and repaints on its own.
                child: RepaintBoundary(
                  child: ListenableBuilder(
                    listenable: session.progress,
                    builder: (context, _) => _Display(
                      width: width * 1.8,
                      text: _label(session),
                      caption: simulated ? 'SIMULATED CHIP' : 'PHONE NFC',
                      error: session.reading ? null : session.error,
                      warning: session.errorIsWarning,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  static String _label(ReadSession session) {
    if (session.waitingForDocument) return 'Hold card';
    if (session.reading) {
      return 'Reading ${(session.progress.value * 100).round()}%';
    }
    if (session.document != null) return 'Card read';
    return 'Press Read';
  }
}

/// Eases into [color] and pulses while [blinking]; brightness is 0 to 1.
class _Glow extends StatefulWidget {
  const _Glow({
    required this.color,
    required this.blinking,
    required this.builder,
  });

  final Color color;
  final bool blinking;
  final Widget Function(BuildContext context, Color color, double glow) builder;

  @override
  State<_Glow> createState() => _GlowState();
}

// The pulse is an animation the controller drives; nothing else is state.
class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(_Glow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blinking != widget.blinking) _follow();
  }

  void _follow() {
    if (widget.blinking) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The pulse repaints every frame while reading: keep it to itself.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final glow = 0.15 + 0.85 * Curves.easeInOut.transform(_pulse.value);
          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: widget.color),
            duration: const Duration(milliseconds: 300),
            builder: (context, color, _) =>
                widget.builder(context, color ?? widget.color, glow),
          );
        },
      ),
    );
  }
}

/// The reader's small LED screen: light blue text, or an [error] in red.
class _Display extends StatelessWidget {
  const _Display({
    required this.width,
    required this.text,
    required this.caption,
    this.error,
    this.warning = false,
  });

  static const _lit = Color(0xFFDCEBFF);
  static const _red = Color(0xFFFF5A5F);
  static const _amber = Color(0xFFFFA53A);

  final double width;
  final String text;
  final String caption;
  final String? error;

  /// Shows [error] in amber rather than red.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: width * 0.14,
      padding: EdgeInsets.symmetric(horizontal: width * 0.035),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C0B),
        borderRadius: BorderRadius.circular(width * 0.018),
        border: Border.all(
          color: const Color(0xFF020302),
          width: width * 0.004,
        ),
        boxShadow: [
          // A thin highlight under the glass, where the case catches light.
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.08),
            offset: Offset(0, width * 0.004),
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: const _DotMatrix(),
        child: error != null
            ? Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  error!.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: width * 0.032,
                    fontWeight: FontWeight.w700,
                    letterSpacing: width * 0.002,
                    height: 1.2,
                    color: warning ? _amber : _red,
                    shadows: [
                      Shadow(
                        color: (warning ? _amber : _red).withValues(alpha: 0.6),
                        blurRadius: width * 0.02,
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: width * 0.04,
                      fontWeight: FontWeight.w700,
                      letterSpacing: width * 0.004,
                      height: 1.1,
                      color: _lit,
                      shadows: [
                        Shadow(
                          color: _lit.withValues(alpha: 0.6),
                          blurRadius: width * 0.02,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    caption,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: width * 0.024,
                      letterSpacing: width * 0.003,
                      height: 1.3,
                      color: _lit.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The fine grid of an LED screen, drawn over the text.
class _DotMatrix extends CustomPainter {
  const _DotMatrix();

  @override
  void paint(Canvas canvas, Size size) {
    // A zero pitch would never end the loops below.
    if (size.isEmpty) return;
    final pitch = size.height / 18;
    final paint = Paint()
      ..color = const Color(0xFF0A0C0B).withValues(alpha: 0.55)
      ..strokeWidth = pitch * 0.35;
    for (var y = pitch / 2; y < size.height; y += pitch) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var x = pitch / 2; x < size.width; x += pitch) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_DotMatrix oldDelegate) => false;
}
