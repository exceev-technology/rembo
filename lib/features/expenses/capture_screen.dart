import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/ocr/receipt_reader.dart';
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
      reading = await readReceipt(
        picked.bytes,
        picked.name,
        onDevice: state.isDemo ? null : deviceReceiptReader,
        onServer: state.backend.readReceipt,
      );
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
        const RemboHero(title: 'Nouvelle dépense'),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: RemboSpace.xxl),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: RemboSpace.md),
                Text('Lecture du justificatif…'),
              ],
            ),
          )
        else ...[
          // Four ways in, each said in one line. The photo comes first.
          _Way(
            key: const ValueKey('capture-photo'),
            title: 'Prendre une photo',
            hint: 'Ticket entier, photo nette.',
            icon: Icons.photo_camera_outlined,
            primary: true,
            onTap: () => _pick(camera: true),
          ),
          _Way(
            key: const ValueKey('capture-import'),
            title: 'Importer une image',
            hint: 'Depuis la galerie ou vos fichiers.',
            icon: Icons.image_outlined,
            onTap: () => _pick(camera: false),
          ),
          _Way(
            key: const ValueKey('capture-whatsapp'),
            title: 'Envoyer par WhatsApp',
            hint: 'Un message vocal ou une photo suffit.',
            icon: Icons.chat_outlined,
            onTap: () => showWhatsAppSheet(context),
          ),
          _Way(
            key: const ValueKey('capture-manual'),
            title: 'Saisir sans photo',
            hint: 'Vous remplissez les champs vous-même.',
            icon: Icons.edit_note_rounded,
            onTap: () => ExpenseFormScreen.open(context),
          ),
          if (demo)
            Center(
              child: TextButton(
                key: const ValueKey('capture-unreadable'),
                onPressed: () => _pick(camera: true, unreadable: true),
                child: const Text('Démo : tester un reçu illisible'),
              ),
            ),
        ],
      ],
    );
  }
}

/// One way to declare an expense: what it is, and what it asks of you.
class _Way extends StatelessWidget {
  const _Way({
    super.key,
    required this.title,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });
  final String title;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  /// The recommended way: filled, with the camera picture.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final onColor = primary ? Colors.white : RemboColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: RemboSpace.md),
      child: Semantics(
        button: true,
        child: RemboCard(
          color: primary ? RemboColors.indigo : RemboColors.card,
          borderColor: primary ? RemboColors.indigo : RemboColors.border,
          padding: EdgeInsets.fromLTRB(
            RemboSpace.lg,
            primary ? RemboSpace.xl : RemboSpace.lg,
            RemboSpace.md,
            primary ? RemboSpace.xl : RemboSpace.lg,
          ),
          onTap: onTap,
          child: Row(
            children: [
              IconTile(
                icon,
                color: primary ? Colors.white : RemboColors.indigo,
                background: primary
                    ? const Color(0x33FFFFFF)
                    : RemboColors.surface,
              ),
              const SizedBox(width: RemboSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: (primary ? RemboText.title : RemboText.subtitle)
                          .copyWith(color: onColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: RemboText.note.copyWith(
                        color: primary
                            ? const Color(0xE6FFFFFF)
                            : RemboColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (primary)
                const ExcludeSemantics(
                  child: HeroArt(height: 76, art: RemboArt.camera),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: RemboColors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
