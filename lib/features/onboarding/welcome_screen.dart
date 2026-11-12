import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../core/motion/rembo_motion.dart';
import '../../core/theme/rembo_tokens.dart';
import '../../core/widgets/language.dart';
import '../../core/widgets/rembo_logo.dart';
import '../../core/l10n/l10n.dart';

/// First screen of a person who is not signed in: what REMBO is for, then
/// « Commencer » (create an account) or « Se connecter ».
///
/// The drawing tells the product in three beats, the same as the pitch:
/// a receipt arrives (capture), a beam reads it line by line and the total
/// counts up (understand), a green stamp lands (validate). Then it floats,
/// and is read again from time to time. The receipt follows the finger.
/// Nothing moves when the phone asks for reduced motion.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  /// Plays once: arrival, reading, stamp, then the words.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  /// Then it floats, slowly, and is read again once per turn.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  /// Brings the receipt back after the finger let it go.
  late final AnimationController _release = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addListener(_springBack);

  /// How far the finger turned the receipt, in radians (y axis, x axis).
  final _tilt = ValueNotifier<Offset>(Offset.zero);
  Offset _releasedFrom = Offset.zero;
  bool _still = false;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.of(context).disableAnimations;
    if (_still) {
      _intro.value = 1;
      _loop
        ..stop()
        ..value = 0;
    } else {
      if (!_asked) {
        _asked = true;
        RemboMotion.whenVisible(() {
          if (mounted && !_still) _intro.forward();
        });
      }
      if (!_loop.isAnimating) _loop.repeat();
    }
  }

  void _springBack() {
    _tilt.value =
        _releasedFrom * (1 - Curves.elasticOut.transform(_release.value));
  }

  void _turn(DragUpdateDetails details) {
    if (_still) return;
    _release.stop();
    final next = _tilt.value + details.delta / 150;
    _tilt.value = Offset(next.dx.clamp(-.7, .7), next.dy.clamp(-.45, .45));
  }

  void _letGo([DragEndDetails? _]) {
    _releasedFrom = _tilt.value;
    _release.forward(from: 0);
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _release.dispose();
    _tilt.dispose();
    super.dispose();
  }

  Animation<double> _slice(double from, double to, [Curve? curve]) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(from, to, curve: curve ?? Curves.easeOutCubic),
      );

  /// Fades [child] in during one slice of the intro.
  Widget _fade(double from, double to, Widget child) =>
      FadeTransition(opacity: _slice(from, to, Curves.easeOut), child: child);

  /// A line of the headline rises from behind its own base line.
  Widget _line(double from, double to, Widget child) => ClipRect(
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 1.05),
        end: Offset.zero,
      ).animate(_slice(from, to, Curves.easeOutQuart)),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return Scaffold(
      backgroundColor: RemboColors.surface,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _BackgroundPainter()),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(constraints.maxWidth, 480.0);
                final narrow = width < 370;
                final heroHeight = (constraints.maxHeight * .42).clamp(
                  200.0,
                  420.0,
                );
                final headline = TextStyle(
                  fontFamily: RemboFonts.display,
                  fontFamilyFallback: RemboFonts.sansFallback,
                  fontSize: narrow ? 36 : 44,
                  height: 1.08,
                  letterSpacing: -1.6,
                  fontWeight: FontWeight.w900,
                  fontVariations: const [FontVariation('wght', 900)],
                  color: RemboColors.ink,
                );
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: width,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _fade(0, .25, const RemboLogo(size: 44)),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanUpdate: _turn,
                                onPanEnd: _letGo,
                                onPanCancel: _letGo,
                                child: SizedBox(
                                  height: heroHeight,
                                  width: double.infinity,
                                  child: ExcludeSemantics(
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        painter: _ReceiptPainter(
                                          intro: _intro,
                                          loop: _loop,
                                          tilt: _tilt,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    key: const ValueKey('welcome-title'),
                                    header: true,
                                    label: tr('Vos frais, l’esprit libre.'),
                                    child: ExcludeSemantics(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _line(
                                            .5,
                                            .76,
                                            Text(
                                              tr('Vos frais,'),
                                              style: headline,
                                            ),
                                          ),
                                          _line(
                                            .57,
                                            .83,
                                            Text(
                                              tr('l’esprit libre.'),
                                              style: headline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _fade(
                                    .7,
                                    .92,
                                    Text(
                                      tr(
                                        'Moins de paperasse.\nPlus de temps pour l’essentiel.',
                                      ),
                                      style: TextStyle(
                                        fontSize: 18,
                                        height: 1.4,
                                        color: Color(0xFF20202B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  _fade(
                                    .78,
                                    1,
                                    ScaleTransition(
                                      scale: Tween(begin: .94, end: 1.0)
                                          .animate(
                                            _slice(.78, 1, Curves.easeOutBack),
                                          ),
                                      child: _Actions(navigator: navigator),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Above the page, so that it can be reached at any time.
          const SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: LanguageButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.navigator});
  final NavigatorState navigator;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('welcome-start'),
          onPressed: () => navigator.pushNamed(AppRoutes.signup),
          style: FilledButton.styleFrom(
            backgroundColor: RemboColors.indigo,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 58),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: const StadiumBorder(),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                tr('Commencer'),
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              Icon(Icons.arrow_forward_rounded, size: 24),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            tr('Déjà un compte ?'),
            style: TextStyle(fontSize: 15, color: RemboColors.ink),
          ),
          TextButton(
            key: const ValueKey('welcome-login'),
            onPressed: () => navigator.pushNamed(AppRoutes.login),
            style: TextButton.styleFrom(
              foregroundColor: RemboColors.indigo,
              minimumSize: const Size(48, 48),
            ),
            child: Text(
              tr('Se connecter'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ],
  );
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F4FF), Color(0xFFEAE7FC), Color(0xFFF5F4FF)],
        ).createShader(rect),
    );
    final paint = Paint()..color = const Color(0x127B61E8);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .45,
        -size.height * .25,
        size.width * 1.4,
        size.height * .6,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * .9,
        size.height * .53,
        size.width * 1.5,
        size.height * .65,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) => false;
}

/// The receipt and what happens to it. Drawn in a 360 × 360 box, centred.
class _ReceiptPainter extends CustomPainter {
  _ReceiptPainter({required this.intro, required this.loop, required this.tilt})
    : super(repaint: Listenable.merge([intro, loop, tilt]));

  /// 0 → 1, once.
  final Animation<double> intro;

  /// 0 → 1, for ever.
  final Animation<double> loop;
  final ValueListenable<Offset> tilt;

  static const _ringTilt = -.32;
  static const _ring = Rect.fromLTWH(-166, -82, 332, 98);

  /// Demo total written on the receipt, in centimes.
  static const _total = 24000;

  /// The paper: top and bottom edges are torn in small waves.
  static final Path _paper = () {
    final p = Path()..moveTo(-96, -125);
    for (var i = 0; i < 8; i++) {
      final x = -96.0 + i * 24;
      p.quadraticBezierTo(x + 6, -134, x + 12, -125);
      p.quadraticBezierTo(x + 18, -116, x + 24, -125);
    }
    p.lineTo(96, 125);
    for (var i = 0; i < 8; i++) {
      final x = 96.0 - i * 24;
      p.quadraticBezierTo(x - 6, 134, x - 12, 125);
      p.quadraticBezierTo(x - 18, 116, x - 24, 125);
    }
    return p..close();
  }();

  /// Rows of the receipt: y, width of the label, width of the price.
  static const _rows = [
    (-38.0, 78.0, 30.0),
    (-12.0, 54.0, 24.0),
    (14.0, 92.0, 34.0),
  ];

  double _part(double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((intro.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 360, size.height / 360);
    final turn = loop.value;
    final phase = turn * math.pi * 2;
    final done = intro.value >= 1;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);

    final arrive = _part(0, .34);
    final settle = _part(0, .42, Curves.easeOutBack);
    final float = math.sin(phase) * 7;

    // Where the beam is: once in the intro, once per turn afterwards.
    final reading = done
        ? ((turn - .52) / .2).clamp(0.0, 1.0)
        : _part(.3, .6, Curves.easeInOut);
    final beamOn = reading > 0 && reading < 1;
    final beamY = -140 + 280 * reading;

    // Shadow on the ground: tightens when the receipt comes down.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 150),
        width: (170 + math.sin(phase) * 12) * arrive,
        height: 14,
      ),
      Paint()
        ..color = Color.fromRGBO(114, 90, 203, .18 * arrive)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    final spheres = _part(.18, .6, Curves.easeOutBack);
    _sphere(canvas, Offset(-142, -70 + math.sin(phase + 1) * 7), 11 * spheres);
    _sphere(canvas, Offset(128, 104 + math.sin(phase + 2) * 9), 22 * spheres);
    _sphere(canvas, Offset(138, -118 + math.cos(phase) * 6), 19 * spheres);

    // The ring goes round the receipt: its far half first.
    final ringDrawn = _part(.3, .8);
    final orbit = phase + math.pi * .25;
    final planetBehind = math.sin(orbit) < 0;
    _ringHalf(canvas, back: true, drawn: ringDrawn);
    if (planetBehind) _planet(canvas, orbit, ringDrawn);

    // The receipt itself, in perspective: it falls flat from above, sways
    // slowly, and follows the finger.
    final finger = tilt.value;
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, .0016)
      ..translateByDouble(0, float - (1 - settle) * 70, 0, 1)
      ..rotateX((1 - arrive) * 1.2 - finger.dy + math.cos(phase) * .05)
      ..rotateY(finger.dx + math.sin(phase) * .14)
      ..rotateZ(.14 * arrive + math.sin(phase) * .012);
    canvas.save();
    canvas.transform(matrix.storage);
    canvas.saveLayer(
      const Rect.fromLTWH(-190, -200, 380, 400),
      Paint()..color = Color.fromRGBO(0, 0, 0, _part(0, .16, Curves.easeOut)),
    );

    canvas.drawPath(
      _paper.shift(const Offset(5, 14)),
      Paint()
        ..color = const Color(0x40725ACB)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(
      _paper,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFBFAFF), Color(0xFFE4E0FB)],
        ).createShader(const Rect.fromLTWH(-100, -140, 200, 280)),
    );

    canvas.save();
    canvas.clipPath(_paper);

    // How much of the receipt has been read at height [y] (intro only),
    // and how close the beam is to it right now.
    double read(double y) =>
        done ? 1 : ((beamY - y) / 18).clamp(0.0, 1.0) * (reading > 0 ? 1 : 0);
    double lit(double y) =>
        beamOn ? (1 - (beamY - y).abs() / 30).clamp(0.0, 1.0) : 0;
    Color ink(double y, {double strength = 1}) => Color.lerp(
      const Color(0xFFB5A6F2),
      RemboColors.indigo,
      lit(y),
    )!.withValues(alpha: read(y) * strength);

    void bar(double x, double y, double w, double h, {double strength = 1}) {
      final shown = w * read(y);
      if (shown < h) return;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, shown, h),
          Radius.circular(h / 2),
        ),
        Paint()..color = ink(y, strength: strength),
      );
    }

    // Shop name and date.
    bar(-70, -98, 84, 11);
    bar(-70, -78, 48, 7, strength: .7);
    // Lines bought, with their prices on the right.
    for (final (y, label, price) in _rows) {
      bar(-70, y, label, 8);
      final r = read(y);
      if (r > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(70 - price, y, price, 8),
            const Radius.circular(4),
          ),
          Paint()..color = ink(y, strength: .8),
        );
      }
    }
    // Dashed rule above the total.
    final rule = Paint()
      ..color = const Color(0xFFCFC6F5).withValues(alpha: read(44))
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var x = -70.0; x < 70; x += 10) {
      canvas.drawLine(Offset(x, 44), Offset(x + 4, 44), rule);
    }
    // The total counts up while it is read.
    final counted = done ? 1.0 : _part(.5, .78);
    final cents = (_total * counted).round();
    final shown = read(64);
    if (shown > 0) {
      _text(
        canvas,
        tr('Total'),
        const Offset(-70, 62),
        size: 13,
        weight: 600,
        color: const Color(0xFF8676D6).withValues(alpha: shown),
      );
      _text(
        canvas,
        '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}',
        const Offset(70, 56),
        size: 24,
        weight: 800,
        alignRight: true,
        color: Color.lerp(
          RemboColors.night,
          RemboColors.indigo,
          lit(70),
        )!.withValues(alpha: shown),
      );
      _text(
        canvas,
        tr('MAD'),
        const Offset(70, 86),
        size: 10,
        weight: 600,
        alignRight: true,
        color: const Color(0xFF8676D6).withValues(alpha: shown),
      );
    }

    // The reading beam: a bright line and the light it leaves behind.
    if (beamOn) {
      final fade = math.sin(reading * math.pi).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(-100, beamY - 54, 200, 54),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0x004A35E0),
              Color.fromRGBO(74, 53, 224, .20 * fade),
            ],
          ).createShader(Rect.fromLTWH(-100, beamY - 54, 200, 54)),
      );
      canvas.drawRect(
        Rect.fromLTWH(-100, beamY - 1.5, 200, 3),
        Paint()..color = Color.fromRGBO(74, 53, 224, .9 * fade),
      );
      canvas.drawRect(
        Rect.fromLTWH(-100, beamY - 5, 200, 10),
        Paint()
          ..color = Color.fromRGBO(122, 99, 240, .45 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.restore(); // clip

    // The stamp lands last; afterwards it beats once each time the
    // receipt has been read again.
    const badge = Offset(74, -104);
    final landed = _part(.8, .96, Curves.easeOutBack);
    if (intro.value > .8) {
      final again = done ? ((turn - .72) / .22).clamp(0.0, 1.0) : 0.0;
      final ripple = done ? again : _part(.88, 1, Curves.easeOut);
      if (ripple > 0 && ripple < 1) {
        canvas.drawCircle(
          badge,
          30 + ripple * 26,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - ripple) + .5
            ..color = Color.fromRGBO(47, 176, 110, .5 * (1 - ripple)),
        );
      }
      final size = (1.7 - .7 * landed) * (1 + .09 * math.sin(again * math.pi));
      canvas.save();
      canvas.translate(badge.dx, badge.dy);
      canvas.scale(size);
      canvas.drawCircle(
        const Offset(1, 4),
        30,
        Paint()
          ..color = Color.fromRGBO(50, 133, 86, .35 * _part(.8, .9))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      final face = Rect.fromCircle(center: Offset.zero, radius: 30);
      canvas.drawCircle(
        Offset.zero,
        30,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.5, -.6),
            colors: [
              const Color(0xFFB1F4B9).withValues(alpha: _part(.8, .88)),
              const Color(0xFF3FBF73).withValues(alpha: _part(.8, .88)),
            ],
          ).createShader(face),
      );
      // The check mark is drawn, not shown at once.
      final drawn = _part(.86, 1, Curves.easeOut);
      final check = Path()
        ..moveTo(-14, 1)
        ..lineTo(-4, 11)
        ..lineTo(15, -9);
      final metric = check.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * drawn),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }
    canvas.restore(); // layer
    canvas.restore(); // perspective

    _ringHalf(canvas, back: false, drawn: ringDrawn);
    if (!planetBehind) _planet(canvas, orbit, ringDrawn);
    canvas.restore();
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required double size,
    required double weight,
    required Color color,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: RemboFonts.display,
          fontFamilyFallback: RemboFonts.sansFallback,
          fontSize: size,
          height: 1.1,
          letterSpacing: -.3,
          fontVariations: [FontVariation('wght', weight)],
          fontFeatures: const [FontFeature.tabularFigures()],
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, alignRight ? at - Offset(painter.width, 0) : at);
    painter.dispose();
  }

  void _ringHalf(Canvas canvas, {required bool back, required double drawn}) {
    if (drawn <= 0) return;
    canvas.save();
    canvas.rotate(_ringTilt);
    canvas.drawArc(
      _ring,
      back ? math.pi : 0,
      math.pi * drawn,
      false,
      Paint()
        ..color = Color.fromRGBO(196, 183, 250, back ? .32 : .62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = back ? 3.5 : 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  /// A small sphere travelling on the ring, larger when it is in front.
  void _planet(Canvas canvas, double angle, double shown) {
    if (shown <= 0) return;
    final depth = (math.sin(angle) + 1) / 2;
    canvas.save();
    canvas.rotate(_ringTilt);
    _sphere(
      canvas,
      Offset(
        _ring.center.dx + _ring.width / 2 * math.cos(angle),
        _ring.center.dy + _ring.height / 2 * math.sin(angle),
      ),
      (7 + depth * 5) * shown,
    );
    canvas.restore();
  }

  void _sphere(Canvas canvas, Offset center, double radius) {
    if (radius <= 0) return;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.5, -.6),
          colors: [Color(0xFFE5DCFF), Color(0xFFA28AE7)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_ReceiptPainter oldDelegate) => false;
}
