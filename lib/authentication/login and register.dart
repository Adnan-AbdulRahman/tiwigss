import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tiwigsstrand/pages/stylist/stylist.dart';

import '../pages/admin/admin_homepage.dart';
import '../pages/customer/customer_homepage.dart';

// ─── Replace these with your actual route screens ───────────────────────────
// import 'customer_home.dart';
// import 'stylist_dashboard.dart';

class TiwigsstrandLoginPage extends StatefulWidget {
  const TiwigsstrandLoginPage({super.key});

  @override
  State<TiwigsstrandLoginPage> createState() => _TiwigsstrandLoginPageState();
}

class _TiwigsstrandLoginPageState extends State<TiwigsstrandLoginPage>
    with TickerProviderStateMixin {

  // ── Brand Colors ──────────────────────────────────────────────────────────
  static const Color kPrimary    = Color(0xFF8B1A4A);  // Deep rose/burgundy
  static const Color kAccent     = Color(0xFFD4A853);  // Warm gold
  static const Color kDark       = Color(0xFF1C0A14);  // Very dark wine
  static const Color kCardBg     = Color(0xFF2A1020);  // Deep plum card
  static const Color kText       = Color(0xFFF5E6EE);  // Soft blush white
  static const Color kSubText    = Color(0xFFB08090);  // Muted rose

  // ── Hardcoded admin bootstrap credentials ─────────────────────────────────
  // Kept in one place so TiwigsstrandLandingPage's kAdminEmail check and this
  // login form always agree. This does NOT bypass Firebase Auth — it still
  // goes through signInWithEmailAndPassword / createUserWithEmailAndPassword,
  // it just auto-creates the admin account the very first time it's used so
  // you don't have to add it by hand in the Firebase Console.
  static const String kAdminEmail    = 'admin@gmail.com';
  static const String kAdminPassword = 'tiwigsstrand';

  // ── Tab & form state ──────────────────────────────────────────────────────
  int _selectedTab = 0;
  bool _loginFormLoading = false;
  bool _signupFormLoading = false;

  // ── Form keys ─────────────────────────────────────────────────────────────
  final _loginFormKey  = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  // ── Login controllers ─────────────────────────────────────────────────────
  final _loginEmailCtrl    = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginPasswordVisible = false;
  bool _rememberMe = false;

  // ── Sign-up controllers ───────────────────────────────────────────────────
  final _signupNameCtrl     = TextEditingController();
  final _signupEmailCtrl    = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();
  final _signupPhoneCtrl    = TextEditingController();
  bool   _signupPasswordVisible = false;
  bool   _agreeTerms = false;
  // Roles are now Customer and Stylist (wig business)
  String _signupRole = 'Customer';

  // ── Focus nodes ───────────────────────────────────────────────────────────
  final FocusNode _loginEmailFocus    = FocusNode();
  final FocusNode _loginPasswordFocus = FocusNode();
  final FocusNode _signupNameFocus    = FocusNode();
  final FocusNode _signupEmailFocus   = FocusNode();
  final FocusNode _signupPasswordFocus = FocusNode();
  final FocusNode _signupPhoneFocus   = FocusNode();

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _logoController;
  late AnimationController _logoScaleController;
  late AnimationController _formController;
  late AnimationController _tabSlideController;
  late AnimationController _shakeController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFloat;
  late Animation<double> _formSlide;
  late Animation<double> _formFade;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _logoScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoScaleController, curve: Curves.elasticOut),
    );

    _logoFloat = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _formSlide = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic),
    );
    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeIn),
    );

    _tabSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0,   end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end:  12), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  12, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end:  10), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  10, end:   0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _logoScaleController.dispose();
    _formController.dispose();
    _tabSlideController.dispose();
    _shakeController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPasswordCtrl.dispose();
    _signupPhoneCtrl.dispose();
    _loginEmailFocus.dispose();
    _loginPasswordFocus.dispose();
    _signupNameFocus.dispose();
    _signupEmailFocus.dispose();
    _signupPasswordFocus.dispose();
    _signupPhoneFocus.dispose();
    super.dispose();
  }

  // ── Tab switch ────────────────────────────────────────────────────────────
  void _switchTab(int tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
    if (tab == 1) {
      _tabSlideController.forward();
    } else {
      _tabSlideController.reverse();
    }
    _formController.reset();
    _formController.forward();
  }

  // ── Error dialog ──────────────────────────────────────────────────────────
  void _showErrorDialog(String message) {
    _shakeController.forward(from: 0);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: kAccent, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Oops!',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ],
        ),
        content: Text(message,
            style: TextStyle(color: kText.withOpacity(0.85))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(
                    color: kAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isSuccess ? kPrimary : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── LOGIN LOGIC ───────────────────────────────────────────────────────────
  Future<void> _submitLoginForm() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _loginFormLoading = true);
    try {
      await _loginAccount(
        email: _loginEmailCtrl.text.trim(),
        password: _loginPasswordCtrl.text.trim(),
      );
    } finally {
      if (mounted) setState(() => _loginFormLoading = false);
    }
  }

  Future<void> _loginAccount(
      {required String email, required String password}) async {
    try {
      final bool isAdminAttempt =
          email == kAdminEmail && password == kAdminPassword;

      UserCredential credential;

      if (isAdminAttempt) {
        // ── Admin bootstrap ───────────────────────────────────────────────
        // Try a normal sign-in first. If the admin account doesn't exist
        // yet in Firebase Auth, create it (and its Firestore profile) on
        // the spot, so this credential pair "just works" without anyone
        // having to add the user in the Firebase Console beforehand.
        try {
          credential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(email: email, password: password);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found') {
            credential = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
                email: email, password: password);

            await FirebaseFirestore.instance
                .collection('users')
                .doc(credential.user!.uid)
                .set({
              'fullName'            : 'Admin',
              'email'               : email,
              'phone'               : '',
              'role'                : 'Admin',
              'createdAt'           : FieldValue.serverTimestamp(),
              'uid'                 : credential.user!.uid,
              'profileImage'        : '',
              'notificationEnabled' : true,
              'isOnline'            : true,
              'wigOrdersCount'      : 0,
              'favouriteStyles'     : [],
            });
          } else {
            rethrow;
          }
        }
      } else {
        // 1. Normal Firebase Auth sign-in
        credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
      }

      final String uid = credential.user!.uid;

      // ── Admin shortcut: route straight to AdminHomepage by email ─────────
      // Mirrors the kAdminEmail check in TiwigsstrandLandingPage, so the
      // admin never depends on a Firestore doc existing/being correct.
      if (email == kAdminEmail) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          _fadeRoute(AdminHomepage()),
              (_) => false,
        );
        return;
      }

      // 2. Fetch Firestore user document
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          _showErrorDialog('Account data not found. Please contact support.');
        }
        return;
      }

      final data = userDoc.data() as Map<String, dynamic>?;
      final String role = (data?['role'] as String?) ?? 'Customer';

      if (!mounted) return;

      // 3. Route by role
      switch (role) {
        case 'Admin':
          Navigator.pushAndRemoveUntil(
            context,
            _fadeRoute(AdminHomepage()),
                (_) => false,
          );
          break;
        case 'Stylist':
          Navigator.pushAndRemoveUntil(
            context,
            _fadeRoute( StylistHomepage()),
                (_) => false,
          );
          break;
        case 'Customer':
        default:
          Navigator.pushAndRemoveUntil(
            context,
            _fadeRoute(CustomerHomepage()),
                (_) => false,
          );
          break;
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showErrorDialog(_friendlyAuthError(e));
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Something went wrong. Please try again.');
      }
    }
  }

  // ── SIGN UP LOGIC ─────────────────────────────────────────────────────────
  Future<void> _submitSignupForm() async {
    if (!_signupFormKey.currentState!.validate()) return;
    if (!_agreeTerms) {
      _showErrorDialog('Please agree to the Terms & Conditions to continue.');
      return;
    }
    setState(() => _signupFormLoading = true);
    try {
      // 1. Create Firebase Auth user
      final UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _signupEmailCtrl.text.trim(),
        password: _signupPasswordCtrl.text.trim(),
      );
      final String uid = userCredential.user!.uid;

      // 2. Save full profile to Firestore
      final userDocRef =
      FirebaseFirestore.instance.collection('users').doc(uid);
      await userDocRef.set({
        'fullName'            : _signupNameCtrl.text.trim(),
        'email'               : _signupEmailCtrl.text.trim(),
        'phone'               : _signupPhoneCtrl.text.trim(),
        'role'                : _signupRole,   // 'Customer' or 'Stylist'
        'createdAt'           : FieldValue.serverTimestamp(),
        'uid'                 : uid,
        'profileImage'        : '',
        'notificationEnabled' : true,
        'isOnline'            : true,
        // Wig-business specific fields
        'wigOrdersCount'      : 0,
        'favouriteStyles'     : [],
      });

      // 3. Verify doc was saved
      final userSnapshot = await userDocRef.get();
      if (!mounted) return;

      if (userSnapshot.exists) {
        _showSnack('Welcome to Tiwigsstrand! 🎉', isSuccess: true);

        // ✅ Replace _PlaceholderScreen with your actual screens
        if (_signupRole == 'Customer') {
          Navigator.pushAndRemoveUntil(
            context,
            _fadeRoute(const _PlaceholderScreen(
              title: 'Welcome to Tiwigsstrand',
              message:
              'Replace this with your CustomerHomePage() screen.\nImport it and swap the widget above.',
            )),
                (_) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            _fadeRoute(const _PlaceholderScreen(
              title: 'Stylist Dashboard',
              message:
              'Replace this with your StylistDashboard() screen.\nImport it and swap the widget above.',
            )),
                (_) => false,
          );
        }
      } else {
        _showErrorDialog('Error saving your data. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showErrorDialog(_friendlyAuthError(e));
    } catch (e) {
      if (mounted) _showErrorDialog('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _signupFormLoading = false);
    }
  }

  // ── Human-friendly Firebase error messages ────────────────────────────────
  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check and try again.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  // ── Smooth fade page route ────────────────────────────────────────────────
  Route _fadeRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 500),
  );

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.5,
            colors: [Color(0xFF3D0A28), Color(0xFF0E0409)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  _buildLogo(),
                  const SizedBox(height: 28),
                  _buildAnimatedForm(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── LOGO ──────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return ScaleTransition(
      scale: _logoScale,
      child: AnimatedBuilder(
        animation: _logoFloat,
        builder: (_, child) => Transform.translate(
            offset: Offset(0, _logoFloat.value), child: child),
        child: Column(
          children: [
            // Wig crown icon in a glowing circle
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [
                  Color(0xFF8B1A4A),
                  Color(0xFF4A0A28),
                  Colors.transparent,
                ], stops: [0.0, 0.55, 1.0]),
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withOpacity(0.55),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                child: Text('👑', style: TextStyle(fontSize: 52)),
              ),
            ),
            const SizedBox(height: 12),
            // Brand name
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Tiwigs',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: kAccent,
                      letterSpacing: 1.5,
                      shadows: [Shadow(color: kPrimary, blurRadius: 10)],
                    ),
                  ),
                  TextSpan(
                    text: 'strand',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: kText,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Wig Making · Revamping · Styling',
              style: TextStyle(
                fontSize: 11,
                color: kSubText,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ANIMATED FORM CARD ────────────────────────────────────────────────────
  Widget _buildAnimatedForm() {
    return AnimatedBuilder(
      animation: Listenable.merge([_formSlide, _formFade]),
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _formSlide.value),
        child: Opacity(opacity: _formFade.value, child: child),
      ),
      child: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.translate(
            offset: Offset(_shakeAnim.value, 0), child: child),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: kCardBg.withOpacity(0.88),
                border: Border.all(
                  color: kPrimary.withOpacity(0.25),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTabBar(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(
                        begin:
                        Offset(_selectedTab == 0 ? -0.15 : 0.15, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: _selectedTab == 0
                        ? _buildLoginForm()
                        : _buildSignupForm(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── TAB BAR ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: kDark.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border:
          Border.all(color: kPrimary.withOpacity(0.12), width: 1),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: _selectedTab == 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  height: 42,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: const LinearGradient(
                      colors: [kPrimary, Color(0xFF5C0F30)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimary.withOpacity(0.45),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _buildTab('Log In', 0),
                _buildTab('Sign Up', 1),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int idx) {
    final bool active = _selectedTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTab(idx),
        behavior: HitTestBehavior.opaque,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: active ? Colors.white : kSubText,
            fontWeight:
            active ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
          child: Center(child: Text(label)),
        ),
      ),
    );
  }

  // ── LOGIN FORM ────────────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Padding(
      key: const ValueKey('login'),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildLabel('Email Address'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _loginEmailCtrl,
              focusNode: _loginEmailFocus,
              nextFocus: _loginPasswordFocus,
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
            ),
            const SizedBox(height: 16),
            _buildLabel('Password'),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _loginPasswordCtrl,
              focusNode: _loginPasswordFocus,
              hint: '••••••••',
              visible: _loginPasswordVisible,
              onToggle: () => setState(
                      () => _loginPasswordVisible = !_loginPasswordVisible),
              validator: _passwordValidator,
              onFieldSubmitted: (_) => _submitLoginForm(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildCheckbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v!),
                  label: 'Remember me',
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _handleForgotPassword,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: kAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildActionButton(
              label: 'Log In',
              loading: _loginFormLoading,
              onPressed: _submitLoginForm,
            ),
            const SizedBox(height: 20),
            _buildDivider(),
            const SizedBox(height: 16),
            _buildSocialButtons(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // ── SIGN UP FORM ──────────────────────────────────────────────────────────
  Widget _buildSignupForm() {
    return Padding(
      key: const ValueKey('signup'),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _signupFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildLabel('Full Name'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _signupNameCtrl,
              focusNode: _signupNameFocus,
              nextFocus: _signupPhoneFocus,
              hint: 'e.g. Akosua Mensah',
              icon: Icons.person_outline_rounded,
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            _buildLabel('Phone Number'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _signupPhoneCtrl,
              focusNode: _signupPhoneFocus,
              nextFocus: _signupEmailFocus,
              hint: '+233 XX XXX XXXX',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter your phone number'
                  : null,
            ),
            const SizedBox(height: 16),
            _buildLabel('Email Address'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _signupEmailCtrl,
              focusNode: _signupEmailFocus,
              nextFocus: _signupPasswordFocus,
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
            ),
            const SizedBox(height: 16),
            _buildLabel('Password'),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _signupPasswordCtrl,
              focusNode: _signupPasswordFocus,
              hint: 'Min. 6 characters',
              visible: _signupPasswordVisible,
              onToggle: () => setState(
                      () => _signupPasswordVisible = !_signupPasswordVisible),
              validator: _passwordValidator,
              onFieldSubmitted: (_) => _submitSignupForm(),
            ),
            const SizedBox(height: 16),
            _buildLabel('I am joining as a'),
            const SizedBox(height: 8),
            _buildRoleSelector(),
            const SizedBox(height: 14),
            _buildTermsRow(),
            const SizedBox(height: 20),
            _buildActionButton(
              label: 'Create Account',
              loading: _signupFormLoading,
              onPressed: _submitSignupForm,
            ),
            const SizedBox(height: 20),
            _buildDivider(),
            const SizedBox(height: 16),
            _buildSocialButtons(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // ── Role selector (Customer / Stylist) ─────────────────────────────────────
  Widget _buildRoleSelector() {
    const roles = {
      'Customer': Icons.shopping_bag_outlined,
      'Stylist':  Icons.content_cut_rounded,
    };
    return Row(
      children: roles.entries.map((entry) {
        final role     = entry.key;
        final icon     = entry.value;
        final selected = _signupRole == role;
        final isFirst  = role == 'Customer';
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _signupRole = role),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: isFirst ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: selected
                    ? kPrimary.withOpacity(0.18)
                    : kDark.withOpacity(0.6),
                border: Border.all(
                  color: selected
                      ? kPrimary.withOpacity(0.8)
                      : const Color(0xFF444444),
                  width: selected ? 1.5 : 1.0,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: kPrimary.withOpacity(0.2), blurRadius: 12)]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: selected ? kAccent : kSubText, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    role,
                    style: TextStyle(
                      color: selected ? kAccent : kSubText,
                      fontWeight:
                      selected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── REUSABLE WIDGETS ──────────────────────────────────────────────────────
  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: kText,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return _StyledField(
      controller: controller,
      focusNode: focusNode,
      hint: hint,
      prefixIcon: icon,
      keyboardType: keyboardType,
      obscureText: false,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted ??
              (_) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            }
          },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return _StyledField(
      controller: controller,
      focusNode: focusNode,
      hint: hint,
      prefixIcon: Icons.lock_outline_rounded,
      obscureText: !visible,
      suffixIcon: IconButton(
        icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: kSubText,
          size: 20,
        ),
        onPressed: onToggle,
      ),
      validator: validator,
      onFieldSubmitted: onFieldSubmitted ?? (_) {},
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required void Function(bool?) onChanged,
    required String label,
  }) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: value ? kPrimary : Colors.transparent,
              border: Border.all(
                color: value ? kPrimary : const Color(0xFF555555),
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: kSubText, fontSize: 13)),
      ],
    );
  }

  Widget _buildTermsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _agreeTerms = !_agreeTerms),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: _agreeTerms ? kPrimary : Colors.transparent,
              border: Border.all(
                color:
                _agreeTerms ? kPrimary : const Color(0xFF555555),
                width: 1.5,
              ),
            ),
            child: _agreeTerms
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style:
              TextStyle(color: kSubText, fontSize: 12.5),
              children: const [
                TextSpan(text: 'I agree to Tiwigsstrand\'s '),
                TextSpan(
                  text: 'Terms & Conditions',
                  style: TextStyle(
                      color: kAccent, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: TextStyle(
                      color: kAccent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return _AnimatedButton(
      label: label,
      loading: loading,
      onPressed: onPressed,
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFF3D1530))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or continue with',
              style: TextStyle(color: kSubText, fontSize: 12)),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFF3D1530))),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            label: 'Google',
            icon: '🔴',
            onTap: () {/* TODO: Implement Google sign-in */},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            label: 'Facebook',
            icon: '🔵',
            onTap: () {/* TODO: Implement Facebook sign-in */},
          ),
        ),
      ],
    );
  }

  void _handleForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(),
    );
  }

  // ── Validators ─────────────────────────────────────────────────────────────
  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter your email';
    final emailReg = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailReg.hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  String? _passwordValidator(String? v) {
    if (v == null || v.isEmpty) return 'Enter your password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PLACEHOLDER SCREEN  — remove once you add your real screens
// ─────────────────────────────────────────────────────────────────────────────
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;
  const _PlaceholderScreen({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C0A14),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B1A4A).withOpacity(0.15),
                  border: Border.all(
                      color: const Color(0xFF8B1A4A).withOpacity(0.4)),
                ),
                child: const Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFFD4A853), size: 48),
              ),
              const SizedBox(height: 24),
              Text(title,
                  style: const TextStyle(
                    color: Color(0xFFD4A853),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 12),
              Text(
                '✅ Login successful!\n\n$message',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFB08090), fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STYLED TEXT FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _StyledField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String) onFieldSubmitted;

  const _StyledField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.prefixIcon,
    required this.obscureText,
    required this.onFieldSubmitted,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  State<_StyledField> createState() => _StyledFieldState();
}

