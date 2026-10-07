import 'package:eid_icao/eid_icao.dart';
import 'package:eid_nfc_example/src/format.dart';
import 'package:eid_nfc_example/src/palette.dart';
import 'package:eid_nfc_example/src/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Where the holder was born and lives, when the chip holds it: DG11, which
/// Belgian cards keep on their contact chip alone.
class HolderPanel extends StatelessWidget {
  const HolderPanel({super.key, required this.document});

  final IcaoDocument document;

  @override
  Widget build(BuildContext context) {
    final details = document.personalDetails;
    final issued = document.documentDetails;
    final mrz = document.mrz;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(Icons.person_outline, 'Holder'),
          const SizedBox(height: 14),
          Text(
            titleCase('${details?.firstNames ?? mrz.firstNames} '
                '${details?.lastName ?? mrz.lastName}'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Palette.ink,
            ),
          ),
          Text(
            '${documentTypeName(mrz.documentType)} of '
            '${stateName(mrz.issuingState)}',
            style: const TextStyle(fontSize: 15, color: Palette.muted),
          ),
          const SizedBox(height: 18),
          if (details == null)
            const Text(
              'No personal details on this chip (DG11): Belgian cards keep '
              'the address and birthplace on their contact chip.',
              style: TextStyle(color: Palette.muted, height: 1.4),
            )
          else ...[
            if (details.address case final address?) ...[
              const Caption('Address'),
              Text(address.join(', '),
                  style: const TextStyle(color: Palette.ink)),
              const SizedBox(height: 10),
            ],
            if (details.birthPlace case final place?) ...[
              const Caption('Born in'),
              Text(place.join(', '),
                  style: const TextStyle(color: Palette.ink)),
              const SizedBox(height: 10),
            ],
            if (details.profession case final profession?) ...[
              const Caption('Profession'),
              Text(profession, style: const TextStyle(color: Palette.ink)),
              const SizedBox(height: 10),
            ],
          ],
          if (issued?.issuingAuthority case final authority?) ...[
            const Caption('Issued by'),
            Text(authority, style: const TextStyle(color: Palette.ink)),
          ],
        ],
      ),
    );
  }
}

/// What the app could check on its own, with no server.
class ChecksPanel extends StatelessWidget {
  const ChecksPanel({super.key, required this.session});

  final ReadSession session;

  @override
  Widget build(BuildContext context) {
    final document = session.document!;
    final mrz = document.mrz;
    final passive = document.passiveAuthentication;
    final proof = document.authenticity;
    final birth = mrz.birthDate;
    final age = birth?.ageOn(DateTime.now());
    final expiry = mrz.expiryDate;
    final nationalNumber = belgianNationalNumber(mrz);
    final face = document.face;
    final time = session.readTime;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(Icons.fact_check_outlined, 'Checks'),
          const SizedBox(height: 12),
          _Check(
            ok: passive?.isValid ?? false,
            pending: passive == null,
            label: switch (passive) {
              null => 'Signatures not checked',
              final check when !check.isValid => 'Signatures do not hold',
              final check when check.chain == IcaoChainStatus.verified =>
                'Signed by the state, up to its CSCA',
              _ => 'Signed by a document signer; its CSCA not checked',
            },
          ),
          _Check(
            ok: passive != null && passive.mismatchedGroups.isEmpty,
            pending: passive == null,
            label: passive == null
                ? 'Data groups not checked'
                : '${passive.verifiedGroups.length} data groups match '
                    'their signed hashes',
          ),
          _Check(
            ok: session.chipGenuine,
            pending:
                proof == null || proof == IcaoChipAuthenticity.notSupported,
            label: switch (proof) {
              null => 'Chip not asked to prove itself',
              IcaoChipAuthenticity.notSupported =>
                'Older chip: it cannot prove itself',
              final proof => 'Genuine chip: ${proofName(proof)}',
            },
          ),
          _Check(
            ok: mrz.isValid,
            label: mrz.isValid
                ? 'MRZ check digits hold'
                : 'MRZ check digits do not hold',
          ),
          _Check(
            ok: !mrz.isExpiredOn(),
            pending: expiry == null,
            label: expiry == null
                ? 'No expiry date'
                : mrz.isExpiredOn()
                    ? 'Expired on ${longDate(expiry.year, expiry.month, expiry.day)}'
                    : 'Valid until '
                        '${longDate(expiry.year, expiry.month, expiry.day)}',
          ),
          _Check(
            ok: age != null && age >= 18,
            label: age != null && age >= 18
                ? 'Holder is 18 or older'
                : 'Holder is not known to be 18',
          ),
          if (mrz.issuingState == 'BEL')
            _Check(
              ok: nationalNumber != null &&
                  isValidNationalNumber(nationalNumber),
              pending: nationalNumber == null,
              label: nationalNumber == null
                  ? 'National number not read (showPrivateData)'
                  : 'National number check digits',
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (document.accessProtocol case final access?)
                _Tag(access.name.toUpperCase()),
              if (age != null) _Tag('Age $age'),
              if (face != null)
                _Tag(face.format == IcaoImageFormat.jpeg2000
                    ? 'Face in JPEG 2000, shown as PNG'
                    : 'Face in ${face.format.name.toUpperCase()}'),
              _Tag('${document.dataGroups.length} data groups'),
              if (time != null)
                _Tag('Read in '
                    '${(time.inMilliseconds / 1000).toStringAsFixed(1)} s'),
            ],
          ),
        ],
      ),
    );
  }
}

