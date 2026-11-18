import 'package:flutter/material.dart';

import '../../core/widgets/rembo_widgets.dart';
import 'export_store.dart';

class ExportHistoryScreen extends StatelessWidget {
  const ExportHistoryScreen({super.key, required this.store});
  final ExportStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historique des exports')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => store.history.isEmpty
            ? const Center(
                child: Text(
                  'Aucun export pour le moment.',
                  style: RemboText.caption,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(RemboSpace.xl),
                itemCount: store.history.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: RemboSpace.md),
                itemBuilder: (context, i) {
                  final r = store.history[i];
                  return Card(
                    key: ValueKey('export-$i'),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(RemboSpace.lg),
                      leading: const Icon(
                        Icons.description_outlined,
                        color: RemboColors.indigo,
                      ),
                      title: Text(r.fileName, style: RemboText.subtitle),
                      subtitle: Text(
                        '${formatDate(r.at)} · ${r.count} dépenses · '
                        '${formatMad(r.totalCentimes)}',
                        style: RemboText.caption,
                      ),
                    ),
                  );
                },
              ),
      ),
    ),
  );
}
