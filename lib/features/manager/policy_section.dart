import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// Pages read at most in a PDF: a policy rarely needs more.
const maxPolicyPages = 6;

/// How a policy document is picked. Tests replace it.
Future<PolicySource?> Function() policyPicker = pickPolicyWithDevice;

/// A PDF, a photo or a text file from the phone, ready for the reader.
Future<PolicySource?> pickPolicyWithDevice() async {
  final PlatformFile? file;
  try {
    file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'txt', 'md'],
    );
  } catch (_) {
    throw RemboException(
      tr('Impossible d’ouvrir vos fichiers sur cet appareil.'),
    );
  }
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > 10 * 1024 * 1024) {
    throw RemboException(tr('Le fichier dépasse 10 Mo.'));
  }
  final ext = file.name.toLowerCase().split('.').last;
  if (ext == 'txt' || ext == 'md') {
    return PolicySource.text(
      file.name,
      utf8.decode(bytes, allowMalformed: true),
    );
  }
  if (ext != 'pdf') return PolicySource.pages(file.name, [bytes]);
  try {
    final document = await PdfDocument.openData(bytes);
    try {
      final pages = <Uint8List>[];
      final count = document.pagesCount.clamp(1, maxPolicyPages);
      for (var i = 1; i <= count; i++) {
        final page = await document.getPage(i);
        final scale = 1400 / page.width;
        final image = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: PdfPageImageFormat.jpeg,
          quality: 80,
          backgroundColor: '#FFFFFF',
        );
        await page.close();
        if (image != null) pages.add(image.bytes);
      }
      if (pages.isEmpty) throw const FormatException();
      return PolicySource.pages(file.name, pages);
    } finally {
      await document.close();
    }
  } catch (_) {
    throw RemboException(
      tr('Ce PDF ne peut pas être lu. Essayez une photo ou collez le texte.'),
    );
  }
}

/// The company's own policy: imported, read by REMBO, applied by a manager
/// once checked. Without one, REMBO's rules apply.
class PolicyDocumentCard extends StatefulWidget {
  const PolicyDocumentCard({super.key});

  @override
  State<PolicyDocumentCard> createState() => _PolicyDocumentCardState();
}

class _PolicyDocumentCardState extends State<PolicyDocumentCard> {
  bool _reading = false;

  Future<void> _read(Future<PolicySource?> Function() pick) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    try {
      // No spinner while the person picks or types: only while reading.
      final source = await pick();
      if (source == null || !mounted) return;
      setState(() => _reading = true);
      final proposal = await state.readPolicy(source);
      if (!mounted) return;
      setState(() => _reading = false);
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => PolicyProposalScreen(proposal: proposal),
        ),
      );
    } on RemboException catch (e) {
      if (mounted) {
        showRemboSnackBar(context, e.message, tone: MessageTone.error);
      }
    } finally {
      if (mounted && _reading) setState(() => _reading = false);
    }
  }

  Future<PolicySource?> _paste() async {
    final typed = await showRemboSheet<String>(
      context,
      title: tr('Coller le texte de votre politique'),
      builder: (_) => const _PasteSheet(),
    );
    if (typed == null || typed.trim().isEmpty) return null;
    return PolicySource.text(tr('Texte collé'), typed);
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Revenir aux règles par défaut ?')),
        content: Text(
          tr(
            'Les plafonds, le délai et la règle du projet reprennent les '
            'valeurs de REMBO. Le document importé est oublié.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Annuler')),
          ),
          TextButton(
            key: const ValueKey('confirm-reset-policy'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Revenir aux règles par défaut')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AppScope.read(context).resetPolicy();
      if (mounted) {
        showRemboSnackBar(context, tr('Règles par défaut rétablies.'));
      }
    } on RemboException catch (e) {
      if (mounted) {
        showRemboSnackBar(context, e.message, tone: MessageTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = AppScope.of(context).companyPolicy.document;
    return RemboCard(
      key: const ValueKey('rules-policy'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(Icons.description_outlined, size: 40),
              const SizedBox(width: RemboSpace.md),
              Expanded(
                child: Text(
                  document == null
                      ? tr('Votre politique de remboursement')
                      : document.name,
                  style: RemboText.subtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: RemboSpace.sm),
          if (document == null)
            Text(
              tr(
                'REMBO applique ses règles par défaut. Importez la politique '
                'de votre entreprise : REMBO la lit et vous propose les '
                'règles à appliquer. Rien ne change sans votre accord.',
              ),
              style: RemboText.note,
            )
          else ...[
            if (document.appliedAt != null)
              Text(
                tr('Appliquée le {date} par {name}', {
                  'date': formatDate(document.appliedAt!),
                  'name': document.appliedBy,
                }),
                style: RemboText.caption,
              ),
            if (document.summary.isNotEmpty) ...[
              const SizedBox(height: RemboSpace.sm),
              Text(document.summary, style: RemboText.body),
            ],
            if (document.notApplied.isNotEmpty) ...[
              const SizedBox(height: RemboSpace.md),
              _NotApplied(document.notApplied),
            ],
          ],
          const SizedBox(height: RemboSpace.lg),
          RemboPrimaryButton(
            key: const ValueKey('rules-policy-import'),
            icon: Icons.upload_file_outlined,
            label: _reading
                ? tr('Lecture du document…')
                : document == null
                ? tr('Importer un document')
                : tr('Importer une nouvelle version'),
            loading: _reading,
            onPressed: () => _read(policyPicker),
          ),
          const SizedBox(height: RemboSpace.sm),
          RemboSecondaryButton(
            key: const ValueKey('rules-policy-paste'),
            icon: Icons.content_paste_rounded,
            label: tr('Coller le texte'),
            onPressed: _reading ? null : () => _read(_paste),
          ),
          if (document != null)
            Center(
              child: TextButton(
                key: const ValueKey('rules-policy-reset'),
                onPressed: _reading ? null : _reset,
                child: Text(tr('Revenir aux règles par défaut')),
              ),
            ),
        ],
      ),
    );
  }
}

/// The text of the policy, pasted; its controller lives as long as the
/// sheet, closing animation included.
class _PasteSheet extends StatefulWidget {
  const _PasteSheet();

  @override
  State<_PasteSheet> createState() => _PasteSheetState();
}

class _PasteSheetState extends State<_PasteSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      RemboTextField(
        fieldKey: const ValueKey('policy-text'),
        label: tr('Texte de la politique'),
        controller: _text,
        maxLines: 8,
      ),
      const SizedBox(height: RemboSpace.md),
      RemboPrimaryButton(
        key: const ValueKey('policy-text-read'),
        label: tr('Lire ce texte'),
        onPressed: () => Navigator.of(context).pop(_text.text),
      ),
    ],
  );
}

