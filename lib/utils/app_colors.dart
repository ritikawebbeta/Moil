// lib/utils/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Colors (MOIL Theme)
  static const Color primary = Color(0xFF232B8C); // Official MOIL Deep Blue
  static const Color primaryDark = Color(0xFF171C5C);
  static const Color primaryLight = Color(0xFFE8EAF6);
  static const Color accent = Color(0xFF3F51B5);
  static const Color accentLight = Color(0xFF7986CB);

  // Background
  static const Color background = Color(0xFFF5F7FB);
  static const Color backgroundSecondary = Color(0xFFFFFFFF);
  static const Color backgroundTertiary = Color(0xFFE8EDF5);

  // Card
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color cardHighlight = Color(0xFFF8FAFC);

  // Navigation
  static const Color navBar = Color(0xFFFFFFFF);

  // Input
  static const Color inputBg = Color(0xFFF8FAFC);
  static const Color inputBorder = Color(0xFFE2E8F0);

  // Text
  static const Color textPrimary = Color(0xFF0F172A); // Dark slate grey for primary text
  static const Color textSecondary = Color(0xFF475569); // Slate grey for subtitles
  static const Color textHint = Color(0xFF94A3B8); // Muted hint text
  static const Color textMuted = Color(0xFF64748B);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Leave Types
  static const Color earnedLeave = Color(0xFF232B8C);
  static const Color casualLeave = Color(0xFF10B981);
  static const Color hpl = Color(0xFFF59E0B);
  static const Color optionalHoliday = Color(0xFF8B5CF6);
  static const Color officialTour = Color(0xFF06B6D4);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF232B8C), Color(0xFF3F51B5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF5F7FB), Color(0xFFE8EDF5)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
