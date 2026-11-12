import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/widgets/rembo_widgets.dart';

/// Floating 3D welcome scene. Layers drift with the pointer (or a drag on a
/// phone) according to their depth, and bob on their own.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  /// Pointer position in the stage, from -0.5 to 0.5 on each axis.
  Offset _tilt = Offset.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _track(Offset local, Size size) => setState(() {
    _tilt = Offset(
      (local.dx / size.width - .5).clamp(-.5, .5),
      (local.dy / size.height - .5).clamp(-.5, .5),
    );
  });

  void _reset() => setState(() => _tilt = Offset.zero);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    final size = Size(
      math.min(media.size.width, 430),
      (media.size.height - 380).clamp(300, 520).toDouble(),
    );
    return Scaffold(
      backgroundColor: RemboColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: RemboLogo(size: 28),
                            ),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('welcome-skip'),
                          onPressed: () =>
                              Navigator.of(context).pushNamed(AppRoutes.login),
                          child: const Text('Passer'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox.fromSize(
                    size: size,
                    child: MouseRegion(
                      onHover: (e) => _track(e.localPosition, size),
                      onExit: (_) => _reset(),
                      child: GestureDetector(
                        onPanUpdate: (e) => _track(e.localPosition, size),
                        onPanEnd: (_) => _reset(),
                        // The scene is an illustration: its labels keep their
                        // drawn size whatever the system text scale.
                        child: MediaQuery.withNoTextScaling(
                          child: ClipRect(
                            child: AnimatedBuilder(
                              animation: _clock,
                              builder: (context, _) => _Stage(
                                size: size,
                                tilt: _tilt,
                                t: reduceMotion ? 0 : _clock.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const _Pitch(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.size, required this.tilt, required this.t});
  final Size size;
  final Offset tilt;

  /// Animation phase, 0 to 1.
  final double t;

  double _wave(double speed, double phase) =>
      math.sin((t * speed + phase) * 2 * math.pi);

  @override
  Widget build(BuildContext context) {
    final sway = _wave(1, 0) * .08;
    final scale = math.min(size.width / 390, size.height / 470).clamp(.6, 1.2);

    // A layer drifts against the pointer in proportion to its depth.
    Widget layer({
      required double left,
      required double top,
      required double depth,
      required Widget child,
      double bob = 0,
      double speed = 2,
      double phase = 0,
      double turn = 0,
    }) {
      final dx = -tilt.dx * depth * 60 + sway * depth * 40;
      final dy = -tilt.dy * depth * 40 + _wave(speed, phase) * bob;
      return Positioned(
        left: left,
        top: top,
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: turn + _wave(speed, phase) * .03,
            child: child,
          ),
        ),
      );
    }

    final stage = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0012)
        ..rotateX(tilt.dy * -.3)
        ..rotateY(tilt.dx * .4 + sway),
      child: SizedBox(
        width: 390,
        height: 470,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            layer(
              left: 70,
              top: 412,
              depth: 0,
              child: Opacity(
                opacity: .45 + _wave(2, 0) * .1,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 250,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0x592E2A7E),
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(125, 17),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            layer(left: 75, top: 40, depth: .3, child: const _ArchWindow()),
            layer(
              left: 300,
              top: 36,
              depth: .7,
              bob: 9,
              phase: .2,
              child: const _Sphere(
                size: 46,
                colors: [
                  Color(0xFFB3A9FF),
                  Color(0xFF6B57F0),
                  Color(0xFF2E2A7E),
                ],
              ),
            ),
            layer(
              left: 40,
              top: 378,
              depth: 1.2,
              bob: 7,
              phase: .6,
              child: const _Sphere(
                size: 26,
                colors: [
                  Color(0xFFF6C99A),
                  RemboColors.orange,
                  Color(0xFF8A4B0C),
                ],
              ),
            ),
            layer(
              left: 150,
              top: 18,
              depth: .5,
              bob: 6,
              phase: .4,
              child: const _Pill(),
            ),
            layer(
              left: 16,
              top: 160,
              depth: 1,
              bob: 12,
              turn: -.14,
              child: _Receipt(scan: (_wave(2.5, 0) + 1) / 2),
            ),
            layer(
              left: 192,
              top: 96,
              depth: 1.4,
              bob: 9,
              phase: .3,
              child: const _VatChip(),
            ),
            layer(
              left: 212,
              top: 326,
              depth: 1.7,
              bob: 8,
              phase: .7,
              child: const _ApprovedChip(),
            ),
          ],
        ),
      ),
    );

    return Center(
      child: Transform.scale(scale: scale.toDouble(), child: stage),
    );
  }
}

class _ArchWindow extends StatelessWidget {
  const _ArchWindow();

  @override
  Widget build(BuildContext context) => Container(
    width: 240,
    height: 350,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(120),
        bottom: Radius.circular(26),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x402E2A7E),
          blurRadius: 60,
          offset: Offset(0, 30),
        ),
      ],
    ),
    padding: const EdgeInsets.all(6),
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(114),
        bottom: Radius.circular(20),
      ),
      child: Image.asset(
        'assets/images/receipt-art.webp',
        fit: BoxFit.cover,
        alignment: const Alignment(0, -.1),
        semanticLabel:
            'Un reçu et une coche de validation flottent sous une arche',
      ),
    ),
  );
}

