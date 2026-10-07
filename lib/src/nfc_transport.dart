import 'dart:async';

import 'package:eid/eid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

/// Whether the device can read NFC.
enum NfcAvailability {
  /// NFC is on.
  available,

  /// The device has NFC, turned off in its settings.
  disabled,

  /// The device has no NFC, or the platform has none (desktop, web).
  notSupported,
}

/// The holder closed the system sheet, on iOS, before a document was read,
/// or the application called [NfcTransport.cancel].
final class NfcCancelledException implements Exception {
  /// The holder gave up.
  const NfcCancelledException();

  @override
  String toString() => 'NfcCancelledException: the NFC session was cancelled';
}

/// A tag the phone found.
final class NfcTag {
  /// A tag of identifier [id], speaking ISO 7816 commands when [isIsoDep].
  const NfcTag(
      {required this.id, required this.isIsoDep, this.historicalBytes});

  /// The tag's identifier, in hexadecimal. Passports draw a random one at
  /// each session.
  final String id;

  /// Whether the tag takes ISO 7816 commands (ISO-DEP), as identity
  /// documents do.
  final bool isIsoDep;

  /// The historical bytes of its answer to select, in hexadecimal.
  final String? historicalBytes;
}

/// What [NfcTransport] needs from the NFC plugin. [FlutterNfcKitDriver] is
/// the default; tests put a simulated document in its place.
abstract interface class NfcDriver {
  /// Whether NFC is there and on.
  Future<NfcAvailability> availability();

  /// Waits up to [timeout] for a tag, showing [iosMessage] on iOS, and
  /// opens a session with it.
  ///
  /// Throws an [NfcCancelledException] when the holder closes the iOS
  /// sheet, and a [CardTransportException] when no tag comes.
  Future<NfcTag> poll({
    required Duration timeout,
    required String iosMessage,
    Duration? androidPresenceCheckDelay,
  });

  /// Sends [command] and returns the answer, status bytes included.
  Future<Uint8List> transceive(Uint8List command, Duration timeout);

  /// Ends the session, showing [iosMessage] or [iosError] on iOS.
  Future<void> finish({String? iosMessage, String? iosError});

  /// Changes the message of the iOS sheet. Does nothing elsewhere.
  Future<void> setIosMessage(String message);
}

/// A connection to the identity document on the phone, over NFC.
///
/// One at a time: NFC on a phone serves one session. On iOS the system
/// sheet stays up while connected, at most a minute.
///
/// ```dart
/// final transport = await NfcTransport.connect();
/// try {
///   final document = await IcaoReader(transport).read(access: key);
///   await transport.finish(iosMessage: 'Done');
/// } on Exception {
///   await transport.finish(iosError: 'Could not read the document');
///   rethrow;
/// }
/// ```
final class NfcTransport implements CardConnection {
  NfcTransport._(this.tag, this._driver, this._timeout);

  /// The tag connected.
  final NfcTag tag;

  final NfcDriver _driver;
  final Duration _timeout;
  bool _released = false;

  static NfcTransport? _current;

  // The wait of connect under way, and the driver it waits with.
  static Completer<NfcTag>? _waiting;
  static NfcDriver? _waitingDriver;

  /// The default of `androidPresenceCheckDelay`: longer than Android's
  /// own, a fraction of a second.
  static const defaultPresenceCheckDelay = Duration(milliseconds: 1500);

  /// Whether NFC is there and on.
  static Future<NfcAvailability> availability({NfcDriver? driver}) =>
      (driver ?? const FlutterNfcKitDriver()).availability();

