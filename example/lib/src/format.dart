import 'package:eid_icao/eid_icao.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// A date in words, its unknown parts left out: 15 May 1990, May 1990.
String longDate(int year, [int? month, int? day]) => [
      if (day != null) '$day',
      if (month != null) _months[month - 1],
      '$year',
    ].join(' ');

/// A date as the card prints it: 15 05 1990, blanks for unknown parts.
String cardDate(int year, [int? month, int? day]) {
  String two(int? value) =>
      value == null ? '  ' : value.toString().padLeft(2, '0');
  return '${two(day)} ${two(month)} $year';
}

/// MRZ names are upper case: ALICE MARIE becomes Alice Marie.
String titleCase(String text) => text
    .split(' ')
    .where((word) => word.isNotEmpty)
    .map((word) => word[0] + word.substring(1).toLowerCase())
    .join(' ');

/// The Belgian national register number in the optional data of [mrz],
/// when [mrz] is Belgian and the number was read.
String? belgianNationalNumber(IcaoMrz mrz) {
  if (mrz.issuingState != 'BEL') return null;
  for (final data in [mrz.optionalData, mrz.optionalData2]) {
    if (RegExp(r'^\d{11}$').hasMatch(data)) return data;
  }
  return null;
}

/// 85073003328 as printed: 85.07.30-033.28.
String formatNationalNumber(String number) =>
    '${number.substring(0, 2)}.${number.substring(2, 4)}.'
    '${number.substring(4, 6)}-${number.substring(6, 9)}.'
    '${number.substring(9)}';

/// Whether the two check digits of a Belgian national number hold, for a
/// birth in the 1900s or from 2000.
bool isValidNationalNumber(String number) {
  final body = int.parse(number.substring(0, 9));
  final check = int.parse(number.substring(9));
  return 97 - body % 97 == check || 97 - (2000000000 + body) % 97 == check;
}

/// A Belgian card number of 12 digits as printed: 595-3253250-82.
String formatDocumentNumber(IcaoMrz mrz) {
  final number = mrz.documentNumber;
  if (mrz.issuingState != 'BEL' || !RegExp(r'^\d{12}$').hasMatch(number)) {
    return number;
  }
  return '${number.substring(0, 3)}-${number.substring(3, 10)}-'
      '${number.substring(10)}';
}

/// The document type in words.
String documentTypeName(IcaoDocumentType type) => switch (type) {
      IcaoDocumentType.passport => 'Passport',
      IcaoDocumentType.identityCard => 'Identity card',
      IcaoDocumentType.visa => 'Visa',
      IcaoDocumentType.other => 'Travel document',
    };

/// The way the chip proved itself, in words.
String proofName(IcaoChipAuthenticity proof) => switch (proof) {
      IcaoChipAuthenticity.chipAuthentication => 'Chip Authentication',
      IcaoChipAuthenticity.chipAuthenticationMapping =>
        'Chip Authentication Mapping',
      IcaoChipAuthenticity.activeAuthentication => 'Active Authentication',
      IcaoChipAuthenticity.notSupported => 'none offered',
    };

/// The member states of the European Union, ICAO code to ISO code and
/// English name, and the state of the ICAO specimens.
const states = {
  'AUT': ('AT', 'Austria'),
  'BEL': ('BE', 'Belgium'),
  'BGR': ('BG', 'Bulgaria'),
  'HRV': ('HR', 'Croatia'),
  'CYP': ('CY', 'Cyprus'),
  'CZE': ('CZ', 'Czechia'),
  'DNK': ('DK', 'Denmark'),
  'EST': ('EE', 'Estonia'),
  'FIN': ('FI', 'Finland'),
  'FRA': ('FR', 'France'),
  'D': ('DE', 'Germany'),
  'GRC': ('GR', 'Greece'),
  'HUN': ('HU', 'Hungary'),
  'IRL': ('IE', 'Ireland'),
  'ITA': ('IT', 'Italy'),
  'LVA': ('LV', 'Latvia'),
  'LTU': ('LT', 'Lithuania'),
  'LUX': ('LU', 'Luxembourg'),
  'MLT': ('MT', 'Malta'),
  'NLD': ('NL', 'Netherlands'),
  'POL': ('PL', 'Poland'),
  'PRT': ('PT', 'Portugal'),
  'ROU': ('RO', 'Romania'),
  'SVK': ('SK', 'Slovakia'),
  'SVN': ('SI', 'Slovenia'),
  'ESP': ('ES', 'Spain'),
  'SWE': ('SE', 'Sweden'),
};

/// The English name of the state of ICAO code [code], else the code.
String stateName(String code) =>
    code == 'UTO' ? 'Utopia' : (states[code]?.$2 ?? code);
