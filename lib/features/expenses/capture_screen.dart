import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/widgets/rembo_widgets.dart';
import 'expense_draft.dart';
import 'receipt_preview.dart';

/// Step 1: attach a receipt. No camera or file picker in V1: both buttons
/// attach the same fictional receipt.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _draft = ExpenseDraft();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _draft,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Nouvelle dépense')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(RemboSpace.xl),
          children: [
            const ExpenseStepLabel(1, 'Justificatif'),
            const SizedBox(height: RemboSpace.sm),
            const Text(
              'Capture du justificatif',
              key: ValueKey('destination-title'),
              style: RemboText.display,
            ),
            const SizedBox(height: RemboSpace.sm),
            const Text(
              'Photographiez le reçu à plat, en entier et bien éclairé.',
              style: RemboText.body,
            ),
            const SizedBox(height: RemboSpace.xl),
            if (!_draft.hasReceipt) ...[
              const Center(child: RemboIllustration(height: 140)),
              const SizedBox(height: RemboSpace.lg),
              _SourceButton(
                key: const ValueKey('capture-camera'),
                icon: Icons.photo_camera_outlined,
                title: 'Prendre une photo',
                subtitle: 'Simulation : aucune caméra n’est ouverte.',
                onTap: () => _draft.attach(ReceiptSource.camera),
              ),
              const SizedBox(height: RemboSpace.md),
              _SourceButton(
                key: const ValueKey('capture-import'),
                icon: Icons.upload_file_outlined,
                title: 'Importer un justificatif',
                subtitle: 'Image ou PDF — simulation.',
                onTap: () => _draft.attach(ReceiptSource.import),
              ),
              const SizedBox(height: RemboSpace.lg),
              Center(
                child: TextButton(
                  key: const ValueKey('capture-manual'),
                  onPressed: () {
                    _draft.startManual();
                    Navigator.of(context)
                        .pushNamed(AppRoutes.review, arguments: _draft);
                  },
                  child: const Text('Saisir manuellement'),
                ),
              ),
              Center(
                child: TextButton(
                  key: const ValueKey('capture-unreadable'),
                  onPressed: () =>
                      _draft.attach(ReceiptSource.camera, unreadable: true),
                  child: const Text('Tester avec un reçu illisible'),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: RemboSpace.xl),
                decoration: BoxDecoration(
                  color: RemboColors.surface,
                  borderRadius: BorderRadius.circular(RemboRadius.lg),
                ),
                child: ReceiptPreview(unreadable: _draft.unreadable),
              ),
              const SizedBox(height: RemboSpace.lg),
              if (_draft.unreadable)
                const RemboMessage(
                  tone: MessageTone.warning,
                  title: 'Le reçu semble flou',
                  message:
                      'Reprenez la photo pour une lecture automatique, ou '
                      'continuez et complétez les champs à la main.',
                )
              else
                const RemboMessage(
                  tone: MessageTone.success,
                  title: 'Justificatif prêt',
                  message: 'Les informations seront lues à l’étape suivante.',
                ),
              const SizedBox(height: RemboSpace.xl),
              RemboPrimaryButton(
                key: const ValueKey('capture-continue'),
                label: 'Continuer',
                icon: Icons.arrow_forward_rounded,
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamed(AppRoutes.review, arguments: _draft),
              ),
              const SizedBox(height: RemboSpace.md),
              RemboSecondaryButton(
                key: const ValueKey('capture-retake'),
                label: 'Reprendre',
                icon: Icons.refresh_rounded,
                onPressed: _draft.clearReceipt,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Step header shared by the capture, review and summary screens.
class ExpenseStepLabel extends StatelessWidget {
  const ExpenseStepLabel(this.number, this.label, {super.key});
  final int number;
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    'ÉTAPE $number SUR 3 · ${label.toUpperCase()}',
    style: RemboText.label.copyWith(color: RemboColors.indigo),
  );
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(RemboSpace.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(RemboSpace.md),
              decoration: BoxDecoration(
                color: RemboColors.surface,
                borderRadius: BorderRadius.circular(RemboRadius.md),
              ),
              child: Icon(icon, color: RemboColors.indigo),
            ),
            const SizedBox(width: RemboSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: RemboText.subtitle),
                  Text(subtitle, style: RemboText.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: RemboColors.muted),
          ],
        ),
      ),
    ),
  );
}
