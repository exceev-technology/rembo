import 'package:flutter/material.dart';

import '../../core/widgets/rembo_widgets.dart';
import 'capture_screen.dart';
import 'expense_draft.dart';
import 'summary_screen.dart';

/// Step 2: simulated reading of the receipt, then correction and completion
/// of the fields. Receives the draft from [CaptureScreen] as route
/// arguments; opened directly, it starts from the fictional receipt.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, this.draft});
  final ExpenseDraft? draft;

  static const readingDelay = Duration(milliseconds: 1200);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  ExpenseDraft? _draft;
  bool _owned = false;
  bool _reading = false;
  bool _checked = false;
  final _scroll = ScrollController();
  final _controllers = {
    for (final f in DraftField.values)
      if (f != DraftField.category) f: TextEditingController(),
  };

  ExpenseDraft get draft => _draft!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draft != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    final given = widget.draft ?? (args is ExpenseDraft ? args : null);
    _owned = given == null;
    _draft = given ?? (ExpenseDraft()..attach(ReceiptSource.camera));
    if (draft.analyzed) {
      _fillControllers();
    } else {
      _read();
    }
  }

  Future<void> _read() async {
    setState(() => _reading = true);
    await Future<void>.delayed(ReviewScreen.readingDelay);
    if (!mounted) return;
    draft.simulateReading();
    _fillControllers();
    setState(() => _reading = false);
  }

  void _fillControllers() {
    for (final entry in _controllers.entries) {
      entry.value.text = draft.value(entry.key);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _scroll.dispose();
    if (_owned) _draft?.dispose();
    super.dispose();
  }

  void _next() {
    setState(() => _checked = true);
    if (draft.errors().isNotEmpty) {
      // Bring the error summary into view.
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SummaryScreen(draft: draft)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nouvelle dépense')),
    body: SafeArea(
      child: _reading
          ? const _Reading()
          : ListenableBuilder(
              listenable: draft,
              builder: (context, _) => _form(context),
            ),
    ),
  );

  Widget _form(BuildContext context) {
    final errors = _checked ? draft.errors() : const <DraftField, String>{};
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(RemboSpace.xl),
      children: [
        const ExpenseStepLabel(2, 'Vérification'),
        const SizedBox(height: RemboSpace.sm),
        const Text(
          'Vérification des informations',
          key: ValueKey('destination-title'),
          style: RemboText.title,
        ),
        const SizedBox(height: RemboSpace.sm),
        const Text(
          'Les valeurs lues sur le reçu sont des propositions : corrigez-les '
          'si besoin et complétez le reste.',
          style: RemboText.body,
        ),
        const SizedBox(height: RemboSpace.lg),
        if (draft.manual) ...[
          const RemboMessage(
            key: ValueKey('review-manual'),
            tone: MessageTone.info,
            title: 'Saisie manuelle',
            message:
                'Aucun justificatif n’est joint : votre responsable pourra '
                'vous le demander avant de valider.',
          ),
          const SizedBox(height: RemboSpace.lg),
        ],
        if (draft.unreadable) ...[
          RemboMessage(
            key: const ValueKey('review-unreadable'),
            tone: MessageTone.error,
            title: 'Justificatif illisible',
            message:
                'Aucune information n’a pu être lue. Reprenez la photo ou '
                'saisissez les champs à la main.',
            action: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Reprendre la photo'),
            ),
          ),
          const SizedBox(height: RemboSpace.lg),
        ],
        if (errors.isNotEmpty) ...[
          RemboMessage(
            key: const ValueKey('review-errors'),
            tone: MessageTone.error,
            title: errors.length == 1
                ? '1 champ à corriger'
                : '${errors.length} champs à corriger',
          ),
          const SizedBox(height: RemboSpace.lg),
        ],
        for (final field in DraftField.readable)
          _field(field, errors[field], keyboard: _keyboardOf(field)),
        _categories(errors[DraftField.category]),
        _field(DraftField.reason, errors[DraftField.reason], maxLines: 3),
        _field(DraftField.project, null, hint: 'Facultatif'),
        const SizedBox(height: RemboSpace.sm),
        RemboPrimaryButton(
          key: const ValueKey('review-next'),
          label: 'Voir le récapitulatif',
          onPressed: _next,
        ),
      ],
    );
  }

  static TextInputType? _keyboardOf(DraftField field) => switch (field) {
    DraftField.amount ||
    DraftField.vat => const TextInputType.numberWithOptions(decimal: true),
    DraftField.date || DraftField.ice => TextInputType.number,
    _ => null,
  };

  Widget _header(DraftField field) {
    final empty = draft.value(field).trim().isEmpty;
    return Row(
      children: [
        Flexible(
          child: Text(
            field.required ? '${field.label} *' : field.label,
            style: RemboText.caption.copyWith(color: RemboColors.ink),
          ),
        ),
        const SizedBox(width: RemboSpace.sm),
        if (draft.proposed.contains(field))
          const Flexible(
            child: RemboBadge(
              label: 'Lu sur le reçu',
              tone: BadgeTone.info,
              icon: Icons.auto_awesome_outlined,
            ),
          )
        else if (field.required && empty)
          const Flexible(
            child: RemboBadge(label: 'À compléter', tone: BadgeTone.warning),
          ),
      ],
    );
  }

  Widget _field(
    DraftField field,
    String? error, {
    TextInputType? keyboard,
    int maxLines = 1,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: RemboSpace.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(field),
        const SizedBox(height: RemboSpace.sm),
        TextField(
          key: ValueKey('field-${field.name}'),
          controller: _controllers[field],
          keyboardType: keyboard,
          maxLines: maxLines,
          style: field == DraftField.amount || field == DraftField.vat
              ? RemboText.amount
              : RemboText.body,
          onChanged: (text) => draft.set(field, text),
          decoration: InputDecoration(
            hintText: hint ?? (field == DraftField.date ? 'JJ/MM/AAAA' : null),
            suffixText: field == DraftField.amount || field == DraftField.vat
                ? 'MAD'
                : null,
            errorText: error,
            errorMaxLines: 3,
          ),
        ),
      ],
    ),
  );

  Widget _categories(String? error) => Padding(
    padding: const EdgeInsets.only(bottom: RemboSpace.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(DraftField.category),
        const SizedBox(height: RemboSpace.sm),
        Wrap(
          spacing: RemboSpace.sm,
          runSpacing: RemboSpace.sm,
          children: [
            for (final c in expenseCategories)
              ChoiceChip(
                key: ValueKey('category-$c'),
                label: Text(c),
                selected: draft.value(DraftField.category) == c,
                onSelected: (_) => draft.set(DraftField.category, c),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: RemboSpace.sm),
          Text(
            error,
            style: RemboText.caption.copyWith(color: RemboColors.danger),
          ),
        ],
      ],
    ),
  );
}

class _Reading extends StatelessWidget {
  const _Reading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(RemboSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: RemboSpace.xl),
          Text(
            'Lecture du justificatif…',
            key: ValueKey('review-reading'),
            style: RemboText.subtitle,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: RemboSpace.sm),
          Text(
            'Fournisseur, date, montant, TVA et ICE.',
            style: RemboText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
