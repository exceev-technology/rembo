import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/widgets/rembo_widgets.dart';

/// A fictional receipt; blurred when the demo simulates an unreadable one.
class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({super.key, this.unreadable = false});
  final bool unreadable;

  @override
  Widget build(BuildContext context) {
    Widget line(String a, String b, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: RemboText.amount.copyWith(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            b,
            style: RemboText.amount.copyWith(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    final receipt = MediaQuery.withNoTextScaling(
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(RemboSpace.lg),
        decoration: BoxDecoration(
          color: RemboColors.card,
          borderRadius: BorderRadius.circular(RemboRadius.sm),
          boxShadow: RemboElevation.floating,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LE ZELLIGE · RABAT',
              style: RemboText.amount.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text('27/10/2026 · 13:42', style: RemboText.caption),
            const Divider(height: RemboSpace.xl),
            line('2 menus du jour', '345,45'),
            line('TVA 10 %', '34,55'),
            const Divider(height: RemboSpace.lg),
            line('TOTAL TTC MAD', '380,00', bold: true),
            const SizedBox(height: RemboSpace.sm),
            Text(
              'ICE 001234567000089',
              style: RemboText.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      label: unreadable
          ? 'Justificatif fictif flou'
          : 'Justificatif fictif : Le Zellige, 380 dirhams',
      child: ExcludeSemantics(
        child: Center(
          child: unreadable
              ? ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                  child: receipt,
                )
              : receipt,
        ),
      ),
    );
  }
}
