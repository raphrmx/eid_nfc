import 'package:eid_nfc_example/src/apdu_log.dart';
import 'package:eid_nfc_example/src/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Commands and answers, newest at the bottom.
class ApduConsole extends StatelessWidget {
  const ApduConsole({super.key, required this.log, this.height = 260});

  final ApduLog log;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Rebuilt and repainted on its own, once a command, apart from the page.
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: log,
        builder: (context, _) => _build(log),
      ),
    );
  }

  Widget _build(ApduLog log) {
    return Panel(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 18, color: Palette.accent),
                const SizedBox(width: 8),
                const Text(
                  'Under the hood',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Palette.ink,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${log.commandCount} commands',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Palette.muted, fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy the log',
                  visualDensity: VisualDensity.compact,
                  onPressed: log.isEmpty
                      ? null
                      : () => Clipboard.setData(
                            ClipboardData(text: log.text),
                          ),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Clear the log',
                  visualDensity: VisualDensity.compact,
                  onPressed: log.isEmpty ? null : log.clear,
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Palette.line),
          SizedBox(
            height: height,
            child: log.isEmpty
                ? const Center(
                    child: Text(
                      'The commands sent to the chip show up here.',
                      style: TextStyle(color: Palette.muted, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    // Reversed so the newest line stays in view.
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: log.length,
                    itemBuilder: (context, index) =>
                        _Line(log[log.length - 1 - index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.entry);

  final ApduLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final status = entry.status;
    final Color color;
    if (entry.isCommand) {
      color = Palette.accent;
    } else if (status == '9000') {
      color = Palette.success;
    } else if (status != null &&
        (status.startsWith('6C') || status.startsWith('61'))) {
      color = Palette.warning;
    } else {
      color = Palette.danger;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1.5),
      child: Row(
        children: [
          Icon(
            entry.isCommand ? Icons.arrow_forward : Icons.arrow_back,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.hex,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: entry.isCommand ? Palette.ink : Palette.muted,
              ),
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