/// Rules read in the document that REMBO does not check by itself.
class _NotApplied extends StatelessWidget {
  const _NotApplied(this.rules);
  final List<String> rules;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(RemboSpace.md),
    decoration: BoxDecoration(
      color: RemboColors.warningTint,
      borderRadius: BorderRadius.circular(RemboRadius.sm),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('À vérifier par les responsables'),
          style: RemboText.label.copyWith(color: RemboColors.warningText),
        ),
        const SizedBox(height: RemboSpace.xs),
        for (final rule in rules)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('• $rule', style: RemboText.body),
          ),
        const SizedBox(height: RemboSpace.xs),
        Text(
          tr('REMBO ne contrôle pas ces règles automatiquement.'),
          style: RemboText.caption,
        ),
      ],
    ),
  );
}

/// The deadline and the project rule, changed by hand.
class CompanyRulesCard extends StatefulWidget {
  const CompanyRulesCard({super.key});

  @override
  State<CompanyRulesCard> createState() => _CompanyRulesCardState();
}

class _CompanyRulesCardState extends State<CompanyRulesCard> {
  final _days = TextEditingController();
  bool _project = false;
  CompanyPolicy? _shown;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reloaded rules (an applied document, a reset) replace what is shown.
    final policy = AppScope.of(context).companyPolicy;
    if (!identical(policy, _shown)) {
      _shown = policy;
      _days.text = '${policy.deadlineDays}';
      _project = policy.projectRequired;
      _error = null;
    }
  }

  Future<void> _save() async {
    final days = int.tryParse(_days.text.trim());
    if (days == null || days < 1 || days > 365) {
      setState(
        () => _error = tr('Saisissez un nombre de jours entre 1 et 365.'),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppScope.read(context)
          .saveCompanyRules(deadlineDays: days, projectRequired: _project);
      if (mounted) showRemboSnackBar(context, tr('Règles enregistrées.'));
    } on RemboException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = AppScope.of(context).companyPolicy;
    final changed =
        _days.text.trim() != '${policy.deadlineDays}' ||
        _project != policy.projectRequired;
    return RemboCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RemboTextField(
            fieldKey: const ValueKey('rules-deadline'),
            label: tr('Délai de déclaration (jours)'),
            helper: tr('Au-delà, la dépense est signalée au responsable.'),
            icon: Icons.event_outlined,
            controller: _days,
            errorText: _error,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            key: const ValueKey('rules-project'),
            contentPadding: EdgeInsets.zero,
            value: _project,
            onChanged: _saving ? null : (v) => setState(() => _project = v),
            title: Text(
              tr('Projet ou client obligatoire'),
              style: RemboText.body,
            ),
            subtitle: Text(
              tr('Sans projet ni client, la dépense est signalée.'),
              style: RemboText.caption,
            ),
          ),
          if (changed)
            RemboPrimaryButton(
              key: const ValueKey('rules-general-save'),
              label: tr('Enregistrer'),
              loading: _saving,
              onPressed: _save,
            ),
        ],
      ),
    );
  }
}

