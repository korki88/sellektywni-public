import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Na webie: wąska, wyśrodkowana kolumna (jak statyczny podgląd HTML), zamiast
/// rozciągania na całą szerokość monitora.
class WebAppFrame extends StatelessWidget {
  const WebAppFrame({super.key, required this.child});

  final Widget child;

  static const double maxContentWidth = 1200;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ColoredBox(
          color: const Color(0xFFF0F0F0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxContentWidth,
                minHeight: constraints.maxHeight,
              ),
              child: Material(
                color: Colors.white,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
