import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/rembo_logo.dart';

/// Opening of the app, shown from the very first frame while the session
/// is restored. On a deep indigo screen (the colour of the Android launch
/// window, so nothing flashes) the « r » lands in white and the name
/// unrolls beside it. When the app is [ready], a disc of light grows from
/// the logo until it fills the screen and the logo takes its colours:
/// the app is then shown on that same light background.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.ready, required this.onDone});

  /// The app behind is prepared: the opening may finish.
  final bool ready;

  /// Called once, when the screen is fully light.
  final VoidCallback onDone;

  static const night = Color(0xFF16133F);
  static const light = Color(0xFFF1EEFF);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..addStatusListener((_) => _maybeReveal());
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool _started = false;
  bool _finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _intro.value = 1;
    } else {
      // The very first frames of an app are slow to reach the screen:
      // starting at once would show the logo already half way through.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (mounted) _intro.forward();
      });
    }
    _maybeReveal();
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeReveal();
  }

  Future<void> _maybeReveal() async {
    if (_finished || !_intro.isCompleted) return;
    if (!widget.ready) {
      // Still preparing: the logo breathes instead of freezing.
      if (!_breath.isAnimating &&
          !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
        _breath.repeat(reverse: true);
      }
      return;
    }
    _finished = true;
    _breath.stop();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _reveal.value = 1;
    } else {
      // A short hold, so the complete logo is seen before the light.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await _reveal.forward();
    }
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    _reveal.dispose();
    super.dispose();
  }

  double _part(double from, double to, Curve curve) =>
      curve.transform(((_intro.value - from) / (to - from)).clamp(0.0, 1.0));

  /// The logo at its current step, white on the night or in its colours.
  Widget _logo({required bool white}) {
    final land = _part(0, .5, Curves.easeOutBack);
    final unroll = _part(.38, 1, Curves.easeOutCubic);
    const logo = SizedBox(
      width: 220,
      child: FittedBox(child: RemboLogo(size: 52)),
    );
    return Opacity(
      opacity:
          _part(0, .22, Curves.easeOut) *
          (1 - .3 * Curves.easeInOut.transform(_breath.value)),
      child: Transform.translate(
        // The mark starts centred, then makes room for the name.
        offset: Offset((1 - unroll) * 62, (1 - land) * 16),
        child: Transform.scale(
          scale: .5 + .5 * land,
          alignment: Alignment.centerLeft,
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: math.max(.245, unroll),
              child: white
                  ? const ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      child: logo,
                    )
                  : logo,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_intro, _breath, _reveal]),
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: SplashScreen.night,
          child: Center(child: _logo(white: true)),
        ),
        if (_reveal.value > 0)
          ClipPath(
            clipper: _Disc(Curves.easeInOutCubic.transform(_reveal.value)),
            child: ColoredBox(
              color: SplashScreen.light,
              child: Center(child: _logo(white: false)),
            ),
          ),
      ],
    ),
  );
}

/// A disc centred on the screen: 0 is a point, 1 covers the corners.
class _Disc extends CustomClipper<Path> {
  const _Disc(this.progress);
  final double progress;

  @override
  Path getClip(Size size) => Path()
    ..addOval(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: size.longestSide * .75 * progress,
      ),
    );

  @override
  bool shouldReclip(_Disc oldClipper) => oldClipper.progress != progress;
}
