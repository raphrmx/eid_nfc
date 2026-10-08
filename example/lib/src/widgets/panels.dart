import 'package:eid_icao/eid_icao.dart' show IcaoMrzKey;
import 'package:eid_icao/testing.dart';
import 'package:eid_nfc/eid_nfc.dart';
import 'package:eid_nfc_example/src/palette.dart';
import 'package:eid_nfc_example/src/session.dart';
import 'package:eid_nfc_example/src/widgets/id_card.dart';
import 'package:eid_nfc_example/src/widgets/mrz_scan_page.dart';
import 'package:eid_nfc_example/src/widgets/nfc_mark.dart';
import 'package:eid_nfc_example/src/widgets/phone_stage.dart';
import 'package:eid_nfc_example/src/widgets/result_panels.dart';
import 'package:flutter/material.dart';

/// The phone, the key of the document, and the read.
class ReaderPanel extends StatelessWidget {
  const ReaderPanel({super.key, required this.session});

  final ReadSession session;

  @override
  Widget build(BuildContext context) {
    final simulated = session.source == DocumentSource.simulated;
    final availability = session.availability;
    return Panel(
      padding: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (simulated) ...[
            CardPicker(session: session),
            const SizedBox(height: 8),
          ] else if (availability != null &&
              availability != NfcAvailability.available) ...[
            _NfcOff(session: session),
            const SizedBox(height: 16),
          ],
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: PhoneStage(session: session),
            ),
          ),
          const SizedBox(height: 20),
          _KeyFields(session: session),
          const SizedBox(height: 16),
          if (session.reading)
            OutlinedButton.icon(
              onPressed: session.cancel,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            )
          else
            FilledButton.icon(
              onPressed: session.read,
              icon: const NfcMark(size: 20),
              label: const Text('Read'),
            ),
          const SizedBox(height: 10),
          Text(
            session.waitingForDocument
                ? 'Lay the card flat against the back of the phone, and keep '
                    'it still until the result shows.'
                : simulated
                    ? 'The simulated chip needs no card: press Read.'
                    : 'Press Read, then lay the card against the phone.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Palette.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// NFC off or missing, and a way to look again.
class _NfcOff extends StatelessWidget {
  const _NfcOff({required this.session});

  final ReadSession session;

  @override
  Widget build(BuildContext context) {
    final disabled = session.availability == NfcAvailability.disabled;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: Palette.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const NfcMark(color: Palette.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              disabled
                  ? 'NFC is off: turn it on in the settings.'
                  : 'This phone has no NFC: try the simulated document.',
              style: const TextStyle(color: Palette.ink),
            ),
          ),
          if (disabled)
            TextButton(
              onPressed: session.checkAvailability,
              child: const Text('Check again'),
            ),
        ],
      ),
    );
  }
}

/// The CAN, or the document number and dates of the MRZ.
class _KeyFields extends StatelessWidget {
  const _KeyFields({required this.session});

  final ReadSession session;