/// What the reader found in the document, beside the rules in place: the
/// manager applies it, or not.
class PolicyProposalScreen extends StatefulWidget {
  const PolicyProposalScreen({super.key, required this.proposal});
  final PolicyProposal proposal;

  @override
  State<PolicyProposalScreen> createState() => _PolicyProposalScreenState();
}

class _PolicyProposalScreenState extends State<PolicyProposalScreen> {
  bool _applying = false;

  Future<void> _apply() async {
    final navigator = Navigator.of(context);
    setState(() => _applying = true);
    try {
      await AppScope.read(context).applyPolicy(widget.proposal);
      if (!mounted) return;
      showRemboSnackBar(context, tr('Règles appliquées.'));
      navigator.pop();
    } on RemboException catch (e) {
      if (mounted) {
        showRemboSnackBar(context, e.message, tone: MessageTone.error);
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = widget.proposal;
    final now = state.companyPolicy;
    String yesNo(bool required) =>
        required ? tr('Obligatoire') : tr('Facultatif');
    String rule(PolicyRule? r) => r == null
        ? tr('Aucun plafond')
        : r.receiptRequired
        ? tr('{amount}, justificatif requis', {
            'amount': formatMad(r.limitCents),
          })
        : formatMad(r.limitCents);
    final changes = <(String, String, String)>[
      if (p.deadlineDays != null)
        (
          tr('Délai de déclaration'),
          tr('{n} jours', {'n': now.deadlineDays}),
          tr('{n} jours', {'n': p.deadlineDays}),
        ),
      if (p.projectRequired != null)
        (
          tr('Projet ou client'),
          yesNo(now.projectRequired),
          yesNo(p.projectRequired!),
        ),
      for (final r in p.rules)
        (tr(r.category), rule(state.policyOf(r.category)), rule(r)),
    ];
    return RemboPage(
      children: [
        RemboHero(
          title: tr('Règles proposées'),
          subtitle: tr('Lues dans « {name} ». Vérifiez avant d’appliquer.', {
            'name': p.documentName,
          }),
        ),
        if (p.summary.isNotEmpty) ...[
          Text(p.summary, style: RemboText.body),
          const SizedBox(height: RemboSpace.lg),
        ],
        if (changes.isNotEmpty)
          RemboCard(
            key: const ValueKey('policy-changes'),
            padding: const EdgeInsets.symmetric(horizontal: RemboSpace.lg),
            child: Column(
              children: [
                for (var i = 0; i < changes.length; i++)
                  _Change(
                    changes[i].$1,
                    before: changes[i].$2,
                    after: changes[i].$3,
                    last: i == changes.length - 1,
                  ),
              ],
            ),
          ),
        if (p.notApplied.isNotEmpty) ...[
          const SizedBox(height: RemboSpace.lg),
          _NotApplied(p.notApplied),
        ],
        const SizedBox(height: RemboSpace.xl),
        RemboPrimaryButton(
          key: const ValueKey('policy-apply'),
          label: tr('Appliquer ces règles'),
          loading: _applying,
          onPressed: _apply,
        ),
        const SizedBox(height: RemboSpace.sm),
        RemboSecondaryButton(
          key: const ValueKey('policy-cancel'),
          label: tr('Annuler'),
          onPressed: _applying ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _Change extends StatelessWidget {
  const _Change(
    this.label, {
    required this.before,
    required this.after,
    this.last = false,
  });
  final String label;
  final String before;
  final String after;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final same = before == after;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: RemboSpace.md),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: RemboColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: RemboText.subtitle),
          const SizedBox(height: 2),
          if (same)
            Text(
              tr('{value} (déjà en place)', {'value': after}),
              style: RemboText.caption,
            )
          else
            Wrap(
              spacing: RemboSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  before,
                  style: RemboText.caption.copyWith(
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: RemboColors.muted,
                ),
                Text(
                  after,
                  style: RemboText.body.copyWith(
                    color: RemboColors.night,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
