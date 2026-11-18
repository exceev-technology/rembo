import 'package:flutter/material.dart';

import '../../core/widgets/rembo_widgets.dart';

/// « Envoi interrompu » : the request did not reach the server. Nothing is
/// lost: the same request can be sent again. Pops the result of [retry],
/// or null when the person gives up.
class InterruptedScreen<T> extends StatefulWidget {
  const InterruptedScreen({
    super.key,
    required this.expense,
    required this.retry,
  });
  final Expense expense;
  final Future<T> Function() retry;

  static Future<T?> show<T>(
    BuildContext context, {
    required Expense expense,
    required Future<T> Function() retry,
  }) => Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      builder: (_) => InterruptedScreen<T>(expense: expense, retry: retry),
    ),
  );

  @override
  State<InterruptedScreen<T>> createState() => _InterruptedScreenState<T>();
}

class _InterruptedScreenState<T> extends State<InterruptedScreen<T>> {
  bool _loading = false;
  String? _failure;

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    final navigator = Navigator.of(context);
    try {
      final result = await widget.retry();
      navigator.pop(result);
    } on RemboException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failure = e.network ? 'Toujours pas de connexion.' : e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    return RemboPage(
      showBack: false,
      children: [
        const RemboMoment(
          title: 'Envoi interrompu',
          message:
              'La dépense n’a pas encore été envoyée. Vérifiez votre '
              'connexion puis réessayez.',
          illustration: RemboArt.warning,
        ),
        RemboCard(
          child: Column(
            children: [
              Row(
                children: [
                  const IconTile(Icons.receipt_long_outlined),
                  const SizedBox(width: RemboSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dépense', style: RemboText.subtitle),
                        Text(
                          e.reason.isEmpty ? e.title : e.reason,
                          style: RemboText.caption,
                        ),
                      ],
                    ),
                  ),
                  const RemboBadge(label: 'À envoyer', tone: BadgeTone.warning),
                ],
              ),
              const Divider(height: RemboSpace.xl),
              _Line('Montant', formatMad(e.amountCents)),
              _Line('Date', e.date == null ? '—' : formatDate(e.date!)),
              _Line('Catégorie', e.category.isEmpty ? '—' : e.category),
            ],
          ),
        ),
        if (_failure != null) ...[
          const SizedBox(height: RemboSpace.lg),
          RemboMessage(tone: MessageTone.error, title: _failure!),
        ],
        const SizedBox(height: RemboSpace.xl),
        RemboPrimaryButton(
          key: const ValueKey('interrupted-retry'),
          label: 'Réessayer',
          loading: _loading,
          onPressed: _retry,
        ),
        const SizedBox(height: RemboSpace.md),
        RemboSecondaryButton(
          key: const ValueKey('interrupted-cancel'),
          label: 'Annuler l’envoi',
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: RemboSpace.xs),
    child: Row(
      children: [
        Expanded(child: Text(label, style: RemboText.body)),
        Text(value, style: RemboText.amount),
      ],
    ),
  );
}
