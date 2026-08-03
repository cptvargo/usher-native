import 'package:flutter/material.dart';

/// A soft radial-gradient circle used as a decorative background accent
/// (Landing hero, dashboard background, etc.).
class GlowBlob extends StatelessWidget {
  const GlowBlob({super.key, required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}
