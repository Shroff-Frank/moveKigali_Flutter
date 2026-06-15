import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:movekigali/screens/dashboard/home_screen.dart';
import 'package:movekigali/screens/login/register/login_screen.dart';
import 'package:movekigali/screens/shared/loading_screen.dart';
import 'package:movekigali/utils/localization.dart';
import 'package:movekigali/user_state.dart' as user_state;
import 'package:movekigali/services/firestore_service.dart';

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
  String? nameFieldError;
  String? emailFieldError;
  String? phoneFieldError;
  String? passwordFieldError;
  String? confirmFieldError;

  // â”€â”€ Animated gradient button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    if (topErrorMessage != null ||
        nameFieldError != null ||
        emailFieldError != null ||
        phoneFieldError != null ||
        passwordFieldError != null ||
        confirmFieldError != null) {
      setState(() {
        topErrorMessage = null;
        nameFieldError = null;
        emailFieldError = null;
        phoneFieldError = null;
        passwordFieldError = null;
        confirmFieldError = null;
      });
    }
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // REGISTER â€” Firebase Auth + Firestore
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  Future<void> register() async {
    final languageCode = supportedLanguages.any((item) => item['code'] == selectedLanguage)
        ? selectedLanguage
        : 'rw';

    // â”€â”€ 1. Basic validation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    final fullName = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmController.text;
      final phoneDigits = phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final emailValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+').hasMatch(email);

    setState(() {
      topErrorMessage = null;
      nameFieldError = fullName.isEmpty ? translate('please_fill_all_fields', languageCode) : null;
      emailFieldError = email.isEmpty
          ? translate('email_address', languageCode)
          : (!emailValid ? 'Enter a valid email address' : null);
      phoneFieldError = phoneController.text.isEmpty
          ? translate('phone_number', languageCode)
          : (!RegExp(r'^[0-9]{9}$').hasMatch(phoneDigits)
              ? translate('enter_valid_phone', languageCode)
              : null);
      passwordFieldError = password.isEmpty
          ? translate('password', languageCode)
          : (!_isStrongPassword(password)
              ? translate('password_guidelines', languageCode)
              : null);
      confirmFieldError = confirmPassword.isEmpty
          ? translate('confirm_password', languageCode)
          : (password != confirmPassword ? translate('passwords_do_not_match', languageCode) : null);
    });

    if (nameFieldError != null ||
        emailFieldError != null ||
        phoneFieldError != null ||
        passwordFieldError != null ||
        confirmFieldError != null) {
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LoadingScreen(
        label: 'movekigali',
        message: 'Creating account...',
      ),
    ));

    setState(() {
      isLoading = true;
      topErrorMessage = null;
    });

    var authSucceeded = false;
    try {
      // â”€â”€ 2. Create account in Firebase Auth â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      final UserCredential credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email:    emailController.text.trim(),
            password: passwordController.text,
          );

      final User? user = credential.user;
      if (user == null) throw Exception("User creation failed");

      // â”€â”€ 3. Update display name in Firebase Auth â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      await user.updateDisplayName(nameController.text.trim());
      await user.sendEmailVerification();

      // â”€â”€ 4. Save full profile to Firestore via shared service â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

      // â”€â”€ 5. Navigate to HomeScreen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      if (!mounted) return;
      _showSnack("Account created successfully! ðŸŽ‰ Please check your email for verification.", Colors.green);

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      await Navigator.pushAndRemoveUntil(
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
      authSucceeded = true;

    } on FirebaseAuthException catch (e) {
      // â”€â”€ Firebase Auth errors with friendly messages â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
      if (mounted && !authSucceeded) {
        Navigator.of(context).pop();
      }
    }
  }

  // â”€â”€ Helper: show snackbar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  // BUILD â€” UI stays exactly the same
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
                                    'Fungura konti yawe ya\nmoveKigali',
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
                                  fieldLabel('${translate('full_name', languageCode)} *'),
                                  cardInputField(
                                    nameController,
                                    translate('full_name', languageCode),
                                    Icons.person,
                                    errorText: nameFieldError,
                                    onChanged: (_) => _clearError(),
                                  ),
                                  const SizedBox(height: 16),
                                  fieldLabel('${translate('email_address', languageCode)} *'),
                                  cardInputField(
                                    emailController,
                                    translate('email_address', languageCode),
                                    Icons.email,
                                    errorText: emailFieldError,
                                    onChanged: (_) => _clearError(),
                                  ),
                                  const SizedBox(height: 16),
                                  fieldLabel('${translate('phone', languageCode)} *'),
                                  phoneField(languageCode, errorText: phoneFieldError),
                                  const SizedBox(height: 16),
                                  fieldLabel('${translate('password', languageCode)} *'),
                                  passwordField(languageCode, errorText: passwordFieldError, controller: passwordController),
                                  const SizedBox(height: 16),
                                  fieldLabel('${translate('confirm_password', languageCode)} *'),
                                  passwordField(languageCode, errorText: confirmFieldError, controller: confirmController),
                                  const SizedBox(height: 8),
                                  passwordRequirements(),
                                  const SizedBox(height: 16),
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
                                            builder: (_) => LoginScreen(languageCode: languageCode),
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

  // â”€â”€ Widgets (unchanged) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    Widget cardInputField(
      TextEditingController controller,
      String hint,
      IconData icon,
      {String? errorText,
      ValueChanged<String>? onChanged,
      TextInputType keyboardType = TextInputType.text}) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black26,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          errorText: errorText,
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

  Widget phoneField(String languageCode, {String? errorText}) {
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
                   onChanged: (_) => _clearError(),
                   decoration: InputDecoration(
                     hintText: translate('phone_number', languageCode),
                     errorText: errorText,
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

  Widget passwordField(String languageCode,
      {String? errorText, required TextEditingController controller}) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black26,
      child: TextField(
        controller: controller,
        obscureText: controller == confirmController ? hideConfirm : hidePassword,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: errorText ?? translate('password', languageCode),
          hintStyle: const TextStyle(color: Colors.black45),
          errorText: errorText,
          prefixIcon: const Icon(Icons.lock, color: Colors.black45),
          suffixIcon: IconButton(
            icon: Icon(
                controller == confirmController
                    ? (hideConfirm ? Icons.visibility_off : Icons.visibility)
                    : (hidePassword ? Icons.visibility_off : Icons.visibility),
                color: Colors.black45),
            onPressed: () => setState(() {
              if (controller == confirmController) {
                hideConfirm = !hideConfirm;
              } else {
                hidePassword = !hidePassword;
              }
            }),
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
    return const SizedBox.shrink();
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