class _Sphere extends StatelessWidget {
  const _Sphere({required this.size, required this.colors});
  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-.36, -.44),
        colors: colors,
        stops: const [0, .5, 1],
      ),
      boxShadow: [
        BoxShadow(
          color: colors.last.withValues(alpha: .35),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: RemboColors.night,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x4D2E2A7E),
          blurRadius: 22,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: const Text(
      'Repas client · Atlas',
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.scan});

  /// Scan line position, 0 (top) to 1 (bottom).
  final double scan;

  static const _mono = TextStyle(
    fontFamily: RemboFonts.mono,
    fontFamilyFallback: RemboFonts.monoFallback,
    fontSize: 9,
    color: Color(0xFF50505F),
  );

  Widget _row(String label, String value, {TextStyle style = _mono}) => Row(
    children: [
      Expanded(
        child: Text(label, style: style, overflow: TextOverflow.clip),
      ),
      Text(value, style: style),
    ],
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Color(0x380E0E14),
          blurRadius: 26,
          offset: Offset(0, 22),
        ),
      ],
    ),
    child: ClipPath(
      clipper: _ZigzagClipper(),
      child: Container(
        width: 148,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 22),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'LE ZELLIGE · RABAT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: RemboFonts.mono,
                    fontFamilyFallback: RemboFonts.monoFallback,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: RemboColors.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Container(height: 1, color: const Color(0xFFC9C5BB)),
                const SizedBox(height: 7),
                _row('2 menus', '345,45'),
                const SizedBox(height: 7),
                _row('TVA 10%', '34,55'),
                const SizedBox(height: 7),
                _row(
                  'TOTAL',
                  '380,00',
                  style: const TextStyle(
                    fontFamily: RemboFonts.mono,
                    fontFamilyFallback: RemboFonts.monoFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: RemboColors.ink,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'ICE 001234567000089',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: RemboFonts.mono,
                    fontFamilyFallback: RemboFonts.monoFallback,
                    fontSize: 8,
                    color: Color(0xFF7A7A88),
                  ),
                ),
              ],
            ),
            Positioned(
              left: -14,
              right: -14,
              top: 4 + scan * 100,
              child: Container(
                height: 2,
                decoration: const BoxDecoration(
                  color: RemboColors.indigo,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x734A35E0),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ZigzagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const teeth = 10;
    const depth = 8.0;
    final step = size.width / teeth;
    final path = Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - depth);
    for (var i = teeth; i > 0; i--) {
      path
        ..lineTo((i - .5) * step, size.height)
        ..lineTo((i - 1) * step, size.height - depth);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_ZigzagClipper oldClipper) => false;
}

class _VatChip extends StatelessWidget {
  const _VatChip();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: RemboColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.document_scanner_outlined,
                size: 18,
                color: RemboColors.indigo,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TVA lue sur le reçu',
                  style: TextStyle(fontSize: 11, color: RemboColors.muted),
                ),
                Text(
                  '34,55 MAD',
                  style: TextStyle(
                    fontFamily: RemboFonts.mono,
                    fontFamilyFallback: RemboFonts.monoFallback,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ApprovedChip extends StatelessWidget {
  const _ApprovedChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [
        BoxShadow(
          color: Color(0x380F5A3C),
          blurRadius: 34,
          offset: Offset(0, 18),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: RemboColors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 8),
        const Text(
          'Approuvée',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F5A3C),
          ),
        ),
      ],
    ),
  );
}

class _Pitch extends StatelessWidget {
  const _Pitch();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOTES DE FRAIS · PENSÉ POUR LE MAROC',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: RemboColors.indigo,
          ),
        ),
        const SizedBox(height: 14),
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Le reçu entre.\nLa dépense sort '),
              TextSpan(
                text: 'prête.',
                style: TextStyle(color: RemboColors.indigo),
              ),
            ],
          ),
          key: ValueKey('destination-title'),
          style: TextStyle(
            fontSize: 36,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            color: RemboColors.ink,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Une photo suffit. REMBO lit le montant, la TVA et l’ICE, '
          'puis une personne décide.',
          style: TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF50505F)),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: double.infinity,
            minHeight: 56,
          ),
          child: FilledButton.icon(
            key: const ValueKey('welcome-start'),
            style: FilledButton.styleFrom(
              backgroundColor: RemboColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.login),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text(
              'Commencer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            key: const ValueKey('back-to-menu'),
            onPressed: () =>
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.menu, (_) => false),
            child: const Text('Revenir aux espaces'),
          ),
        ),
      ],
    ),
  );
}
