import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.markSize = 64,
    this.showWordmark = true,
    this.textColor = DesignTokens.ink,
  });

  final double markSize;
  final bool showWordmark;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoMark(size: markSize),
        if (showWordmark) ...[
          const SizedBox(height: 14),
          Text(
            'Sellektywni',
            style: TextStyle(
              color: textColor,
              fontSize: markSize * 0.30,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = Paint()..color = DesignTokens.ink;
    final accent = Paint()..color = DesignTokens.accent;

    canvas.drawCircle(center, size.width * 0.48, base);

    final path = Path()
      ..moveTo(size.width * 0.70, size.height * 0.20)
      ..quadraticBezierTo(
        size.width * 0.40,
        size.height * 0.10,
        size.width * 0.35,
        size.height * 0.34,
      )
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.56,
        size.width * 0.55,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.77,
        size.height * 0.61,
        size.width * 0.64,
        size.height * 0.81,
      )
      ..quadraticBezierTo(
        size.width * 0.51,
        size.height * 0.95,
        size.width * 0.28,
        size.height * 0.83,
      );

    canvas.drawPath(
      path,
      accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.13
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(Offset(size.width * 0.70, size.height * 0.20), size.width * 0.05, accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}