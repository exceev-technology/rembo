import 'package:flutter/material.dart';

import '../motion/rembo_motion.dart';
import '../theme/rembo_tokens.dart';
import 'rembo_illustration.dart';
import 'rembo_logo.dart';

/// Lavender backdrop of every screen: a soft gradient and two pale shapes.
class RemboBackground extends StatelessWidget {
  const RemboBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF1EEFF), Color(0xFFFAF9FF), Color(0xFFF3F0FF)],
      ),
    ),
    child: CustomPaint(painter: const _ShapesPainter(), child: child),
  );
}

class _ShapesPainter extends CustomPainter {
  const _ShapesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1F7A63F0);
    canvas.drawCircle(
      Offset(size.width * 1.05, -size.width * 0.15),
      size.width * 0.62,
      paint,
    );
    canvas.drawCircle(
      Offset(-size.width * 0.12, size.height + size.width * 0.05),
      size.width * 0.42,
      paint..color = const Color(0x147A63F0),
    );
  }

  @override
  bool shouldRepaint(_ShapesPainter oldDelegate) => false;
}

/// Standard screen: logo header, scrolling content, optional pinned
/// actions above the keyboard. Tabs pass [embedded] to skip the scaffold.
class RemboPage extends StatelessWidget {
  const RemboPage({
    super.key,
    required this.children,
    this.bottom,
    this.trailing,
    this.showBack,
    this.logo = false,
    this.embedded = false,
    this.onRefresh,
    this.floatingActionButton,
  });
  final List<Widget> children;

  /// Pinned under the content, typically the primary button.
  final Widget? bottom;
  final Widget? trailing;

  /// Defaults to « there is a screen to go back to ».
  final bool? showBack;

  /// The REMBO logo, kept for the entry pages and each role's home.
  final bool logo;
  final bool embedded;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;

  /// How many of the first elements arrive one after the other.
  static const _staggered = 7;

  @override
  Widget build(BuildContext context) {
    final back = showBack ?? Navigator.of(context).canPop();
    Widget list = ListView(
      padding: const EdgeInsets.fromLTRB(
        RemboSpace.xl - 4,
        RemboSpace.sm,
        RemboSpace.xl - 4,
        RemboSpace.xl,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final (i, child) in children.indexed)
          // What is below the fold is not delayed: it is not seen arriving.
          i < _staggered
              ? Entrance(key: ValueKey('arrive-$i'), order: i, child: child)
              : child,
      ],
    );
    if (onRefresh != null) {
      list = RefreshIndicator(onRefresh: onRefresh!, child: list);
    }
    final content = SafeArea(
      bottom: !embedded,
      child: Column(
        children: [
          _Header(back: back, logo: logo, trailing: trailing),
          Expanded(child: list),
          if (bottom != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RemboSpace.xl - 4,
                RemboSpace.sm,
                RemboSpace.xl - 4,
                RemboSpace.lg,
              ),
              child: bottom,
            ),
        ],
      ),
    );
    if (embedded) {
      if (floatingActionButton == null) return content;
      return Stack(
        children: [
          content,
          Positioned(
            right: RemboSpace.lg,
            bottom: RemboSpace.lg,
            child: floatingActionButton!,
          ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: RemboColors.background,
      floatingActionButton: floatingActionButton,
      body: RemboBackground(child: content),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.back, required this.logo, this.trailing});
  final bool back;
  final bool logo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: RemboSpace.sm),
    child: SizedBox(
      // Nothing to show: only a little air above the title.
      height: back || logo || trailing != null ? 56 : RemboSpace.md,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (logo)
            Align(
              alignment: back ? Alignment.center : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: RemboSpace.md),
                child: RemboLogo(size: back ? 26 : 24),
              ),
            ),
          if (back)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                key: const ValueKey('page-back'),
                tooltip: 'Retour',
                icon: const Icon(Icons.arrow_back_rounded),
                color: RemboColors.night,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    ),
  );
}

/// Receipt illustration with an optional round pictogram on its corner
/// (lock, key, check, warning…) so one asset serves every screen.
class HeroArt extends StatelessWidget {
  const HeroArt({
    super.key,
    this.height = 112,
    this.badge,
    this.badgeColor = RemboColors.indigo,
    this.art = RemboArt.receipt,
  });
  final double height;
  final IconData? badge;
  final Color badgeColor;
  final RemboArt art;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        RemboIllustration(height: height, art: art),
        if (badge != null)
          Positioned(
            right: height * 0.06,
            bottom: height * 0.08,
            child: Container(
              width: height * 0.36,
              height: height * 0.36,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: RemboElevation.card,
              ),
              child: Icon(badge, color: Colors.white, size: height * 0.2),
            ),
          ),
      ],
    ),
  );
}

