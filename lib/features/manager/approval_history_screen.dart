import 'package:flutter/material.dart';

import '../../core/widgets/rembo_widgets.dart';
import 'approval_store.dart';

class ApprovalHistoryScreen extends StatelessWidget {
  const ApprovalHistoryScreen({super.key, required this.store});
  final ApprovalStore store;

  static String _when(DateTime at) =>
      '${formatDate(at)} · ${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Historique des décisions')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => store.history.isEmpty
            ? const Center(
                child: Text(
                  'Aucune décision pour le moment.',
                  style: RemboText.caption,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(RemboSpace.xl),
                itemCount: store.history.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: RemboSpace.md),
                itemBuilder: (context, i) {
                  final d = store.history[i];
                  return Card(
                    key: ValueKey('decision-$i'),
                    child: Padding(
                      padding: const EdgeInsets.all(RemboSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d.supplier,
                                  style: RemboText.subtitle,
                                ),
                              ),
                              const SizedBox(width: RemboSpace.sm),
                              Flexible(
                                child: RemboBadge(
                                  label: d.approved ? 'Approuvée' : 'Rejetée',
                                  tone: d.approved
                                      ? BadgeTone.success
                                      : BadgeTone.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: RemboSpace.xs),
                          Text(
                            '${d.employee} · ${formatMad(d.amountCentimes)}',
                            style: RemboText.caption,
                          ),
                          Text(_when(d.at), style: RemboText.caption),
                          if (d.reason != null) ...[
                            const SizedBox(height: RemboSpace.sm),
                            Text('Motif : ${d.reason}', style: RemboText.body),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    ),
  );
}
