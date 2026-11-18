import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/data/ids.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../collaborator/expense_detail_screen.dart';
import 'interrupted_screen.dart';
import 'receipt_picker.dart';
import 'receipt_view.dart';
import 'summary_screen.dart';

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
  final _date = TextEditingController();
  final _project = TextEditingController();
  final _reason = TextEditingController();
  String? _category;
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
      if (e.date != null) _date.text = formatDayInput(e.date!);
      _project.text = e.project;
      _reason.text = e.reason;
      _category = e.category.isEmpty ? null : e.category;
    } else if (r != null) {
      if (r.supplier != null) {
        _supplier.text = r.supplier!;
        _proposed.add('supplier');
      }
      if (r.amountCents != null) {
        _amount.text = amountInput(r.amountCents!);
        _proposed.add('amount');
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
  void dispose() {
    for (final c in [_supplier, _amount, _date, _project, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  /// [strict] also requires every mandatory field; a draft only refuses
  /// values that are present but malformed.
  bool _validate({required bool strict}) {
    final amount = _amount.text.trim();
    final date = _date.text.trim();
    setState(() {
      _errors
        ..clear()
        ..addAll({
          if (strict && _supplier.text.trim().isEmpty)
            'supplier': 'Renseignez le fournisseur.',
          if ((strict || amount.isNotEmpty) && parseAmount(amount) == null)
            'amount': 'Saisissez un montant positif, ex. 240,00.',
          if ((strict || date.isNotEmpty) && parseDay(date) == null)
            'date': 'Date invalide : JJ/MM/AAAA, pas dans le futur.',
          if (strict && _category == null)
            'category': 'Choisissez une catégorie.',
          if (strict && _reason.text.trim().isEmpty)
            'reason': 'Précisez le motif de la dépense.',
        });
    });
    return _errors.isEmpty;
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
      // The VAT read on the receipt only holds for the amount read with it.
      vatCents: reading?.amountCents == amount && reading?.vatCents != null
          ? reading!.vatCents!
          : (base.amountCents == amount ? base.vatCents : 0),
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
      const SnackBar(content: Text('Brouillon enregistré.')),
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
        subtitle: '$note · ${e.date == null ? '' : formatDate(e.date!)}',
        showStatus: false,
      ),
    );
    return showRemboSheet<bool>(
      context,
      title: 'Doublon possible',
      subtitle: 'Une autre dépense a la même date et le même montant.',
      builder: (context) => Column(
        children: [
          line(draft, 'Cette dépense'),
          line(twin, 'Existante · ${twin.status.label}'),
          const InfoStrip('Comparez les justificatifs avant de continuer.'),
          const SizedBox(height: RemboSpace.lg),
          RemboPrimaryButton(
            key: const ValueKey('duplicate-view'),
            label: 'Voir la dépense existante',
            onPressed: () {
              Navigator.of(context).pop(false);
              ExpenseDetailScreen.open(this.context, twin.id);
            },
          ),
          const SizedBox(height: RemboSpace.md),
          RemboSecondaryButton(
            key: const ValueKey('duplicate-keep-draft'),
            label: 'Conserver le brouillon',
            onPressed: () {
              Navigator.of(context).pop(false);
              Navigator.of(this.context).popUntil((r) => r.isFirst);
            },
          ),
          TextButton(
            key: const ValueKey('duplicate-continue'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ce n’est pas un doublon, continuer'),
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
      title: 'Justificatif',
      builder: (context) => Column(
        children: [
          RemboPrimaryButton(
            label: 'Prendre une photo',
            icon: Icons.photo_camera_outlined,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: RemboSpace.md),
          RemboSecondaryButton(
            label: 'Importer une image',
            icon: Icons.insert_drive_file_outlined,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (camera == null || !mounted) return;
    final state = AppScope.read(context);
    try {
      final picked = await receiptPicker(camera: camera);
      if (picked == null || !mounted) return;
      setState(() {
        _receiptBytes = picked.bytes;
        _receiptName = picked.name;
        _receiptDirty = true;
      });
    } on RemboException catch (e) {
      if (!mounted) return;
      if (state.isDemo) {
        final sample = await sampleReceipt();
        if (!mounted) return;
        setState(() {
          _receiptBytes = sample.bytes;
          _receiptName = sample.name;
          _receiptDirty = true;
        });
        showRemboSnackBar(
          context,
          'Démonstration : un reçu d’exemple est utilisé.',
          tone: MessageTone.info,
        );
      } else {
        showRemboSnackBar(context, e.message, tone: MessageTone.error);
      }
    }
  }

  Widget? _readBadge(String field) => _proposed.contains(field)
      ? const Padding(
          padding: EdgeInsets.only(right: RemboSpace.md),
          child: RemboBadge(
            label: 'Reçu',
            tone: BadgeTone.info,
            icon: Icons.receipt_long_outlined,
          ),
        )
      : null;

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final existing = widget.expense;
    final rejection = _correcting ? existing!.lastDecision : null;
    final hasReceipt = _receiptBytes != null || (_saved?.hasReceipt ?? false);
    final title = _correcting
        ? 'Corriger ma dépense'
        : (reading != null
              ? 'Vérifier les informations'
              : (existing != null
                    ? 'Reprendre le brouillon'
                    : 'Saisir une dépense'));
    return RemboPage(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RemboPrimaryButton(
            key: const ValueKey('form-continue'),
            label: _correcting ? 'Enregistrer les corrections' : 'Continuer',
            loading: _saving,
            onPressed: _continue,
          ),
          TextButton(
            key: const ValueKey('form-save-draft'),
            onPressed: _saving ? null : _saveDraft,
            child: const Text('Enregistrer le brouillon'),
          ),
        ],
      ),
      children: [
        RemboHero(
          title: title,
          subtitle: _correcting
              ? 'Vous pourrez ensuite la soumettre à nouveau.'
              : 'Contrôlez et complétez les détails de votre dépense avant '
                    'de l’envoyer.',
          below: _correcting
              ? const StatusBadge(status: ExpenseStatus.rejected)
              : null,
        ),
        if (rejection?.reason != null) ...[
          RemboMessage(
            tone: MessageTone.warning,
            title: 'Commentaire du responsable',
            message: rejection!.reason,
          ),
          const SizedBox(height: RemboSpace.lg),
        ],
        if (reading != null) ...[
          InfoStrip(
            reading.simulated
                ? 'Démonstration : valeurs simulées, non lues sur la photo.'
                : 'Informations proposées par l’IA : vérifiez-les.',
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: RemboSpace.lg),
        ] else if (widget.readerMissing) ...[
          const InfoStrip(
            'Lecture automatique indisponible : saisissez les informations '
            'du justificatif.',
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
            label: Text(hasReceipt ? 'Remplacer' : 'Ajouter un justificatif'),
            onPressed: _pickReceipt,
          ),
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('form-supplier'),
          label: 'Fournisseur',
          required: true,
          hint: 'Nom du fournisseur',
          icon: Icons.storefront_outlined,
          controller: _supplier,
          errorText: _errors['supplier'],
          suffix: _readBadge('supplier'),
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _proposed.remove('supplier')),
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('form-amount'),
          label: 'Montant TTC (MAD)',
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
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('form-date'),
          label: 'Date',
          required: true,
          hint: 'JJ/MM/AAAA',
          icon: Icons.calendar_today_outlined,
          controller: _date,
          errorText: _errors['date'],
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _proposed.remove('date')),
          suffix: IconButton(
            tooltip: 'Choisir dans le calendrier',
            icon: const Icon(Icons.expand_more_rounded),
            onPressed: _pickDate,
          ),
        ),
        const SizedBox(height: RemboSpace.lg),
        Text.rich(
          const TextSpan(
            text: 'Catégorie',
            children: [
              TextSpan(
                text: ' *',
                style: TextStyle(color: RemboColors.danger),
              ),
            ],
          ),
          style: RemboText.subtitle.copyWith(fontSize: 15),
        ),
        const SizedBox(height: RemboSpace.sm),
        DropdownButtonFormField<String>(
          key: const ValueKey('form-category'),
          initialValue: _category,
          isExpanded: true,
          hint: const Text('Choisir'),
          decoration: InputDecoration(
            prefixIcon: Icon(
              categoryIcon(_category ?? ''),
              color: RemboColors.night,
            ),
            errorText: _errors['category'],
          ),
          items: [
            for (final c in expenseCategories)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (c) => setState(() {
            _category = c;
            _errors.remove('category');
          }),
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('form-project'),
          label: 'Client ou projet',
          hint: 'Facultatif',
          icon: Icons.work_outline_rounded,
          controller: _project,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: RemboSpace.lg),
        RemboTextField(
          fieldKey: const ValueKey('form-reason'),
          label: 'Motif',
          required: true,
          hint: 'Précisez le contexte de la dépense',
          icon: Icons.notes_rounded,
          controller: _reason,
          errorText: _errors['reason'],
          maxLines: 3,
          maxLength: 200,
        ),
        if (_correcting && existing!.events.isNotEmpty) ...[
          const SectionTitle('Historique de décision'),
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
                          '${ev.status.label} · ${ev.actorName}',
                          style: RemboText.subtitle.copyWith(fontSize: 15),
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
              child: const Text('Abandonner'),
            ),
          ),
      ],
    );
  }
}
