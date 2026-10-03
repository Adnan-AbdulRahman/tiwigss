import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tiwigsstrand/pages/admin/receip.dart';
import 'package:tiwigsstrand/pages/admin/user_management_tab.dart';

import 'ad_theme.dart';
import 'add_service_tab.dart';
import 'admin_dashboard_tab.dart';
import 'bookings_tab.dart';



// ─────────────────────────────────────────────────────────────────────────────
//  ADMIN HOMEPAGE
//  File structure:
//    admin/
//      admin_homepage.dart           ← this file (entry point)
//      theme/
//        ad_theme.dart               ← brand tokens, shared widgets
//      tabs/
//        admin_dashboard_tab.dart    ← stats, orders today, low stock
//        add_service_tab.dart        ← add wig/service with dynamic fields
//        bookings_tab.dart           ← customer bookings management
//        user_management_tab.dart    ← view/search/edit all users
// ─────────────────────────────────────────────────────────────────────────────
class AdminHomepage extends StatefulWidget {
  const AdminHomepage({super.key});

  @override
  State<AdminHomepage> createState() => _AdminHomepageState();
}

class _AdminHomepageState extends State<AdminHomepage>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  late AnimationController _pageCtrl;
  late Animation<double>   _pageFade;

  static const _navItems = [
    (icon: Icons.dashboard_rounded,         label: 'Dashboard'),
    (icon: Icons.add_circle_outline_rounded, label: 'Add Service'),
    (icon: Icons.calendar_month_rounded,    label: 'Bookings'),
    (icon: Icons.people_alt_rounded,        label: 'Receipts'),
  ];

  static const _pages = [
    AdminDashboardTab(),
    AddServiceTab(),
    BookingsTab(),
    Receipts(),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _pageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeIn);
    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    if (_currentIndex == index) return;
    _pageCtrl.reset();
    setState(() => _currentIndex = index);
    _pageCtrl.forward();
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AdTheme.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdTheme.rLg)),
        title: const Row(
          children: [
            Text('🛡️', style: TextStyle(fontSize: 22)),
            SizedBox(width: 10),
            Text('Sign Out',
                style: TextStyle(
                    color: AdTheme.textHigh, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to sign out of the admin panel?',
            style: AdTheme.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AdTheme.textMid)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
            },
            child: const Text('Sign Out',
                style: TextStyle(
                    color: AdTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdTheme.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: AdTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top app bar ────────────────────────────────────────────────
              _buildTopBar(),

              // ── Page content ──────────────────────────────────────────────
              Expanded(
                child: FadeTransition(
                  opacity: _pageFade,
                  child: _pages[_currentIndex],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _AdminBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        items: _navItems,
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AdTheme.cardBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Crown icon
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AdTheme.primaryGradient,
              boxShadow: AdTheme.primaryGlow,
            ),
            child: const Center(child: Text('👑', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          // Brand + page title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(children: [
                    TextSpan(text: 'Tiwigs',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                            color: AdTheme.accent, letterSpacing: 0.5)),
                    TextSpan(text: 'strand Admin',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                            color: AdTheme.textHigh, letterSpacing: 0.5)),
                  ]),
                ),
                Text(_navItems[_currentIndex].label,
                    style: AdTheme.caption),
              ],
            ),
          ),
          // Sign out
          GestureDetector(
            onTap: _showSignOutDialog,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdTheme.cardBg,
                border: Border.all(color: AdTheme.error.withOpacity(0.3)),
              ),
              child: const Icon(Icons.logout_rounded, color: AdTheme.error, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ADMIN BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────
class _AdminBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<({IconData icon, String label})> items;

  const _AdminBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdTheme.cardBg,
        border: Border(top: BorderSide(color: AdTheme.cardBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item   = items[i];
              final active = currentIndex == i;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active
                        ? AdTheme.primary.withOpacity(0.15)
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon,
                          color: active ? AdTheme.accent : AdTheme.textLow,
                          size: active ? 24 : 22),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? AdTheme.accent : AdTheme.textLow,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
