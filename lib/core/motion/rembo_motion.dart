import 'package:flutter/material.dart';

/// Motion of the app, in one place. Three rules:
/// - a screen never appears « dry »: it comes from where the person acted;
/// - one arrival per screen, short, then nothing moves on its own;
/// - when the phone asks for reduced motion, everything is shown at once.
abstract final class RemboMotion {
  static const quick = Duration(milliseconds: 180);
  static const page = Duration(milliseconds: 480);
  static const arrival = Duration(milliseconds: 600);

  /// Gap between two elements arriving one after the other.
  static const step = Duration(milliseconds: 95);

  static const enter = Curves.easeOutCubic;
  static const leave = Curves.easeInCubic;

  /// False while the opening still covers the app: arrivals wait for it,
  /// so that they are seen. True everywhere else (and in tests).
  static final curtainUp = ValueNotifier<bool>(true);

  /// Runs [start] now, or as soon as the opening is over.
  static void whenVisible(VoidCallback start) {
    if (curtainUp.value) return start();
    void once() {
      if (!curtainUp.value) return;
      curtainUp.removeListener(once);
      start();
    }

    curtainUp.addListener(once);
  }

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Screen changes: the new page slides in from the side it was called
/// from while it fades in; the page underneath steps back a little.
/// Going back plays the same movement in reverse.
class RemboPageTransitions extends PageTransitionsBuilder {
  const RemboPageTransitions();

  static final _fadeIn = CurveTween(
    curve: const Interval(0, .7, curve: Curves.easeOut),
  );
  static final _slideIn = Tween(
    begin: const Offset(.09, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: RemboMotion.enter));
  static final _stepBack = Tween(
    begin: Offset.zero,
    end: const Offset(-.05, 0),
  ).chain(CurveTween(curve: Curves.easeInOutCubic));
  static final _dim = Tween(
    begin: 1.0,
    end: .0,
  ).chain(CurveTween(curve: const Interval(0, .6, curve: Curves.easeIn)));

  @override
  Duration get transitionDuration => RemboMotion.page;

  @override
  Duration get reverseTransitionDuration => RemboMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (RemboMotion.reduced(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return SlideTransition(
      position: secondaryAnimation.drive(_stepBack),
      child: FadeTransition(
        opacity: secondaryAnimation.drive(_dim),
        child: SlideTransition(
          position: animation.drive(_slideIn),
          child: FadeTransition(
            opacity: animation.drive(_fadeIn),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Plays once when [child] is first shown: it fades in while rising (or
/// growing, with [scaleFrom]). [order] delays it so that a few elements
/// arrive one after the other.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.order = 0,
    this.rise = 14,
    this.scaleFrom,
    this.curve = RemboMotion.enter,
  });
  final Widget child;
  final int order;

  /// Distance travelled upwards, in logical pixels.
  final double rise;
  final double? scaleFrom;
  final Curve curve;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RemboMotion.arrival + RemboMotion.step * widget.order,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (RemboMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      RemboMotion.whenVisible(() {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _controller.duration!.inMilliseconds;
    final start = (RemboMotion.step.inMilliseconds * widget.order) / total;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: widget.curve),
    );
    final fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = curved.value;
        Widget result = Transform.translate(
          offset: Offset(0, widget.rise * (1 - t)),
          child: child,
        );
        final from = widget.scaleFrom;
        if (from != null) {
          result = Transform.scale(scale: from + (1 - from) * t, child: result);
        }
        return Opacity(opacity: fade.value.clamp(0.0, 1.0), child: result);
      },
    );
  }
}

/// A number that counts up to [value] when it first appears.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.delay = Duration.zero,
  });
  final int value;
  final String Function(int) format;
  final TextStyle? style;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (RemboMotion.reduced(context)) return Text(format(value), style: style);
    const run = Duration(milliseconds: 700);
    final total = delay + run;
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, _) => Text(
        format((value * t).round()),
        style: style,
        // Read once, with the final amount.
        semanticsLabel: format(value),
      ),
    );
  }
}
