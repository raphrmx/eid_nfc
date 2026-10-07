# eid_nfc

[![Pub Version](https://img.shields.io/pub/v/eid_nfc?color=0175C2)](https://pub.dev/packages/eid_nfc)
[![Build](https://img.shields.io/github/actions/workflow/status/raphrmx/eid_nfc/ci.yml?branch=main&label=build)](https://github.com/raphrmx/eid_nfc/actions/workflows/ci.yml)
![Maintainer](https://img.shields.io/badge/Maintainer-Raphael_Vrient-733d90)
[![Licence](https://img.shields.io/badge/Licence-MIT-8C6A3F)](LICENSE)
![Platforms](https://img.shields.io/badge/Platforms-Android,_iOS-22375C.svg)
[![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?logo=paypal&logoColor=white)](https://www.paypal.com/donate/?hosted_button_id=ZN6D382YQAV5N)

Reads electronic identity documents through the NFC of an Android phone or
an iPhone: the `eid` transport for the
[flutter_nfc_kit](https://pub.dev/packages/flutter_nfc_kit) plugin. With
`eid_icao`, it reads passports and identity cards.

![Which packages for which document: a Belgian card in a USB reader takes eid_belgium and eid_ccid and needs no key; a passport or an EU identity card takes eid_icao, with eid_nfc on a phone or eid_ccid on a contactless USB reader, and needs the CAN or the MRZ](https://public.comapps.be/packages/eid/eid_situations.svg)

## Install

```yaml
dependencies:
  eid_nfc: ^0.1.0
  eid_icao: ^0.1.0
```

| Platform | Setup |
| --- | --- |
| Android 7 and later | `minSdk = 24`; the NFC permission comes with the plugin |
| iOS 13 and later, iPhone 7 and later | The NFC entitlement and two `Info.plist` keys, below |

On a computer, a contactless reader is a PC/SC reader: use `eid_ccid`. No
browser can read an identity document: Web NFC, in Chrome on Android, reads
NDEF tags but sends no ISO 7816 command.

### iOS

In Xcode, add the Near Field Communication Tag Reading capability, which
creates `Runner.entitlements` with:

```xml
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
  <string>TAG</string>
</array>
```

Then, in `Info.plist`, a reason shown to the user and the application of
ICAO documents, without which iOS does not let the chip be read:

```xml
<key>NFCReaderUsageDescription</key>
<string>Reads the chip of your passport or identity card.</string>
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
  <string>A0000002471001</string>
</array>
```

## Read a document

```dart
import 'package:eid_icao/eid_icao.dart';
import 'package:eid_nfc/eid_nfc.dart';

if (await NfcTransport.availability() != NfcAvailability.available) return;

final transport = await NfcTransport.connect(); // waits for the document
try {
  final document = await IcaoReader(transport).read(
    access: IcaoAccessKey.can('123456'),
    onProgress: (f) => transport.setIosMessage('Reading… ${(f * 100).round()} %'),
  );
  await transport.finish(iosMessage: 'Done');
} on Exception {
  await transport.finish(iosError: 'Could not read the document');
  rethrow;
}
```

`connect` throws an `NfcCancelledException` when the user closes the iOS
sheet, and a `CardTransportException` when no document comes in time (20
seconds by default, on Android) or the tag is not an identity document.

`NfcTransport.cancel()` stops a wait or a read under way, for a Cancel
button: the wait throws an `NfcCancelledException`, the read fails at its
next command with a `CardTransportException`.

The phone holds one NFC session at a time: a new `connect` ends the previous
one. On iOS the system sheet stays up while connected, a minute at most:
finish as soon as the read is done.

## Watch

```dart
final watcher = IcaoWatcher(
  NfcTerminal(onCancelled: showTryAgainButton),
  accessPrompt: askForCan,
)..start();
```

`NfcTerminal` waits for documents one after the other, which suits Android.
On iOS each wait opens the system sheet: when the user closes it, the
terminal pauses until `resume()`. A read button calling
`NfcTransport.connect` usually suits iOS better.

## Tips

- Hold the document still against the back of the phone, or the top of an
  iPhone, until the read ends: the face takes a few seconds.
- Some phones do not take extended length commands. Reading works anyway,
  except Active Authentication with a 2048-bit RSA key, which then fails
  with a `CardTransportException`.
- `transceiveTimeout` (5 seconds) is how long one command may take on
  Android.

## Example

`example/` reads a document with its CAN or MRZ, shows the face and the
checks, and copies the command log.

## License

Released under the [MIT licence](https://pub.dev/packages/eid_nfc/license).

## More from COMAPPS

Electronic identity cards in Dart:

| Package | What it does |
| --- | --- |
| [eid](https://pub.dev/packages/eid) | APDUs, ISO 7816-4 file reading and the values national cards share. |
| [eid_belgium](https://pub.dev/packages/eid_belgium) | The Belgian eID, Kids ID and residence cards, through their contact chip. |
| [eid_icao](https://pub.dev/packages/eid_icao) | Passports and identity cards with an ICAO 9303 chip. |
| [eid_ccid](https://pub.dev/packages/eid_ccid) | The transport for a USB or PC/SC card reader. |

Every package COMAPPS publishes is listed at
[packages.comapps.be](https://packages.comapps.be).
