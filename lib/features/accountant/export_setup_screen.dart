import 'package:flutter/material.dart';

import '../../core/agents/export_agent.dart';
import '../../core/data/app_state.dart';
import '../../core/data/ids.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'accounts_screen.dart';
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

  Future<void> _generate(ExportCheck check) async {
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
          builder: (_) => ExportReadyScreen(batch: batch, expected: check),
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
    final check = prepareExport(rows, accounts: state.accounts);
    return RemboPage(
      bottom: RemboPrimaryButton(
        key: const ValueKey('export-generate'),
        label: tr('Générer le CSV'),
        icon: Icons.download_rounded,
        loading: _loading,
        onPressed: rows.isEmpty ? null : () => _generate(check),
      ),
      children: [
        RemboHero(
          title: tr('Préparer l’export'),
          illustration: RemboArt.download,
        ),
        _ExportAgentCard(check: check),
        if (_failure != null) ...[
          const SizedBox(height: RemboSpace.lg),
          RemboMessage(tone: MessageTone.error, title: _failure!),
        ],
        SectionTitle(tr('Format d’export')),
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
                              tr('Pas encore disponible'),
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
        Text(tr('Délimiteur'), style: RemboText.subtitle),
        const SizedBox(height: RemboSpace.sm),
        DropdownButtonFormField<String>(
          key: const ValueKey('export-delimiter'),
          initialValue: _delimiter,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.code_rounded, color: RemboColors.night),
          ),
          items: [
            DropdownMenuItem(value: ';', child: Text(tr('Point-virgule'))),
            DropdownMenuItem(value: ',', child: Text(tr('Virgule'))),
          ],
          onChanged: (d) => setState(() => _delimiter = d ?? ';'),
        ),
        SectionTitle(
          tr('Aperçu des enregistrements ({rows})', {'rows': rows.length}),
        ),
        for (final e in rows)
          ExpenseTile(
            e,
            showStatus: false,
            subtitle:
                '${isolate(e.employeeName)} · '
                '${e.date == null ? '' : formatDayShort(e.date!)}',
          ),
        InfoStrip(tr('Une dépense exportée ne peut plus l’être à nouveau.')),
      ],
    );
  }
}

/// What the export agent prepared: the totals of the batch and what an
/// accountant would look at before importing it.
class _ExportAgentCard extends StatelessWidget {
  const _ExportAgentCard({required this.check});
  final ExportCheck check;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: RemboSpace.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: RemboText.caption)),
          Text(value, style: RemboText.amount),
        ],
      ),
    );
    return RemboCard(
      key: const ValueKey('export-agent'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Agent d’export'), style: RemboText.subtitle),
          line(tr('Dépenses'), expenseCount(check.count)),
          line(tr('Total TTC'), formatMad(check.totalCents)),
          line(tr('Dont TVA'), formatMad(check.vatCents)),
          line(tr('Total HT'), formatMad(check.netCents)),
          if (check.missingAccounts.isNotEmpty) ...[
            const SizedBox(height: RemboSpace.sm),
            InfoStrip(
              tr('Compte comptable manquant : {categories}', {
                'categories': check.missingAccounts.map(tr).join(', '),
              }),
              icon: Icons.account_balance_outlined,
              color: RemboColors.warningText,
              background: RemboColors.warningTint,
            ),
            TextButton(
              key: const ValueKey('export-accounts'),
              onPressed: () => AccountsScreen.open(context),
              child: Text(tr('Renseigner les comptes')),
            ),
          ],
          for (final issue in check.issues)
            Padding(
              padding: const EdgeInsets.only(top: RemboSpace.xs),
              child: Text(
                '• ${isolate(issue.expense.title)} : ${trData(issue.message)}',
                style: RemboText.caption.copyWith(
                  color: RemboColors.warningText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
