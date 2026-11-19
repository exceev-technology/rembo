import 'package:flutter/material.dart';

import '../../core/agents/export_agent.dart';
import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// « Comptes comptables » : the account each category is booked on. The
/// export carries it; the accountant of the company decides.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const AccountsScreen()));

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late final Map<String, TextEditingController> _codes = {
    for (final c in expenseCategories)
      c: TextEditingController(text: AppScope.read(context).accounts[c] ?? ''),
  };
  bool _saving = false;
  String? _failure;

  @override
  void dispose() {
    for (final c in _codes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final state = AppScope.read(context);
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      for (final e in _codes.entries) {
        final code = e.value.text.trim();
        if (code != (state.accounts[e.key] ?? '')) {
          await state.saveAccount(e.key, code);
        }
      }
      if (!mounted) return;
      showRemboSnackBar(context, tr('Comptes enregistrés.'));
      Navigator.of(context).pop();
    } on RemboException catch (e) {
      if (mounted) setState(() => _failure = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RemboPage(
      bottom: RemboPrimaryButton(
        key: const ValueKey('accounts-save'),
        label: tr('Enregistrer les comptes'),
        loading: _saving,
        onPressed: _save,
      ),
      children: [
        RemboHero(
          title: tr('Comptes comptables'),
          subtitle: tr('Le compte de chaque catégorie figure dans l’export.'),
        ),
        if (_failure != null) ...[
          RemboMessage(tone: MessageTone.error, title: _failure!),
          const SizedBox(height: RemboSpace.lg),
        ],
        for (final c in expenseCategories) ...[
          RemboTextField(
            fieldKey: ValueKey('account-$c'),
            label: tr(c),
            hint: suggestedAccounts[c] == null
                ? tr('Compte choisi par votre comptable')
                : tr('Proposé : {code}', {'code': suggestedAccounts[c]}),
            icon: categoryIcon(c),
            controller: _codes[c]!,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: RemboSpace.md),
        ],
        InfoStrip(
          tr(
            'Les comptes proposés suivent le plan comptable marocain (CGNC) : '
            'faites-les valider par votre comptable.',
          ),
        ),
      ],
    );
  }
}
