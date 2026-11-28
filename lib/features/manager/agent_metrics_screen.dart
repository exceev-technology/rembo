import 'package:flutter/material.dart';

import '../../core/agents/agent_metrics.dart';
import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// « Mesures des agents » : what people kept of the agents' proposals and
/// how long they took to declare, over the expenses this person may read.
class AgentMetricsScreen extends StatelessWidget {
  const AgentMetricsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const AgentMetricsScreen()));

  static String fieldName(String field) => switch (field) {
    'supplier' => tr('Fournisseur'),
    'ice' => 'ICE',
    'date' => tr('Date'),
    'amount' => tr('Montant TTC (MAD)'),
    'vat' => tr('TVA incluse'),
    'rate' => tr('Taux de TVA'),
    'currency' => tr('Devise du reçu'),
    'foreign' => tr('Montant payé'),
    'category' => tr('Catégorie'),
    'project' => tr('Client ou projet'),
    _ => field,
  };

  static String _duration(Duration? d) {
    if (d == null) return '—';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return m == 0 ? '$s s' : '$m min ${s.toString().padLeft(2, '0')} s';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final metrics = AgentMetrics.of(state.expenses);
    final percent = (metrics.acceptance * 100).round();
    return RemboPage(
      children: [
        RemboHero(
          title: tr('Mesures des agents'),
          subtitle: tr(
            'Ce que les personnes ont gardé des propositions des agents, '
            'sur les dépenses soumises.',
          ),
        ),
        if (metrics.assisted.isEmpty)
          InfoStrip(
            key: const ValueKey('metrics-empty'),
            tr(
              'Aucune dépense soumise avec une proposition d’agent pour '
              'l’instant.',
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _Tile(
                  key: const ValueKey('metrics-acceptance'),
                  value: '$percent %',
                  label: tr('des champs proposés gardés tels quels'),
                ),
              ),
              const SizedBox(width: RemboSpace.sm),
              Expanded(
                child: _Tile(
                  value: '${metrics.corrected}',
                  label: tr('champs corrigés sur {count}', {
                    'count': metrics.proposed,
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: RemboSpace.sm),
          Row(
            children: [
              Expanded(
                child: _Tile(
                  value: '${metrics.untouched}/${metrics.assisted.length}',
                  label: tr('reçus sans aucune correction'),
                ),
              ),
              const SizedBox(width: RemboSpace.sm),
              Expanded(
                child: _Tile(
                  value: _duration(metrics.medianDeclare(assisted: true)),
                  label: tr('temps médian de déclaration avec lecture'),
                ),
              ),
            ],
          ),
          SectionTitle(tr('Par champ')),
          RemboCard(
            child: Column(
              children: [
                for (final f in metrics.byField)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: RemboSpace.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fieldName(f.field),
                            style: RemboText.subtitle,
                          ),
                        ),
                        Text(
                          '${f.accepted}/${f.proposed} · '
                          '${(f.rate * 100).round()} %',
                          style: RemboText.amount,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: RemboSpace.md),
          InfoStrip(
            tr('Temps médian sans lecture automatique : {time}.', {
              'time': _duration(metrics.medianDeclare(assisted: false)),
            }),
            icon: Icons.timer_outlined,
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => RemboCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: RemboText.amount.copyWith(fontSize: 22)),
        const SizedBox(height: RemboSpace.xs),
        Text(label, style: RemboText.caption),
      ],
    ),
  );
}
