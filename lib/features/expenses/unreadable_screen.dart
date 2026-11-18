import 'package:flutter/material.dart';

import '../../core/widgets/rembo_widgets.dart';
import 'expense_form_screen.dart';
import 'receipt_picker.dart';

/// « Photo difficile à lire » : retake the picture or type the values.
class UnreadableScreen extends StatelessWidget {
  const UnreadableScreen({super.key, required this.receipt});
  final PickedReceipt receipt;

  @override
  Widget build(BuildContext context) => RemboPage(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(RemboRadius.lg),
        child: SizedBox(
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                receipt.bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: RemboColors.surface),
              ),
              const ColoredBox(color: Color(0x662E2A7E)),
              const Center(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: RemboColors.warningTint,
                  child: Icon(
                    Icons.priority_high_rounded,
                    color: RemboColors.orange,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: RemboSpace.xl),
      Semantics(
        header: true,
        child: Text(tr('Photo difficile à lire'), style: RemboText.display),
      ),
      const SizedBox(height: RemboSpace.sm),
      Text(
        tr('Reprenez la photo ou saisissez les informations.'),
        style: RemboText.body.copyWith(color: RemboColors.muted),
      ),
      const SizedBox(height: RemboSpace.lg),
      _Tip(
        Icons.crop_free_rounded,
        tr('Ticket à plat'),
        tr('Placez le ticket bien à plat sur une surface stable.'),
      ),
      const SizedBox(height: RemboSpace.sm),
      _Tip(
        Icons.light_mode_outlined,
        tr('Évitez les reflets'),
        tr('Prenez la photo dans une lumière uniforme, sans flash.'),
      ),
      const SizedBox(height: RemboSpace.xl),
      RemboPrimaryButton(
        key: const ValueKey('unreadable-retake'),
        label: tr('Reprendre la photo'),
        icon: Icons.photo_camera_outlined,
        onPressed: () => Navigator.of(context).pop(),
      ),
      const SizedBox(height: RemboSpace.md),
      RemboSecondaryButton(
        key: const ValueKey('unreadable-manual'),
        label: tr('Saisir manuellement'),
        icon: Icons.edit_outlined,
        onPressed: () =>
            ExpenseFormScreen.open(context, receipt: receipt, replace: true),
      ),
    ],
  );
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => RemboCard(
    color: RemboColors.surface,
    borderColor: Colors.transparent,
    child: Row(
      children: [
        IconTile(icon, size: 52, background: Colors.white),
        const SizedBox(width: RemboSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: RemboText.subtitle),
              Text(text, style: RemboText.caption),
            ],
          ),
        ),
      ],
    ),
  );
}
