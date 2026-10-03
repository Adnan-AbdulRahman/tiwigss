import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tiwigsstrand/pages/customer/profile.dart';
import 'package:tiwigsstrand/pages/customer/promo_banner.dart';
import 'package:tiwigsstrand/pages/customer/search%20page.dart';
import 'package:tiwigsstrand/pages/customer/services_section.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';

import 'customer_header.dart';
import 'featured_wigs_section.dart';
import 'orders.dart';



// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOMER HOMEPAGE
//  Entry point for the customer experience.
//  File structure:
//    customer/
//      customer_homepage.dart          ← this file
//      theme/
//        tw_theme.dart                 ← brand tokens + service data
//      widgets/
//        customer_header.dart          ← greeting, avatar, notifications
//        promo_banner.dart             ← auto-scrolling promo carousel
//        services_section.dart         ← horizontal service cards
//        featured_wigs_section.dart    ← Firestore grid of featured wigs
// ─────────────────────────────────────────────────────────────────────────────
class CustomerHomepage extends StatefulWidget {
  const CustomerHomepage({super.key});

  @override
  State<CustomerHomepage> createState() => _CustomerHomepageState();
}

class _CustomerHomepageState extends State<CustomerHomepage>
    with TickerProviderStateMixin {
  int _currentNavIndex = 0;

  // Bottom-nav pages
  static const List<Widget> _pages = [
    _HomeTab(),
    MyOrdersTab(),
    FavouritesPage(),

    CustomerProfilePage()
  ];

  @override
  void initState() {
    super.initState();
    // Keep status bar icons light against the dark background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwTheme.darkBg,
      // Gradient background behind everything
      body: Container(
        decoration: const BoxDecoration(gradient: TwTheme.bgGradient),
        child: _pages[_currentNavIndex],
      ),
      bottomNavigationBar: _TwBottomNav(
        currentIndex: _currentNavIndex,
        onTap: (i) => setState(() => _currentNavIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HOME TAB CONTENT
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          const SliverToBoxAdapter(child: CustomerHeader()),



          // ── Promo banner ─────────────────────────────────────────────────
          const SliverToBoxAdapter(child: PromoBanner()),

          // ── Services ─────────────────────────────────────────────────────
          const SliverToBoxAdapter(child: ServicesSection()),

          // ── Featured wigs ─────────────────────────────────────────────────
          const SliverToBoxAdapter(child: FeaturedWigsSection()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
//  SEARCH BAR WIDGET
//  Drop-in replacement for the old _SearchBar in customer_homepage.dart.
//  Tapping anywhere on the bar navigates to SearchPage.
//  Make this a public class so it can be used inside customer_homepage.dart.
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
//  BOTTOM NAVIGATION BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TwBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _TwBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (icon: Icons.home_rounded,              label: 'Home'),
    (icon: Icons.shopping_bag_outlined,     label: 'Orders'),
    (icon: Icons.favorite_border_rounded,   label: 'Saved'),
    (icon: Icons.person_outline_rounded,    label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TwTheme.cardBg,
        border: Border(
          top: BorderSide(color: TwTheme.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
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
            children: List.generate(_items.length, (i) {
              final item    = _items[i];
              final active  = currentIndex == i;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: active
                        ? TwTheme.primary.withOpacity(0.15)
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          item.icon,
                          color: active ? TwTheme.accent : TwTheme.textLow,
                          size: active ? 24 : 22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active ? TwTheme.accent : TwTheme.textLow,
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

// ─────────────────────────────────────────────────────────────────────────────
//  ORDERS TAB
//  Standalone page widget — build out real order-history UI here.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
//  FAVOURITES TAB
//  Standalone page widget — build out real saved/favourites UI here.
// ─────────────────────────────────────────────────────────────────────────────
class FavouritesPage extends StatelessWidget {
  const FavouritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderContent(
      label: 'Favourites',
      emoji: '❤️',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROFILE TAB
//  Standalone page widget — build out real profile UI here.
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
//  SHARED PLACEHOLDER CONTENT
//  Same UI/logic as before — reused by OrdersPage, FavouritesPage and
//  ProfilePage so each can be extended independently later without
//  duplicating this scaffold.
// ─────────────────────────────────────────────────────────────────────────────
class _PlaceholderContent extends StatelessWidget {
  final String label;
  final String emoji;

  const _PlaceholderContent({required this.label, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TwTheme.primary.withOpacity(0.12),
                border:
                Border.all(color: TwTheme.primary.withOpacity(0.3)),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 16),
            Text(label, style: TwTheme.displayMd),
            const SizedBox(height: 8),
            Text(
              'This page is coming soon.',
              style: TwTheme.body,
            ),
            const SizedBox(height: 28),
            // Sign out shortcut (useful during dev)
            GestureDetector(
              onTap: () => FirebaseAuth.instance.signOut(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: TwTheme.primaryGradient,
                  boxShadow: TwTheme.primaryGlow,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Sign Out',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}