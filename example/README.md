# eid_nfc example

Reads a passport or an identity card held against the phone, with its CAN
or its MRZ, and draws it as a specimen card: the face, the fields and the
MRZ read from the chip, then the checks of `eid_icao`. Belgian cards come
out as Belgium prints them. A read can be cancelled, and NFC turned on in
the settings is seen on return to the app.

"Simulated document", at the top, reads simulated chips instead: valid,
expired, tampered or cloned, with no document needed.

```bash
flutter run   # on an Android phone or an iPhone with NFC
```

iOS needs a team set for signing in Xcode, and a real iPhone: the simulator
has no NFC. The command log can be copied to report a document that reads
wrong; it holds the data read, never the keys.

To test with your own document without typing its key each time, give it at
launch, so that it stays out of the code:

```bash
flutter run --release --dart-define=CAN=123456
flutter run --release --dart-define=MRZ_NUMBER=UT1234567 --dart-define=MRZ_BIRTH=900515 --dart-define=MRZ_EXPIRY=340313
```
