import 'package:flutter/material.dart';

class MinimalAnimatedBackground extends StatelessWidget {
  const MinimalAnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    // Pure, clean, minimalist Space Grey / Titanium Gradient Background
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF18181B), // Deep Carbon Black
              Color(0xFF27272A), // Space Grey / Matte Titanium
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}
