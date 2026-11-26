import 'package:flutter/material.dart';

import 'app/rembo_app.dart';
import 'core/data/app_state.dart';
import 'core/data/backend_factory.dart';
import 'core/l10n/l10n.dart';
import 'core/motion/rembo_motion.dart';
import 'features/expenses/receipt_picker.dart';
import 'features/onboarding/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RemboBoot());
}

/// Draws at once, then prepares the app behind the logo: opening the
/// backend and restoring the session may take a few seconds on a phone.
class RemboBoot extends StatefulWidget {
  const RemboBoot({super.key, this.receiptPicker = pickWithDevice});

  /// How the screens obtain a receipt; a test on a phone hands over a
  /// picture instead.
  final ReceiptPicker receiptPicker;

  @override
  State<RemboBoot> createState() => _RemboBootState();
}

class _RemboBootState extends State<RemboBoot> {
  AppState? _state;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    RemboMotion.curtainUp.value = false;
    _prepare();
  }

  Future<void> _prepare() async {
    await loadLanguage();
    final state = AppState(await createBackend());
    await state.restore(wait: false);
    if (mounted) setState(() => _state = state);
  }

  void _open() {
    // Arrivals (welcome animation, first elements of the home) start now.
    RemboMotion.curtainUp.value = true;
    setState(() => _opened = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Built behind the opening as soon as it is ready, so that
          // nothing has to be prepared once the light has spread.
          if (state != null)
            RemboApp(state: state, receiptPicker: widget.receiptPicker)
          else
            const ColoredBox(color: SplashScreen.night),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchOutCurve: Curves.easeIn,
            child: _opened
                ? const SizedBox.shrink()
                : SplashScreen(ready: state != null, onDone: _open),
          ),
        ],
      ),
    );
  }
}
