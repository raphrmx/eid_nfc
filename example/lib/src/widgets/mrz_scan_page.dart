import 'dart:isolate';

import 'package:eid_icao/mrz_scanner.dart';
import 'package:eid_nfc_example/src/palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:universal_barcode_scanner/universal_barcode_scanner.dart';

/// The camera over the document until its MRZ is read, two frames agreeing.
///
/// Pops with the [MrzScanResult], or null when the user goes back.
class MrzScanPage extends StatefulWidget {
  /// The page.
  const MrzScanPage({super.key});

  /// Opens the page; completes with the zone read, or null.
  static Future<MrzScanResult?> open(BuildContext context) =>
      Navigator.of(context).push<MrzScanResult>(
        MaterialPageRoute(builder: (_) => const MrzScanPage()),
      );

  @override
  State<MrzScanPage> createState() => _MrzScanPageState();
}

// Rebuilds come from the notifier, not setState.
class _MrzScanPageState extends State<MrzScanPage> {
  final _scanner = MrzScanner();

  /// Whether the last frame read showed a zone.
  final _inView = ValueNotifier<bool>(false);

  bool _busy = false;
  bool _done = false;

  // One frame at a time: the frames that come meanwhile are dropped.
  Future<void> _onFrame(ScanFrame frame) async {
    if (_busy || _done) return;
    _busy = true;
    try {
      final reading = await _readAside(
        MrzImage.luminance(
          width: frame.width,
          height: frame.height,
          bytes: frame.bytes,
          rotation: MrzRotation.values[frame.quarterTurns],
        ),
      );
      if (!mounted || _done) return;
      _inView.value = reading != null;
      final result = _scanner.addReading(reading);
      if (result != null) {
        _done = true;
        Navigator.of(context).pop(result);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _inView.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan the MRZ'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // An ID-1 card, 85.6 by 54 mm, across most of the screen.
          final width = constraints.maxWidth * 0.9;
          return Stack(
            fit: StackFit.expand,
            children: [
              UniversalBarcodeScanner(
                scanFormat: ScanFormat.none,
                continuous: true,
                scanWindowSize: Size(width, width * 54 / 85.6),
                lineColor: Palette.accent,
                buttons: const {ScannerButton.torch},
                onFrame: _onFrame,
                onCreated: (_) {},
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 32,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _inView,
                  builder: (context, inView, _) => Text(
                    inView
                        ? 'Reading… hold the document still.'
                        : 'Fit the back of the card, or the photo page of the '
                            'passport, in the frame: its two or three lines '
                            'of letters and <<< at the bottom.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, height: 1.4),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// In another isolate, where there is one: a frame takes some 100 ms.
Future<MrzReading?> _readAside(MrzImage image) =>
    kIsWeb ? Future.value(_read(image)) : Isolate.run(() => _read(image));

MrzReading? _read(MrzImage image) => const MrzRecognizer().read(image);
