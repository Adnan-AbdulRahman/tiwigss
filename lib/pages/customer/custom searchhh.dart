import 'package:flutter/material.dart';
import 'package:tiwigsstrand/pages/customer/search%20page.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';

class CustomerSearchBar extends StatefulWidget {
  const CustomerSearchBar({super.key});

  @override
  State<CustomerSearchBar> createState() => _CustomerSearchBarState();
}

class _CustomerSearchBarState extends State<CustomerSearchBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => SearchPage(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: GestureDetector(
          onTap: () => _openSearch(context),
          child: Hero(
            tag: 'search_bar',
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(TwTheme.radiusMd),
                  color: TwTheme.cardBg,
                  border: Border.all(
                      color: TwTheme.primary.withOpacity(0.2),
                      width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color: TwTheme.textLow, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Search wigs, styles, services…',
                      style: TwTheme.body
                          .copyWith(color: TwTheme.textLow),
                    ),
                    const Spacer(),
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: TwTheme.primaryGradient,
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}