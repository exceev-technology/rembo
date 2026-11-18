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
    this.icon,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.maxLength,
    this.required = false,
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
  final IconData? icon;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final int? maxLength;

  /// Adds the red asterisk of mandatory fields.
  final bool required;

  /// Numbers, e-mail addresses and passwords read left to right even in
  /// Arabic: without this, « 06 12 34 » would show its groups reversed.
  bool get _latin =>
      obscureText ||
      keyboardType == TextInputType.phone ||
      keyboardType == TextInputType.number ||
      keyboardType == TextInputType.datetime ||
      keyboardType == TextInputType.emailAddress ||
      keyboardType == TextInputType.visiblePassword ||
      (keyboardType?.index == TextInputType.number.index);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          text: label,
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: RemboColors.danger),
              ),
          ],
        ),
        style: RemboText.subtitle.copyWith(fontSize: 13.5),
      ),
      const SizedBox(height: RemboSpace.sm),
      TextField(
        key: fieldKey,
        controller: controller,
        enabled: enabled,
        readOnly: readOnly,
        onTap: onTap,
        maxLength: maxLength,
        obscureText: obscureText,
        textDirection: _latin ? TextDirection.ltr : null,
        textAlign: _latin && Directionality.of(context) == TextDirection.rtl
            ? TextAlign.right
            : TextAlign.start,
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
          prefixIcon: icon == null
              ? null
              : Icon(
                  icon,
                  color: errorText == null
                      ? RemboColors.night
                      : RemboColors.danger,
                ),
          fillColor: errorText != null
              ? RemboColors.dangerTint
              : (enabled ? RemboColors.card : RemboColors.surface),
        ),
      ),
    ],
  );
}
