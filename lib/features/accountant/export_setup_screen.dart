import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/data/ids.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'export_ready_screen.dart';

/// « Préparer l’export » : format, delimiter and a preview of the rows.
class ExportSetupScreen extends StatefulWidget {
  const ExportSetupScreen({super.key, required this.expenseIds});
  final List<String> expenseIds;

  @override
  State<ExportSetupScreen> createState() => _ExportSetupScreenState();
}

class _ExportSetupScreenState extends State<ExportSetupScreen> {
  /// One id per screen: generating twice returns the same batch.
  final _requestId = newUuid();
  String _delimiter = ';';
  bool _loading = false;
  String? _failure;

  Future<void> _generate() async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final batch = await state.createExport(
        widget.expenseIds,
        requestId: _requestId,
        delimiter: _delimiter,
      );
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ExportReadyScreen(batch: batch),
        ),
      );
    } on RemboException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failure = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rows = [
      for (final id in widget.expenseIds)
        if (state.byId(id) != null) state.byId(id)!,
    ];
    final total = rows.fold<int>(0, (s, e) => s + e.amountCents);
    return RemboPage(
      bottom: RemboPrimaryButton(
        key: const ValueKey('export-generate'),
        label: 'Générer le CSV',
        icon: Icons.download_rounded,
        loading: _loading,
        onPressed: rows.isEmpty ? null : _generate,
      ),
      children: [
        const RemboHero(
          title: 'Préparer l’export',
          illustration: RemboArt.download,
        ),
        InfoStrip(
          '${rows.length} dépense${rows.length > 1 ? 's' : ''} · '
          '${formatMad(total)}',
          icon: Icons.layers_outlined,
        ),
        if (_failure != null) ...[
          const SizedBox(height: RemboSpace.lg),
          RemboMessage(tone: MessageTone.error, title: _failure!),
        ],
        const SectionTitle('Format d’export'),
        Row(
          children: [
            Expanded(
              child: RemboCard(
                borderColor: RemboColors.indigo,
                color: RemboColors.surface,
                child: Row(
                  children: [
                    const Icon(
                      Icons.radio_button_checked_rounded,
                      color: RemboColors.indigo,
                    ),
                    const SizedBox(width: RemboSpace.sm),
                    Text('CSV', style: RemboText.subtitle),
                  ],
                ),
              ),
            ),
            const SizedBox(width: RemboSpace.md),
            Expanded(
              child: Opacity(
                opacity: 0.6,
                child: RemboCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.radio_button_off_rounded,
                        color: RemboColors.muted,
                      ),
                      const SizedBox(width: RemboSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ERP', style: RemboText.subtitle),
                            Text(
                              'Pas encore disponible',
                              style: RemboText.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: RemboSpace.lg),
        Text('Délimiteur', style: RemboText.subtitle),
        const SizedBox(height: RemboSpace.sm),
        DropdownButtonFormField<String>(
          key: const ValueKey('export-delimiter'),
          initialValue: _delimiter,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.code_rounded, color: RemboColors.night),
          ),
          items: const [
            DropdownMenuItem(value: ';', child: Text('Point-virgule')),
            DropdownMenuItem(value: ',', child: Text('Virgule')),
          ],
          onChanged: (d) => setState(() => _delimiter = d ?? ';'),
        ),
        SectionTitle('Aperçu des enregistrements (${rows.length})'),
        for (final e in rows)
          ExpenseTile(
            e,
            showStatus: false,
            subtitle:
                '${e.employeeName} · '
                '${e.date == null ? '' : formatDayShort(e.date!)}',
          ),
        const InfoStrip('Une dépense exportée ne peut plus l’être à nouveau.'),
      ],
    );
  }
}