class _StyledFieldState extends State<_StyledField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? const Color(0xFF8B1A4A).withOpacity(0.8)
              : const Color(0xFF444444),
          width: _focused ? 1.5 : 1.0,
        ),
        color: const Color(0xFF1C0A14).withOpacity(0.65),
        boxShadow: _focused
            ? [
          BoxShadow(
            color: const Color(0xFF8B1A4A).withOpacity(0.15),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle:
          const TextStyle(color: Color(0xFF5A3040), fontSize: 14),
          prefixIcon: Icon(widget.prefixIcon,
              color: _focused
                  ? const Color(0xFFD4A853)
                  : const Color(0xFF6A4050),
              size: 20),
          suffixIcon: widget.suffixIcon,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          errorStyle: const TextStyle(color: Color(0xFFFF8A9B), fontSize: 11),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ANIMATED SUBMIT BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedButton extends StatefulWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _AnimatedButton(
      {required this.label, required this.loading, required this.onPressed});

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _ctrl.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _ctrl.reverse();
        if (!widget.loading) widget.onPressed();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _ctrl.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: _pressed
                  ? [const Color(0xFF5C0F30), const Color(0xFF8B1A4A)]
                  : [const Color(0xFF8B1A4A), const Color(0xFF5C0F30)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B1A4A)
                    .withOpacity(_pressed ? 0.2 : 0.45),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            )
                : Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SOCIAL BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _SocialButton extends StatefulWidget {
  final String label;
  final String icon;
  final VoidCallback onTap;

  const _SocialButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) {
        setState(() => _hovered = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _hovered
              ? const Color(0xFF3D0A28)
              : const Color(0xFF1C0A14).withOpacity(0.6),
          border: Border.all(
            color: _hovered
                ? const Color(0xFF8B1A4A).withOpacity(0.5)
                : const Color(0xFF444444),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FORGOT PASSWORD BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ForgotPasswordSheet extends StatefulWidget {
  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _emailCtrl  = TextEditingController();
  final _focusNode  = FocusNode();
  bool  _loading    = false;
  bool  _sent       = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Error sending reset email.'),
            backgroundColor: const Color(0xFF3D0A28),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Color(0xFF2A1020),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _sent
          ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📧', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Reset Link Sent!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check your inbox and follow the instructions to reset your password.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFB08090), fontSize: 14),
          ),
          const SizedBox(height: 20),
          _AnimatedButton(
            label: 'Done',
            loading: false,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forgot Password?',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your email and we\'ll send you a reset link.',
            style: TextStyle(color: Color(0xFFB08090), fontSize: 13),
          ),
          const SizedBox(height: 20),
          _StyledField(
            controller: _emailCtrl,
            focusNode: _focusNode,
            hint: 'your@email.com',
            prefixIcon: Icons.email_outlined,
            obscureText: false,
            keyboardType: TextInputType.emailAddress,
            onFieldSubmitted: (_) => _sendReset(),
          ),
          const SizedBox(height: 20),
          _AnimatedButton(
            label: 'Send Reset Link',
            loading: _loading,
            onPressed: _sendReset,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}