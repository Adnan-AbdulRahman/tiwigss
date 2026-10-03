import 'package:flutter/material.dart';

/// Tiwigsstrand Admin brand tokens — updated palette
/// Primary  : Deep Plum       #49243F
/// Accent   : Champagne/Gold  #D6B77A
/// Light    : Ivory           #F7F2E8
class AdTheme {
  AdTheme._();

  // ── Core palette ──────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF49243F); // Deep Plum
  static const Color primaryDark  = Color(0xFF2E1228); // Darker plum
  static const Color primaryLight = Color(0xFF6B3560); // Lighter plum
  static const Color accent       = Color(0xFFD6B77A); // Champagne/Rose Gold
  static const Color accentLight  = Color(0xFFEDD9A3); // Light champagne
  static const Color ivory        = Color(0xFFF7F2E8); // Ivory

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color darkBg      = Color(0xFF1A0A16);
  static const Color surface     = Color(0xFF2E1228);
  static const Color cardBg      = Color(0xFF3D1A35);
  static const Color cardBorder  = Color(0xFF4A2040);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textHigh    = Color(0xFFF7F2E8); // Ivory
  static const Color textMid     = Color(0xFFD6B77A); // Champagne
  static const Color textLow     = Color(0xFF8A6070); // Muted

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success     = Color(0xFF4CAF7D);
  static const Color warning     = Color(0xFFE8A838);
  static const Color error       = Color(0xFFE05C72);
  static const Color info        = Color(0xFF5A90C9);

  // ── Stat card tints ───────────────────────────────────────────────────────
  static const Color statOrders   = Color(0xFF49243F);
  static const Color statRevenue  = Color(0xFFD6B77A);
  static const Color statBookings = Color(0xFF5A90C9);
  static const Color statUsers    = Color(0xFF4CAF7D);
  static const Color statLowStock = Color(0xFFE05C72);

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

  static const RadialGradient bgGradient = RadialGradient(
    center: Alignment(0, -0.5),
    radius: 1.6,
    colors: [Color(0xFF3D1A35), Color(0xFF080206)],
  );

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.45),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: primary.withOpacity(0.4),
      blurRadius: 20,
      spreadRadius: 2,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> accentGlow = [
    BoxShadow(
      color: accent.withOpacity(0.35),
      blurRadius: 16,
      spreadRadius: 1,
      offset: const Offset(0, 4),
    ),
  ];

  // ── Radii ─────────────────────────────────────────────────────────────────
  static const double rSm = 8.0;
  static const double rMd = 14.0;
  static const double rLg = 20.0;
  static const double rXl = 28.0;

  // ── Text styles ───────────────────────────────────────────────────────────
  static const TextStyle headingLg = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: textHigh,
    letterSpacing: 0.3,
  );

  static const TextStyle headingMd = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: textHigh,
  );

  static const TextStyle titleSm = TextStyle(
    fontSize: 14,
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
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: accent,
    letterSpacing: 1.1,
  );

  // ── Reusable card decoration ───────────────────────────────────────────────
  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
    borderRadius: BorderRadius.circular(rMd),
    color: cardBg,
    border: Border.all(
        color: borderColor ?? cardBorder, width: 1),
    boxShadow: cardShadow,
  );

  // ── Section header ─────────────────────────────────────────────────────────
  static Widget sectionHeader(String title,
      {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              gradient: primaryGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(title, style: headingMd),
          if (action != null) ...[
            const Spacer(),
            GestureDetector(
              onTap: onAction,
              child: Text(action, style: label),
            ),
          ],
        ],
      ),
    );
  }

  // ── Gradient button ────────────────────────────────────────────────────────
  static Widget gradientButton({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
    bool isLoading = false,
    LinearGradient? gradient,
  }) {
    return _GradientBtn(
      label: label,
      onTap: onTap,
      icon: icon,
      isLoading: isLoading,
      gradient: gradient ?? primaryGradient,
    );
  }
}

class _GradientBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isLoading;
  final LinearGradient gradient;

  const _GradientBtn({
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
    required this.gradient,
  });

  @override
  State<_GradientBtn> createState() => _GradientBtnState();
}

class _GradientBtnState extends State<_GradientBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); if (!widget.isLoading) widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdTheme.rMd),
            gradient: widget.gradient,
            boxShadow: AdTheme.primaryGlow,
          ),
          child: widget.isLoading
              ? const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}