  /// Waits for a document on the phone and connects to it.
  ///
  /// [pollTimeout] is how long to wait on Android; iOS decides alone.
  /// [iosMessage] shows on the iOS sheet. [transceiveTimeout] is how long a
  /// command may take on Android, key agreement included.
  /// [androidPresenceCheckDelay] spaces the checks Android makes that the
  /// tag is still there: checked too often, some identity documents drop
  /// the connection during key agreement.
  ///
  /// Ends the connection before, if any. Throws an [NfcCancelledException]
  /// when the holder closes the iOS sheet, and a [CardTransportException]
  /// when no document comes or the tag is not one.
  static Future<NfcTransport> connect({
    Duration pollTimeout = const Duration(seconds: 20),
    Duration transceiveTimeout = const Duration(seconds: 5),
    String iosMessage = 'Hold your document against the top of your iPhone',
    Duration androidPresenceCheckDelay = defaultPresenceCheckDelay,
    NfcDriver? driver,
  }) async {
    final nfc = driver ?? const FlutterNfcKitDriver();
    final previous = _current;
    if (previous != null && !previous._released) await previous.disconnect();
    // The plugin never answers a poll that finish stopped, on Android:
    // cancel ends the wait here.
    final waiting = _waiting = Completer<NfcTag>();
    _waitingDriver = nfc;
    final NfcTag tag;
    try {
      tag = await Future.any([
        nfc.poll(
          timeout: pollTimeout,
          iosMessage: iosMessage,
          androidPresenceCheckDelay: androidPresenceCheckDelay,
        ),
        waiting.future,
      ]);
    } finally {
      if (identical(_waiting, waiting)) {
        _waiting = null;
        _waitingDriver = null;
      }
    }
    if (!tag.isIsoDep) {
      await nfc.finish(iosError: 'Not an identity document');
      throw const CardTransportException('The tag takes no ISO 7816 command');
    }
    return _current = NfcTransport._(tag, nfc, transceiveTimeout);
  }

  /// Stops the wait of [connect], which throws an [NfcCancelledException],
  /// and ends the connection under way, whose next command throws a
  /// [CardTransportException]: what a Cancel button calls.
  static Future<void> cancel() async {
    final waiting = _waiting;
    final driver = _waitingDriver;
    _waiting = null;
    _waitingDriver = null;
    if (waiting != null && !waiting.isCompleted) {
      waiting.completeError(const NfcCancelledException());
      try {
        await driver?.finish();
      } on CardTransportException {
        // No session to end.
      }
    }
    await _current?.finish();
  }

  @override
  Future<Uint8List> transmit(Uint8List command) {
    if (_released) {
      return Future.error(
        const CardTransportException('The NFC session has ended'),
      );
    }
    return _driver.transceive(command, _timeout);
  }

  /// Changes the message of the iOS sheet, to show progress. Does nothing
  /// on Android.
  Future<void> setIosMessage(String message) =>
      _released ? Future.value() : _driver.setIosMessage(message);

  /// Ends the session. On iOS the sheet closes on [iosMessage], or on
  /// [iosError] shown as a failure.
  Future<void> finish({String? iosMessage, String? iosError}) async {
    if (_released) return;
    _released = true;
    if (identical(_current, this)) _current = null;
    await _driver.finish(iosMessage: iosMessage, iosError: iosError);
  }

  /// Ends the session, the iOS sheet closing without a message.
  @override
  Future<void> disconnect() => finish();
}

/// The phone's NFC as a terminal, for a `CardWatcher` or an `IcaoWatcher`:
/// each wait for a document is a [NfcTransport.connect].
///
/// On iOS each wait opens the system sheet. When the holder closes it, the
/// terminal pauses, so that the sheet does not open again at once, and
/// calls [onCancelled]; [resume] waits again. On iOS, a button that calls
/// [NfcTransport.connect] usually suits better than watching.
final class NfcTerminal implements CardTerminal {
  /// A terminal waiting [pollTimeout] for each document.
  NfcTerminal({
    this.pollTimeout = const Duration(seconds: 20),
    this.transceiveTimeout = const Duration(seconds: 5),
    this.iosMessage = 'Hold your document against the top of your iPhone',
    this.androidPresenceCheckDelay = NfcTransport.defaultPresenceCheckDelay,
    this.onCancelled,
    NfcDriver? driver,
  }) : _driver = driver ?? const FlutterNfcKitDriver();

  /// How long each wait lasts on Android.
  final Duration pollTimeout;

