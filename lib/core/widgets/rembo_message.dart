import 'package:flutter/material.dart';

import '../theme/rembo_tokens.dart';
import 'status_badge.dart';

enum MessageTone { info, success, warning, error }

/// Inline feedback block. Use [showRemboSnackBar] for transient messages.
class RemboMessage extends StatelessWidget {
  const RemboMessage({
    super.key,
    required this.tone,
    required this.title,
    this.message,
    this.action,
  });
  final MessageTone tone;
  final String title;
  final String? message;
  final Widget? action;

  static BadgeTone _badgeTone(MessageTone tone) => switch (tone) {
    MessageTone.info => BadgeTone.info,
    MessageTone.success => BadgeTone.success,
    MessageTone.warning => BadgeTone.warning,
    MessageTone.error => BadgeTone.danger,
  };

  static IconData iconOf(MessageTone tone) => switch (tone) {
    MessageTone.info => Icons.info_outline_rounded,
    MessageTone.success => Icons.check_circle_outline_rounded,
    MessageTone.warning => Icons.warning_amber_rounded,
    MessageTone.error => Icons.error_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final (text, tint) = RemboBadge.colors(_badgeTone(tone));
    return Semantics(
      liveRegion: tone == MessageTone.error,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(RemboSpace.lg),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(RemboRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(iconOf(tone), color: text),
            const SizedBox(width: RemboSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: RemboText.subtitle.copyWith(color: text)),
                  if (message != null) ...[
                    const SizedBox(height: RemboSpace.xs),
                    Text(message!, style: RemboText.body.copyWith(color: text)),
                  ],
                  if (action != null) ...[
                    const SizedBox(height: RemboSpace.sm),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showRemboSnackBar(
  BuildContext context,
  String text, {
  MessageTone tone = MessageTone.success,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(RemboMessage.iconOf(tone), color: Colors.white),
            const SizedBox(width: RemboSpace.md),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
}
