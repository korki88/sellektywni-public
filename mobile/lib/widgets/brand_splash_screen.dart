import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'brand_logo.dart';

class BrandSplashScreen extends StatefulWidget {
  const BrandSplashScreen({super.key});

  @override
  State<BrandSplashScreen> createState() => _BrandSplashScreenState();
}

class _BrandSplashScreenState extends State<BrandSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DesignTokens.splashAnim,
  )..forward();

  late final Animation<double> _scale = Tween<double>(begin: 0.86, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<double> _fade = Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.white,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: const BrandLogo(markSize: 92),
          ),
        ),
      ),
    );
  }
}