import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:movekigali/utils/localization.dart';
import '../../dashboard/home_screen.dart';
import '../../shared/loading_screen.dart';
import 'register_screen.dart';
import 'forgotpassword.dart';

class LoginScreen extends StatefulWidget {
  final String languageCode;

  const LoginScreen({super.key, this.languageCode = 'rw'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool rememberMe     = false;
  bool hidePassword   = true;
  bool isLoading      = false;
  bool usePhoneLogin  = true;
  String selectedLanguage = 'rw';

  String? topErrorMessage;

  late AnimationController _controller;
  late Animation<Color?> _color1;
  late Animation<Color?> _color2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedLanguage = widget.languageCode;

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);

    _color1 = ColorTween(
      begin: Colors.orangeAccent,
      end:   Colors.deepOrange,
    ).animate(_controller);

    _color2 = ColorTween(
      begin: Colors.deepOrange,
      end:   Colors.orangeAccent,
    ).animate(_controller);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      emailController.clear();
      passwordController.clear();
      setState(() => topErrorMessage = null);
    }
  }

  void _clearError() {
    if (topErrorMessage != null) {
      setState(() => topErrorMessage = null);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGIN — Firebase Auth + load profile from Firestore
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> login() async {
    final identifier = emailController.text.trim();
    if (identifier.isEmpty) {
      setState(() => topErrorMessage =
          'Enter your email or phone number above to continue.');
      return;
    }
    if (passwordController.text.isEmpty) {
      setState(() => topErrorMessage =
          'Enter your password above to continue.');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LoadingScreen(
        label: 'movekigali',
        message: 'Signing in...',
      ),
    ));

    setState(() {
      isLoading = true;
      topErrorMessage = null;
    });

    var authSucceeded = false;
    try {
      String email = identifier;
      if (usePhoneLogin) {
        final phoneDigits = identifier.replaceAll(RegExp(r'[^0-9]'), '');
        if (!RegExp(r'^[0-9]{9}$').hasMatch(phoneDigits)) {
          throw FirebaseAuthException(
            code: 'invalid-phone',
            message: 'Enter a valid 9-digit Rwanda phone number.',
          );
        }

        final fullPhone = '+250$phoneDigits';
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: fullPhone)
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No account found for this phone number.',
          );
        }

        email = query.docs.first.data()['email'] as String? ?? '';
        if (email.isEmpty) {
          throw FirebaseAuthException(
            code: 'missing-email',
            message: 'The account associated with this phone number does not have an email on record.',
          );
        }
      }

      final UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email:    email,
            password: passwordController.text,
          );

      final User? user = credential.user;
      if (user == null) throw Exception('Login failed');

      authSucceeded = true;
      debugPrint('✅ Logged in: ${user.uid}');

      // ── 3. Load profile from Firestore ───────────────────────────────────
      String name        = user.displayName ?? '';
      String phone       = '';
      String nickName    = '';
      String profileImage= '';
      int    buspoints   = 0;

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final d     = doc.data()!;
          name        = d['name']         ?? name;
          phone       = d['phone']        ?? '';
          nickName    = d['nickName']     ?? '';
          profileImage= d['profileImage'] ?? '';
          buspoints   = (d['buspoints']   ?? 0) as int;
        }
      } catch (e) {
        debugPrint('Firestore load warning: $e');
        // Not fatal — we still have the Auth user, continue to home
      }

      if (!mounted) return;

      // ── 4. Navigate to HomeScreen with real user data ────────────────────
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            username:         name.isNotEmpty ? name : user.email ?? 'User',
            profileImagePath: profileImage.isNotEmpty ? profileImage : null,
            userEmail:        user.email ?? '',
            phoneNumber:      phone,
            nickName:         nickName,
          ),
        ),
        (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      // ── Friendly error messages ──────────────────────────────────────────
      String message;
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-credential':
          message = 'No account found with these details. Please register first.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled. Contact support.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'No internet connection. Please check your network.';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }
      _showSnack(message, Colors.red);

    } catch (e) {
      _showSnack('Something went wrong. Please try again.', Colors.red);
      debugPrint('Login error: $e');

    } finally {
      if (mounted && !authSucceeded) {
        Navigator.of(context).pop();
      }
    }
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void forgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD — UI stays exactly the same
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final languageCode = supportedLanguages.any((item) => item['code'] == selectedLanguage)
        ? selectedLanguage
        : 'rw';
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/centre.png", fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth > 600 ? 48 : 24,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _openLanguagePicker,
                            icon: const Icon(Icons.menu, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'moveKigali Account',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const SizedBox(height: 18),
                      Text(
                        translate('sign_in_to_movekigali', languageCode),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        translate('enter_your_email_or_phone', languageCode),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _loginChoiceButton(
                              label: translate('phone', languageCode),
                              selected: usePhoneLogin,
                              onTap: () => setState(() {
                                usePhoneLogin = true;
                                _clearError();
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _loginChoiceButton(
                              label: translate('email', languageCode),
                              selected: !usePhoneLogin,
                              onTap: () => setState(() {
                                usePhoneLogin = false;
                                _clearError();
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (topErrorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            topErrorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Text(
                        translate(usePhoneLogin ? 'phone' : 'email', languageCode),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      cardInputField(
                        controller: emailController,
                        hint: usePhoneLogin
                            ? translate('phone_number', languageCode)
                            : translate('email_address', languageCode),
                        icon: Icons.person,
                        keyboardType: usePhoneLogin
                            ? TextInputType.phone
                            : TextInputType.emailAddress,
                        onChanged: (_) => _clearError(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        translate('password', languageCode),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      passwordField(),
                      const SizedBox(height: 12),
                      loadingBranding(),
                      rememberForgotRow(languageCode),
                      const SizedBox(height: 16),
                      animatedLoginButton(languageCode),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          translate('by_logging_in_terms', languageCode),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 18),
                      registerRow(languageCode),
                      const SizedBox(height: 12),
                      bottomDivider(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets (unchanged) ───────────────────────────────────────────────────
  Widget cardInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.black45),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget passwordField() {
    final languageCode = supportedLanguages.any((item) => item['code'] == selectedLanguage)
        ? selectedLanguage
        : 'rw';
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: TextField(
        controller: passwordController,
        obscureText: hidePassword,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: translate('password', languageCode),
          prefixIcon: const Icon(Icons.lock, color: Colors.black45),
          suffixIcon: IconButton(
            icon: Icon(
                hidePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.black45),
            onPressed: () => setState(() => hidePassword = !hidePassword),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _loginChoiceButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? Colors.orangeAccent : Colors.white12,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget rememberForgotRow(String languageCode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: forgotPassword,
          child: Text(
            translate('forgot_password', languageCode),
            style: const TextStyle(
                color: Colors.orangeAccent,
                decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }

  Widget loadingBranding() {
    return const SizedBox.shrink();
  }

  Widget animatedLoginButton(String languageCode) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: isLoading ? 0.6 : 1.0,
        child: Container(
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient:
                LinearGradient(colors: [_color1.value!, _color2.value!]),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isLoading ? null : login,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        translate('sign_in', languageCode),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget registerRow(String languageCode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(translate('dont_have_account', languageCode),
            style: const TextStyle(color: Colors.white70)),
        TextButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => RegisterScreen(languageCode: languageCode)),
          ),
          child: Text(translate('register', languageCode),
              style: const TextStyle(
                  color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget bottomDivider() {
    return Center(
      child: Container(
        width: 100, height: 4,
        decoration: BoxDecoration(
            color: Colors.white70, borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openLanguagePicker() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Language selector',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.72,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF0D1C22),
                borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    translate('language_title', selectedLanguage),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    translate('language_subtitle', selectedLanguage),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: ListView.separated(
                      itemCount: supportedLanguages.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                      itemBuilder: (context, index) {
                        final language = supportedLanguages[index];
                        final code = language['code']!;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${language['flag']} ${language['name']}',
                            style: TextStyle(
                              color: code == selectedLanguage ? Colors.orangeAccent : Colors.white,
                              fontSize: 16,
                              fontWeight: code == selectedLanguage ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            setState(() => selectedLanguage = code);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}