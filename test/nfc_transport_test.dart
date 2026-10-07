import 'dart:async';

import 'package:eid_icao/eid_icao.dart';
import 'package:eid_icao/testing.dart';
import 'package:eid_nfc/eid_nfc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone whose NFC finds [chip] when it is on the reader.
final class _FakeNfc implements NfcDriver {
  _FakeNfc(this.chip);

  final SimulatedIcaoChip chip;
  bool isoDep = true;
  bool cancelNext = false;

  /// Whether a poll waits for ever, as the plugin's after finish on
  /// Android.
  bool hang = false;
  int polls = 0;
  final finished = <String?>[];
  final messages = <String>[];

  @override
  Future<NfcAvailability> availability() async => NfcAvailability.available;

  @override
  Future<NfcTag> poll({
    required Duration timeout,
    required String iosMessage,
    Duration? androidPresenceCheckDelay,
  }) async {
    polls++;
    if (hang) await Completer<void>().future;
    if (cancelNext) {
      cancelNext = false;
      throw const NfcCancelledException();
    }
    if (!chip.isInserted) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
      throw const CardTransportException('No document came');
    }
    return NfcTag(id: '08AABBCC', isIsoDep: isoDep);
  }

  @override
  Future<Uint8List> transceive(Uint8List command, Duration timeout) =>
      chip.transmit(command);

  @override
  Future<void> finish({String? iosMessage, String? iosError}) async =>
      finished.add(iosError ?? iosMessage);

  @override
  Future<void> setIosMessage(String message) async => messages.add(message);
}

void main() {
  test('cancel stops a wait no document ends', () async {
    final nfc = _FakeNfc(SimulatedIcaoChip())..hang = true;
    final connecting = expectLater(
      NfcTransport.connect(driver: nfc),
      throwsA(isA<NfcCancelledException>()),
    );
    await Future<void>.delayed(Duration.zero);
    await NfcTransport.cancel();
    await connecting;
    expect(nfc.finished, [null], reason: 'the plugin session ended');
  });

  test('cancel ends a read under way', () async {
    final chip = SimulatedIcaoChip();
    final nfc = _FakeNfc(chip);
    final transport = await NfcTransport.connect(driver: nfc);
    final reading = IcaoReader(transport).read(
      access: chip.canKey,
      onProgress: (_) => NfcTransport.cancel(),
    );
    await expectLater(reading, throwsA(isA<Exception>()));
    await expectLater(
      transport.transmit(Uint8List(4)),
      throwsA(isA<CardTransportException>()),
    );
  });

  test('reads a document on the phone', () async {
    final chip = SimulatedIcaoChip();
    final nfc = _FakeNfc(chip);
    final transport = await NfcTransport.connect(driver: nfc);
    expect(transport.tag.id, '08AABBCC');

    final document = await IcaoReader(transport).read(
      access: chip.canKey,
      onProgress: (fraction) =>
          transport.setIosMessage('Reading ${(fraction * 100).round()} %'),
    );
    expect(document.mrz.lastName, 'SPECIMEN');
    expect(nfc.messages.last, 'Reading 100 %');

    await transport.finish(iosMessage: 'Done');
    expect(nfc.finished, ['Done']);
    await expectLater(
      transport.transmit(Uint8List(4)),
      throwsA(isA<CardTransportException>()),
    );
    await transport.disconnect();
    expect(nfc.finished, hasLength(1), reason: 'finished once');
  });

  test('turns down a tag that takes no ISO 7816 command', () async {
    final nfc = _FakeNfc(SimulatedIcaoChip())..isoDep = false;
    await expectLater(
      NfcTransport.connect(driver: nfc),
      throwsA(isA<CardTransportException>()),
    );
    expect(nfc.finished, ['Not an identity document']);
  });

  test('ends the previous session before a new one', () async {
    final nfc = _FakeNfc(SimulatedIcaoChip());
    final first = await NfcTransport.connect(driver: nfc);
    await NfcTransport.connect(driver: nfc);
    expect(nfc.finished, hasLength(1));
    await expectLater(
      first.transmit(Uint8List(4)),
      throwsA(isA<CardTransportException>()),
    );
  });

  test('passes a cancellation on', () async {
    final nfc = _FakeNfc(SimulatedIcaoChip())..cancelNext = true;
    await expectLater(
      NfcTransport.connect(driver: nfc),
      throwsA(isA<NfcCancelledException>()),
    );
  });

  test('watches with an IcaoWatcher', () async {
    final chip = SimulatedIcaoChip()..remove();
    final watcher = IcaoWatcher(
      NfcTerminal(driver: _FakeNfc(chip)),
      accessKey: chip.canKey,
      interval: const Duration(milliseconds: 5),
    )..start();
    chip.insert();
    final read = await watcher.events.firstWhere((e) => e is IcaoChipRead)
        as IcaoChipRead;
    expect(read.document.mrz.firstNames, 'ALICE MARIE');
    chip.remove();
    await watcher.events.firstWhere((e) => e is IcaoChipRemoved);
    await watcher.dispose();
  });

  test('pauses when the holder closes the iOS sheet', () async {
    final nfc = _FakeNfc(SimulatedIcaoChip())..cancelNext = true;
    var cancelled = 0;
    final terminal = NfcTerminal(driver: nfc, onCancelled: () => cancelled++);
    await expectLater(
      terminal.connect(),
      throwsA(isA<CardTransportException>()),
    );
    expect(terminal.isPaused, isTrue);
    expect(cancelled, 1);
    await expectLater(
      terminal.connect(),
      throwsA(isA<CardTransportException>()),
    );
    expect(nfc.polls, 1, reason: 'no new sheet while paused');
    terminal.resume();
    final connection = await terminal.connect();
    await connection.disconnect();
    expect(nfc.polls, 2);
  });
}
