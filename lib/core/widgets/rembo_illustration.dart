import 'package:flutter/material.dart';

/// The floating 3D receipt. Decoration only: keep it to one per screen,
/// on welcome, empty or confirmation moments.
class RemboIllustration extends StatelessWidget {
  const RemboIllustration({super.key, this.height = 160});
  final double height;

  static const asset = 'assets/images/receipt_hero.webp';

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    height: height,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
