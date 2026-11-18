import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// « Règles de remboursement » : one limit per category. The automatic
/// control on the server applies them at submission.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return RemboPage(
      children: [
        RemboHero(
          title: tr('Règles de remboursement'),
          subtitle: tr('Plafonds par dépense et justificatifs exigés.'),
        ),
        for (final category in expenseCategories)
          if (category != 'Autre')
            _RuleCard(
              key: ValueKey('rule-$category'),
              category: category,
              rule: state.policyOf(category),
            ),
        const SizedBox(height: RemboSpace.sm),
        InfoStrip(
          tr('Tout écart, et la catégorie « Autre », va au responsable.'),
        ),
      ],
    );
  }
}

class _RuleCard extends StatefulWidget {
  const _RuleCard({super.key, required this.category, this.rule});
  final String category;
  final PolicyRule? rule;

  @override
  State<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<_RuleCard> {
  late final _limit = TextEditingController(
    text: widget.rule == null ? '' : amountInput(widget.rule!.limitCents),
  );
  late bool _receipt = widget.rule?.receiptRequired ?? true;
  bool _open = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cents = parseAmount(_limit.text);
    if (cents == null) {
      setState(() => _error = tr('Saisissez un plafond positif, ex. 200,00.'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppScope.read(context).savePolicy(
        PolicyRule(
          category: widget.category,
          limitCents: cents,
          receiptRequired: _receipt,
        ),
      );
      if (!mounted) return;
      setState(() => _open = false);
      showRemboSnackBar(
        context,
        tr('Règle {category} enregistrée.', {'category': tr(widget.category)}),
      );
    } on RemboException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;
    return Padding(
      padding: const EdgeInsets.only(bottom: RemboSpace.md),
      child: RemboCard(
        borderColor: _open ? RemboColors.indigo : RemboColors.border,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              key: ValueKey('rule-toggle-${widget.category}'),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.all(RemboSpace.lg),
                child: Row(
                  children: [
                    IconTile(categoryIcon(widget.category)),
                    const SizedBox(width: RemboSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(widget.category), style: RemboText.subtitle),
                          Text(
                            rule == null
                                ? tr('Aucun plafond')
                                : formatMad(rule.limitCents),
                            style: RemboText.amount.copyWith(
                              color: RemboColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined, color: RemboColors.night),
                    Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: RemboColors.night,
                    ),
                  ],
                ),
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RemboSpace.lg,
                  0,
                  RemboSpace.lg,
                  RemboSpace.lg,
                ),
                child: Column(
                  children: [
                    RemboTextField(
                      fieldKey: ValueKey('rule-limit-${widget.category}'),
                      label: tr('Plafond par dépense (MAD)'),
                      icon: Icons.payments_outlined,
                      controller: _limit,
                      errorText: _error,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        tr('Justificatif requis'),
                        style: RemboText.body,
                      ),
                      value: _receipt,
                      onChanged: (v) => setState(() => _receipt = v),
                    ),
                    RemboPrimaryButton(
                      key: ValueKey('rule-save-${widget.category}'),
                      label: tr('Enregistrer'),
                      loading: _loading,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
