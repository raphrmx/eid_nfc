## 0.1.0

- First release: `NfcTransport` carries the commands of any `eid` package
  to a document on the phone, through `flutter_nfc_kit`.
- `NfcTerminal`, for a `CardWatcher` or an `IcaoWatcher`.
- `NfcTransport.availability` and, on iOS, the messages of the system
  sheet.
- `NfcTransport.cancel`, for a Cancel button: stops the wait for a document
  or the read under way.
