import 'package:eid_icao/eid_icao.dart';
import 'package:flutter/foundation.dart';

/// One line of the console: a command sent to the card, or its answer.
@immutable
class ApduLogEntry {
  const ApduLogEntry(
    this.time,
    this.isCommand,
    this.hex, {
    this.status,
    this.dataLength = 0,
  });

  /// The two lines of [exchange]; data the reader hid stays hidden.
  static List<ApduLogEntry> of(ApduExchange exchange) {
    final command = hexString(exchange.command);
    final response = exchange.response;
    final statusWord = exchange.statusWord;
    return [
      ApduLogEntry(
        exchange.time,
        true,
        exchange.isRedacted ? '$command (data not logged)' : command,
      ),
      ApduLogEntry(
        exchange.time.add(exchange.duration),
        false,
        response == null
            ? 'failed: ${exchange.failure?.message}'
            : hexString(response),
        status: statusWord?.toRadixString(16).toUpperCase().padLeft(4, '0'),
        dataLength: exchange.responseDataLength,
      ),
    ];
  }

  final DateTime time;
  final bool isCommand;
  final String hex;

  /// The status word of a response, such as `9000`, or null.
  final String? status;

  /// A response's data length, status bytes excluded.
  final int dataLength;

  @override
  String toString() {
    final clock = time.toIso8601String().substring(11, 23);
    return '$clock ${isCommand ? '>>' : '<<'} $hex';
  }
}

/// The console's lines, kept apart from the session: it changes with every
/// command, and only the console listens to it.
class ApduLog extends ChangeNotifier {
  /// The most lines kept; older ones are dropped, two per exchange.
  static const capacity = 500;

  final List<ApduLogEntry> _entries = [];
  int _commands = 0;

  /// The lines kept.
  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  /// The line [index], counted from the oldest kept.
  ApduLogEntry operator [](int index) => _entries[index];

  /// The commands sent since the log was cleared, dropped lines included.
  int get commandCount => _commands;

  /// The lines kept, as text, saying how many older ones were dropped.
  String get text => [
        if (_dropped > 0) '... $_dropped earlier lines dropped',
        ..._entries,
      ].join('\n');

  int _dropped = 0;

  void add(ApduExchange exchange) {
    _entries.addAll(ApduLogEntry.of(exchange));
    _commands++;
    final excess = _entries.length - capacity;
    if (excess > 0) {
      _entries.removeRange(0, excess);
      _dropped += excess;
    }
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    _commands = 0;
    _dropped = 0;
    notifyListeners();
  }
}