/// Screen heading: big title and subtitle on the left, the receipt on the
/// right. The picture gives way on narrow screens or with enlarged text.
class RemboHero extends StatelessWidget {
  const RemboHero({
    super.key,
    required this.title,
    this.subtitle,
    this.overline,
    this.badge,
    this.badgeColor = RemboColors.indigo,
    this.below,
    this.art = true,
    this.illustration = RemboArt.receipt,
  });
  final String title;
  final String? subtitle;
  final String? overline;
  final IconData? badge;
  final Color badgeColor;

  /// Shown under the subtitle, e.g. a status badge.
  final Widget? below;
  final bool art;
  final RemboArt illustration;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final roomy = media.size.width >= 340 && media.textScaler.scale(10) <= 12.5;
    return Padding(
      padding: const EdgeInsets.only(top: RemboSpace.sm, bottom: RemboSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[
                  Text(overline!, style: RemboText.caption),
                  const SizedBox(height: RemboSpace.xs),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: RemboText.display.copyWith(fontSize: 26),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: RemboSpace.sm),
                  Text(subtitle!, style: RemboText.note.copyWith(fontSize: 14)),
                ],
                if (below != null) ...[
                  const SizedBox(height: RemboSpace.md),
                  below!,
                ],
              ],
            ),
          ),
          // A long word would be cut in two beside the picture.
          // The plain receipt said nothing about the page: only a picture
          // chosen for the page is shown.
          if (art &&
              illustration != RemboArt.receipt &&
              roomy &&
              !title.split(RegExp(r'\s+')).any((w) => w.length > 11)) ...[
            const SizedBox(width: RemboSpace.sm),
            HeroArt(
              height: 96,
              badge: badge,
              badgeColor: badgeColor,
              art: illustration,
            ),
          ],
        ],
      ),
    );
  }
}

/// Centered heading used by full-screen moments (errors, confirmations).
class RemboMoment extends StatelessWidget {
  const RemboMoment({
    super.key,
    required this.title,
    required this.message,
    this.badge,
    this.badgeColor = RemboColors.indigo,
    this.illustration = RemboArt.receipt,
  });
  final String title;
  final String message;
  final IconData? badge;
  final Color badgeColor;
  final RemboArt illustration;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: RemboSpace.sm),
      Entrance(
        rise: 0,
        scaleFrom: .78,
        curve: Curves.easeOutBack,
        child: HeroArt(
          height: illustration == RemboArt.receipt ? 150 : 180,
          badge: badge,
          badgeColor: badgeColor,
          art: illustration,
        ),
      ),
      const SizedBox(height: RemboSpace.xl),
      Entrance(
        order: 2,
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: RemboText.display,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      const SizedBox(height: RemboSpace.sm),
      Entrance(
        order: 3,
        child: Text(
          message,
          style: RemboText.note.copyWith(fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: RemboSpace.xl),
    ],
  );
}

/// White bordered surface used for every grouped block.
class RemboCard extends StatelessWidget {
  const RemboCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(RemboSpace.lg),
    this.color = RemboColors.card,
    this.borderColor = RemboColors.border,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RemboRadius.md),
      side: BorderSide(color: borderColor),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Rounded square holding a pictogram, at the start of rows.
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.size = 44,
    this.color = RemboColors.indigo,
    this.background = RemboColors.surface,
  });
  final IconData icon;
  final double size;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(RemboRadius.sm),
    ),
    child: Icon(icon, color: color, size: size * 0.5),
  );
}

/// One line of quiet information on a tinted strip.
class InfoStrip extends StatelessWidget {
  const InfoStrip(
    this.text, {
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.color = RemboColors.infoText,
    this.background = RemboColors.surface,
  });
  final String text;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: RemboSpace.md,
      vertical: RemboSpace.sm + 2,
    ),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(RemboRadius.md),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: RemboSpace.sm),
        Expanded(
          child: Text(text, style: RemboText.note.copyWith(color: color)),
        ),
      ],
    ),
  );
}

/// Section heading with an optional link on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: RemboSpace.xl, bottom: RemboSpace.sm),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: RemboText.title),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

/// Row of a details card: pictogram, small label, value.
class DetailRow extends StatelessWidget {
  const DetailRow(
    this.icon,
    this.label,
    this.value, {
    super.key,
    this.mono = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: RemboSpace.sm),
    child: Row(
      children: [
        IconTile(icon, size: 40),
        const SizedBox(width: RemboSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: RemboText.caption),
              Text(
                value.isEmpty ? '—' : value,
                style: mono ? RemboText.amount : RemboText.subtitle,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Bottom sheet with the mockups' handle, title and close button.
Future<T?> showRemboSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: RemboColors.background,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        RemboSpace.xl - 4,
        0,
        RemboSpace.xl - 4,
        RemboSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: RemboText.title)),
                IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: RemboText.body.copyWith(color: RemboColors.muted),
              ),
            const SizedBox(height: RemboSpace.lg),
            builder(context),
          ],
        ),
      ),
    ),
  ),
);
