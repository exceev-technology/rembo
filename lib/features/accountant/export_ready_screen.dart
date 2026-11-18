import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'export_tab.dart';

/// « Export prêt » : the file exists; save or share it.
class ExportReadyScreen extends StatelessWidget {
  const ExportReadyScreen({super.key, required this.batch});
  final ExportBatch batch;

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
    } catch (_) {
      if (!context.mounted) return;
      await Clipboard.setData(ClipboardData(text: csv));
      if (!context.mounted) return;
      showRemboSnackBar(
        context,
        'Partage indisponible ici : le contenu du CSV a été copié.',
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
        label: 'Terminer',
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
      children: [
        const RemboMoment(
          title: 'Export prêt',
          message:
              'Vos dépenses sont marquées « Exportée ». Enregistrez le '
              'fichier pour votre logiciel comptable.',
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
                      '${batch.count} dépense${batch.count > 1 ? 's' : ''} · '
                      '${formatMad(batch.totalCents)}',
                      key: const ValueKey('export-summary'),
                      style: RemboText.body,
                    ),
                    Text(
                      'Créé le ${formatDateLong(batch.createdAt)}',
                      style: RemboText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboPrimaryButton(
          key: const ValueKey('export-share'),
          label: 'Enregistrer ou partager le CSV',
          icon: Icons.download_rounded,
          onPressed: batch.csv == null ? null : () => _share(context),
        ),
        if (earlier.isNotEmpty) ...[
          const SectionTitle('Exports récents'),
          for (final b in earlier) ExportBatchTile(b),
        ],
      ],
    );
  }
}
