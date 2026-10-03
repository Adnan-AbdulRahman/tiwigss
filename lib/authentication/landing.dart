import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:tiwigsstrand/pages/stylist/stylist.dart';

// ─── Replace these imports with your actual screen files ────────────────────
// import '../pages/customer/customer_home.dart';
// import '../pages/stylist/stylist_dashboard.dart';
// import '../pages/adminirebase admin_dashboard.dart';
import '../pages/admin/admin_homepage.dart';
import '../pages/customer/customer_homepage.dart';
import 'login and register.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LANDING PAGE — Firebase init + auth state + role routing
// ─────────────────────────────────────────────────────────────────────────────
class TiwigsstrandLandingPage extends StatelessWidget {
  TiwigsstrandLandingPage({super.key});

  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  // ── Brand colors (shared with login page) ─────────────────────────────────
  static const Color kDark    = Color(0xFF1C0A14);
  static const Color kPrimary = Color(0xFF8B1A4A);
  static const Color kAccent  = Color(0xFFD4A853);
  static const Color kText    = Color(0xFFF5E6EE);
  static const Color kSubText = Color(0xFFB08090);

  // ── Hardcoded admin email ─────────────────────────────────────────────────
  // NOTE: This file only checks the EMAIL of an already-authenticated user
  // (Firebase has already verified the password before this widget ever
  // runs, via authStateChanges()). To make "admin@gmail.com" log in with
  // the password "tiwigsstrand", set that as the account's actual password
  // in Firebase Authentication (Console → Authentication → Users → Add
  // user, or through your sign-up screen in "login and register.dart").
  // There is intentionally no password comparison in this file — hardcoding
  // a password in client-side code would be insecure and is not something
  // this routing widget is responsible for.
  static const String kAdminEmail = 'admin@gmail.com';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initialization,
      builder: (context, snapshot) {
        // Firebase failed to initialize
        if (snapshot.hasError) {
          return _ErrorScreen(
            message: 'Firebase failed to start.\n${snapshot.error}',
          );
        }

        // Firebase is ready — listen to auth state
        if (snapshot.connectionState == ConnectionState.done) {
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (authSnapshot.hasError) {
                return _ErrorScreen(
                  message: 'Auth error:\n${authSnapshot.error}',
                );
              }

              if (authSnapshot.connectionState == ConnectionState.active) {
                final User? user = authSnapshot.data;

                // ── Not logged in → show login page ───────────────────────
                if (user == null) {
                  return const TiwigsstrandLoginPage();
                }

                // ── Hardcoded admin shortcut ──────────────────────────────
                if (user.email == kAdminEmail) {
                  return AdminHomepage();
                }

                // ── Logged in → fetch Firestore role ──────────────────────
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get(),
                  builder: (context, userSnapshot) {
                    // Waiting for Firestore
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const _SplashScreen(
                        message: 'Getting your profile…',
                      );
                    }

                    // Firestore error or doc missing
                    if (userSnapshot.hasError ||
                        !userSnapshot.hasData ||
                        !userSnapshot.data!.exists) {
                      return _ErrorScreen(
                        message:
                        'We couldn\'t find your account data.\nPlease contact support.',
                        showLogout: true,
                      );
                    }

                    final data = userSnapshot.data!.data()
                    as Map<String, dynamic>?;
                    final String role =
                        (data?['role'] as String?) ?? 'Customer';

                    // ── Route by role ─────────────────────────────────────
                    switch (role) {
                      case 'Admin':
                        return AdminHomepage();
                      case 'Stylist':
                        return StylistHomepage();
                      case 'Customer':
                      default:
                        return CustomerHomepage();
                    }
                  },
                );
              }

              // Auth state not yet determined
              return const _SplashScreen(message: 'Checking authentication…');
            },
          );
        }

        // Firebase still initializing
        return const _SplashScreen(message: 'Starting Tiwigsstrand…');
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BRANDED SPLASH SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  final String message;
  const _SplashScreen({required this.message});

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TiwigsstrandLandingPage.kDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.4,
            colors: [Color(0xFF3D0A28), Color(0xFF0E0409)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing crown logo
              ScaleTransition(
                scale: _pulse,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [
                      Color(0xFF8B1A4A),
                      Color(0xFF4A0A28),
                      Colors.transparent,
                    ], stops: [
                      0.0,
                      0.55,
                      1.0
                    ]),
                    boxShadow: [
                      BoxShadow(
                        color: TiwigsstrandLandingPage.kPrimary
                            .withOpacity(0.55),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('👑', style: TextStyle(fontSize: 52)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Brand name
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Tiwigs',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD4A853),
                        letterSpacing: 1.5,
                      ),
                    ),
                    TextSpan(
                      text: 'strand',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF5E6EE),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Wig Making · Revamping · Styling',
                style: TextStyle(
                  fontSize: 11,
                  color: TiwigsstrandLandingPage.kSubText,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 36),
              // Loading indicator
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: TiwigsstrandLandingPage.kAccent,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.message,
                style: TextStyle(
                  color: TiwigsstrandLandingPage.kSubText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ERROR SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorScreen extends StatelessWidget {
  final String message;
  final bool showLogout;

  const _ErrorScreen({required this.message, this.showLogout = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TiwigsstrandLandingPage.kDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withOpacity(0.12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 44),
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TiwigsstrandLandingPage.kSubText,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              if (showLogout) ...[
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B1A4A), Color(0xFF5C0F30)],
                      ),
                    ),
                    child: const Text(
                      'Sign Out & Try Again',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PLACEHOLDER SCREENS
//  ✅ Replace each of these with your real screen widgets by:
//     1. Importing the real screen file at the top of this file
//     2. Replacing the placeholder widget in the switch/case above
// ─────────────────────────────────────────────────────────────────────────────




// ─────────────────────────────────────────────────────────────────────────────
//  SHARED PLACEHOLDER UI  (delete once you add real screens)
// ─────────────────────────────────────────────────────────────────────────────
class _RolePlaceholder extends StatelessWidget {
  final String role;
  final String emoji;
  final Color color;
  final String description;

  const _RolePlaceholder({
    required this.role,
    required this.emoji,
    required this.color,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TiwigsstrandLandingPage.kDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.5,
            colors: [Color(0xFF3D0A28), Color(0xFF0E0409)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Role badge
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(0.12),
                      border: Border.all(color: color.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 24,
                            spreadRadius: 4)
                      ],
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 52)),
                  ),
                  const SizedBox(height: 20),
                  // Brand
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Tiwigs',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFD4A853),
                          ),
                        ),
                        TextSpan(
                          text: 'strand',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF5E6EE),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: color.withOpacity(0.15),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Text(
                      '✅ Logged in as $role',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFF2A1020).withOpacity(0.9),
                      border: Border.all(
                          color: TiwigsstrandLandingPage.kPrimary
                              .withOpacity(0.2)),
                    ),
                    child: Text(
                      description,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: Color(0xFFB08090),
                        fontSize: 13,
                        height: 1.7,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Sign out button
                  GestureDetector(
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B1A4A), Color(0xFF5C0F30)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B1A4A).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}