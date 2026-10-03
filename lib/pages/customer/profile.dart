import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOMER PROFILE PAGE
//  Features:
//   • Loads user data from Firestore (name, email, phone, profileImage, role)
//   • Edit name & phone inline — saves to Firestore
//   • Change profile photo — uploads to Firebase Storage (web + mobile)
//   • Change password via Firebase Auth email reset
//   • Booking stats pulled live from 'bookings' collection
//   • Sign out with confirmation dialog
// ─────────────────────────────────────────────────────────────────────────────
class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  // ── User data ──────────────────────────────────────────────────────────────
  String _fullName     = '';
  String _email        = '';
  String _phone        = '';
  String _profileImage = '';
  String _role         = 'Customer';
  bool   _isOnline     = false;
  bool   _loading      = true;

  // ── Edit mode ──────────────────────────────────────────────────────────────
  bool   _editMode    = false;
  bool   _savingEdit  = false;
  late TextEditingController _nameEditCtrl;
  late TextEditingController _phoneEditCtrl;

  // ── Image upload ───────────────────────────────────────────────────────────
  bool        _uploadingImage = false;
  File?       _imageFile;       // mobile
  Uint8List?  _imageBytes;      // web

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _nameEditCtrl  = TextEditingController();
    _phoneEditCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameEditCtrl.dispose();
    _phoneEditCtrl.dispose();
    super.dispose();
  }

  // ── Load user data from Firestore ──────────────────────────────────────────
  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;
      final data = doc.data() ?? {};

      setState(() {
        _fullName     = data['fullName']     as String? ?? '';
        _email        = data['email']        as String? ?? user.email ?? '';
        _phone        = data['phone']        as String? ?? '';
        _profileImage = data['profileImage'] as String? ?? '';
        _role         = data['role']         as String? ?? 'Customer';
        _isOnline     = data['isOnline']     as bool?   ?? false;
        _loading      = false;
        _nameEditCtrl.text  = _fullName;
        _phoneEditCtrl.text = _phone;
      });

      _fadeCtrl.forward();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Save profile edits ─────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    final name  = _nameEditCtrl.text.trim();
    final phone = _phoneEditCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Name cannot be empty.');
      return;
    }

    setState(() => _savingEdit = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fullName': name,
        'phone'   : phone,
      });

      if (!mounted) return;
      setState(() {
        _fullName = name;
        _phone    = phone;
        _editMode = false;
      });
      _showSnack('Profile updated!', isSuccess: true);
    } catch (_) {
      if (mounted) _showSnack('Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => _savingEdit = false);
    }
  }

  // ── Pick & upload profile image ────────────────────────────────────────────
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid.jpg');

      UploadTask task;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => _imageBytes = bytes);
        task = ref.putData(bytes,
            SettableMetadata(contentType: 'image/jpeg'));
      } else {
        final file = File(picked.path);
        setState(() => _imageFile = file);
        task = ref.putFile(file);
      }

      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'profileImage': url});

      if (!mounted) return;
      setState(() => _profileImage = url);
      _showSnack('Photo updated!', isSuccess: true);
    } catch (_) {
      if (mounted) _showSnack('Failed to upload photo.');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  // ── Send password reset email ──────────────────────────────────────────────
  Future<void> _sendPasswordReset() async {
    try {
      final email = FirebaseAuth.instance.currentUser?.email ?? _email;
      if (email.isEmpty) return;
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        _showSnack('Password reset email sent to $email', isSuccess: true);
      }
    } catch (_) {
      if (mounted) _showSnack('Could not send reset email. Try again.');
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TwTheme.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(
                color: TwTheme.textHigh, fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to sign out of Tiwigsstrand?',
            style: TextStyle(color: TwTheme.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: TwTheme.textMid)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
            },
            child: Text('Sign Out',
                style: TextStyle(
                    color: TwTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
            isSuccess
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: Colors.white,
            size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: isSuccess ? TwTheme.success : TwTheme.error,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return const _ProfileSkeleton();

    return FadeTransition(
      opacity: _fade,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ── Hero header ──────────────────────────────────────────────
              _ProfileHero(
                fullName:       _fullName,
                email:          _email,
                profileImage:   _profileImage,
                imageFile:      _imageFile,
                imageBytes:     _imageBytes,
                isOnline:       _isOnline,
                uploadingImage: _uploadingImage,
                onPickImage:    _pickAndUploadImage,
              ),

              const SizedBox(height: 20),

              // ── Booking stats ────────────────────────────────────────────
              _BookingStats(uid: FirebaseAuth.instance.currentUser?.uid ?? ''),

              const SizedBox(height: 20),

              // ── Info card (editable) ─────────────────────────────────────
              _InfoCard(
                fullName:      _fullName,
                email:         _email,
                phone:         _phone,
                role:          _role,
                editMode:      _editMode,
                savingEdit:    _savingEdit,
                nameCtrl:      _nameEditCtrl,
                phoneCtrl:     _phoneEditCtrl,
                onEdit:        () => setState(() => _editMode = true),
                onCancel:      () {
                  setState(() {
                    _editMode           = false;
                    _nameEditCtrl.text  = _fullName;
                    _phoneEditCtrl.text = _phone;
                  });
                },
                onSave: _saveProfile,
              ),

              const SizedBox(height: 16),

              // ── Settings tiles ───────────────────────────────────────────
              _SettingsTiles(
                onChangePassword: _sendPasswordReset,
                onSignOut:        _confirmSignOut,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROFILE HERO
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileHero extends StatelessWidget {
  final String    fullName, email, profileImage;
  final File?     imageFile;
  final Uint8List? imageBytes;
  final bool      isOnline, uploadingImage;
  final VoidCallback onPickImage;

  const _ProfileHero({
    required this.fullName,
    required this.email,
    required this.profileImage,
    required this.imageFile,
    required this.imageBytes,
    required this.isOnline,
    required this.uploadingImage,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            TwTheme.primary.withOpacity(0.9),
            TwTheme.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(TwTheme.radiusXl)),
        boxShadow: [
          BoxShadow(
            color: TwTheme.primary.withOpacity(0.45),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Page title row ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MY PROFILE',
                  style: TwTheme.label.copyWith(
                      color: Colors.white60, fontSize: 10)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? TwTheme.success
                            : Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(isOnline ? 'Online' : 'Offline',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Avatar ────────────────────────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow ring
              Container(
                width: 104, height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: TwTheme.accent.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: TwTheme.accent.withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              // Avatar image
              ClipOval(
                child: SizedBox(
                  width: 96, height: 96,
                  child: _buildAvatarImage(),
                ),
              ),
              // Upload loading overlay
              if (uploadingImage)
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.55),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    ),
                  ),
                ),
              // Camera button
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: uploadingImage ? null : onPickImage,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TwTheme.accent,
                      border: Border.all(
                          color: TwTheme.primaryDark, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Name ──────────────────────────────────────────────────────
          Text(
            fullName.isEmpty ? 'Your Name' : fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(email,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65), fontSize: 13)),

          const SizedBox(height: 12),

          // ── Role badge ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: TwTheme.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TwTheme.accent.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👑', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text('Tiwigsstrand Customer',
                    style: TextStyle(
                      color: TwTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    // Prefer local preview while uploading
    if (kIsWeb && imageBytes != null) {
      return Image.memory(imageBytes!, fit: BoxFit.cover);
    }
    if (!kIsWeb && imageFile != null) {
      return Image.file(imageFile!, fit: BoxFit.cover);
    }
    if (profileImage.isNotEmpty) {
      return Image.network(profileImage, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsWidget());
    }
    return _initialsWidget();
  }

  Widget _initialsWidget() {
    final parts = fullName.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : fullName.isNotEmpty
        ? fullName[0].toUpperCase()
        : '?';
    return Container(
      color: TwTheme.primaryDark,
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 32)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOOKING STATS ROW
// ─────────────────────────────────────────────────────────────────────────────
class _BookingStats extends StatelessWidget {
  final String uid;
  const _BookingStats({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        final total     = docs.length;
        final pending   = docs.where((d) => d['status'] == 'pending').length;
        final completed = docs.where((d) => d['status'] == 'completed').length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _StatChip(
                  label: 'Total\nBookings',
                  value: '$total',
                  color: TwTheme.primary),
              const SizedBox(width: 10),
              _StatChip(
                  label: 'Pending',
                  value: '$pending',
                  color: TwTheme.error),
              const SizedBox(width: 10),
              _StatChip(
                  label: 'Completed',
                  value: '$completed',
                  color: TwTheme.success),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color  color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TwTheme.radiusMd),
          color: TwTheme.cardBg,
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TwTheme.caption.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INFO CARD (editable)
// ─────────────────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String fullName, email, phone, role;
  final bool   editMode, savingEdit;
  final TextEditingController nameCtrl, phoneCtrl;
  final VoidCallback onEdit, onCancel, onSave;

  const _InfoCard({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.editMode,
    required this.savingEdit,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TwTheme.radiusMd),
          color: TwTheme.cardBg,
          border: Border.all(color: TwTheme.divider),
        ),
        child: Column(
          children: [
            // ── Card header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 3, height: 16,
                    decoration: BoxDecoration(
                      gradient: TwTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Personal Details',
                      style: TwTheme.titleSm),
                  const Spacer(),
                  if (!editMode)
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: TwTheme.primary.withOpacity(0.1),
                          border: Border.all(
                              color: TwTheme.primary.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded,
                                color: TwTheme.primary, size: 13),
                            SizedBox(width: 5),
                            Text('Edit',
                                style: TextStyle(
                                    color: TwTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Container(height: 1, color: TwTheme.divider),

            // ── Fields ─────────────────────────────────────────────────────
            if (!editMode) ...[
              _InfoRow(
                icon: Icons.person_outline_rounded,
                label: 'Full Name',
                value: fullName.isEmpty ? 'Not set' : fullName,
              ),
              _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: email,
              ),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: phone.isEmpty ? 'Not set' : phone,
                isLast: true,
              ),
            ] else ...[
              // Edit fields
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  children: [
                    _EditField(
                      ctrl: nameCtrl,
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    _EditField(
                      ctrl: phoneCtrl,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      inputType: TextInputType.phone,
                    ),
                    const SizedBox(height: 4),
                    // Email is read-only
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        borderRadius:
                        BorderRadius.circular(TwTheme.radiusMd),
                        color: TwTheme.darkBg.withOpacity(0.5),
                        border: Border.all(color: TwTheme.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined,
                              color: TwTheme.textLow, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(email,
                                style: TwTheme.body
                                    .copyWith(color: TwTheme.textLow)),
                          ),
                          Text('cannot change',
                              style: TwTheme.caption
                                  .copyWith(fontSize: 9)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Save / Cancel
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: onCancel,
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    TwTheme.radiusMd),
                                color: TwTheme.darkBg,
                                border: Border.all(
                                    color: TwTheme.divider),
                              ),
                              child: const Center(
                                child: Text('Cancel',
                                    style: TextStyle(
                                        color: TwTheme.textMid,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: savingEdit ? null : onSave,
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    TwTheme.radiusMd),
                                gradient: TwTheme.primaryGradient,
                                boxShadow: TwTheme.primaryGlow,
                              ),
                              child: Center(
                                child: savingEdit
                                    ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2))
                                    : const Text('Save Changes',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight:
                                        FontWeight.bold,
                                        fontSize: 13)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final bool     isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TwTheme.primary.withOpacity(0.1),
                ),
                child: Icon(icon, color: TwTheme.primary, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TwTheme.caption),
                    const SizedBox(height: 2),
                    Text(value, style: TwTheme.titleSm.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(height: 1, color: TwTheme.divider),
          ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String   label;
  final IconData icon;
  final TextInputType inputType;

  const _EditField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.inputType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      style: const TextStyle(color: TwTheme.textHigh, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        const TextStyle(color: TwTheme.textMid, fontSize: 13),
        prefixIcon: Icon(icon, color: TwTheme.textLow, size: 20),
        filled: true,
        fillColor: TwTheme.darkBg.withOpacity(0.5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            borderSide: const BorderSide(color: TwTheme.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            borderSide: const BorderSide(color: TwTheme.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            borderSide:
            const BorderSide(color: TwTheme.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SETTINGS TILES
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsTiles extends StatelessWidget {
  final VoidCallback onChangePassword;
  final VoidCallback onSignOut;

  const _SettingsTiles({
    required this.onChangePassword,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 3, height: 16,
                  decoration: BoxDecoration(
                    gradient: TwTheme.accentGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Account Settings', style: TwTheme.titleSm),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              color: TwTheme.cardBg,
              border: Border.all(color: TwTheme.divider),
            ),
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.lock_reset_rounded,
                  label: 'Change Password',
                  subtitle: 'Send a reset link to your email',
                  iconColor: TwTheme.accent,
                  onTap: onChangePassword,
                ),
                Container(height: 1, color: TwTheme.divider,
                    margin: const EdgeInsets.symmetric(horizontal: 16)),
                _SettingTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  subtitle: 'Manage booking alerts',
                  iconColor: const Color(0xFF4A90D9),
                  onTap: () {},
                  showArrow: true,
                ),
                Container(height: 1, color: TwTheme.divider,
                    margin: const EdgeInsets.symmetric(horizontal: 16)),
                _SettingTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  subtitle: 'Contact our team',
                  iconColor: TwTheme.success,
                  onTap: () {},
                  showArrow: true,
                ),
                Container(height: 1, color: TwTheme.divider,
                    margin: const EdgeInsets.symmetric(horizontal: 16)),
                _SettingTile(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  subtitle: 'Log out of Tiwigsstrand',
                  iconColor: TwTheme.error,
                  labelColor: TwTheme.error,
                  onTap: onSignOut,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // App version footer
          Center(
            child: Column(
              children: [
                const Text('👑',
                    style: TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text('Tiwigsstrand v1.0.0',
                    style: TwTheme.caption),
                const SizedBox(height: 2),
                Text('Wig Making · Revamping · Styling',
                    style: TwTheme.caption.copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatefulWidget {
  final IconData icon;
  final String   label, subtitle;
  final Color    iconColor;
  final Color?   labelColor;
  final VoidCallback onTap;
  final bool showArrow;

  const _SettingTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
    this.labelColor,
    this.showArrow = false,
  });

  @override
  State<_SettingTile> createState() => _SettingTileState();
}

class _SettingTileState extends State<_SettingTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _pressed
            ? TwTheme.primary.withOpacity(0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.iconColor.withOpacity(0.1),
              ),
              child: Icon(widget.icon,
                  color: widget.iconColor, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: TwTheme.titleSm.copyWith(
                          fontSize: 13,
                          color:
                          widget.labelColor ?? TwTheme.textHigh)),
                  const SizedBox(height: 2),
                  Text(widget.subtitle,
                      style: TwTheme.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
            Icon(
              widget.showArrow
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.chevron_right_rounded,
              color: TwTheme.textLow,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SKELETON LOADER
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileSkeleton extends StatefulWidget {
  const _ProfileSkeleton();

  @override
  State<_ProfileSkeleton> createState() => _ProfileSkeletonState();
}

class _ProfileSkeletonState extends State<_ProfileSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
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
      builder: (_, __) {
        final c = TwTheme.cardBg.withOpacity(_anim.value);
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Hero skeleton
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: TwTheme.primary.withOpacity(_anim.value * 0.5),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(TwTheme.radiusXl)),
                  ),
                ),
                const SizedBox(height: 20),
                // Stats skeleton
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: List.generate(
                        3,
                            (_) => Expanded(
                          child: Container(
                            margin:
                            const EdgeInsets.only(right: 10),
                            height: 70,
                            decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(
                                    TwTheme.radiusMd)),
                          ),
                        )),
                  ),
                ),
                const SizedBox(height: 16),
                // Card skeleton
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                        color: c,
                        borderRadius:
                        BorderRadius.circular(TwTheme.radiusMd)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}