/// The MRZ, the files read and who signed them, to check a real document.
class DetailsPanel extends StatelessWidget {
  const DetailsPanel({super.key, required this.document});

  final IcaoDocument document;

  @override
  Widget build(BuildContext context) {
    final passive = document.passiveAuthentication;
    final signer = passive?.documentSigner;
    final failures = document.decodingFailures;
    return Panel(
      padding: 8,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(
          children: [
            ExpansionTile(
              leading: const Icon(Icons.text_snippet_outlined,
                  color: Palette.accent),
              title: const Text('MRZ'),
              subtitle: Text('${document.mrz.format.name.toUpperCase()}, '
                  'from DG1'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  document.mrz.text,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Palette.ink,
                  ),
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.folder_outlined, color: Palette.accent),
              title: const Text('Data groups'),
              subtitle: Text(
                document.dataGroups.keys
                    .map((group) => 'DG${group.number}')
                    .join(', '),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final MapEntry(key: group, value: bytes)
                    in document.dataGroups.entries)
                  _Row(
                    'DG${group.number}',
                    '${bytes.length} bytes'
                        '${passive?.verifiedGroups.contains(group) ?? false ? ', hash verified' : ''}'
                        '${failures[group] == null ? '' : ', ${failures[group]}'}',
                  ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.workspace_premium_outlined,
                  color: Palette.accent),
              title: const Text('Document signer'),
              subtitle: Text(signer?.subject.commonName ?? 'Not checked'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (signer != null) ...[
                  _Row('Subject', '${signer.subject}'),
                  _Row('Issuer', '${signer.issuer}'),
                  _Row(
                    'Valid',
                    '${_day(signer.notBefore)} to ${_day(signer.notAfter)}',
                  ),
                  _Row(
                    'Country signing CA',
                    passive?.countrySigningCa?.subject.commonName ??
                        'none given: pass trustedRoots to check it',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What went wrong with a real document, to report it.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel(this.session, {super.key});

  final ReadSession session;

  @override
  Widget build(BuildContext context) {
    final detail = session.errorDetail!;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 20, color: Palette.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.error ?? 'The read failed',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Palette.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                visualDensity: VisualDensity.compact,
                onPressed: () => Clipboard.setData(ClipboardData(text: detail)),
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            detail,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Palette.accent),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Palette.ink,
          ),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.ok, required this.label, this.pending = false});

  final bool ok;
  final bool pending;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = pending
        ? Palette.muted
        : ok
            ? Palette.success
            : Palette.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              pending
                  ? Icons.radio_button_unchecked
                  : ok
                      ? Icons.check_circle
                      : Icons.cancel,
              key: ValueKey('$pending$ok'),
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: Palette.ink)),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.line),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Palette.muted),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Palette.muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13, color: Palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

String _day(DateTime date) => longDate(date.year, date.month, date.day);
