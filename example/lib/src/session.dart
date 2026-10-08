import 'dart:typed_data';

import 'package:eid_icao/eid_icao.dart';
import 'package:eid_icao/testing.dart';
import 'package:eid_nfc/eid_nfc.dart';
import 'package:eid_nfc_example/src/apdu_log.dart';
import 'package:eid_nfc_example/src/widgets/id_card.dart';
import 'package:flutter/widgets.dart';

/// How the key of the document is given.
enum KeyMode {
  /// The card access number.
  can,

  /// The document number and the dates of the MRZ.
  mrz,
}

/// Where the document comes from.
enum DocumentSource {
  /// A real document against the phone.
  nfc,

  /// A simulated chip, to try the app without a document.
  simulated,
}

/// The simulated documents to try.
enum SimulatedKind { valid, expired, tampered, cloned }

/// The phone's status light, on its screen.
enum ReaderLight { waiting, working, success, warning, failure }

// Keys given at launch, so that they stay out of the code:
// flutter run --dart-define=MRZ_NUMBER=... (or CAN=...).
const _testCan = String.fromEnvironment('CAN');
const _testNumber = String.fromEnvironment('MRZ_NUMBER');
const _testBirth = String.fromEnvironment('MRZ_BIRTH');
const _testExpiry = String.fromEnvironment('MRZ_EXPIRY');

/// The state of the page, and the read itself.
class ReadSession extends ChangeNotifier {
  /// A session reading from [source].
  ReadSession({this.source = DocumentSource.nfc}) {
    if (_testCan.isEmpty && _testNumber.isNotEmpty) mode = KeyMode.mrz;
    if (source == DocumentSource.simulated) _fillKey(_newChip());
  }

  /// Where documents come from.
  DocumentSource source;

  /// The simulated document, when [source] is simulated.
  SimulatedKind simulatedKind = SimulatedKind.valid;

  /// How the key is given.
  KeyMode mode = KeyMode.can;

  final can = TextEditingController(text: _testCan);
  final number = TextEditingController(text: _testNumber);
  final birth = TextEditingController(text: _testBirth);
  final expiry = TextEditingController(text: _testExpiry);

  bool _showPrivateData = false;
  bool _readFace = true;
  bool _verifySignatures = true;
  bool _verifyCard = true;
  bool _acceptExpired = false;

  /// The availability of NFC, once known.
  NfcAvailability? availability;

  /// Whether a read is under way.
  bool reading = false;

  /// Whether the read waits for the document to come.
  bool waitingForDocument = false;

  /// The share of the read done; only the phone's screen follows it.
  final progress = ValueNotifier<double>(0);

  /// The document read last.
  IcaoDocument? document;

  /// What the card shows of [document].
  CardData? cardData;

  /// The photo printed on the card before its chip is read: the simulated
  /// document's, none for a real one.
  Uint8List? get printedPhoto =>
      source == DocumentSource.simulated ? specimenPhoto : null;

  /// Whether the chip proved it is not a copy.
  bool get chipGenuine => switch (document?.authenticity) {
        IcaoChipAuthenticity.chipAuthentication ||
        IcaoChipAuthenticity.chipAuthenticationMapping ||
        IcaoChipAuthenticity.activeAuthentication =>
          true,
        _ => false,
      };

  /// What went wrong with the last read, in a few words.
  String? error;

  /// Whether [error] is a warning, as a cancelled read, more than a failure.
  bool errorIsWarning = false;

  /// What went wrong, in full, to report a problem with a real document.
  String? errorDetail;

  /// How long the last read took.
  Duration? readTime;

  /// The reads so far: each one brings the card's fields in again.
  int readCount = 0;

  /// Every command and answer of the last read.
  final apduLog = ApduLog();

  bool _cancelled = false;
  SimulatedIcaoChip? _chip;

  /// Whether the personal numbers are read, such as the Belgian national
  /// register number.
  bool get showPrivateData => _showPrivateData;
  set showPrivateData(bool value) => _set(() => _showPrivateData = value);

  /// Whether the face is read, the largest file.
  bool get readFace => _readFace;
  set readFace(bool value) => _set(() => _readFace = value);

  /// Whether Passive Authentication runs.
  bool get verifySignatures => _verifySignatures;
  set verifySignatures(bool value) => _set(() => _verifySignatures = value);

