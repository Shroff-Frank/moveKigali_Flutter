import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:movekigali/services/firestore_service.dart';
import 'package:movekigali/user_state.dart' as user_state;
import 'package:movekigali/utils/localization.dart';
import '../../dashboard/home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String languageCode;
  const RegisterScreen({super.key, this.languageCode = 'rw'});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController nameController     = TextEditingController();
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController phoneController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController  = TextEditingController();

  bool hidePassword = true;
  bool hideConfirm  = true;
  bool isLoading    = false;
  String selectedLanguage = 'rw';

  String countryCode = "+250";
  String? topErrorMessage;

  // ── Animated gradient button ──────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<Color?> _colorAnimation1;
  late Animation<Color?> _colorAnimation2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedLanguage = widget.languageCode;
    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);

    _colorAnimation1 = ColorTween(
      begin: Colors.orangeAccent,
      end:   Colors.deepOrange,
    ).animate(_animController);

    _colorAnimation2 = ColorTween(
      begin: Colors.deepOrange,
      end:   Colors.orangeAccent,
    ).animate(_animController);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      nameController.clear();
      emailController.clear();
      phoneController.clear();
      passwordController.clear();
      confirmController.clear();
      setState(() => topErrorMessage = null);
    }
  }

  void _clearError() {
    if (topErrorMessage != null) {
      setState(() => topErrorMessage = null);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REGISTER — Firebase Auth + Firestore
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> register() async {
    final languageCode = supportedLanguages.any((item) => item['code'] == selectedLanguage)
        ? selectedLanguage
        : 'rw';

    // ── 1. Basic validation ─────────────────────────────────────────────────
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        confirmController.text.isEmpty) {
      setState(() => topErrorMessage = translate('please_fill_all_fields', languageCode));
      return;
    }

    if (passwordController.text != confirmController.text) {
      _showSnack(translate('passwords_do_not_match', languageCode), Colors.red);
      return;
    }

    final phoneDigits = phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^[0-9]{9}$').hasMatch(phoneDigits)) {
      _showSnack(translate('enter_valid_phone', languageCode), Colors.orange);
      return;
    }

    if (!_isStrongPassword(passwordController.text)) {
      _showSnack(
        "Choose a stronger password: 8+ chars, uppercase, lowercase, number, and symbol",
        Colors.orange,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // ── 2. Create account in Firebase Auth ──────────────────────────────
      final UserCredential credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email:    emailController.text.trim(),
            password: passwordController.text,
          );

      final User? user = credential.user;
      if (user == null) throw Exception("User creation failed");

      // ── 3. Update display name in Firebase Auth ─────────────────────────
      await user.updateDisplayName(nameController.text.trim());
      await user.sendEmailVerification();

      // ── 4. Save full profile to Firestore via shared service ───────────
      final String fullPhone = "$countryCode$phoneDigits";
      final userData = user_state.UserData(
        uid:          user.uid,
        name:         nameController.text.trim(),
        email:        emailController.text.trim(),
        phone:        fullPhone,
        nickName:     '',
        profileImage: '',
        buspoints:    0,
        fcmToken:     '',
      );

      try {
        await FirestoreService.saveUserData(userData);
      } catch (e) {
        // If Firestore write fails after the auth user was created, remove the auth user
        // to avoid accounts without matching profile documents.
        try {
          await user.delete();
        } catch (deleteError) {
          debugPrint('Failed to clean up partially created user: $deleteError');
        }
        rethrow;
      }

      // ── 5. Navigate to HomeScreen ────────────────────────────────────────
      if (!mounted) return;
      _showSnack("Account created successfully! 🎉 Please check your email for verification.", Colors.green);

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            username:    nameController.text.trim(),
            userEmail:   emailController.text.trim(),
            phoneNumber: fullPhone,
          ),
        ),
        (route) => false, // remove all previous routes
      );

    } on FirebaseAuthException catch (e) {
      // ── Firebase Auth errors with friendly messages ─────────────────────
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered. Try logging in.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'network-request-failed':
          message = 'No internet connection. Please check your network.';
          break;
        default:
          message = 'Registration failed: ${e.message}';
      }
      _showSnack(message, Colors.red);

    } on FirebaseException catch (e) {
      _showSnack('Registration failed: ${e.message}', Colors.red);
      debugPrint('Register Firestore error: $e');

    } catch (e) {
      _showSnack('Something went wrong. Please try again.', Colors.red);
      debugPrint('Register error: $e');

    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── Helper: show snackbar ─────────────────────────────────────────────────
  bool _isStrongPassword(String value) {
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasDigit = value.contains(RegExp(r'\d'));
    final hasSymbol = value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    return value.length >= 8 && hasUpper && hasLower && hasDigit && hasSymbol;
  }

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

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD — UI stays exactly the same
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final languageCode = supportedLanguages.any((item) => item['code'] == selectedLanguage)
        ? selectedLanguage
        : 'rw';

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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
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
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: MediaQuery.of(context).size.width > 600 ? 40 : 20,
                                vertical: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'moveKigali Account',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Andika umwirondo wawe kugira ngo ukomeze',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
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
                                  fieldLabel(translate('full_name', languageCode)),
                                  cardInputField(
                                    nameController,
                                    requiredHint(translate('full_name', languageCode)),
                                    Icons.person,
                                    onChanged: (_) => _clearError(),
                                  ),
                                  const SizedBox(height: 16),
                                  fieldLabel(translate('email_address', languageCode)),
                                  cardInputField(
                                    emailController,
                                    requiredHint(translate('email_address', languageCode)),
                                    Icons.email,
                                    onChanged: (_) => _clearError(),
                                  ),
                                  const SizedBox(height: 16),
                                  fieldLabel(translate('phone', languageCode)),
                                  phoneField(languageCode),
                                  const SizedBox(height: 16),
                                  fieldLabel(translate('password', languageCode)),
                                  passwordField(languageCode),
                                  const SizedBox(height: 8),
                                  passwordRequirements(),
                                  const SizedBox(height: 16),
                                  fieldLabel(translate('confirm_password', languageCode)),
                                  confirmPasswordField(languageCode),
                                  const SizedBox(height: 18),
                                  termsRow(languageCode),
                                  const SizedBox(height: 20),
                                  loadingBranding(),
                                  animatedSignUpButton(languageCode),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        translate('already_have_account', languageCode),
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const LoginScreen(),
                                          ),
                                        ),
                                        child: Text(
                                          translate('login', languageCode),
                                          style: const TextStyle(
                                            color: Colors.orangeAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  bottomDivider(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets (unchanged) ───────────────────────────────────────────────────
  Widget cardInputField(
      TextEditingController controller, String hint, IconData icon,
      {ValueChanged<String>? onChanged}) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black26,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black45),
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

  Widget phoneField(String languageCode) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black26,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CountryCodePicker(
              initialSelection: 'RW',
              favorite: const ['+250', 'RW'],
              showFlag: true,
              showCountryOnly: false,
              onChanged: (code) =>
                  setState(() => countryCode = code.dialCode ?? "+250"),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: requiredHint(translate('phone_number', languageCode)),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget passwordGuidelines(String languageCode) {
    return const SizedBox.shrink();
  }

  Widget passwordRequirements() {
    const textStyle = TextStyle(color: Colors.white70, fontSize: 12, height: 1.4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('. Must be at least 8 characters', style: textStyle),
        Text('. Must have at least 1 number', style: textStyle),
        Text('. Must have at least one capital letter', style: textStyle),
        Text('. Must have at least one lowercase letter', style: textStyle),
        Text('. Must have a special character (.!*/-+)', style: textStyle),
      ],
    );
  }

  Widget fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }

  Widget passwordField(String languageCode) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black26,
      child: TextField(
        controller: passwordController,
        obscureText: hidePassword,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: requiredHint(translate('password', languageCode)),
          hintStyle: const TextStyle(color: Colors.black45),
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

  String requiredHint(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('*') ? trimmed : '$trimmed *';
  }

  Widget confirmPasswordField(String languageCode) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black26,
      child: TextField(
        controller: confirmController,
        obscureText: hideConfirm,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: requiredHint(translate('confirm_password', languageCode)),
          hintStyle: const TextStyle(color: Colors.black45),
          prefixIcon: const Icon(Icons.lock, color: Colors.black45),
          suffixIcon: IconButton(
            icon: Icon(
                hideConfirm ? Icons.visibility_off : Icons.visibility,
                color: Colors.black45),
            onPressed: () => setState(() => hideConfirm = !hideConfirm),
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

  Widget termsRow(String languageCode) {
    return languageCode == 'rw'
        ? RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              children: [
                const TextSpan(text: 'Mu kwinjira, wemera '),
                TextSpan(
                  text: 'Amategeko agenga imikorere',
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
                const TextSpan(text: ' harimo na '),
                TextSpan(
                  text: 'Politiki y\'ibanga',
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
                const TextSpan(text: ' ya moveKigali.'),
              ],
            ),
          )
        : Text(
            translate('agree_terms', languageCode),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          );
  }

  Widget loadingBranding() {
    return isLoading
        ? Column(
            children: const [
              Text(
                'movekigali',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
              SizedBox(height: 12),
            ],
          )
        : const SizedBox.shrink();
  }

  Widget animatedSignUpButton(String languageCode) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) => Opacity(
        opacity: isLoading ? 0.6 : 1.0,
        child: Container(
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [_colorAnimation1.value!, _colorAnimation2.value!],
            ),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white24,
              onTap: isLoading ? null : register,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        translate('sign_up', languageCode),
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

  Widget bottomDivider() {
    return Center(
      child: Container(
        width: 100,
        height: 4,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10)),
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