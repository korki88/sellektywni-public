import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

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
        // Gdy rodzic daje nieograniczoną wysokość (np. przejścia tras na webie),
        // samo minHeight: constraints.maxHeight → ∞ psuje Column+Expanded w dziecku.
        var h = constraints.maxHeight;
        if (!h.isFinite || h <= 0) {
          h = MediaQuery.sizeOf(context).height;
        }
        return ColoredBox(
          color: DesignTokens.subtleFill,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxContentWidth,
                minHeight: h,
                maxHeight: h,
              ),
              child: Material(
                color: DesignTokens.white,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