  /// Whether the chip is asked to prove it is not a copy.
  bool get verifyCard => _verifyCard;
  set verifyCard(bool value) => _set(() => _verifyCard = value);

  /// Whether expired documents are read.
  bool get acceptExpired => _acceptExpired;
  set acceptExpired(bool value) => _set(() => _acceptExpired = value);

  void _set(void Function() change) {
    change();
    notifyListeners();
  }

  /// The light on the phone's screen.
  ReaderLight get light {
    if (reading) return ReaderLight.working;
    if (error != null) {
      return errorIsWarning ? ReaderLight.warning : ReaderLight.failure;
    }
    return document == null ? ReaderLight.waiting : ReaderLight.success;
  }

  /// Checks NFC again: it may have been turned on since.
  Future<void> checkAvailability() async {
    if (source == DocumentSource.simulated) return;
    final now = await NfcTransport.availability();
    if (now == availability) return;
    availability = now;
    if (now == NfcAvailability.available && errorIsWarning) error = null;
    notifyListeners();
  }

  /// Switches how the key is given.
  void setMode(KeyMode value) => _set(() => mode = value);

  /// Reads from [value] from now on.
  void setSource(DocumentSource value) {
    if (reading || value == source) return;
    source = value;
    _clear();
    if (value == DocumentSource.simulated) {
      _fillKey(_newChip());
    } else {
      for (final field in [can, number, birth, expiry]) {
        field.clear();
      }
      checkAvailability();
    }
    notifyListeners();
  }

  /// Puts a new simulated document of [kind] on the phone.
  void newSimulatedCard(SimulatedKind kind) {
    if (reading) return;
    simulatedKind = kind;
    _clear();
    _fillKey(_newChip());
    notifyListeners();
  }

  void _clear() {
    document = null;
    cardData = null;
    error = null;
    errorDetail = null;
    readTime = null;
    apduLog.clear();
  }

  SimulatedIcaoChip _newChip() => _chip = SimulatedIcaoChip(
        type: IcaoDocumentType.identityCard,
        photo: specimenPhotoJpeg2000,
        expiryDate: simulatedKind == SimulatedKind.expired
            ? DateTime.utc(2024, 1, 31)
            : null,
        tamperedGroup:
            simulatedKind == SimulatedKind.tampered ? IcaoDataGroup.dg1 : null,
        cloned: simulatedKind == SimulatedKind.cloned,
        // Slow enough to see the read go.
        latency: const Duration(milliseconds: 12),
      );

  // The simulated document's key, ready to read.
  void _fillKey(SimulatedIcaoChip chip) {
    can.text = chip.can;
    number.text = chip.documentNumber;
    final born = chip.birthDate;
    birth.text = _yymmdd(born.year, born.month!, born.day!);
    final until = chip.expiryDate;
    expiry.text = _yymmdd(until.year, until.month, until.day);
  }

  /// Fills the MRZ fields with [key], as the camera read it.
  void fillFromMrz(IcaoMrzKey key) {
    if (reading) return;
    mode = KeyMode.mrz;
    number.text = key.documentNumber;
    final born = key.birthDate;
    // An unknown month or day stays blank, to be typed.
    birth.text = born.month == null || born.day == null
        ? ''
        : _yymmdd(born.year, born.month!, born.day!);
    final until = key.expiryDate;
    expiry.text = _yymmdd(until.year, until.month, until.day);
    _clear();
    notifyListeners();
  }

  static String _yymmdd(int year, int month, int day) =>
      [year % 100, month, day].map((v) => '$v'.padLeft(2, '0')).join();

  /// The key typed, or null when a field is wrong.
  IcaoAccessKey? key() {
    if (mode == KeyMode.can) {
      final value = can.text.replaceAll(RegExp(r'\s'), '');
      return RegExp(r'^\d+$').hasMatch(value) ? IcaoAccessKey.can(value) : null;
    }
    // Dashes, dots and spaces, as on the front of a Belgian card, go.
    final documentNumber =
        number.text.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
    final born = _date(birth.text, birth: true);
    final until = _date(expiry.text, birth: false);
    if (born == null ||
        until == null ||
        !RegExp(r'^[A-Z0-9<]+$').hasMatch(documentNumber)) {
      return null;
    }
    return IcaoAccessKey.mrz(
      documentNumber: documentNumber,
      birthDate: PartialDate(born.year, born.month, born.day),
      expiryDate: until,
    );
  }

