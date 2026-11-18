import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/data/app_state.dart';
import '../../core/widgets/rembo_widgets.dart';

/// Picture of a receipt: bytes still on the phone, the demo copy, or a
/// short-lived signed link from the server.
class ReceiptImage extends StatelessWidget {
  const ReceiptImage({super.key, this.expense, this.bytes, this.fit});
  final Expense? expense;
  final Uint8List? bytes;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final local =
        bytes ??
        (expense == null ? null : state.backend.receiptBytes(expense!));
    if (local != null) {
      return Image.memory(
        local,
        fit: fit ?? BoxFit.cover,
        errorBuilder: (_, _, _) => const _Placeholder(),
      );
    }
    if (expense == null || !expense!.hasReceipt) return const _Placeholder();
    if (state.isDemo) {
      // Seeded demo expenses have no photo: show the illustration.
      return const Padding(
        padding: EdgeInsets.all(RemboSpace.sm),
        child: RemboIllustration(),
      );
    }
    Future<(Uint8List?, String?)> load() async {
      final saved = await state.backend.loadReceipt(expense!);
      if (saved != null) return (saved, null);
      return (null, await state.backend.receiptUrl(expense!));
    }

    return FutureBuilder<(Uint8List?, String?)>(
      future: load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final (saved, url) = snapshot.data ?? (null, null);
        if (saved != null) {
          return Image.memory(
            saved,
            fit: fit ?? BoxFit.cover,
            errorBuilder: (_, _, _) => const _Placeholder(),
          );
        }
        if (url == null) return const _Placeholder();
        return Image.network(
          url,
          fit: fit ?? BoxFit.cover,
          errorBuilder: (_, _, _) => const _Placeholder(),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: RemboColors.surface,
    child: Center(
      child: Icon(Icons.image_not_supported_outlined, color: RemboColors.muted),
    ),
  );
}

/// Thumbnail with an « Agrandir » action, or a note when there is none.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({super.key, this.expense, this.bytes, this.action});
  final Expense? expense;
  final Uint8List? bytes;

  /// Replaces « Agrandir », e.g. with « Remplacer ».
  final Widget? action;

  bool get _has => bytes != null || (expense?.hasReceipt ?? false);

  @override
  Widget build(BuildContext context) {
    if (!_has && action == null) {
      return const InfoStrip(
        'Aucun justificatif joint.',
        icon: Icons.receipt_long_outlined,
        color: RemboColors.neutralText,
        background: RemboColors.neutralTint,
      );
    }
    return RemboCard(
      padding: const EdgeInsets.all(RemboSpace.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(RemboRadius.sm),
            child: SizedBox(
              width: 96,
              height: 84,
              child: _has
                  ? ReceiptImage(expense: expense, bytes: bytes)
                  : const _Placeholder(),
            ),
          ),
          const SizedBox(width: RemboSpace.md),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  action ??
                  OutlinedButton.icon(
                    key: const ValueKey('receipt-zoom'),
                    icon: const Icon(Icons.open_in_full_rounded, size: 18),
                    label: const Text('Agrandir'),
                    onPressed: () =>
                        showReceipt(context, expense: expense, bytes: bytes),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showReceipt(
  BuildContext context, {
  Expense? expense,
  Uint8List? bytes,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(RemboSpace.lg),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: InteractiveViewer(
            maxScale: 5,
            child: ReceiptImage(
              expense: expense,
              bytes: bytes,
              fit: BoxFit.contain,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    ),
  ),
);
