import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ad_theme.dart';

/// User Management Tab
/// Reads from Firestore collection: 'users'
/// Allows admin to: view all users, search, change roles, disable accounts
class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  String _searchQuery  = '';
  String _filterRole   = 'All';

  static const List<String> _roles = ['All', 'Customer', 'Stylist', 'Admin'];

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeRole(String uid, String newRole) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'role': newRole});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Role updated to $newRole'),
        backgroundColor: AdTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _toggleDisable(String uid, bool currentlyDisabled) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'disabled': !currentlyDisabled});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(currentlyDisabled ? 'Account re-enabled' : 'Account disabled'),
        backgroundColor: currentlyDisabled ? AdTheme.success : AdTheme.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('User Management', style: AdTheme.headingLg),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text('View and manage all registered users.', style: AdTheme.body),
          ),

          // ── Search bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AdTheme.textHigh, fontSize: 14),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name or email…',
                hintStyle: const TextStyle(color: AdTheme.textLow, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AdTheme.textLow, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AdTheme.textLow, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AdTheme.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AdTheme.rMd),
                  borderSide: const BorderSide(color: AdTheme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AdTheme.rMd),
                  borderSide: const BorderSide(color: AdTheme.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AdTheme.rMd),
                  borderSide: const BorderSide(color: AdTheme.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ── Role filter pills ─────────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _roles.map((role) {
                final active = _filterRole == role;
                return GestureDetector(
                  onTap: () => setState(() => _filterRole = role),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: active ? AdTheme.primary : AdTheme.cardBg,
                      border: Border.all(
                          color: active ? AdTheme.primary : AdTheme.cardBorder),
                    ),
                    child: Text(role,
                        style: TextStyle(
                          color: active ? Colors.white : AdTheme.textMid,
                          fontSize: 12,
                          fontWeight: active ? FontWeight.bold : FontWeight.w500,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Users list ────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _UsersSkeleton();
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: AdTheme.error)),
                  );
                }

                var docs = snapshot.data?.docs ?? [];

                // Filter by role
                if (_filterRole != 'All') {
                  docs = docs
                      .where((d) => (d['role'] as String?) == _filterRole)
                      .toList();
                }

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final name  = (data['fullName'] as String? ?? '').toLowerCase();
                    final email = (data['email']    as String? ?? '').toLowerCase();
                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return _EmptyUsers(query: _searchQuery, role: _filterRole);
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d   = docs[i].data() as Map<String, dynamic>;
                    final uid = docs[i].id;
                    return _UserCard(
                      uid: uid,
                      data: d,
                      onChangeRole: _changeRole,
                      onToggleDisable: _toggleDisable,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── User card ─────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final Future<void> Function(String uid, String role) onChangeRole;
  final Future<void> Function(String uid, bool disabled) onToggleDisable;

  const _UserCard({
    required this.uid,
    required this.data,
    required this.onChangeRole,
    required this.onToggleDisable,
  });

  String get _name     => data['fullName']      as String? ?? 'Unknown';
  String get _email    => data['email']          as String? ?? '-';
  String get _phone    => data['phone']          as String? ?? '-';
  String get _role     => data['role']           as String? ?? 'Customer';
  String get _image    => data['profileImage']   as String? ?? '';
  bool   get _disabled => data['disabled']       as bool?   ?? false;
  bool   get _online   => data['isOnline']       as bool?   ?? false;

  String _formatDate(dynamic ts) {
    if (ts == null) return 'Unknown';
    final dt = (ts as Timestamp).toDate();
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color get _roleColor {
    switch (_role) {
      case 'Admin':    return AdTheme.accent;
      case 'Stylist':  return AdTheme.info;
      default:         return AdTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AdTheme.cardDecoration(
          borderColor: _disabled
              ? AdTheme.error.withOpacity(0.3)
              : AdTheme.cardBorder),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AdTheme.primary.withOpacity(0.15),
                      border: Border.all(color: AdTheme.primary.withOpacity(0.3)),
                    ),
                    child: ClipOval(
                      child: _image.isNotEmpty
                          ? Image.network(_image, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _initials())
                          : _initials(),
                    ),
                  ),
                  // Online dot
                  Positioned(
                    bottom: 1, right: 1,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _online ? AdTheme.success : AdTheme.textLow,
                        border: Border.all(color: AdTheme.cardBg, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Name + email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_name,
                              style: AdTheme.titleSm,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (_disabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AdTheme.error.withOpacity(0.12),
                            ),
                            child: const Text('Disabled',
                                style: TextStyle(
                                    color: AdTheme.error,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_email,
                        style: AdTheme.caption.copyWith(fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Joined ${_formatDate(data['createdAt'])}',
                        style: AdTheme.caption.copyWith(fontSize: 10)),
                  ],
                ),
              ),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _roleColor.withOpacity(0.12),
                  border: Border.all(color: _roleColor.withOpacity(0.4)),
                ),
                child: Text(_role,
                    style: TextStyle(
                        color: _roleColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Phone row
          Row(
            children: [
              const Icon(Icons.phone_outlined, color: AdTheme.textLow, size: 13),
              const SizedBox(width: 6),
              Text(_phone, style: AdTheme.caption.copyWith(fontSize: 11)),
            ],
          ),

          const SizedBox(height: 12),

          // Action row
          Row(
            children: [
              // Change role dropdown
              Expanded(
                child: _RoleDropdown(
                  currentRole: _role,
                  onChanged: (newRole) => onChangeRole(uid, newRole),
                ),
              ),
              const SizedBox(width: 10),
              // Disable / Enable button
              GestureDetector(
                onTap: () => onToggleDisable(uid, _disabled),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AdTheme.rSm),
                    color: _disabled
                        ? AdTheme.success.withOpacity(0.12)
                        : AdTheme.error.withOpacity(0.12),
                    border: Border.all(
                      color: _disabled
                          ? AdTheme.success.withOpacity(0.4)
                          : AdTheme.error.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    _disabled ? 'Enable' : 'Disable',
                    style: TextStyle(
                      color: _disabled ? AdTheme.success : AdTheme.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initials() {
    final parts = _name.trim().split(' ');
    final txt   = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : _name.isNotEmpty ? _name[0].toUpperCase() : '?';
    return Container(
      color: AdTheme.primary,
      child: Center(
        child: Text(txt,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}

// ── Role dropdown ─────────────────────────────────────────────────────────────
class _RoleDropdown extends StatelessWidget {
  final String currentRole;
  final void Function(String) onChanged;

  const _RoleDropdown({required this.currentRole, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdTheme.rSm),
        color: AdTheme.surface,
        border: Border.all(color: AdTheme.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentRole,
          dropdownColor: AdTheme.surface,
          style: const TextStyle(color: AdTheme.textHigh, fontSize: 12),
          icon: const Icon(Icons.arrow_drop_down, color: AdTheme.textLow, size: 18),
          isDense: true,
          items: ['Customer', 'Stylist', 'Admin']
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

// ── Empty & skeleton ──────────────────────────────────────────────────────────
class _EmptyUsers extends StatelessWidget {
  final String query;
  final String role;
  const _EmptyUsers({required this.query, required this.role});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👥', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              query.isNotEmpty ? 'No users match "$query"' : 'No $role users',
              style: AdTheme.headingMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text('Try a different search or filter.',
                style: AdTheme.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _UsersSkeleton extends StatefulWidget {
  const _UsersSkeleton();

  @override
  State<_UsersSkeleton> createState() => _UsersSkeletonState();
}

class _UsersSkeletonState extends State<_UsersSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.6)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdTheme.rMd),
            color: AdTheme.cardBg.withOpacity(_anim.value),
          ),
        ),
      ),
    );
  }
}
