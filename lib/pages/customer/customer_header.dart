import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';


/// Animated header — greeting, user name, profile avatar from Firebase Storage
class CustomerHeader extends StatefulWidget {
  const CustomerHeader({super.key});

  @override
  State<CustomerHeader> createState() => _CustomerHeaderState();
}

class _CustomerHeaderState extends State<CustomerHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  String _name         = '';
  String _profileImage = '';
  bool   _loading      = true;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final data = doc.data();
      setState(() {
        _name         = (data?['fullName'] as String?) ?? 'Customer';
        _profileImage = (data?['profileImage'] as String?) ?? '';
        _loading      = false;
      });

      _ctrl.forward();
    } catch (_) {
      if (mounted) {
        setState(() {
          _name    = 'Customer';
          _loading = false;
        });
        _ctrl.forward();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName => _name.split(' ').first;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _HeaderSkeleton();

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Greeting + name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: TwTheme.caption.copyWith(
                        color: TwTheme.textMid,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: _firstName,
                            style: TwTheme.displayMd.copyWith(
                              color: TwTheme.accent,
                              fontSize: 22,
                            ),
                          ),
                          const TextSpan(
                            text: ' 👋',
                            style: TextStyle(fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'What style are you going for today? v2',
                      style: TwTheme.body.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Avatar + notification bell
              Row(
                children: [
                  // Notification bell
                  _IconBtn(
                    icon: Icons.notifications_outlined,
                    badge: true,
                    onTap: () {},
                  ),
                  const SizedBox(width: 10),
                  // Profile avatar
                  _ProfileAvatar(imageUrl: _profileImage, name: _name),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Icon button with optional badge ──────────────────────────────────────────
class _IconBtn extends StatefulWidget {
  final IconData icon;
  final bool badge;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounce;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _bounce.forward(),
      onTapUp: (_) {
        _bounce.reverse();
        widget.onTap();
      },
      onTapCancel: () => _bounce.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TwTheme.cardBg,
                border: Border.all(
                    color: TwTheme.primary.withOpacity(0.25), width: 1),
              ),
              child: Icon(widget.icon,
                  color: TwTheme.textMid, size: 20),
            ),
            if (widget.badge)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: TwTheme.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: TwTheme.darkBg, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Profile avatar with network image fallback ────────────────────────────────
class _ProfileAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;

  const _ProfileAvatar({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: imageUrl.isEmpty ? TwTheme.primaryGradient : null,
        boxShadow: [
          BoxShadow(
            color: TwTheme.primary.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Initials(name: name),
              )
            : _Initials(name: name),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String name;
  const _Initials({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0].toUpperCase()).take(2).join();

    return Container(
      color: TwTheme.primary,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────
class _HeaderSkeleton extends StatefulWidget {
  const _HeaderSkeleton();

  @override
  State<_HeaderSkeleton> createState() => _HeaderSkeletonState();
}

class _HeaderSkeletonState extends State<_HeaderSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(begin: 0.3, end: 0.7)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        final color =
            TwTheme.cardBg.withOpacity(_shimmer.value);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 80,  height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 6),
                    Container(width: 140, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 6),
                    Container(width: 180, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ],
          ),
        );
      },
    );
  }
}