  @override
  Widget build(BuildContext context) {
    final enabled = !session.reading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<KeyMode>(
          segments: const [
            ButtonSegment(
              value: KeyMode.can,
              label: Text('CAN'),
              icon: Icon(Icons.pin_outlined),
            ),
            ButtonSegment(
              value: KeyMode.mrz,
              label: Text('MRZ'),
              icon: Icon(Icons.text_snippet_outlined),
            ),
          ],
          selected: {session.mode},
          onSelectionChanged:
              enabled ? (selection) => session.setMode(selection.first) : null,
        ),
        const SizedBox(height: 14),
        if (session.mode == KeyMode.can)
          _Field(
            session.can,
            'Card access number',
            helper: 'The 6 digits printed on the front, when there are.',
            digits: true,
            enabled: enabled,
          )
        else ...[
          if (session.source == DocumentSource.nfc) ...[
            OutlinedButton.icon(
              onPressed: enabled ? () => _scan(context) : null,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan the MRZ with the camera'),
            ),
            const SizedBox(height: 14),
          ],
          _Field(
            session.number,
            'Document number, in full',
            helper: 'Without its check digit. A Belgian card number has 12 '
                'digits; the MRZ shows only its first 9.',
            enabled: enabled,
          ),
          Row(
            children: [
              Expanded(
                child: _Field(
                  session.birth,
                  'Born (YYMMDD)',
                  digits: true,
                  enabled: enabled,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  session.expiry,
                  'Expires (YYMMDD)',
                  digits: true,
                  enabled: enabled,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // The fields filled from the camera, once two frames agree.
  Future<void> _scan(BuildContext context) async {
    final result = await MrzScanPage.open(context);
    if (result == null) return;
    session.fillFromMrz(result.accessKey as IcaoMrzKey);
  }
}

class _Field extends StatelessWidget {
  const _Field(
    this.controller,
    this.label, {
    this.helper,
    this.digits = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool digits;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: digits ? TextInputType.number : TextInputType.text,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          color: Palette.ink,
        ),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 3,
          filled: true,
          fillColor: Palette.paper,
          border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: Palette.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: Palette.line, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// The simulated documents to try, the one in use highlighted. Choosing one
/// puts a fresh document of that kind by the phone, its key filled in.
class CardPicker extends StatelessWidget {
  const CardPicker({super.key, required this.session});

  final ReadSession session;

  static const _choices = [
    (
      SimulatedKind.valid,
      'Valid',
      Icons.verified_outlined,
      Palette.success,
      'A valid identity card, its face in JPEG 2000'
    ),
    (
      SimulatedKind.expired,
      'Expired',
      Icons.event_busy_outlined,
      Palette.warning,
      'A card past its expiry date'
    ),
    (
      SimulatedKind.tampered,
      'Tampered',
      Icons.edit_note,
      Palette.danger,
      'A card whose MRZ was rewritten after the state signed it'
    ),
    (
      SimulatedKind.cloned,
      'Cloned',
      Icons.copy_all_outlined,
      Palette.danger,
      "A copy of a chip's files on another chip"
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final idle = !session.reading;
    return Row(
      children: [
        for (final (kind, label, icon, color, tooltip) in _choices) ...[
          if (kind != SimulatedKind.valid) const SizedBox(width: 8),
          Expanded(
            child: _CardChoice(
              label: label,
              icon: icon,
              color: color,
              tooltip: tooltip,
              selected: session.simulatedKind == kind,
              cloned: kind == SimulatedKind.cloned,
              onTap: idle ? () => session.newSimulatedCard(kind) : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _CardChoice extends StatelessWidget {
  const _CardChoice({
    required this.label,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    this.cloned = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String tooltip;
  final bool selected;
  final VoidCallback? onTap;

  /// Draws a second card behind the first.
  final bool cloned;

  // One instance for every tile: an identical widget is not rebuilt.
  static final _miniature = ClipRRect(
    borderRadius: const BorderRadius.all(Radius.circular(5)),
    child: IgnorePointer(child: IdCard(printedPhoto: specimenPhoto)),
  );

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Column(
            children: [
              AnimatedScale(
                scale: selected ? 1 : 0.9,
                duration: const Duration(milliseconds: 200),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (cloned)
                      Positioned.fill(
                        child: Transform.translate(
                          offset: const Offset(5, -5),
                          child: Opacity(opacity: 0.55, child: _miniature),
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: selected ? color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: selected ? Palette.softShadow : null,
                      ),
                      child: _miniature,
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Palette.white, width: 2),
                        ),
                        child: Icon(icon, size: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : Palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reader's options, applied from the next read.
class OptionsPanel extends StatelessWidget {
  const OptionsPanel({super.key, required this.session});

  final ReadSession session;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Options',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Palette.ink,
            ),
          ),
          const SizedBox(height: 4),
          _Option(
            title: 'Read the photo',
            code: 'parts: face',
            value: session.readFace,
            onChanged: (value) => session.readFace = value,
          ),
          _Option(
            title: 'Check the signatures',
            code: 'verifySignatures',
            value: session.verifySignatures,
            onChanged: (value) => session.verifySignatures = value,
          ),
          _Option(
            title: 'Check the chip is genuine',
            code: 'verifyCard',
            value: session.verifyCard,
            onChanged: (value) => session.verifyCard = value,
          ),
          _Option(
            title: 'Turn down expired documents',
            code: 'acceptExpired: false',
            value: !session.acceptExpired,
            onChanged: (value) => session.acceptExpired = !value,
          ),
          const Divider(height: 20),
          _Option(
            title: 'Show private data',
            code: 'showPrivateData',
            value: session.showPrivateData,
            onChanged: (value) => session.showPrivateData = value,
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.code,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String code;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Palette.ink,
        ),
      ),
      subtitle: Text(
        code,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: Palette.muted,
        ),
      ),
    );
  }
}

/// The card as read, then the holder, the checks and the details.
class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.session, required this.wide});

  final ReadSession session;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final document = session.document;
    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: FlippableIdCard(
        data: session.cardData,
        revealKey: session.readCount,
        verified: session.chipGenuine,
      ),
    );
    final failure = session.errorDetail == null ? null : ErrorPanel(session);

    if (document == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Opacity(opacity: 0.55, child: card)),
          const SizedBox(height: 24),
          if (failure != null)
            failure
          else
            const Text(
              'Give the key printed on the document, press Read,\nthen lay '
              'the document against the phone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Palette.muted, height: 1.5),
            ),
        ],
      );
    }

    final holder = HolderPanel(document: document);
    final checks = ChecksPanel(session: session);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: card),
        const SizedBox(height: 24),
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: holder),
                const SizedBox(width: 20),
                Expanded(child: checks),
              ],
            ),
          )
        else ...[
          holder,
          const SizedBox(height: 20),
          checks,
        ],
        const SizedBox(height: 20),
        DetailsPanel(document: document),
      ],
    );
  }
}
