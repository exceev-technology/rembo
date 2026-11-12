import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';
import '../whatsapp/whatsapp.dart';
import 'expense_form_screen.dart';
import 'receipt_picker.dart';
import 'unreadable_screen.dart';

/// « Nouvelle dépense » : photograph, import or type an expense.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  bool _busy = false;

  Future<void> _pick({required bool camera, bool unreadable = false}) async {
    if (_busy) return;
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    PickedReceipt? picked;
    try {
      picked = unreadable
          ? await sampleReceipt(unreadable: true)
          : await receiptPicker(camera: camera);
    } on RemboException catch (e) {
      if (!mounted) return;
      if (state.isDemo) {
        picked = await sampleReceipt();
        if (!mounted) return;
        showRemboSnackBar(
          context,
          'Démonstration : un reçu d’exemple est utilisé.',
          tone: MessageTone.info,
        );
      } else {
        showRemboSnackBar(context, e.message, tone: MessageTone.error);
        return;
      }
    }
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    ReceiptReading? reading;
    try {
      reading = await state.backend.readReceipt(picked.bytes, picked.name);
    } on RemboException {
      reading = null; // The form opens without proposals.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (reading?.unreadable ?? false) {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => UnreadableScreen(receipt: picked!),
        ),
      );
    } else {
      ExpenseFormScreen.open(
        context,
        receipt: picked,
        reading: reading,
        readerMissing: reading == null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).isDemo;
    return RemboPage(
      children: [
        Semantics(
          header: true,
          child: Text(
            'Nouvelle dépense',
            style: RemboText.display,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: RemboSpace.sm),
        Text(
          'Ajoutez un justificatif pour l’enregistrer et le faire valider.',
          style: RemboText.body.copyWith(color: RemboColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RemboSpace.xl),
        const Center(child: HeroArt(height: 220, art: RemboArt.camera)),
        const SizedBox(height: RemboSpace.xl),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: RemboSpace.xl),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: RemboSpace.md),
                Text('Lecture du justificatif…'),
              ],
            ),
          )
        else ...[
          RemboPrimaryButton(
            key: const ValueKey('capture-photo'),
            label: 'Prendre une photo',
            icon: Icons.photo_camera_outlined,
            onPressed: () => _pick(camera: true),
          ),
          const SizedBox(height: RemboSpace.md),
          RemboSecondaryButton(
            key: const ValueKey('capture-import'),
            label: 'Importer une image',
            icon: Icons.insert_drive_file_outlined,
            onPressed: () => _pick(camera: false),
          ),
          const SizedBox(height: RemboSpace.sm),
          Center(
            child: TextButton(
              key: const ValueKey('capture-manual'),
              onPressed: () => ExpenseFormScreen.open(context),
              child: const Text('Saisir manuellement'),
            ),
          ),
          Center(
            child: TextButton.icon(
              key: const ValueKey('capture-whatsapp'),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('Envoyer par WhatsApp ou note vocale'),
              onPressed: () => showWhatsAppSheet(context),
            ),
          ),
          if (demo)
            Center(
              child: TextButton(
                key: const ValueKey('capture-unreadable'),
                onPressed: () => _pick(camera: true, unreadable: true),
                child: const Text('Démo : tester un reçu illisible'),
              ),
            ),
          const SizedBox(height: RemboSpace.md),
          const Center(
            child: RemboBadge(
              label: 'Photo nette, ticket entier',
              tone: BadgeTone.info,
              icon: Icons.auto_awesome_outlined,
            ),
          ),
        ],
      ],
    );
  }
}
