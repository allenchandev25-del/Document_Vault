import 'package:flutter/material.dart';

class MinimalAnimatedBackground extends StatelessWidget {
  const MinimalAnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamically adjust background gradient based on theme
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [
                    Color(0xFF18181B), // Deep Carbon Black
                    Color(0xFF27272A), // Space Grey / Matte Titanium
                  ]
                : const [
                    Color(0xFFF1F5F9), // Light Slate Silver
                    Color(0xFFE2E8F0), // Soft Slate
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}