  /// How long a command may take on Android.
  final Duration transceiveTimeout;

  /// The message of the iOS sheet.
  final String iosMessage;

  /// How often Android checks the tag is still there.
  final Duration androidPresenceCheckDelay;

  /// Called when the holder closes the iOS sheet.
  final VoidCallback? onCancelled;

  final NfcDriver _driver;
  bool _paused = false;

  @override
  String get name => 'NFC';

  /// Whether waiting stopped after the holder closed the iOS sheet.
  bool get isPaused => _paused;

  /// Waits for documents again after a cancellation.
  void resume() => _paused = false;

  @override
  Future<CardConnection> connect() async {
    if (_paused) throw const CardTransportException('NFC is paused');
    try {
      return await NfcTransport.connect(
        pollTimeout: pollTimeout,
        transceiveTimeout: transceiveTimeout,
        iosMessage: iosMessage,
        androidPresenceCheckDelay: androidPresenceCheckDelay,
        driver: _driver,
      );
    } on NfcCancelledException catch (cancelled) {
      _paused = true;
      onCancelled?.call();
      throw CardTransportException('NFC cancelled', cause: cancelled);
    }
  }

  @override
  String toString() => 'NfcTerminal()';
}

/// The [NfcDriver] over the `flutter_nfc_kit` plugin.
final class FlutterNfcKitDriver implements NfcDriver {
  /// The driver.
  const FlutterNfcKitDriver();

  // SKIP_NDEF_CHECK: identity documents hold no NDEF, and the check
  // selects another application.
  static const _skipNdefCheck = 0x80;

  @override
  Future<NfcAvailability> availability() async {
    if (kIsWeb) return NfcAvailability.notSupported;
    try {
      return switch (await FlutterNfcKit.nfcAvailability) {
        NFCAvailability.available => NfcAvailability.available,
        NFCAvailability.disabled => NfcAvailability.disabled,
        NFCAvailability.not_supported => NfcAvailability.notSupported,
      };
    } on MissingPluginException {
      return NfcAvailability.notSupported;
    }
  }

  @override
  Future<NfcTag> poll({
    required Duration timeout,
    required String iosMessage,
    Duration? androidPresenceCheckDelay,
  }) async {
    final NFCTag tag;
    try {
      tag = await FlutterNfcKit.poll(
        timeout: timeout,
        iosAlertMessage: iosMessage,
        androidCheckNDEF: false,
        androidReaderModeFlags: _skipNdefCheck,
        readIso15693: false,
        extraReaderPresenceCheckDelay: androidPresenceCheckDelay,
      );
    } on PlatformException catch (error) {
      if (error.code == '409') throw const NfcCancelledException();
      throw CardTransportException(
        error.code == '408' ? 'No document came' : 'NFC failed',
        cause: error,
      );
    } on Object catch (error) {
      throw CardTransportException('NFC failed', cause: error);
    }
    return NfcTag(
      id: tag.id,
      isIsoDep: tag.type == NFCTagType.iso7816,
      historicalBytes: tag.historicalBytes,
    );
  }

  @override
  Future<Uint8List> transceive(Uint8List command, Duration timeout) async {
    try {
      return await FlutterNfcKit.transceive(command, timeout: timeout);
    } on Object catch (error) {
      // A tag pulled away, or a session the OS closed.
      final detail = error is PlatformException ? ': ${error.details}' : '';
      throw CardTransportException(
        'The document did not answer$detail',
        cause: error,
      );
    }
  }

  @override
  Future<void> finish({String? iosMessage, String? iosError}) async {
    try {
      await FlutterNfcKit.finish(
        iosAlertMessage: iosMessage,
        iosErrorMessage: iosError,
      );
    } on Object catch (error) {
      throw CardTransportException('Could not end the session', cause: error);
    }
  }

  @override
  Future<void> setIosMessage(String message) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await FlutterNfcKit.setIosAlertMessage(message);
    } on PlatformException {
      // The session has just ended: the message no longer matters.
    }
  }
}
