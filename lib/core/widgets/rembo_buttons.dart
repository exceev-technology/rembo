import 'package:flutter/material.dart';

import '../theme/rembo_tokens.dart';

/// Main call to action. Shows a spinner and ignores taps while [loading].
class RemboPrimaryButton extends StatelessWidget {
  const RemboPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          )
        : _ButtonLabel(label: label, icon: icon);
    return _Expand(
      expand: expand,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: loading
            ? FilledButton.styleFrom(
                disabledBackgroundColor: RemboColors.indigo,
              )
            : null,
        child: Semantics(label: loading ? 'Chargement' : null, child: child),
      ),
    );
  }
}

/// Secondary action, outlined, never competing with the primary one.
class RemboSecondaryButton extends StatelessWidget {
  const RemboSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) => _Expand(
    expand: expand,
    child: OutlinedButton(
      onPressed: onPressed,
      child: _ButtonLabel(label: label, icon: icon),
    ),
  );
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 10)],
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ],
  );
}

class _Expand extends StatelessWidget {
  const _Expand({required this.expand, required this.child});
  final bool expand;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      expand ? SizedBox(width: double.infinity, child: child) : child;
}
