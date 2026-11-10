import 'package:flutter/material.dart';

import '../theme/rembo_tokens.dart';

/// The REMBO mark (indigo tile) followed by the wordmark.
class RemboLogo extends StatelessWidget {
  const RemboLogo({super.key, this.size = 40, this.showWordmark = true});
  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'REMBO',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [RemboColors.indigo, RemboColors.night],
              ),
              borderRadius: BorderRadius.circular(size * 0.3),
              boxShadow: RemboElevation.card,
            ),
            child: Text(
              'r',
              style: RemboText.display.copyWith(
                color: Colors.white,
                fontSize: size * 0.6,
                height: 1,
              ),
            ),
          ),
          if (showWordmark) ...[
            SizedBox(width: size * 0.3),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'rembo'),
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: RemboColors.indigo),
                      ),
                    ],
                  ),
                  style: RemboText.display.copyWith(fontSize: size * 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
