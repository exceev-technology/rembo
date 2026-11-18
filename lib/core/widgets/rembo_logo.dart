import 'package:flutter/material.dart';

/// The REMBO logo from the pitch, for light backgrounds. [size] is the
/// height of the « r » mark; [showWordmark] false keeps only the mark.
class RemboLogo extends StatelessWidget {
  const RemboLogo({super.key, this.size = 40, this.showWordmark = true});
  final double size;
  final bool showWordmark;

  static const asset = 'assets/images/rembo_logo.png';

  /// Share of the image width taken by the « r » mark.
  static const _markWidth = 0.245;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      asset,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    return Semantics(
      label: 'REMBO',
      image: true,
      child: ExcludeSemantics(
        child: showWordmark
            ? logo
            : ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _markWidth,
                  child: logo,
                ),
              ),
      ),
    );
  }
}
