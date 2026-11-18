import 'package:flutter/material.dart';

import '../theme/rembo_tokens.dart';

/// Labelled text field. The label sits above the field so it stays readable
/// with large text, and [errorText] replaces [helper] when set.
class RemboTextField extends StatelessWidget {
  const RemboTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.fieldKey,
    this.maxLines = 1,
  });
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final Key? fieldKey;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: RemboText.caption.copyWith(color: RemboColors.ink)),
      const SizedBox(height: RemboSpace.sm),
      TextField(
        key: fieldKey,
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofillHints: autofillHints,
        maxLines: obscureText ? 1 : maxLines,
        style: RemboText.body,
        decoration: InputDecoration(
          hintText: hint,
          helperText: errorText == null ? helper : null,
          helperMaxLines: 3,
          errorText: errorText,
          errorMaxLines: 3,
          suffixIcon: suffix,
        ),
      ),
    ],
  );
}