  // YYMMDD as typed, the century guessed as the MRZ does.
  static DateTime? _date(String text, {required bool birth}) {
    final value = text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return null;
    final yy = int.parse(value.substring(0, 2));
    final month = int.parse(value.substring(2, 4));
    final day = int.parse(value.substring(4));
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final now = DateTime.now().year;
    final year = birth
        ? (2000 + yy > now ? 1900 + yy : 2000 + yy)
        : (2000 + yy > now + 50 ? 1900 + yy : 2000 + yy);
    return DateTime.utc(year, month, day);
  }

  /// Waits for a document and reads it with the key typed.
  Future<void> read() async {
    if (reading) return;
    final access = key();
    if (access == null) {
      _clear();
      error = mode == KeyMode.can ? 'Check the CAN' : 'Check the MRZ fields';
      errorIsWarning = true;
      notifyListeners();
      return;
    }
    if (source == DocumentSource.nfc) {
      await checkAvailability();
      if (availability != NfcAvailability.available) {
        error = availability == NfcAvailability.disabled
            ? 'Turn NFC on'
            : 'This phone has no NFC';
        errorIsWarning = true;
        notifyListeners();
        return;
      }
    }
    _clear();
    reading = true;
    waitingForDocument = source == DocumentSource.nfc;
    _cancelled = false;
    progress.value = 0;
    errorIsWarning = false;
    notifyListeners();

    NfcTransport? nfc;
    final clock = Stopwatch()..start();
    try {
      final CardTransport transport;
      if (source == DocumentSource.simulated) {
        transport = _chip!..insert();
      } else {
        transport = nfc = await NfcTransport.connect();
        waitingForDocument = false;
        notifyListeners();
      }
      document = await IcaoReader(transport, onApdu: apduLog.add).read(
        access: access,
        parts:
            _readFace ? IcaoPart.all : IcaoPart.all.difference({IcaoPart.face}),
        acceptExpired: _acceptExpired,
        verifySignatures: _verifySignatures,
        verifyCard: _verifyCard,
        showPrivateData: _showPrivateData,
        onProgress: (fraction) {
          progress.value = fraction;
          nfc?.setIosMessage('Reading… ${(fraction * 100).round()} %');
        },
      );
      cardData = CardData.of(document!);
      readTime = clock.elapsed;
      readCount++;
      await nfc?.finish(iosMessage: 'Done');
    } on NfcCancelledException {
      _cancelledRead();
    } on Exception catch (failure) {
      if (_cancelled) {
        _cancelledRead();
      } else {
        error = icaoErrorMessage(failure, IcaoLanguage.en);
        final log = apduLog;
        final last = log.length < 2 ? 'none' : '${log[log.length - 2]}';
        // The key as the chip got it, to spot a typo.
        final used = switch (access) {
          final IcaoMrzKey mrz => '\nMRZ information: ${mrz.information}',
          _ => '',
        };
        errorDetail = '$failure\n\n'
            'After ${apduLog.commandCount} commands, the last: $last$used';
        await _finish(nfc, error!);
      }
    } on Object catch (bug, stack) {
      // An error of the package itself: shown whole, to be reported.
      error = 'Unexpected error';
      final where = '$stack'.split('\n').take(8).join('\n');
      errorDetail = '$bug\n\nAfter ${apduLog.commandCount} commands\n\n$where';
      await _finish(nfc, 'Could not read the document');
    } finally {
      reading = false;
      waitingForDocument = false;
      notifyListeners();
    }
  }

  void _cancelledRead() {
    error = 'Read cancelled';
    errorIsWarning = true;
    errorDetail = null;
  }

  static Future<void> _finish(NfcTransport? nfc, String message) async {
    try {
      await nfc?.finish(iosError: message);
    } on CardTransportException {
      // The session is already over.
    }
  }

  /// Stops the read under way.
  Future<void> cancel() async {
    if (!reading) return;
    _cancelled = true;
    if (source == DocumentSource.simulated) {
      _chip?.remove();
    } else {
      await NfcTransport.cancel();
    }
  }

  @override
  void dispose() {
    for (final field in [can, number, birth, expiry]) {
      field.dispose();
    }
    progress.dispose();
    apduLog.dispose();
    super.dispose();
  }
}
