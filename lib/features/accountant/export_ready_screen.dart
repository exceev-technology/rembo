import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/agents/export_agent.dart';
import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'export_tab.dart';
import '../../core/log.dart';

/// « Export prêt » : the file exists; save or share it.
class ExportReadyScreen extends StatelessWidget {
  const ExportReadyScreen({super.key, required this.batch, this.expected});
  final ExportBatch batch;

  /// The totals the export agent prepared, checked against the batch.
  final ExportCheck? expected;

  /// Writes the CSV (UTF-8 with BOM, so spreadsheets read the accents)
  /// and opens the system share sheet, which also offers « Enregistrer ».
  Future<void> _share(BuildContext context) async {
    final csv = batch.csv;
    if (csv == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${batch.fileName}');
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: batch.fileName,
        ),
      );
    } catch (e, st) {
      logFailure('CSV not shared, copied instead', e, st);
      if (!context.mounted) return;
      await Clipboard.setData(ClipboardData(text: csv));
      if (!context.mounted) return;
      showRemboSnackBar(
        context,
        tr('Partage indisponible ici : le contenu du CSV a été copié.'),
        tone: MessageTone.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final earlier = state.exports.where((b) => b.id != batch.id).take(3);
    return RemboPage(
      showBack: false,
      bottom: RemboSecondaryButton(
        key: const ValueKey('export-done'),
        label: tr('Terminer'),
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
      children: [
        RemboMoment(
          title: tr('Export prêt'),
          message: tr('Enregistrez le fichier pour votre logiciel comptable.'),
          illustration: RemboArt.approved,
        ),
        RemboCard(
          child: Row(
            children: [
              const IconTile(Icons.description_outlined, size: 56),
              const SizedBox(width: RemboSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.fileName,
                      key: const ValueKey('export-file'),
                      style: RemboText.amount.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: RemboSpace.xs),
                    Text(
                      '${expenseCount(batch.count)} · '
                      '${formatMad(batch.totalCents)}',
                      key: const ValueKey('export-summary'),
                      style: RemboText.body,
                    ),
                    Text(
                      tr('Créé le {createdAt}', {
                        'createdAt': formatDateLong(batch.createdAt),
                      }),
                      style: RemboText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (expected != null) ...[
          const SizedBox(height: RemboSpace.md),
          expected!.matches(batch)
              ? InfoStrip(
                  key: const ValueKey('export-totals-ok'),
                  tr(
                    'Totaux contrôlés : le fichier contient exactement le '
                    'nombre, le TTC et la TVA du lot enregistré.',
                  ),
                  icon: Icons.verified_outlined,
                )
              : RemboMessage(
                  key: const ValueKey('export-totals-differ'),
                  tone: MessageTone.error,
                  title: tr('Les totaux du lot diffèrent de ceux préparés.'),
                  message: tr(
                    'Ne l’importez pas : rechargez les dépenses et '
                    'vérifiez le lot.',
                  ),
                ),
        ],
        const SizedBox(height: RemboSpace.lg),
        RemboPrimaryButton(
          key: const ValueKey('export-share'),
          label: tr('Enregistrer ou partager le CSV'),
          icon: Icons.download_rounded,
          onPressed: batch.csv == null ? null : () => _share(context),
        ),
        if (earlier.isNotEmpty) ...[
          SectionTitle(tr('Exports récents')),
          for (final b in earlier) ExportBatchTile(b),
        ],
      ],
    );
  }
}
