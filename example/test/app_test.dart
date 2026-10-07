import 'package:eid_nfc_example/main.dart';
import 'package:eid_nfc_example/src/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const ExampleApp(source: DocumentSource.simulated),
  );
}

// Reads with the simulated chip, whose commands take real time.
Future<void> _read(WidgetTester tester) async {
  await tester.tap(find.text('Read'));
  await tester.runAsync(() async {
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      if (find.text('Cancel').evaluate().isEmpty) break;
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('asks for the CAN, or the MRZ in full', (tester) async {
    await _open(tester);
    expect(find.text('Card access number'), findsOneWidget);
    await tester.tap(find.text('MRZ'));
    await tester.pump();
    expect(find.text('Document number, in full'), findsOneWidget);
  });

  testWidgets('reads the simulated card onto the specimen', (tester) async {
    await _open(tester);
    await _read(tester);
    expect(find.text('Specimen'), findsWidgets);
    expect(find.text('Alice Marie'), findsOneWidget);
    expect(find.text('UTOPIA'), findsOneWidget);
    expect(find.text('Genuine chip: Chip Authentication'), findsOneWidget);
    expect(find.text('Face in JPEG 2000, shown as PNG'), findsOneWidget);
  });

  testWidgets('turns down a tampered card', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Tampered'));
    await tester.pump();
    await _read(tester);
    expect(find.text('Alice Marie'), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('cancels a read', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Read'));
    await tester.pump();
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Alice Marie'), findsNothing);
  });
}
