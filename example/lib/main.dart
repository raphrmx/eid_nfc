import 'package:eid_nfc_example/src/palette.dart';
import 'package:eid_nfc_example/src/session.dart';
import 'package:eid_nfc_example/src/widgets/apdu_console.dart';
import 'package:eid_nfc_example/src/widgets/nfc_mark.dart';
import 'package:eid_nfc_example/src/widgets/panels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// A browser has no NFC: there, the simulated document comes first.
void main() => runApp(
      const ExampleApp(
        source: kIsWeb ? DocumentSource.simulated : DocumentSource.nfc,
      ),
    );

/// Reads a passport or an identity card held against the phone.
class ExampleApp extends StatelessWidget {
  /// The app, reading from [source] first.
  const ExampleApp({super.key, this.source = DocumentSource.nfc});

  /// Where documents come from at launch.
  final DocumentSource source;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eid_nfc demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Palette.accent,
        scaffoldBackgroundColor: Palette.paper,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Palette.accent,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Palette.ink,
            minimumSize: const Size(0, 48),
            side: const BorderSide(color: Palette.line, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: HomePage(source: source),
    );
  }
}

/// The page: the phone and the key, the options, then what was read.
class HomePage extends StatefulWidget {
  /// The page, reading from [source] first.
  const HomePage({super.key, this.source = DocumentSource.nfc});

  /// Where documents come from at launch.
  final DocumentSource source;

  @override
  State<HomePage> createState() => _HomePageState();
}

// Rebuilds come from the session's listeners, not setState.
class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final _session = ReadSession(source: widget.source);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.checkAvailability();
  }

  // NFC may have been turned on in the settings meanwhile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _session.checkAvailability();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _session,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1000;
              final gutter = constraints.maxWidth < 600 ? 16.0 : 32.0;
              final header = _Header(session: _session);
              final reader = ReaderPanel(session: _session);
              final options = OptionsPanel(session: _session);
              final console = ApduConsole(
                log: _session.apduLog,
                height: wide ? 300 : 220,
              );
              final result = ResultView(session: _session, wide: wide);

              return SingleChildScrollView(
                padding: EdgeInsets.all(gutter),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1320 : 640),
                    child: wide
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              header,
                              const SizedBox(height: 28),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 400,
                                    child: Column(
                                      children: [
                                        reader,
                                        const SizedBox(height: 20),
                                        options,
                                        const SizedBox(height: 20),
                                        console,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 28),
                                  Expanded(child: result),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              header,
                              const SizedBox(height: 20),
                              reader,
                              const SizedBox(height: 20),
                              result,
                              const SizedBox(height: 20),
                              options,
                              const SizedBox(height: 20),
                              console,
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session});

  final ReadSession session;

  @override
  Widget build(BuildContext context) {
    const title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'eid_nfc',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Palette.ink,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Read a passport or an identity card with the phone',
          style: TextStyle(fontSize: 15, color: Palette.muted),
        ),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      spacing: 16,
      children: [title, _SourcePicker(session: session)],
    );
  }
}

/// The phone's NFC, or a simulated document to try the app without one.
class _SourcePicker extends StatelessWidget {
  const _SourcePicker({required this.session});

  final ReadSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: Palette.softShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.source == DocumentSource.nfc)
            const NfcMark(size: 18, color: Palette.muted)
          else
            const Icon(Icons.science_outlined, size: 18, color: Palette.muted),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<DocumentSource>(
              value: session.source,
              items: const [
                DropdownMenuItem(
                  value: DocumentSource.nfc,
                  child: Text("This phone's NFC"),
                ),
                DropdownMenuItem(
                  value: DocumentSource.simulated,
                  child: Text('Simulated document'),
                ),
              ],
              onChanged: session.reading
                  ? null
                  : (source) => session.setSource(source!),
            ),
          ),
        ],
      ),
    );
  }
}
