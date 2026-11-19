import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/agents/classification_agent.dart';
import '../../core/data/app_state.dart';
import '../../core/data/ids.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../collaborator/expense_detail_screen.dart';
import 'interrupted_screen.dart';
import 'receipt_picker.dart';
import 'receipt_view.dart';
import 'summary_screen.dart';
import '../../core/data/demo_build.dart';

/// The one expense form: check what was read on a receipt, type an expense
/// by hand, resume a draft or correct a rejected expense.
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({
    super.key,
    this.expense,
    this.receipt,
    this.reading,
    this.readerMissing = false,
  });

  /// Existing draft or rejected expense; null for a new one.
  final Expense? expense;
  final PickedReceipt? receipt;
  final ReceiptReading? reading;

  /// A picture was taken but nothing could read it.
  final bool readerMissing;

  static Future<void> open(
    BuildContext context, {
    Expense? expense,
    PickedReceipt? receipt,
    ReceiptReading? reading,
    bool readerMissing = false,
    bool replace = false,
  }) {
    final route = MaterialPageRoute<void>(
      builder: (_) => ExpenseFormScreen(
        expense: expense,
        receipt: receipt,
        reading: reading,
        readerMissing: readerMissing,
      ),
    );
    final navigator = Navigator.of(context);
    return replace ? navigator.pushReplacement(route) : navigator.push(route);
  }

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _supplier = TextEditingController();
  final _amount = TextEditingController();
  final _vat = TextEditingController();
  final _date = TextEditingController();
  final _project = TextEditingController();
  final _reason = TextEditingController();
  final _foreign = TextEditingController();
  String _currency = 'MAD';
  int? _vatRate;
  String? _category;

  /// Proposals of the classification agent still shown as such, and why.
  final _agentNotes = <String, FieldNote>{};
  bool _categoryTouched = false;
  bool _projectTouched = false;
  bool _classified = false;

  /// Rebuilds the category field when the agent changes its value: the
  /// field only reads its initial value.
  int _categoryVersion = 0;
  final _errors = <String, String>{};
  final _proposed = <String>{};
  String? _failure;
  bool _saving = false;

  /// Server copy once saved; its id makes later saves updates.
  Expense? _saved;
  Uint8List? _receiptBytes;
  String? _receiptName;
  bool _receiptDirty = false;

  /// Id of the row to create: a retried save never creates a second one.
  final _createId = newUuid();

  bool get _correcting => widget.expense?.status == ExpenseStatus.rejected;

  @override
  void initState() {
    super.initState();
    _saved = widget.expense;
    _receiptBytes = widget.receipt?.bytes;
    _receiptName = widget.receipt?.name;
    _receiptDirty = widget.receipt != null;
    final e = widget.expense;
    final r = widget.reading;
    if (e != null) {
      _supplier.text = e.supplier;
      if (e.amountCents > 0) _amount.text = amountInput(e.amountCents);
      if (e.vatCents > 0) _vat.text = amountInput(e.vatCents);
      if (e.date != null) _date.text = formatDayInput(e.date!);
      _project.text = e.project;
      _reason.text = e.reason;
      _category = e.category.isEmpty ? null : e.category;
      _currency = e.currency;
      _vatRate = e.vatRate;
      if (e.foreignAmountCents != null) {
        _foreign.text = amountInput(e.foreignAmountCents!);
      }
    } else if (r != null) {
      if (r.supplier != null) {
        _supplier.text = r.supplier!;
        _proposed.add('supplier');
      }
      if (r.currency != null && r.currency != 'MAD') {
        // Paid in another currency: what the receipt says is the amount
        // paid in it; the person types what it cost in dirhams.
        _currency = r.currency!;
        _proposed.add('currency');
        if (r.amountCents != null) {
          _foreign.text = amountInput(r.amountCents!);
          _proposed.add('foreign');
        }
      } else if (r.amountCents != null) {
        _amount.text = amountInput(r.amountCents!);
        _proposed.add('amount');
      }
      if (r.vatRate != null) {
        _vatRate = r.vatRate;
        _proposed.add('rate');
      }
      if (r.vatCents != null && r.vatCents! > 0) {
        _vat.text = amountInput(r.vatCents!);
        _proposed.add('vat');
      }
      if (r.date != null) {
        _date.text = formatDayInput(r.date!);
        _proposed.add('date');
      }
    } else {
      _date.text = formatDayInput(DateTime.now());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_classified) return;
    _classified = true;
    if (widget.expense == null) _classify();
  }

  /// Asks the classification agent for a category and a project, without
  /// ever overwriting what the person chose.
  void _classify() {
    final state = AppScope.read(context);
    final result = classifyExpense(
      supplier: _supplier.text,
      ice: widget.reading?.supplierIce ?? _saved?.supplierIce ?? '',
      history: state.mine,
    );
    if (!_categoryTouched) {
      final proposed = result.category?.value ?? _category;
      if (proposed != _category) _categoryVersion++;
      _category = proposed;
      if (result.category == null) {
        _agentNotes.remove('category');
      } else {
        _agentNotes['category'] = result.category!.note;
        _errors.remove('category');
      }
    }
    if (!_projectTouched) {
      if (result.project != null && _project.text.trim().isEmpty) {
        _project.text = result.project!.value;
        _agentNotes['project'] = result.project!.note;
      } else if (result.project == null && _agentNotes.containsKey('project')) {
        _project.clear();
        _agentNotes.remove('project');
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _supplier,
      _amount,
      _vat,
      _date,
      _project,
      _reason,
      _foreign,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// [strict] also requires every mandatory field; a draft only refuses
  /// values that are present but malformed.
  bool _validate({required bool strict}) {
    final amount = _amount.text.trim();
    final date = _date.text.trim();
    final vat = _vatCents;
    setState(() {
      _errors
        ..clear()
        ..addAll({
          if (strict && _supplier.text.trim().isEmpty)
            'supplier': tr('Renseignez le fournisseur.'),
          if ((strict || amount.isNotEmpty) && parseAmount(amount) == null)
            'amount': tr('Saisissez un montant positif, ex. 240,00.'),
          if (vat == null)
            'vat': tr('Saisissez un montant, ex. 21,82, ou laissez vide.')
          else if (vat > 0 && vat >= (parseAmount(amount) ?? vat + 1))
            'vat': tr('La TVA doit être inférieure au montant TTC.'),
          if (_currency != 'MAD' &&
              (strict || _foreign.text.trim().isNotEmpty) &&
              parseAmount(_foreign.text.trim()) == null)
            'foreign': tr('Saisissez le montant payé, ex. 85,00.'),
          if ((strict || date.isNotEmpty) && parseDay(date) == null)
            'date': tr('Date invalide : JJ/MM/AAAA, pas dans le futur.'),
          if (strict && _category == null)
            'category': tr('Choisissez une catégorie.'),
          if (strict && _reason.text.trim().isEmpty)
            'reason': tr('Précisez le motif de la dépense.'),
        });
    });
    return _errors.isEmpty;
  }

  /// VAT typed in the form, in centimes: 0 when left empty, null when it
  /// is not an amount.
  int? get _vatCents {
    final text = _vat.text.trim();
    if (text.isEmpty || RegExp(r'^0+([.,]0{1,2})?$').hasMatch(text)) return 0;
    return parseAmount(text);
  }

  Expense _draft(AppUser user) {
    final amount = parseAmount(_amount.text) ?? 0;
    final reading = widget.reading;
    final base =
        _saved ??
        Expense(
          id: '',
          employeeId: user.id,
          employeeName: user.fullName,
          supplierIce: reading?.supplierIce ?? '',
          createdAt: DateTime.now(),
        );
    return Expense(
      id: base.id,
      employeeId: base.employeeId,
      employeeName: base.employeeName,
      supplier: _supplier.text,
      supplierIce: base.supplierIce,
      date: parseDay(_date.text),
      amountCents: amount,
      vatCents: _vatCents ?? 0,
      vatRate: _vatRate,
      currency: _currency,
      foreignAmountCents: _currency == 'MAD'
          ? null
          : parseAmount(_foreign.text.trim()),
      category: _category ?? '',
      project: _project.text,
      reason: _reason.text,
      status: base.status,
      receiptPath: base.receiptPath,
      flags: base.flags,
      events: base.events,
      source: base.source,
      transcript: base.transcript,
      voicePath: base.voicePath,
      createdAt: base.createdAt,
    );
  }

  /// Saves the draft; an interrupted upload offers to retry. Null when it
  /// could not be saved.
  Future<Expense?> _save() async {
    final state = AppScope.read(context);
    final draft = _draft(state.user!);
    Future<Expense> send() => state.saveDraft(
      draft,
      receiptBytes: _receiptDirty ? _receiptBytes : null,
      receiptName: _receiptName,
      createId: _createId,
    );
    setState(() {
      _saving = true;
      _failure = null;
    });
    Expense? saved;
    try {
      saved = await send();
    } on RemboException catch (e) {
      if (!mounted) return null;
      if (e.network) {
        saved = await InterruptedScreen.show<Expense>(
          context,
          expense: draft,
          retry: send,
        );
      } else {
        setState(() => _failure = e.message);
      }
    }
    if (!mounted) return null;
    setState(() {
      _saving = false;
      if (saved != null) {
        _saved = saved;
        _receiptDirty = false;
      }
    });
    return saved;
  }

  Future<void> _saveDraft() async {
    if (!_validate(strict: false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (await _save() == null) return;
    navigator.popUntil((r) => r.isFirst);
    messenger.showSnackBar(
      SnackBar(content: Text(tr('Brouillon enregistré.'))),
    );
  }

  Future<void> _continue() async {
    if (!_validate(strict: true)) return;
    final state = AppScope.read(context);
    final saved = await _save();
    if (saved == null || !mounted) return;
    final twin = state.possibleDuplicateOf(saved);
    if (twin != null) {
      final go = await _duplicateSheet(saved, twin);
      if (go != true || !mounted) return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SummaryScreen(expenseId: saved.id, receiptBytes: _receiptBytes),
      ),
    );
  }

  Future<bool?> _duplicateSheet(Expense draft, Expense twin) {
    Widget line(Expense e, String note) => Padding(
      padding: const EdgeInsets.only(bottom: RemboSpace.sm),
      child: ExpenseTile(
        e,
        subtitle:
            '${isolate(note)} · ${e.date == null ? '' : formatDate(e.date!)}',
        showStatus: false,
      ),
    );
    return showRemboSheet<bool>(
      context,
      title: tr('Doublon possible'),
      subtitle: tr('Une autre dépense a la même date et le même montant.'),
      builder: (context) => Column(
        children: [
          line(draft, tr('Cette dépense')),
          line(twin, tr('Existante · {label}', {'label': twin.status.label})),
          InfoStrip(tr('Comparez les justificatifs avant de continuer.')),
          const SizedBox(height: RemboSpace.lg),
          RemboPrimaryButton(
            key: const ValueKey('duplicate-view'),
            label: tr('Voir la dépense existante'),
            onPressed: () {
              Navigator.of(context).pop(false);
              ExpenseDetailScreen.open(this.context, twin.id);
            },
          ),
          const SizedBox(height: RemboSpace.md),
          RemboSecondaryButton(
            key: const ValueKey('duplicate-keep-draft'),
            label: tr('Conserver le brouillon'),
            onPressed: () {
              Navigator.of(context).pop(false);
              Navigator.of(this.context).popUntil((r) => r.isFirst);
            },
          ),
          TextButton(
            key: const ValueKey('duplicate-continue'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Ce n’est pas un doublon, continuer')),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDay(_date.text) ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _date.text = formatDayInput(picked);
        _proposed.remove('date');
        _errors.remove('date');
      });
    }
  }

  Future<void> _pickReceipt() async {
    final camera = await showRemboSheet<bool>(
      context,
      title: tr('Justificatif'),
      builder: (context) => Column(
        children: [
          RemboPrimaryButton(
            label: tr('Prendre une photo'),
            icon: Icons.photo_camera_outlined,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: RemboSpace.md),
          RemboSecondaryButton(
            label: tr('Importer une image'),
            icon: Icons.insert_drive_file_outlined,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (camera == null || !mounted) return;
    final state = AppScope.read(context);
    final picker = ReceiptPickerScope.read(context);
    try {
      final picked = await picker(camera: camera);
      if (picked == null || !mounted) return;
      setState(() {
        _receiptBytes = picked.bytes;
        _receiptName = picked.name;
        _receiptDirty = true;
      });
    } on RemboException catch (e) {
      if (!mounted) return;
      if (demoAllowed && state.isDemo) {
        final sample = await sampleReceipt();
        if (!mounted) return;
        setState(() {
          _receiptBytes = sample.bytes;
          _receiptName = sample.name;
          _receiptDirty = true;
        });
        showRemboSnackBar(
          context,
          tr('Démonstration : un reçu d’exemple est utilisé.'),
          tone: MessageTone.info,
        );
      } else {
        showRemboSnackBar(context, e.message, tone: MessageTone.error);
      }
    }
  }

  /// Choosing a rate fills an empty VAT from the amount with taxes.
  void _pickRate(int? rate) {
    setState(() {
      _vatRate = rate;
      _proposed.remove('rate');
      final amount = parseAmount(_amount.text.trim());
      if (rate != null &&
          rate > 0 &&
          _vat.text.trim().isEmpty &&
          amount != null) {
        _vat.text = amountInput((amount * rate / (100 + rate)).round());
        _proposed
          ..remove('vat')
          ..add('vat-computed');
      }
    });
  }

  /// « Reçu » on a value read on the receipt; « À vérifier » when the
  /// reader was not sure of it.
  Widget? _readBadge(String field) {
    if (!_proposed.contains(field)) return null;
    final unsure = widget.reading?.notes[field]?.confidence == Confidence.low;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: RemboSpace.md),
      child: RemboBadge(
        label: unsure ? Confidence.low.label : tr('Reçu'),
        tone: unsure ? BadgeTone.warning : BadgeTone.info,
        icon: unsure
            ? Icons.warning_amber_rounded
            : Icons.receipt_long_outlined,
      ),
    );
  }

  /// What the reading agent found, what it is unsure of, what it missed.
  Widget _readingReport(ReceiptReading reading) {
    String name(String field) => switch (field) {
      'supplier' => tr('fournisseur'),
      'date' => tr('date'),
      'amount' => tr('montant'),
      'vat' => tr('TVA'),
      _ => field,
    };
    final unsure = [
      for (final e in reading.notes.entries)
        if (e.value.confidence == Confidence.low && _proposed.contains(e.key))
          e.key,
    ];
    final missing = reading.missing;
    return RemboCard(
      key: const ValueKey('form-reading-report'),
      color: RemboColors.surface,
      borderColor: RemboColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 20,
                color: RemboColors.indigo,
              ),
              const SizedBox(width: RemboSpace.sm),
              Expanded(
                child: Text(
                  reading.engine == 'server'
                      ? tr('Agent de lecture · serveur')
                      : tr('Agent de lecture · sur le téléphone'),
                  style: RemboText.subtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: RemboSpace.xs),
          Text(
            reading.simulated
                ? tr('Démonstration : valeurs simulées, non lues sur la photo.')
                : tr('Valeurs lues sur le ticket : vérifiez-les.'),
            style: RemboText.caption,
          ),
          for (final field in unsure)
            Padding(
              padding: const EdgeInsets.only(top: RemboSpace.xs),
              child: Text(
                tr('À vérifier : {field} — {reason}', {
                  'field': name(field),
                  'reason': trData(reading.notes[field]!.reason),
                }),
                style: RemboText.caption.copyWith(
                  color: RemboColors.warningText,
                ),
              ),
            ),
          if (missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: RemboSpace.xs),
              child: Text(
                tr('Non lu : {fields}', {
                  'fields': missing.map(name).join(', '),
                }),
                style: RemboText.caption,
              ),
            ),
        ],
      ),
    );
  }

  /// « Proposé » on a value chosen by the classification agent.
  Widget? _agentLine(String field) {
    final note = _agentNotes[field];
    if (note == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: RemboSpace.xs),
      child: Text(
        tr('Proposé par l’agent : {reason}', {'reason': trData(note.reason)}),
        key: ValueKey('form-proposed-$field'),
        style: RemboText.caption.copyWith(color: RemboColors.infoText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final existing = widget.expense;
    final rejection = _correcting ? existing!.lastDecision : null;
    final hasReceipt = _receiptBytes != null || (_saved?.hasReceipt ?? false);
    final title = _correcting
        ? tr('Corriger ma dépense')
        : (reading != null
              ? tr('Vérifier les informations')
              : (existing != null
                    ? tr('Reprendre le brouillon')
                    : tr('Saisir une dépense')));
    return RemboPage(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RemboPrimaryButton(
            key: const ValueKey('form-continue'),
            label: _correcting
                ? tr('Enregistrer les corrections')
                : tr('Continuer'),
            loading: _saving,
            onPressed: _continue,
          ),
          TextButton(
            key: const ValueKey('form-save-draft'),
            onPressed: _saving ? null : _saveDraft,
            child: Text(tr('Enregistrer le brouillon')),
          ),
        ],
      ),
      children: [
        RemboHero(
          title: title,
          subtitle: _correcting
              ? tr('Vous pourrez ensuite la soumettre à nouveau.')
              : null,
          below: _correcting
              ? const StatusBadge(status: ExpenseStatus.rejected)
              : null,
        ),
        if (rejection?.reason != null) ...[
          RemboMessage(
            tone: MessageTone.warning,
            title: tr('Commentaire du responsable'),
            message: rejection!.reason,
          ),
          const SizedBox(height: RemboSpace.lg),
        ],
        if (reading != null) ...[
          _readingReport(reading),
          const SizedBox(height: RemboSpace.lg),
        ] else if (widget.readerMissing) ...[
          InfoStrip(
            tr('Lecture automatique indisponible : saisissez les valeurs.'),
          ),
          const SizedBox(height: RemboSpace.lg),
        ],
        if (_failure != null) ...[
          RemboMessage(tone: MessageTone.error, title: _failure!),
          const SizedBox(height: RemboSpace.lg),
        ],
        ReceiptCard(
          expense: _receiptBytes == null ? _saved : null,
          bytes: _receiptBytes,
          action: OutlinedButton.icon(
            key: const ValueKey('form-receipt'),
            icon: Icon(
              hasReceipt ? Icons.sync_rounded : Icons.attach_file_rounded,
              size: 18,
            ),
            label: Text(
              hasReceipt ? tr('Remplacer') : tr('Ajouter un justificatif'),
            ),
            onPressed: _pickReceipt,
          ),
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('form-supplier'),
          label: tr('Fournisseur'),
          required: true,
          hint: tr('Nom du fournisseur'),
          icon: Icons.storefront_outlined,
          controller: _supplier,
          errorText: _errors['supplier'],
          suffix: _readBadge('supplier'),
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {
            _proposed.remove('supplier');
            _classify();
          }),
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('form-amount'),
          label: tr('Montant TTC (MAD)'),
          required: true,
          hint: '0,00',
          icon: Icons.payments_outlined,
          controller: _amount,
          errorText: _errors['amount'],
          suffix: _readBadge('amount'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _proposed.remove('amount')),
        ),
        const SizedBox(height: RemboSpace.sm),
        Row(
          children: [
            Expanded(
              child: Text(tr('Devise du reçu'), style: RemboText.caption),
            ),
            if (_proposed.contains('currency')) _readBadge('currency')!,
            DropdownButton<String>(
              key: const ValueKey('form-currency'),
              value: _currency,
              underline: const SizedBox.shrink(),
              items: [
                for (final c in receiptCurrencies)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (c) => setState(() {
                _currency = c ?? 'MAD';
                _proposed.remove('currency');
                _errors.remove('foreign');
              }),
            ),
          ],
        ),
        if (_currency != 'MAD') ...[
          const SizedBox(height: RemboSpace.sm),
          RemboTextField(
            fieldKey: const ValueKey('form-foreign'),
            label: tr('Montant payé ({currency})', {'currency': _currency}),
            required: true,
            hint: '0,00',
            icon: Icons.currency_exchange_rounded,
            controller: _foreign,
            errorText: _errors['foreign'],
            suffix: _readBadge('foreign'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _proposed.remove('foreign')),
          ),
          const SizedBox(height: RemboSpace.sm),
          InfoStrip(
            tr(
              'Le montant TTC en dirhams est celui remboursé : '
              'reportez la conversion de votre relevé.',
            ),
          ),
        ],
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('form-vat'),
          label: tr('TVA incluse (MAD)'),
          hint: tr('Facultatif'),
          icon: Icons.percent_rounded,
          controller: _vat,
          errorText: _errors['vat'],
          suffix: _proposed.contains('vat-computed')
              ? Padding(
                  padding: EdgeInsetsDirectional.only(end: RemboSpace.md),
                  child: RemboBadge(
                    label: tr('Calculée'),
                    tone: BadgeTone.info,
                    icon: Icons.calculate_outlined,
                  ),
                )
              : _readBadge('vat'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {
            _proposed
              ..remove('vat')
              ..remove('vat-computed');
          }),
        ),
        const SizedBox(height: RemboSpace.sm),
        Row(
          children: [
            Text(tr('Taux de TVA'), style: RemboText.caption),
            if (_proposed.contains('rate')) ...[
              const SizedBox(width: RemboSpace.sm),
              _readBadge('rate')!,
            ],
          ],
        ),
        const SizedBox(height: RemboSpace.xs),
        Wrap(
          spacing: RemboSpace.sm,
          runSpacing: RemboSpace.xs,
          children: [
            for (final rate in vatRates)
              ChoiceChip(
                key: ValueKey('form-rate-$rate'),
                label: Text('$rate %'),
                selected: _vatRate == rate,
                showCheckmark: false,
                onSelected: (on) => _pickRate(on ? rate : null),
              ),
          ],
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('form-date'),
          label: tr('Date'),
          required: true,
          hint: tr('JJ/MM/AAAA'),
          icon: Icons.calendar_today_outlined,
          controller: _date,
          errorText: _errors['date'],
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _proposed.remove('date')),
          suffix: IconButton(
            tooltip: tr('Choisir dans le calendrier'),
            icon: const Icon(Icons.expand_more_rounded),
            onPressed: _pickDate,
          ),
        ),
        const SizedBox(height: RemboSpace.lg),
        Text.rich(
          TextSpan(
            text: tr('Catégorie'),
            children: [
              TextSpan(
                text: ' *',
                style: TextStyle(color: RemboColors.danger),
              ),
            ],
          ),
          style: RemboText.subtitle,
        ),
        const SizedBox(height: RemboSpace.sm),
        KeyedSubtree(
          key: ValueKey('form-category-v$_categoryVersion'),
          child: DropdownButtonFormField<String>(
            key: const ValueKey('form-category'),
            initialValue: _category,
            isExpanded: true,
            hint: Text(tr('Choisir')),
            decoration: InputDecoration(
              prefixIcon: Icon(
                categoryIcon(_category ?? ''),
                color: RemboColors.night,
              ),
              errorText: _errors['category'],
            ),
            items: [
              for (final c in expenseCategories)
                DropdownMenuItem(value: c, child: Text(tr(c))),
            ],
            onChanged: (c) => setState(() {
              _category = c;
              _categoryTouched = true;
              _agentNotes.remove('category');
              _errors.remove('category');
            }),
          ),
        ),
        ?_agentLine('category'),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('form-project'),
          label: tr('Client ou projet'),
          hint: tr('Facultatif'),
          icon: Icons.work_outline_rounded,
          controller: _project,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {
            _projectTouched = true;
            _agentNotes.remove('project');
          }),
        ),
        ?_agentLine('project'),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('form-reason'),
          label: tr('Motif'),
          required: true,
          hint: tr('Précisez le contexte de la dépense'),
          icon: Icons.notes_rounded,
          controller: _reason,
          errorText: _errors['reason'],
          maxLines: 3,
          maxLength: 200,
        ),
        if (_correcting && existing!.events.isNotEmpty) ...[
          SectionTitle(tr('Historique de décision')),
          for (final ev in existing.events.reversed.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: RemboSpace.md),
              child: Row(
                children: [
                  Icon(
                    ev.status == ExpenseStatus.rejected
                        ? Icons.cancel_rounded
                        : Icons.check_circle_rounded,
                    color: ev.status == ExpenseStatus.rejected
                        ? RemboColors.danger
                        : RemboColors.green,
                  ),
                  const SizedBox(width: RemboSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ev.status.label} · ${trData(ev.actorName)}',
                          style: RemboText.subtitle,
                        ),
                        Text(
                          '${formatDateLong(ev.at)} à ${formatTime(ev.at)}',
                          style: RemboText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (existing == null && _saved == null)
          Padding(
            padding: const EdgeInsets.only(top: RemboSpace.sm),
            child: TextButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: Text(tr('Abandonner')),
            ),
          ),
      ],
    );
  }
}
