import 'package:flutter/material.dart';

/// Tiwigsstrand brand tokens — updated palette
/// Primary  : Deep Plum       #49243F
/// Accent   : Champagne/Gold  #D6B77A
/// Light    : Ivory           #F7F2E8
class TwTheme {
  TwTheme._();

  // ── Core palette ──────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF49243F); // Deep Plum
  static const Color primaryDark  = Color(0xFF2E1228); // Darker plum
  static const Color primaryLight = Color(0xFF6B3560); // Lighter plum
  static const Color accent       = Color(0xFFD6B77A); // Champagne/Rose Gold
  static const Color accentLight  = Color(0xFFEDD9A3); // Light champagne
  static const Color ivory        = Color(0xFFF7F2E8); // Ivory
  static const Color ivoryDark    = Color(0xFFEDE5D0); // Darker ivory

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color darkBg   = Color(0xFF1A0A16); // Very dark plum bg
  static const Color cardBg   = Color(0xFF2E1228); // Card background
  static const Color surface  = Color(0xFF3D1A35); // Surface / input bg

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textHigh = Color(0xFFF7F2E8); // Ivory — primary text
  static const Color textMid  = Color(0xFFD6B77A); // Champagne — secondary
  static const Color textLow  = Color(0xFF8A6070); // Muted plum-rose
  static const Color divider  = Color(0xFF3D1A35);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success  = Color(0xFF4CAF7D);
  static const Color warning  = Color(0xFFE8A838);
  static const Color error    = Color(0xFFE05C72);
  static const Color info     = Color(0xFF5A90C9);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentLight, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ivoryGradient = LinearGradient(
    colors: [ivory, ivoryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient bgGradient = RadialGradient(
    center: Alignment(0, -0.4),
    radius: 1.5,
    colors: [Color(0xFF3D1A35), Color(0xFF0D0510)],
  );

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: primary.withOpacity(0.45),
      blurRadius: 24,
      spreadRadius: 4,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> accentGlow = [
    BoxShadow(
      color: accent.withOpacity(0.35),
      blurRadius: 18,
      spreadRadius: 2,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.45),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ── Border radius ─────────────────────────────────────────────────────────
  static const double radiusSm = 10.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;

  // ── Text styles ───────────────────────────────────────────────────────────
  static const TextStyle displayLg = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: textHigh,
    letterSpacing: 0.5,
    height: 1.2,
  );

  static const TextStyle displayMd = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: textHigh,
    letterSpacing: 0.3,
  );

  static const TextStyle titleSm = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: textHigh,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textMid,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textLow,
    letterSpacing: 0.8,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: accent,
    letterSpacing: 1.0,
  );
}

/// Wig service categories
class TwService {
  final String title;
  final String emoji;
  final String subtitle;
  final Color  tint;
  const TwService({
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.tint,
  });
}

const List<TwService> kServices = [
  TwService(
    title   : 'Wig Making',
    emoji   : '🪡',
    subtitle: 'Custom from scratch',
    tint    : Color(0xFF49243F),
  ),
  TwService(
    title   : 'Revamping',
    emoji   : '✨',
    subtitle: 'Restore & refresh',
    tint    : Color(0xFF6B3560),
  ),
  TwService(
    title   : 'Styling',
    emoji   : '💇‍♀️',
    subtitle: 'Professional finish',
    tint    : Color(0xFFD6B77A),
  ),
  TwService(
    title   : 'Factory Wigs',
    emoji   : '🏭',
    subtitle: 'Ready to wear',
    tint    : Color(0xFF3A5A8B),
  ),
];